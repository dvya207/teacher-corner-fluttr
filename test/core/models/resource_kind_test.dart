import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/resource_kind.dart';

/// Every string in this file is a real value out of teacher-corner-dev's
/// `learningUnitResources` documents, not an invented one. The classification
/// is the whole feature: pick the wrong kind and a teacher gets a broken image
/// where the activity guide should be.
void main() {
  group('a YouTube link', () {
    test('is recognised with the query the browser left on it', () {
      // video.tacVideoDriveUrl, verbatim. Pasted from a watch page, so it
      // still carries the autoplay radio parameters.
      final resource = ResolvedResource.of(
        'https://www.youtube.com/watch?v=lY2yjAdbvdQ'
        '&list=RDlY2yjAdbvdQ&start_radio=1',
      );

      expect(resource!.kind, ResourceKind.youTube);
      expect(resource.youTubeVideoId, 'lY2yjAdbvdQ');
    });

    test('is recognised in the other unit\'s link too', () {
      final resource = ResolvedResource.of(
        'https://www.youtube.com/watch?v=Pkh8UtuejGw'
        '&list=RDPkh8UtuejGw&start_radio=1',
      );

      expect(resource!.youTubeVideoId, 'Pkh8UtuejGw');
    });

    test('is recognised as a youtu.be short link', () {
      final resource = ResolvedResource.of('https://youtu.be/lY2yjAdbvdQ');

      expect(resource!.kind, ResourceKind.youTube);
      expect(resource.youTubeVideoId, 'lY2yjAdbvdQ');
    });

    test('is recognised as an embed, a short and a live URL', () {
      for (final url in [
        'https://www.youtube.com/embed/lY2yjAdbvdQ',
        'https://www.youtube.com/shorts/lY2yjAdbvdQ',
        'https://www.youtube.com/live/lY2yjAdbvdQ',
      ]) {
        expect(
          ResolvedResource.of(url)!.youTubeVideoId,
          'lY2yjAdbvdQ',
          reason: url,
        );
      }
    });

    test('falls back to the browser when there is no video id in it', () {
      // A channel or a playlist page. THE PLAYER CANNOT PLAY THIS, and
      // mounting it anyway gives a teacher a black box that reports nothing.
      final resource = ResolvedResource.of(
        'https://www.youtube.com/playlist?list=RDlY2yjAdbvdQ',
      );

      expect(resource!.kind, ResourceKind.webPage);
      expect(resource.youTubeVideoId, isNull);
    });

    test('refuses an id that is not eleven of the right characters', () {
      final resource = ResolvedResource.of(
        'https://www.youtube.com/watch?v=tooshort',
      );

      expect(resource!.kind, ResourceKind.webPage);
    });
  });

  group('a Storage path is classified by its extension', () {
    test('an mp4 is a video', () {
      // video.tacVideoMp4 and socialMedia.tacVideoReelMp4 both hold this one.
      final resource = ResolvedResource.of(
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/Treat you better.mp4',
      );

      expect(resource!.kind, ResourceKind.videoFile);
      expect(resource.isUrl, isFalse);
    });

    test('a pdf is a pdf', () {
      final resource = ResolvedResource.of(
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/Sample.pdf',
      );

      expect(resource!.kind, ResourceKind.pdf);
    });

    test('an image is an image', () {
      final resource = ResolvedResource.of(
        'learningUnits/2awVLuyYaxFqMFuVp3Ny/pexels-cottonbro-7396400.jpg',
      );

      expect(resource!.kind, ResourceKind.image);
    });

    test('a deck is a document', () {
      final resource = ResolvedResource.of('learningUnits/lu1/deck.pptx');

      expect(resource!.kind, ResourceKind.document);
    });
  });

  group('the slot name is not trusted', () {
    test('a slot called headlineImage holding a PDF is classified as a PDF', () {
      // THE BUG THIS FILE EXISTS FOR. graphics.headlineImage and
      // graphics.3DConversion both hold Sample.pdf in teacher-corner-dev, and
      // deciding from the slot drew a PDF through the image widget.
      final resource = ResolvedResource.of(
        'learningUnits/cv1lPaUPXTg1EqUSXT0y/Sample.pdf',
      );

      expect(resource!.kind, ResourceKind.pdf);
    });

    test('a slot called tacGuidePrint holding a png is an image', () {
      // And the mirror image of it, in the same document: a slot whose name
      // says print, holding a picture.
      final resource = ResolvedResource.of(
        'learningUnits/cv1lPaUPXTg1EqUSXT0y/'
        'ChatGPT Image Aug 27, 2026, 05_43_01 PM.png',
      );

      expect(resource!.kind, ResourceKind.image);
    });
  });

  group('values that are not files', () {
    test('a bare document id is unrenderable rather than a Storage path', () {
      // graphics.label18Sticker. Handed to Storage this is an
      // object-not-found; there is no file behind it to show.
      final resource = ResolvedResource.of('KeFtaorAkEj6uaB8ywdt');

      expect(resource!.kind, ResourceKind.unrenderable);
    });

    test('nothing at all is null, which is not the same as unrenderable', () {
      // A slot the web app has not filled in yet reads as "no file uploaded",
      // and that has to stay distinguishable from a file we cannot show.
      expect(ResolvedResource.of(null), isNull);
      expect(ResolvedResource.of(''), isNull);
      expect(ResolvedResource.of('   '), isNull);
    });
  });

  group('URLs that are not YouTube', () {
    test('a Drive link is its own kind, not a video', () {
      // The slot is NAMED tacVideoDriveUrl. Dev data holds YouTube links in
      // it, but a Drive link handed to a YouTube player is a blank box.
      final resource = ResolvedResource.of(
        'https://drive.google.com/file/d/1AbCdEfGhIjK/view?usp=sharing',
      );

      expect(resource!.kind, ResourceKind.googleDrive);
    });

    test('a tokenised download URL is read past its query', () {
      // What resolve() returns for a Storage object: the extension is in the
      // path and the token follows it.
      final resource = ResolvedResource.of(
        'https://firebasestorage.googleapis.com/v0/b/x/o/Sample.pdf'
        '?alt=media&token=6f1b',
      );

      expect(resource!.kind, ResourceKind.pdf);
      expect(resource.isUrl, isTrue);
    });

    test('anything else is a page for the browser', () {
      final resource = ResolvedResource.of('https://thinktac.com/activities');

      expect(resource!.kind, ResourceKind.webPage);
    });
  });

  group('fileName', () {
    test('is the last segment of a Storage path, decoded', () {
      final resource = ResolvedResource.of(
        'learningUnits/lu1/Meditaci%C3%B3n%20para%20Dormir.mp4',
      );

      expect(resource!.fileName, 'Meditación para Dormir.mp4');
    });

    test('is null for a URL, which has no name worth showing a teacher', () {
      final resource = ResolvedResource.of(
        'https://www.youtube.com/watch?v=lY2yjAdbvdQ',
      );

      expect(resource!.fileName, isNull);
    });
  });
}
