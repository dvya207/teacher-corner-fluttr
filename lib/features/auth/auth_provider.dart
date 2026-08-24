import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/teacher_account.dart';
import '../../core/services/firestore_service.dart';

/// Which half of the two-step phone flow the login form is showing.
enum LoginStage { phoneEntry, codeEntry }

/// The programme runs in India only, so the dial code is a constant rather than
/// a country picker the teacher has to get past. If Teacher Corner ever ships
/// outside India this becomes a field on the form, not a wider regex.
const String kDialCode = '+91';

/// Indian mobile numbers are ten digits starting 6-9. Checked locally so an
/// obvious typo costs nothing, instead of spending an SMS to learn the same
/// thing from the server a second later.
final RegExp kIndianMobile = RegExp(r'^[6-9]\d{9}$');

/// How long to wait on a callable before giving up. A teacher on school wifi
/// mid-class needs an error message, not a spinner that never resolves.
const Duration kVerificationTimeout = Duration(seconds: 90);

/// The region the forked OTP functions are deployed to. Getting this wrong does
/// not fail loudly: the client calls us-central1, finds nothing, and reports a
/// generic internal error.
const String kFunctionsRegion = 'asia-south1';

/// Callable names, forked from the web app's `tcDev*` pair so the two cannot
/// collide in a project that hosts both.
const String kSendOtpCallable = 'tcDivyaSendOtp';
const String kVerifyOtpCallable = 'tcDivyaVerifyOtp';

/// Echoed into the SMS body by the function, via its DLT-approved template.
const String kPlatformName = 'ThinkTac Teacher Corner';

/// Owns the answer to "who is signed in", and the phone sign-in flow that gets
/// us there.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirestoreService? firestore,
  })  : _injectedAuth = auth,
        _injectedFunctions = functions,
        _firestore = firestore ?? FirestoreService();

  final FirebaseAuth? _injectedAuth;
  final FirebaseFunctions? _injectedFunctions;

  /// Resolved lazily, on first use. `FirebaseAuth.instance` calls
  /// `Firebase.app()`, which throws in a widget test where Firebase was never
  /// initialised. A stub that only reports a uid must be constructible without
  /// Firebase existing at all.
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;

  /// Lazily resolved for the same reason as [_auth]: `instanceFor` reaches for
  /// `Firebase.app()`, which throws in a widget test where Firebase was never
  /// initialised, and StubAuthProvider must be constructible without it.
  late final FirebaseFunctions _functions = _injectedFunctions ??
      FirebaseFunctions.instanceFor(region: kFunctionsRegion);

  final FirestoreService _firestore;

  StreamSubscription<User?>? _authSub;

  bool _authLoaded = false;
  User? _user;
  TeacherAccount? _account;
  LoginStage _stage = LoginStage.phoneEntry;
  bool _busy = false;
  String? _errorKey;
  String _pendingPhone = '';
  bool _disposed = false;

  /// True once Firebase has told us whether anybody is signed in.
  ///
  /// This is NOT [isAuthenticated], and conflating the two is the trap. On a
  /// cold start the answer is genuinely unknown for a few frames while the SDK
  /// restores its persisted session. A redirect that reads "unknown" as "signed
  /// out" is exactly what makes every single launch flash the login screen
  /// before landing on the dashboard.
  bool get authLoaded => _authLoaded;

  bool get isAuthenticated => _user != null;

  String? get uid => _user?.uid;

  /// Both halves of the signed-in teacher, or null when the load has not
  /// finished or failed outright.
  ///
  /// Null here NEVER means "not signed in": check [isAuthenticated] for that. It
  /// also does not mean "unknown teacher" — an account that loaded with neither
  /// document present is a non-null [TeacherAccount] reporting
  /// [TeacherAccount.isEmpty], which is a different thing from not having
  /// managed to ask.
  TeacherAccount? get account => _account;

  /// Whether a `teachers` record is linked to this sign-in. False both while
  /// loading and when genuinely unlinked, so screens gate on
  /// `account != null && !account!.isLinked` when they need to tell those apart.
  bool get isTeacherLinked => _account?.isLinked ?? false;

  LoginStage get stage => _stage;

  bool get isBusy => _busy;

  /// Localisation KEY for the current error, or null when there is none.
  ///
  /// The provider holds a key rather than a sentence on purpose: it has no
  /// BuildContext, and the same failure has to read correctly in both en and
  /// hi. Raw `FirebaseAuthException.message` text never reaches the UI, because
  /// it is English-only and describes Firebase's internals rather than what the
  /// teacher should do next.
  String? get errorKey => _errorKey;

  /// The full E.164 number a code was last sent to, for the "we sent a code
  /// to …" line. Empty before the first send.
  String get pendingPhoneNumber => _pendingPhone;

  /// Starts listening for auth state changes.
  ///
  /// Called once from `main`'s `initState`, after the router exists, so the
  /// first notification actually reaches `refreshListenable`.
  void start() {
    _authSub ??= _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    final signedOut = user == null;
    _user = user;
    // Resolved. Set BEFORE the profile load so the router can leave the splash
    // immediately: whether a teacher document exists is a separate question
    // from whether someone is signed in, and it costs a Firestore round trip
    // that may be slow or may fail outright.
    _authLoaded = true;
    if (signedOut) {
      _account = null;
      _resetFlow();
    }
    _notify();
    if (!signedOut) await _loadTeacher(user.uid);
  }

  /// A missing or unreadable teacher record must not block sign-in. The teacher
  /// is authenticated either way, and the dashboard degrades to showing less
  /// rather than showing an error the teacher cannot act on.
  ///
  /// Reads BOTH `users/{uid}` and the linked `teachers` record, because the
  /// header needs the name from the first and the counts from the second. A
  /// teacher who is signed in but not linked to a teaching record is a normal
  /// state in `teacher-corner-dev` — it means no admin has registered their
  /// number yet — and is reported rather than papered over.
  Future<void> _loadTeacher(String uid) async {
    try {
      _account = await _firestore.fetchTeacherAccount(uid);
    } catch (e) {
      _account = null;
      debugPrint('AuthProvider: teacher account load failed: $e');
    }
    _notify();
  }

  /// Step 1: ask the server to SMS a verification code to [tenDigitNumber].
  ///
  /// The code is generated, salted and hashed server-side and never travels
  /// back over this call. Exotel sends it on ThinkTac's DLT-registered
  /// template, which is the whole reason this path works where Firebase's own
  /// phone auth is refused for an Indian number (error 17006).
  Future<void> sendOtp(String tenDigitNumber) async {
    // Re-entry guard: read AND set before the first await, so a double tap on a
    // laggy device cannot start two challenges against the same number.
    if (_busy) return;
    _busy = true;
    _errorKey = null;
    _pendingPhone = '$kDialCode$tenDigitNumber';
    _notify();

    try {
      await _functions
          .httpsCallable(kSendOtpCallable)
          .call<Map<String, dynamic>>({
            'phone': _pendingPhone,
            'platformName': kPlatformName,
          })
          .timeout(kVerificationTimeout);
      _stage = LoginStage.codeEntry;
    } on FirebaseFunctionsException catch (e) {
      _errorKey = _keyForFunctionsError(e, verifying: false);
      _stage = LoginStage.phoneEntry;
    } on TimeoutException {
      _errorKey = 'auth.error_network';
      _stage = LoginStage.phoneEntry;
    } catch (e) {
      debugPrint('AuthProvider: sendOtp failed: $e');
      _errorKey = 'auth.error_unknown';
      _stage = LoginStage.phoneEntry;
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Step 2: exchange the typed [smsCode] for a session.
  ///
  /// The server compares against its stored hash, then mints a Firebase custom
  /// token keyed on the phone number. Signing in with that token is the only
  /// thing this does with it: `authStateChanges()` stays the single writer of
  /// the signed-in state, exactly as it was under phone auth.
  Future<void> verifyOtp(String smsCode) async {
    if (_busy) return;
    if (_pendingPhone.isEmpty) {
      // No pending number means the flow was reset or the session lapsed. Back
      // to the number field rather than verifying against nothing.
      _errorKey = 'auth.error_code_expired';
      _stage = LoginStage.phoneEntry;
      _notify();
      return;
    }
    _busy = true;
    _errorKey = null;
    _notify();

    try {
      final result = await _functions
          .httpsCallable(kVerifyOtpCallable)
          .call<Map<String, dynamic>>({
            'phone': _pendingPhone,
            'otp': smsCode,
          })
          .timeout(kVerificationTimeout);

      final token = result.data['token'];
      if (token is! String || token.isEmpty) {
        // Verified, but tokenless. The function logs the real cause, which is
        // usually a missing serviceAccountTokenCreator role on the runtime
        // service account. Nothing a teacher can act on.
        debugPrint('AuthProvider: verify succeeded but returned no token');
        _errorKey = 'auth.error_unknown';
        return;
      }
      await _auth.signInWithCustomToken(token);
    } on FirebaseFunctionsException catch (e) {
      _errorKey = _keyForFunctionsError(e, verifying: true);
    } on FirebaseAuthException catch (e) {
      _errorKey = _keyForAuthError(e);
    } on TimeoutException {
      _errorKey = 'auth.error_network';
    } catch (e) {
      debugPrint('AuthProvider: verifyOtp failed: $e');
      _errorKey = 'auth.error_unknown';
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Back to the number field. Clears the pending number too: the server keys
  /// its challenge on that number, so carrying a stale one forward would verify
  /// a code against the wrong phone.
  void changeNumber() {
    _resetFlow();
    _notify();
  }

  void clearError() {
    if (_errorKey == null) return;
    _errorKey = null;
    _notify();
  }

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    _notify();
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthProvider: signOut failed: $e');
      _errorKey = 'auth.error_unknown';
    } finally {
      _busy = false;
      _notify();
    }
  }

  void _resetFlow() {
    _stage = LoginStage.phoneEntry;
    _pendingPhone = '';
    _errorKey = null;
  }

  /// Maps the callable's `HttpsError` code onto one of our own l10n keys.
  ///
  /// The same code means different things on the two calls, so the caller says
  /// which one it is: `invalid-argument` on send is a malformed number, on
  /// verify it is a malformed code.
  static String _keyForFunctionsError(
    FirebaseFunctionsException e, {
    required bool verifying,
  }) {
    debugPrint('AuthProvider: FirebaseFunctionsException(${e.code})');
    return switch (e.code) {
      'invalid-argument' =>
        verifying ? 'auth.error_invalid_code' : 'auth.error_invalid_phone',
      // The server's "Invalid OTP, N attempt(s) remaining".
      'permission-denied' => 'auth.error_invalid_code',
      // No challenge stored, or it expired. Both mean: request a new code.
      'not-found' || 'deadline-exceeded' => 'auth.error_code_expired',
      // Send cap or attempt cap.
      'resource-exhausted' => 'auth.error_too_many_requests',
      'unavailable' => 'auth.error_network',
      _ => 'auth.error_unknown',
    };
  }

  /// Maps a Firebase Auth error onto one of our own l10n keys. Only reachable
  /// now from `signInWithCustomToken`, so the phone-auth codes are gone and the
  /// custom-token ones are what remain.
  static String _keyForAuthError(FirebaseAuthException e) {
    debugPrint('AuthProvider: FirebaseAuthException(${e.code})');
    return switch (e.code) {
      'invalid-custom-token' || 'custom-token-mismatch' =>
        'auth.error_code_expired',
      'too-many-requests' => 'auth.error_too_many_requests',
      'network-request-failed' => 'auth.error_network',
      _ => 'auth.error_unknown',
    };
  }

  /// Firebase callbacks and the profile load are async and can land after the
  /// widget tree holding this provider is gone. Notifying a disposed
  /// ChangeNotifier throws, so the guard is not optional.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }
}
