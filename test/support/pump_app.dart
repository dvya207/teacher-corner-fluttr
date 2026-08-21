// Reaches into easy_localization's src for `Localization.load`, which is a
// public static in an unexported file.
//
// The supported route is to wrap the widget under test in an `EasyLocalization`
// widget, and it does not survive a second test in the same file: that widget
// keeps global state, and its second instance never finishes loading, so every
// test after the first renders an empty tree. Verified, not assumed.
//
// Loading the translations straight into the singleton is what `.tr()` reads
// anyway, and it makes each test independent. The cost is that these tests do
// not exercise EasyLocalization's own wiring; `l10n_test.dart` covers the JSON,
// and `main.dart` is where the widget is actually configured.
// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:tc_starter/core/theme/app_theme.dart';
import 'package:tc_starter/core/theme/text_scaling.dart';

export 'package:provider/provider.dart' show ChangeNotifierProvider;

/// Call from `setUp` (or `setUpAll`) before pumping anything that uses `.tr()`.
///
/// Reads the real `assets/l10n/*.json` off disk, so a screen referencing a key
/// that does not exist fails here rather than silently rendering the key.
void initLocalizationForTest({String locale = 'en'}) {
  TestWidgetsFlutterBinding.ensureInitialized();

  final translations = Translations(
    jsonDecode(File('assets/l10n/$locale.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final fallback = Translations(
    jsonDecode(File('assets/l10n/en.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  Localization.load(
    Locale(locale),
    translations: translations,
    fallbackTranslations: fallback,
  );

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Some plugins reached by the widget tree persist preferences. Nothing under
  // test depends on what comes back, only on the call not throwing.
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return true;
    },
  );

  // The image file cache asks path_provider where to put its files. Without
  // this, any widget rendering a Storage-path image is simply untestable, which
  // is how an image-bearing screen ends up with no test at all.
  final cacheRoot = Directory.systemTemp.createTempSync('tc_test_cache').path;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => cacheRoot,
  );
}

/// Pumps one screen inside the scaffolding `main.dart` gives it.
///
/// The real `ScreenUtilInit`, because `.sp`/`.w` throw if ScreenUtil has not
/// initialised, and the same text-scale clamp, so a maxed-out system font size
/// can be tested the way the app actually behaves.
///
/// [settle] must be FALSE for any screen showing a spinner: `pumpAndSettle`
/// waits for every animation to finish and a CircularProgressIndicator never
/// finishes, so it would time out rather than fail usefully.
Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget child,
  List<SingleChildWidget> providers = const [],
  bool settle = true,
  Size surfaceSize = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  // physicalSize on the view, NOT binding.setSurfaceSize: MediaQuery derives
  // its size from the view, so setSurfaceSize alone leaves ScreenUtil scaling
  // against the default 800px-wide test window. That inflates every `.w` and
  // `.sp` by ~2.2x and produces overflows that do not exist on a phone.
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  // MultiProvider asserts on an empty provider list, and a screen like the
  // splash legitimately needs none.
  Widget withProviders(Widget child) => providers.isEmpty
      ? child
      : MultiProvider(providers: providers, child: child);

  await tester.pumpWidget(
    withProviders(
      ScreenUtilInit(
        designSize: const Size(360, 800),
        minTextAdapt: true,
        fontSizeResolver: FontSizeResolvers.width,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          builder: (context, routerChild) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: clampTextScaler(textScaler)),
              child: routerChild ?? const SizedBox.shrink(),
            );
          },
          home: child,
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Enough frames for the first post-frame callback, which is where screens
    // kick off their load.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Loads the bundled brand fonts into the test engine.
///
/// Without this every glyph renders as an Ahem box, which makes a golden image
/// worthless. Read straight off disk rather than through `rootBundle`, so it
/// does not depend on how the `fonts:` section of pubspec.yaml ends up in the
/// asset manifest.
///
/// Fonts are global to the engine, so call this from `setUpAll`.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  const families = <String, List<String>>{
    'Montserrat': [
      'assets/fonts/Montserrat-SemiBold.ttf',
      'assets/fonts/Montserrat-Bold.ttf',
    ],
    'Noto Sans': [
      'assets/fonts/NotoSans-Regular.ttf',
      'assets/fonts/NotoSans-Bold.ttf',
    ],
  };

  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  // Material icons are not loaded in a test by default, so every Icon renders
  // as an empty square. This one does come from the test asset bundle rather
  // than from disk, because it ships inside the Flutter SDK.
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}
