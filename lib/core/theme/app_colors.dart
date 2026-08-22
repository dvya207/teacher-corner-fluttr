import 'dart:ui';

/// Canonical ThinkTac palette for the TIP Teacher Corner Android app.
///
/// Verified against `_assets/logos/New ThinkTac Logo/Logo/SVG/...`. The brand
/// is a two-colour system. Anything beyond [navy] + [skyBlue] is either a
/// tinted neutral, a semantic state colour, or — for legacy code paths —
/// an alias that resolves back to the canonical pair.
///
/// See `DESIGN.md` at the repo root for the full spec.
class AppColors {
  AppColors._();

  // ───── Brand (the entire palette) ────────────────────────────────────────
  // Values match the 2026-06 mockup tokens (--navy / --sky in
  // docs/mockup/PROVENANCE.md), which supersede the earlier #272B66/#169CD8.
  static const navy = Color(0xFF282B66);
  static const skyBlue = Color(0xFF049CD8);

  // Slightly darker navy for elevated/tonal surfaces. Not a brand colour, do
  // not use for accents.
  static const navyDark = Color(0xFF1E2258);

  // ───── Tinted neutrals (chroma ≤ .01, hue 274 — the navy hue) ────────────
  static const bg = Color(0xFFF8F8FA);
  static const white = Color(0xFFFFFFFF);
  static const borderSubtle = Color(0xFFEFEFF2);
  static const borderLight = Color(0xFFE8E8ED);
  static const borderInput = Color(0xFFDDDDDD);

  // ───── Text hierarchy ────────────────────────────────────────────────────
  static const textPrimary = Color(0xFF1F2030);
  static const textSecondary = Color(0xFF5C5E6E);
  static const textTertiary = Color(0xFF878896);
  static const textDisabled = Color(0xFFB5B6BE);
  static const charcoal = textPrimary; // legacy alias

  // ───── Semantic (only for state, never decoration) ──────────────────────
  static const success = Color(0xFF1B9E5A);
  static const warning = Color(0xFFC97B26);
  static const error = Color(0xFFC3392F);
  static const errorRed = error; // legacy alias
  static const successGreen = success; // legacy alias

  // ───── ISPF reference (programme-context badges only — NOT global chrome)─
  static const ispfTeal = Color(0xFF228E95);
  static const ispfMustard = Color(0xFFE69A2D);

  /// Warm accent for the splash product label ("TEACHER CORNER") only.
  ///
  /// The palette above is deliberately a two-colour system, so this is a
  /// documented exception rather than a new brand colour: it is the mustard
  /// already in the file, reused because the 2026-08 sign-in mockup Divya
  /// approved puts that label in warm orange. Resolve it back to navy or sky if
  /// the brand owner says no. Do NOT spread it to other chrome.
  static const splashProductLabel = ispfMustard;

  // ───── Retired aliases ──────────────────────────────────────────────────
  // Legacy code paths still reference these tokens. Each now resolves to the
  // canonical palette so existing widgets render on-brand without a one-shot
  // mass rewrite. New code MUST NOT use these names.
  static const teal = skyBlue;
  static const amber = warning;
  static const amberDark = warning;
  static const softAqua = borderSubtle;
  static const lightGrey = bg;

  // ───── Mockup-pattern helpers (2026-06 redesign) ─────────────────────────
  /// Translucent white tile on a navy hero (mockup stat tiles).
  static final heroTileBg = white.withValues(alpha: 0.12);

  /// Supporting text ON a navy surface (splash tagline, hero subtitles).
  /// Pure white for a whole sentence of supporting copy is too loud against
  /// navy; this is the dimmed step that the mockup uses.
  static final onNavySecondary = white.withValues(alpha: 0.82);

  /// 10% sky tint — icon tiles, badges, selected rows.
  static final skyBg = skyBlue.withValues(alpha: 0.10);

  /// Search field fill (mockup `Search classrooms…` bar).
  static const searchFill = Color(0xFFF1F5F9);

  /// Chip background at 15% opacity.
  static Color chipBackground(Color color) => color.withValues(alpha: 0.15);

  /// Solid navy — gradient retired in favour of solid surfaces (Sriram audit
  /// 2026-04-29). Kept as a list literal for one-off compat call sites.
  static const navyGradient = [navy, navy];

  /// Sky→teal CTA gradient — mockup CSS `linear-gradient(135deg,#049CD8,#0f766e)`
  /// (Submit Nominations / Confirm Students). Reintroduced by the 2026-06
  /// mockup; use ONLY via TcGradientButton, never as ad-hoc decoration.
  static const ctaGradient = [skyBlue, Color(0xFF0F766E)];

  /// Navy hero gradient — mockup CSS `linear-gradient(160deg,#1E2258,#282B66)`
  /// (splash, login hero, hero headers). Use ONLY via TcHeroHeader/splash.
  static const heroGradient = [navyDark, navy];
}
