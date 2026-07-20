import '../../../l10n/generated/app_localizations.dart';

/// The three standard meals; any other `meal` value is a snack whose value
/// already IS its display name (shared by Today and the food search screen).
const standardMeals = ['breakfast', 'lunch', 'dinner'];

/// Whether [meal] is one of the three standard meals; anything else is a
/// snack.
bool isStandardMeal(String meal) => standardMeals.contains(meal);

/// Maps a raw meal value to its localized display label: the three standard
/// meals are localized; any other value (a snack) already IS its own display
/// name and is shown verbatim.
String mealDisplayLabel(AppLocalizations loc, String meal) {
  switch (meal) {
    case 'breakfast':
      return loc.dietMealBreakfast;
    case 'lunch':
      return loc.dietMealLunch;
    case 'dinner':
      return loc.dietMealDinner;
    default:
      return meal;
  }
}

/// Maps a raw meal value to its emoji; any snack (non-standard meal) gets
/// the snack emoji.
String mealEmoji(String meal) {
  switch (meal) {
    case 'breakfast':
      return '🌅';
    case 'lunch':
      return '🍱';
    case 'dinner':
      return '🌙';
    default:
      return '🍎';
  }
}

/// Tie-break rank for the Today timeline sort: breakfast < lunch < dinner <
/// any snack, used only when two meals share the exact same `time`.
int standardMealRank(String meal) {
  final index = standardMeals.indexOf(meal);
  return index == -1 ? standardMeals.length : index;
}
