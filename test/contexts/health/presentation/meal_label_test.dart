import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/meal_label.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

void main() {
  final loc = lookupAppLocalizations(const Locale('en'));

  group('isStandardMeal', () {
    test('is true for the three standard meals', () {
      expect(isStandardMeal('breakfast'), isTrue);
      expect(isStandardMeal('lunch'), isTrue);
      expect(isStandardMeal('dinner'), isTrue);
    });

    test('is false for a snack name', () {
      expect(isStandardMeal('點心2'), isFalse);
    });
  });

  group('mealDisplayLabel', () {
    test('localizes the three standard meals', () {
      expect(mealDisplayLabel(loc, 'breakfast'), loc.dietMealBreakfast);
      expect(mealDisplayLabel(loc, 'lunch'), loc.dietMealLunch);
      expect(mealDisplayLabel(loc, 'dinner'), loc.dietMealDinner);
    });

    test('shows a snack value verbatim', () {
      expect(mealDisplayLabel(loc, '點心2'), '點心2');
    });
  });

  group('mealEmoji', () {
    test('gives each standard meal a distinct emoji', () {
      expect(mealEmoji('breakfast'), isNotEmpty);
      expect(mealEmoji('lunch'), isNot(mealEmoji('breakfast')));
      expect(mealEmoji('dinner'), isNot(mealEmoji('lunch')));
    });

    test('gives any snack the same fallback emoji', () {
      expect(mealEmoji('點心2'), mealEmoji('點心'));
    });
  });

  group('standardMealRank', () {
    test('orders breakfast < lunch < dinner < snack', () {
      expect(standardMealRank('breakfast'), lessThan(standardMealRank('lunch')));
      expect(standardMealRank('lunch'), lessThan(standardMealRank('dinner')));
      expect(standardMealRank('dinner'), lessThan(standardMealRank('點心')));
    });
  });
}
