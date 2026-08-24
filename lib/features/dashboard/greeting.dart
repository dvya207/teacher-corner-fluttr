/// Which greeting the dashboard opens with, by time of day.
///
/// A PURE FUNCTION OF A [DateTime], not a reader of the clock, so the boundaries
/// are testable. A greeting that reads "Good morning" at six in the evening is a
/// small thing that makes an app feel broken, and it is only ever wrong at the
/// boundaries — which is exactly what a function taking the time can be pinned
/// on and one calling `DateTime.now()` internally cannot.
///
/// LOCAL TIME, because the teacher's afternoon is the one that matters. The
/// caller passes `DateTime.now()`, which is already local.
///
/// The bands are the conventional English ones and are deliberately not
/// configurable: they are shared by every locale here, and a language that
/// divides the day differently needs different STRINGS, not different hours.
library;

/// Returns the localisation key for [at]'s time of day.
///
///   00:00 - 11:59  morning
///   12:00 - 16:59  afternoon
///   17:00 - 23:59  evening
String greetingKeyFor(DateTime at) {
  final hour = at.hour;
  if (hour < 12) return 'dashboard.greeting_morning';
  if (hour < 17) return 'dashboard.greeting_afternoon';
  return 'dashboard.greeting_evening';
}
