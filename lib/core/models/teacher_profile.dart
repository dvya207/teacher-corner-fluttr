import '../utils/safe_parse.dart';

/// The signed-in teacher's own profile: `users/{uid}` in `teacher-corner-dev`.
///
/// THE AUTHORITATIVE ANSWER TO "WHO AM I". The document id IS the Firebase Auth
/// uid, so this is the one read in the whole app that can be done by id with no
/// query, and the one place a name cannot belong to somebody else.
///
/// WRITTEN BY THE WEB APP, NEVER BY THIS ONE. `ProfileService.recordSignIn()` in
/// `~/code/teacher-corner` creates and updates it on every successful sign-in.
/// This app only reads it. Two consequences:
///
///   * A teacher who has only ever signed into THIS app has no such document.
///     Absent is a legitimate state, not a failure, and callers degrade to the
///     teaching record's name instead of showing an error.
///   * A name shown here can disagree with the name on `teachers/{docId}`. They
///     are written by different flows at different times: this one comes off the
///     Auth record and the teacher's own profile form, the other off whatever an
///     admin typed when registering them. This document wins, because it is the
///     one the teacher controls.
///
/// Only the fields the six-screen slice renders are modelled. The document
/// carries considerably more, including the registration and approval
/// bookkeeping the web app routes on, which is none of this app's business.
class TeacherProfile {
  const TeacherProfile({
    required this.uid,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.countryCode,
    this.institutionId,
    this.institutionName,
    this.grade,
    this.section,
    this.programmeId,
    this.programmeName,
    this.approved,
  });

  /// The Firebase Auth uid, which is also the document id.
  final String uid;

  final String? firstName;
  final String? lastName;
  final String? email;

  /// Subscriber digits only. The dial code is held apart in [countryCode],
  /// which is how the web app stores it and why the two are not folded together
  /// here either.
  final String? phone;
  final String? countryCode;

  final String? institutionId;
  final String? institutionName;

  /// A STRING, not an int. The web app stores `'9'` and `'Pre-primary 2'` in the
  /// same field, so there is no int to parse it into. This is the opposite
  /// choice from [ClassroomRef.grade], which is an `int?` because the SUMMARY
  /// map it comes from is production-shaped.
  final String? grade;
  final String? section;

  final String? programmeId;
  final String? programmeName;

  /// The web app's `ApprovedStatus`. PascalCase on the document, because it was
  /// created by hand in the console before any code read it.
  ///
  /// Read and surfaced, never enforced. Gating a teacher out of this app is the
  /// web app's decision to make and its rules already govern what can be read;
  /// duplicating the gate here would mean two apps disagreeing about who is
  /// allowed in.
  final bool? approved;

  /// `users`, the web app's collection name.
  static const String collection = 'users';

  factory TeacherProfile.fromMap(String uid, Map<String, dynamic> data) =>
      TeacherProfile(
        uid: uid,
        firstName: SafeParse.asDisplayString(data['firstName']),
        lastName: SafeParse.asDisplayString(data['lastName']),
        email: SafeParse.asDisplayString(data['email']),
        phone: SafeParse.asDisplayString(data['phone']),
        countryCode: SafeParse.asDisplayString(data['countryCode']),
        institutionId: SafeParse.asDisplayString(data['institutionId']),
        institutionName: SafeParse.asDisplayString(data['institutionName']),
        grade: SafeParse.asDisplayString(data['grade']),
        section: SafeParse.asDisplayString(data['section']),
        programmeId: SafeParse.asDisplayString(data['programmeId']),
        programmeName: SafeParse.asDisplayString(data['programmeName']),
        // Absent means NOT approved on the web app's side, but null is kept
        // distinct from false here so a reader can tell "no answer recorded"
        // from "answered no".
        approved: data['ApprovedStatus'] is bool
            ? data['ApprovedStatus'] as bool
            : null,
      );

  /// Null rather than a stray space when one half of the pair is missing, and
  /// never the literal "null".
  String? get fullName {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// The number as a teacher would recognise it, or null when none is stored.
  String? get displayPhone {
    final digits = phone?.trim();
    if (digits == null || digits.isEmpty) return null;
    final dial = countryCode?.trim();
    // The web app writes the dial code into `phone` on some documents and keeps
    // it separate on others, so prefixing unconditionally would produce
    // "+91+91XXXXXXXXXX".
    if (dial == null || dial.isEmpty || digits.startsWith('+')) return digits;
    return '$dial$digits';
  }
}
