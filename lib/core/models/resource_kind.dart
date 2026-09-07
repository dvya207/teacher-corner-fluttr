/// What one resolved resource actually is, and therefore which viewer renders
/// it.
///
/// DECIDED BY THE RESOURCE, NEVER BY THE SLOT IT CAME FROM. This is the whole
/// reason the file exists. A workflow step's content names a category and a
/// subCategory, and those names promise a kind they do not deliver:
///
///   graphics.headlineImage  = learningUnits/cv1l…/Sample.pdf   (a PDF)
///   graphics.3DConversion   = learningUnits/cv1l…/Sample.pdf   (a PDF)
///   graphics.tacGuidePrint  = learningUnits/cv1l…/ChatGPT….png (an image)
///   graphics.label18Sticker = KeFtaorAkEj6uaB8ywdt             (neither)
///
/// all four in the same live document in teacher-corner-dev. Choosing a viewer
/// from `contentCategory` drew that first PDF as a broken image, and asked
/// Storage for a document id. So the resolved VALUE is inspected instead: its
/// extension where it has one, its host where it is a URL.
///
/// The names are what a teacher would say, not what the uploader called the
/// field.
enum ResourceKind {
  /// A picture, shown inline at once. The one kind cheap enough to fetch
  /// before a teacher asks for it.
  image,

  /// A PDF: the activity guide, a die template, a material list. Rendered page
  /// by page in-app from a downloaded file.
  pdf,

  /// A YouTube watch link, playable inline once tapped.
  youTube,

  /// An mp4, either a Storage path or a plain URL. Played by the platform
  /// player.
  videoFile,

  /// A Google Drive file, which is a viewer of Drive's rather than a file we
  /// can fetch. Shown in a webview.
  ///
  /// PRESENT BECAUSE THE SLOT IS NAMED FOR IT. Every `tacVideoDriveUrl` in
  /// teacher-corner-dev holds a YouTube link rather than a Drive one, so this
  /// is unexercised by dev data, but the field name says production means to
  /// put Drive links here and a Drive link handed to a YouTube player is a
  /// blank box.
  googleDrive,

  /// A slide deck, a Word file, a spreadsheet. Nothing on Android renders
  /// these natively; shown through Google's viewer in a webview.
  document,

  /// An http(s) address that is none of the above. A page, so it gets a
  /// browser rather than a viewer.
  webPage,

  /// Something we cannot show and should not pretend to: a bare Firestore
  /// document id, or a value with no extension and no host to go on.
  ///
  /// A NAMED KIND RATHER THAN A FAILURE, because it is not one. The web app
  /// stored a reference to another document in a slot the app expects a file
  /// in. Saying so beats a spinner that never resolves.
  unrenderable,
}

/// One resolved resource, classified.
///
/// Built from the string [LearningUnitResources.pathFor] returns, which is
/// either a Cloud Storage path or a URL, and holds the small amount of parsing
/// every viewer would otherwise repeat.
class ResolvedResource {
  const ResolvedResource._({
    required this.value,
    required this.kind,
    this.youTubeVideoId,
  });

  /// The resolved value, trimmed. A Storage path or a URL.
  final String value;

  final ResourceKind kind;

  /// The 11-character id, when [kind] is [ResourceKind.youTube]. Null
  /// otherwise.
  final String? youTubeVideoId;

  /// True for a value that is already fetchable as-is, so no Storage
  /// resolution step is needed before it can be handed to a player.
  bool get isUrl => _isUrl(value);

  /// The file name a teacher would recognise, or null when the value has none.
  /// Used to label a viewer, since the slot's own name is a developer's word.
  String? get fileName {
    if (isUrl) return null;
    final segments = value.split('/').where((s) => s.isNotEmpty);
    if (segments.isEmpty) return null;
    final last = Uri.decodeComponent(segments.last);
    return last.contains('.') ? last : null;
  }

  /// Classifies [raw], or returns null when there is nothing there.
  ///
  /// Null rather than an [ResourceKind.unrenderable] instance, so a caller can
  /// tell "no file uploaded for this slot yet" from "a file we cannot show".
  /// Those read identically on screen but mean opposite things: one is the web
  /// app not finished yet, the other is this app falling short.
  static ResolvedResource? of(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;

    if (_isUrl(value)) return _fromUrl(value);

    // A Storage path. Only its extension can say what it holds.
    final kind = _kindFromExtension(value);
    return ResolvedResource._(
      value: value,
      // No extension and no slash is a bare document id, not a file.
      kind: kind ?? ResourceKind.unrenderable,
    );
  }

  static ResolvedResource _fromUrl(String value) {
    final uri = Uri.tryParse(value);
    final host = (uri?.host ?? '').toLowerCase();

    if (_youTubeHosts.any((h) => host == h || host.endsWith('.$h'))) {
      final id = _youTubeId(uri!);
      if (id != null) {
        return ResolvedResource._(
          value: value,
          kind: ResourceKind.youTube,
          youTubeVideoId: id,
        );
      }
      // A YouTube address we cannot pull an id out of, a channel or a playlist
      // page. The browser can still open it; the player cannot play it.
      return ResolvedResource._(value: value, kind: ResourceKind.webPage);
    }

    if (host == 'drive.google.com' || host == 'docs.google.com') {
      return ResolvedResource._(value: value, kind: ResourceKind.googleDrive);
    }

    // Extension of the PATH, with the query dropped: a tokenised download URL
    // carries `?alt=media&token=…` after the file name.
    final kind = _kindFromExtension(uri?.path ?? value);
    return ResolvedResource._(value: value, kind: kind ?? ResourceKind.webPage);
  }

  static bool _isUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static ResourceKind? _kindFromExtension(String path) {
    final lower = path.toLowerCase();
    if (_imageExtensions.any(lower.endsWith)) return ResourceKind.image;
    if (lower.endsWith('.pdf')) return ResourceKind.pdf;
    if (_videoExtensions.any(lower.endsWith)) return ResourceKind.videoFile;
    if (_documentExtensions.any(lower.endsWith)) return ResourceKind.document;
    return null;
  }

  /// The video id out of every YouTube URL shape live data uses.
  ///
  /// THE QUERY IS NOT JUST `v`. Every link in teacher-corner-dev was pasted
  /// straight out of the browser and still carries what the browser added:
  ///
  ///   https://www.youtube.com/watch?v=lY2yjAdbvdQ&list=RDlY2yjAdbvdQ&start_radio=1
  ///
  /// so the id is read from the named parameter rather than from the tail of
  /// the string, and `list` is left where it is.
  static String? _youTubeId(Uri uri) {
    final host = uri.host.toLowerCase();

    // youtu.be/<id>
    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      return _validId(uri.pathSegments.isEmpty ? null : uri.pathSegments.first);
    }

    final fromQuery = _validId(uri.queryParameters['v']);
    if (fromQuery != null) return fromQuery;

    // /embed/<id>, /shorts/<id>, /live/<id>, /v/<id>
    final segments = uri.pathSegments;
    for (var i = 0; i < segments.length - 1; i++) {
      if (_idBearingSegments.contains(segments[i].toLowerCase())) {
        return _validId(segments[i + 1]);
      }
    }
    return null;
  }

  /// Exactly eleven of YouTube's id characters, or nothing.
  ///
  /// CHECKED RATHER THAN TRUSTED, because a wrong id is not a visible error:
  /// the player mounts, goes black, and reports nothing, which is the failure a
  /// teacher can do least with.
  static String? _validId(String? candidate) {
    final id = candidate?.trim() ?? '';
    if (id.length != 11) return null;
    return _idPattern.hasMatch(id) ? id : null;
  }

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static const Set<String> _youTubeHosts = {
    'youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
  };

  static const Set<String> _idBearingSegments = {
    'embed',
    'shorts',
    'live',
    'v',
  };

  static const Set<String> _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.bmp',
    '.heic',
  };

  static const Set<String> _videoExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.webm',
    '.3gp',
    '.mkv',
    '.avi',
  };

  static const Set<String> _documentExtensions = {
    '.ppt',
    '.pptx',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.csv',
    '.rtf',
    '.odt',
    '.odp',
    '.ods',
  };
}
