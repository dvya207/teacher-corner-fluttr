import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/teacher.dart';
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

/// How long to wait for `verifyPhoneNumber` to call one of its callbacks before
/// giving up. A teacher on school wifi mid-class needs an error message, not a
/// spinner that never resolves.
const Duration kVerificationTimeout = Duration(seconds: 90);

/// Owns the answer to "who is signed in", and the phone sign-in flow that gets
/// us there.
class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuth? auth, FirestoreService? firestore})
    : _injectedAuth = auth,
      _firestore = firestore ?? FirestoreService();

  final FirebaseAuth? _injectedAuth;

  /// Resolved lazily, on first use. `FirebaseAuth.instance` calls
  /// `Firebase.app()`, which throws in a widget test where Firebase was never
  /// initialised. A stub that only reports a uid must be constructible without
  /// Firebase existing at all.
  late final FirebaseAuth _auth = _injectedAuth ?? FirebaseAuth.instance;

  final FirestoreService _firestore;

  StreamSubscription<User?>? _authSub;

  bool _authLoaded = false;
  User? _user;
  Teacher? _teacher;
  LoginStage _stage = LoginStage.phoneEntry;
  bool _busy = false;
  String? _errorKey;
  String? _verificationId;
  int? _resendToken;
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

  /// The teacher's profile, or null when it has not loaded or does not exist.
  /// Null here never means "not signed in": check [isAuthenticated] for that.
  Teacher? get teacher => _teacher;

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
      _teacher = null;
      _resetFlow();
    }
    _notify();
    if (!signedOut) await _loadTeacher(user.uid);
  }

  /// A missing or unreadable teacher record must not block sign-in. The teacher
  /// is authenticated either way, and the dashboard degrades to showing less
  /// rather than showing an error the teacher cannot act on.
  Future<void> _loadTeacher(String uid) async {
    try {
      _teacher = await _firestore.fetchTeacher(uid);
    } catch (e) {
      _teacher = null;
      debugPrint('AuthProvider: teacher profile load failed: $e');
    }
    _notify();
  }

  /// Step 1: ask Firebase to SMS a verification code to [tenDigitNumber].
  Future<void> sendOtp(String tenDigitNumber) async {
    // Re-entry guard: read AND set before the first await, so a double tap on a
    // laggy device cannot start two verifications against the same number.
    if (_busy) return;
    _busy = true;
    _errorKey = null;
    _pendingPhone = '$kDialCode$tenDigitNumber';
    _notify();

    // `verifyPhoneNumber` resolves once the request is submitted, not once a
    // callback has fired, so the busy flag has to track the callbacks instead.
    final settled = Completer<void>();
    void settle() {
      if (!settled.isCompleted) settled.complete();
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _pendingPhone,
        forceResendingToken: _resendToken,
        verificationCompleted: (credential) async {
          // Android instant verification or auto-retrieval: Firebase already
          // has the code, so there is nothing for the teacher to type.
          await _trySignIn(credential);
          settle();
        },
        verificationFailed: (e) {
          _errorKey = _keyForAuthError(e);
          _stage = LoginStage.phoneEntry;
          settle();
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _stage = LoginStage.codeEntry;
          settle();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          // Auto-retrieval gave up. Not an error: the manually typed code still
          // works, so keep the id and leave the form where it is.
          _verificationId = verificationId;
        },
      );
      await settled.future.timeout(kVerificationTimeout);
    } on TimeoutException {
      _errorKey = 'auth.error_network';
      _stage = LoginStage.phoneEntry;
    } on FirebaseAuthException catch (e) {
      _errorKey = _keyForAuthError(e);
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
  Future<void> verifyOtp(String smsCode) async {
    if (_busy) return;
    final verificationId = _verificationId;
    if (verificationId == null) {
      // No id means the flow was reset or the session lapsed. Send the teacher
      // back to the number field rather than failing against a stale id.
      _errorKey = 'auth.error_code_expired';
      _stage = LoginStage.phoneEntry;
      _notify();
      return;
    }
    _busy = true;
    _errorKey = null;
    _notify();
    try {
      await _trySignIn(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        ),
        rethrowFailures: true,
      );
    } on FirebaseAuthException catch (e) {
      _errorKey = _keyForAuthError(e);
    } catch (e) {
      debugPrint('AuthProvider: verifyOtp failed: $e');
      _errorKey = 'auth.error_unknown';
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Signs in, and deliberately assigns no state of its own.
  ///
  /// `authStateChanges()` is the single writer of [_user], so the signed-in
  /// state arrives by exactly one path whether the teacher typed a code or
  /// Android auto-verified behind their back. Two writers here would be two
  /// chances to disagree.
  Future<void> _trySignIn(
    PhoneAuthCredential credential, {
    bool rethrowFailures = false,
  }) async {
    try {
      await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (rethrowFailures) rethrow;
      // Reached from the verificationCompleted callback, which has no caller to
      // catch for it, so it has to record its own error.
      _errorKey = _keyForAuthError(e);
      _stage = LoginStage.phoneEntry;
    }
  }

  /// Back to the number field. Clears the resend token too: it belongs to the
  /// old number and reusing it against a new one is a confusing failure.
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
    _verificationId = null;
    _resendToken = null;
    _pendingPhone = '';
    _errorKey = null;
  }

  /// Maps a Firebase error code onto one of our own l10n keys. Anything
  /// unrecognised becomes the generic key rather than leaking a code to a
  /// teacher who cannot act on it.
  static String _keyForAuthError(FirebaseAuthException e) {
    debugPrint('AuthProvider: FirebaseAuthException(${e.code})');
    return switch (e.code) {
      'invalid-phone-number' => 'auth.error_invalid_phone',
      'invalid-verification-code' => 'auth.error_invalid_code',
      'invalid-verification-id' ||
      'session-expired' => 'auth.error_code_expired',
      'too-many-requests' => 'auth.error_too_many_requests',
      'network-request-failed' => 'auth.error_network',
      'quota-exceeded' => 'auth.error_quota',
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
