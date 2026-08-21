import '../utils/safe_parse.dart';

/// One submitted photo: what to render, and what to delete.
///
/// The two travel together because you cannot derive one from the other. A
/// download URL carries a freshly minted access token, so it is not a stable
/// identity, and there is no way back from it to the object it points at.
class EvidencePhoto {
  const EvidencePhoto({required this.url, required this.storagePath});

  final String url;
  final String storagePath;
}

/// The map stored under one assignment id inside
/// `Teachers/{uid}/submissions/{classroomId}-{programmeId}`.
class AssignmentEvidence {
  const AssignmentEvidence({
    required this.assignmentId,
    this.displayName,
    this.luId,
    this.type,
    this.contentType,
    this.photoUrls = const [],
    this.storagePaths = const [],
  });

  final String assignmentId;
  final String? displayName;
  final String? luId;
  final String? type;
  final String? contentType;

  /// What the UI renders.
  final List<String> photoUrls;

  /// What deletion needs. Index-aligned with [photoUrls].
  final List<String> storagePaths;

  static const String submissionsSubcollection = 'submissions';

  /// The submission document id. One document per classroom + programme, with
  /// a map per assignment inside it.
  static String documentId({
    required String classroomId,
    required String programmeId,
  }) =>
      '$classroomId-$programmeId';

  /// The pairs that are actually usable.
  ///
  /// Pairs only up to the shorter list. A URL with no path cannot be deleted
  /// and a path with no URL cannot be shown, so an unbalanced record is
  /// truncated to the part that is coherent rather than trusted.
  List<EvidencePhoto> get photos {
    final count = photoUrls.length < storagePaths.length
        ? photoUrls.length
        : storagePaths.length;
    return [
      for (var i = 0; i < count; i++)
        EvidencePhoto(url: photoUrls[i], storagePath: storagePaths[i]),
    ];
  }

  /// True when the document's two lists disagree in length. Worth surfacing:
  /// it means an earlier write or delete did not complete.
  bool get isMisaligned => photoUrls.length != storagePaths.length;

  int get count => photos.length;

  factory AssignmentEvidence.fromMap(
    String assignmentId,
    Map<String, dynamic> data, {
    String? docId,
  }) {
    // ListPolicy.fail, not drop: these two lists are parallel, so silently
    // dropping one bad element shifts every later pair and makes the app delete
    // the wrong object. Failing yields null, which degrades to empty.
    final urls = SafeParse.asStringList(
      data['photoUrls'],
      policy: ListPolicy.fail,
      collection: AssignmentEvidence.submissionsSubcollection,
      docId: docId,
      field: '$assignmentId.photoUrls',
    );
    final paths = SafeParse.asStringList(
      data['storagePaths'],
      policy: ListPolicy.fail,
      collection: AssignmentEvidence.submissionsSubcollection,
      docId: docId,
      field: '$assignmentId.storagePaths',
    );

    return AssignmentEvidence(
      assignmentId: assignmentId,
      displayName: SafeParse.asDisplayString(data['displayName']),
      luId: SafeParse.asRefString(
        data['luId'],
        collection: AssignmentEvidence.submissionsSubcollection,
        docId: docId,
        field: '$assignmentId.luId',
      ),
      type: SafeParse.asDisplayString(data['type']),
      contentType: SafeParse.asDisplayString(data['contentType']),
      photoUrls: List.unmodifiable(urls ?? const <String>[]),
      storagePaths: List.unmodifiable(paths ?? const <String>[]),
    );
  }

  Map<String, dynamic> toMap() => {
        if (displayName != null) 'displayName': displayName,
        if (luId != null) 'luId': luId,
        if (type != null) 'type': type,
        if (contentType != null) 'contentType': contentType,
        'photoUrls': photoUrls,
        'storagePaths': storagePaths,
      };

  AssignmentEvidence copyWith({
    List<String>? photoUrls,
    List<String>? storagePaths,
  }) =>
      AssignmentEvidence(
        assignmentId: assignmentId,
        displayName: displayName,
        luId: luId,
        type: type,
        contentType: contentType,
        photoUrls: List.unmodifiable(photoUrls ?? this.photoUrls),
        storagePaths: List.unmodifiable(storagePaths ?? this.storagePaths),
      );
}
