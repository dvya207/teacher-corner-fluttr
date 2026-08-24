import 'classroom_ref.dart';
import 'teacher.dart';
import 'teacher_profile.dart';

/// Everything the app knows about the signed-in teacher, from BOTH documents
/// that describe them.
///
/// `teacher-corner-dev` splits one person across two collections, deliberately:
/// `users/{uid}` is who is signed in, `teachers/{docId}` is what they teach.
/// Neither alone can render the dashboard, so this joins them once, at the
/// service boundary, rather than making four providers and two screens each
/// remember which half answers which question.
///
/// WHICH HALF WINS, AND WHY. The profile is authoritative for identity and the
/// teaching record for teaching. That is not arbitrary: the profile is written
/// from the teacher's own Auth record and their own profile form, while the
/// teaching record's name is whatever an admin typed when registering them. The
/// two DO disagree in live data. Preferring the profile means the header shows
/// the teacher the name they set for themselves.
class TeacherAccount {
  const TeacherAccount({required this.uid, this.profile, this.teaching});

  /// The Firebase Auth uid this account was resolved for. Always present, even
  /// when both documents are missing, because it came from the session.
  final String uid;

  /// `users/{uid}`, or null when this teacher has never signed into the web app.
  final TeacherProfile? profile;

  /// The linked `teachers/{docId}` record, or null when no record carries this
  /// uid at `teacherMeta.uid`.
  final Teacher? teaching;

  /// Whether a teaching record has been linked to this sign-in.
  ///
  /// FALSE IS THE STATE THE "profile not linked" MESSAGE EXISTS FOR. It happens
  /// when an admin has not registered this phone number, or has registered it
  /// and the number does not match, so the web app's `linkSignedInUid` never
  /// found a blank to fill. There is nothing the app can do about it and nothing
  /// it should invent: no classrooms, no programmes, no seeded stand-in.
  bool get isLinked => teaching != null;

  /// True when neither document exists. Signed in and entirely unknown to
  /// Teacher Corner.
  bool get isEmpty => profile == null && teaching == null;

  /// The name to show, preferring the teacher's own profile.
  ///
  /// Empty string rather than null when nothing is known, so callers can fall
  /// back to the app title without a second null check.
  String get displayName {
    final fromProfile = profile?.fullName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    final fromTeaching = teaching?.displayName.trim();
    if (fromTeaching != null && fromTeaching.isNotEmpty) return fromTeaching;
    return '';
  }

  /// Just the first name, for a greeting.
  ///
  /// A GREETING USES ONE NAME. "Good afternoon, Divya Jain" reads like a letter
  /// from an institution; "Good afternoon, Divya" reads like the app knows who
  /// is holding it.
  ///
  /// Falls back to the first word of [displayName] rather than to nothing,
  /// because a record carrying only a top-level `name` still has a first name in
  /// it — it is just not split into fields. Empty when nothing is known, so the
  /// caller can drop the name from the greeting entirely instead of greeting a
  /// blank.
  String get firstName {
    for (final candidate in [profile?.firstName, teaching?.meta?.firstName]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    final whole = displayName.trim();
    if (whole.isEmpty) return '';
    return whole.split(RegExp(r'\s+')).first;
  }

  /// Initials for the avatar: first letters of the first two words, or one
  /// letter, or empty.
  ///
  /// Derived here rather than in the widget so the dashboard and anything else
  /// showing an avatar cannot disagree about what a teacher's initials are.
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  /// The school, preferring the profile and falling back to the teaching
  /// record, which derives it from the classrooms.
  String? get institutionName {
    final fromProfile = profile?.institutionName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return teaching?.institutionName;
  }

  /// The classrooms, which only the teaching record knows about.
  List<ClassroomRef> get classrooms => teaching?.classrooms ?? const [];

  int get classroomCount => classrooms.length;

  /// Distinct programmes across every classroom. Delegated so the
  /// count-by-identity rule lives in exactly one place.
  int get programmeCount => teaching?.programmeCount ?? 0;
}
