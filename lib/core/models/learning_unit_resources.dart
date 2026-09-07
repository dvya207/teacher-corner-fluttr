import '../utils/safe_parse.dart';

/// Where a learning unit's files actually live.
///
/// THE STEP ONLY HOLDS A POINTER. A workflow step's content carries
/// `contentCategory` and `contentSubCategory` and an EMPTY `resourcePath`; the
/// file itself is in this collection, one document per learning unit, under
/// `resources[category][subCategory]`. Reading only the step's own
/// `resourcePath` is why every content pane rendered blank while the uploads
/// sat here the whole time.
///
/// The pairing is exact in live data. A step content of
/// `category=video, sub=tacVideoDriveUrl` resolves to
/// `resources.video.tacVideoDriveUrl`, and the same holds for
/// `socialMedia.tacVideoReelMp4` and `tacDev.devGuidePdf`.
///
/// TWO SHAPES OF LEAF, both real:
///
///   resources.video.tacVideoDriveUrl = "https://youtube.com/..."   (a string)
///   resources.tacDev.materialList    = {"CBSE": "KrHYoe8..."}      (by board)
///   resources['3S'].quizzesDev       = {"universalGradeBoardResourcePath": ""}
///
/// so a leaf is either a PATH or, for a grade-dependent slot, a map whose
/// board keys hold `boardGradeResources` DOCUMENT IDS. Those two are not
/// interchangeable and conflating them emptied the Pre-Test tab. See
/// [ResourceSlot] and [BoardGradeResource].
class LearningUnitResources {
  const LearningUnitResources({this.byCategory = const {}});

  static const String collection = 'learningUnitResources';

  /// The field every document carries pointing back at its learning unit. The
  /// document id is its own, so this is how a unit finds its resources.
  static const String unitField = 'learningUnitDocId';

  /// The board key used when a resource is the same for every board. Preferred
  /// over a board-specific one, because a resource that does not vary by board
  /// is the one the app should show when it does not know the board.
  static const String universalKey = 'universalGradeBoardResourcePath';

  /// category -> subCategory -> slot. Empty leaves are dropped at parse time,
  /// so a key being present here means it has something behind it.
  final Map<String, Map<String, ResourceSlot>> byCategory;

  bool get isEmpty => byCategory.isEmpty;

  /// True when any slot stores a board map, and therefore when the extra reads
  /// for [BoardGradeResource] are worth making. Asked before those reads so a
  /// unit with none pays nothing for them.
  bool get hasGradeDependentSlot => byCategory.values.any(
    (group) => group.values.any((slot) => slot.isGradeDependent),
  );

  /// The slot behind one step content, whatever kind it is.
  ResourceSlot? slotFor({String? category, String? subCategory}) {
    final group = category?.trim();
    final key = subCategory?.trim();
    if (group == null || group.isEmpty || key == null || key.isEmpty) {
      return null;
    }
    return byCategory[group]?[key];
  }

  /// The file behind one step content that this document can answer on its
  /// own, or null.
  ///
  /// ONLY EVER A REAL PATH. A grade-dependent slot answers here with its
  /// universal copy and NOTHING ELSE, because its board keys hold document ids
  /// into `boardGradeResources` rather than files. Returning one of those was
  /// the bug: the Pre-Test tab was handed 's9qKMMiIrTMVaay3Kn14' and told a
  /// teacher there was no file, while the PDF sat one document further on. See
  /// [BoardGradeResource], and [boardDocIdFor] for following the signpost.
  ///
  /// Null rather than empty string, so the pane can tell "not uploaded yet"
  /// from "uploaded and blank", and never asks Storage for "".
  String? pathFor({String? category, String? subCategory}) {
    final slot = slotFor(category: category, subCategory: subCategory);
    return slot?.directPath;
  }

  /// The `boardGradeResources` document id this slot holds for one board, or
  /// null when the slot is not grade-dependent or that board has no copy.
  String? boardDocIdFor({
    String? category,
    String? subCategory,
    String? board,
  }) {
    final key = board?.trim();
    if (key == null || key.isEmpty) return null;
    return slotFor(category: category, subCategory: subCategory)?.byBoard[key];
  }

  factory LearningUnitResources.fromMap(
    String docId,
    Map<String, dynamic> data,
  ) {
    final raw = SafeParse.asStringKeyedMap(
      data['resources'],
      collection: collection,
      docId: docId,
      field: 'resources',
    );

    final byCategory = <String, Map<String, ResourceSlot>>{};
    raw.forEach((category, group) {
      final entries = SafeParse.asStringKeyedMap(
        group,
        collection: collection,
        docId: docId,
        field: 'resources.$category',
      );
      final resolved = <String, ResourceSlot>{};
      entries.forEach((subCategory, leaf) {
        final slot = ResourceSlot.of(leaf);
        if (slot != null) resolved[subCategory] = slot;
      });
      if (resolved.isNotEmpty) byCategory[category] = Map.unmodifiable(resolved);
    });

    return LearningUnitResources(byCategory: Map.unmodifiable(byCategory));
  }

}

/// One resource slot's stored value, with its two shapes kept apart.
///
/// THE SHAPES MEAN DIFFERENT THINGS AND THIS USED TO FLATTEN THEM. The old
/// code took "the universal path, else the first non-empty value", which reads
/// a board key's DOCUMENT ID as if it were a file path. Every grade-dependent
/// slot in teacher-corner-dev has an empty universal and a filled board key,
/// so that fallback fired on all of them and produced a path to nothing:
///
///   3S.conceptPreTestQuizPdf   { universalGradeBoardResourcePath: '',
///                                CBSE: 's9qKMMiIrTMVaay3Kn14' }
///   3S.conceptPostTestQuizPdf  { universalGradeBoardResourcePath: '',
///                                CBSE: 'X2GPbu1KeM9arUdINweL' }
///   tacDev.materialList        { universalGradeBoardResourcePath: '',
///                                CBSE: 'KrHYoe8bQJJyRbKKyuhH' }
///   graphics.label18Sticker    { universalGradeBoardResourcePath: '',
///                                CBSE: 'KeFtaorAkEj6uaB8ywdt' }
class ResourceSlot {
  const ResourceSlot._({this.path, this.universal, this.byBoard = const {}});

  /// The whole value, for a slot that is one file for the whole unit.
  final String? path;

  /// The one file a grade-dependent slot falls back to for every board.
  ///
  /// EMPTY ON EVERY SLOT IN THIS DATABASE, which is why the board chain has to
  /// work rather than being a nicety: there is nothing behind it.
  final String? universal;

  /// board -> `boardGradeResources` document id. NOT paths.
  final Map<String, String> byBoard;

  bool get isGradeDependent => path == null;

  /// The path this slot can produce with no further reads: itself when it is a
  /// plain slot, its universal copy when it is grade-dependent, else null.
  String? get directPath => path ?? universal;

  /// The key holding the universal copy inside a grade-dependent slot.
  /// Preferred over a board-specific one where it has a value, because a
  /// resource that does not vary by board is the one to show when the board is
  /// unknown.
  static const String universalKey = 'universalGradeBoardResourcePath';

  /// Classifies a stored leaf, or returns null when there is nothing in it.
  static ResourceSlot? of(Object? leaf) {
    if (leaf is String) {
      final value = leaf.trim();
      return value.isEmpty ? null : ResourceSlot._(path: value);
    }
    if (leaf is! Map) return null;

    final rawUniversal = leaf[universalKey];
    final universal = rawUniversal is String && rawUniversal.trim().isNotEmpty
        ? rawUniversal.trim()
        : null;

    final byBoard = <String, String>{};
    leaf.forEach((key, value) {
      if (key == universalKey) return;
      if (key is String && value is String && value.trim().isNotEmpty) {
        byBoard[key] = value.trim();
      }
    });

    if (universal == null && byBoard.isEmpty) return null;
    return ResourceSlot._(
      universal: universal,
      byBoard: Map.unmodifiable(byBoard),
    );
  }
}
