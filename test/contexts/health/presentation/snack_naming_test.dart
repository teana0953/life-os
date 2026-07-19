import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/presentation/snack_naming.dart';

void main() {
  group('nextSnackName', () {
    test('no snack groups yet -> the base word with no number', () {
      expect(nextSnackName(['breakfast', 'lunch'], '點心'), '點心');
    });

    test('no meals at all -> the base word', () {
      expect(nextSnackName([], '點心'), '點心');
    });

    test('a bare base-word group exists -> base word + 2', () {
      expect(nextSnackName(['breakfast', '點心'], '點心'), '點心2');
    });

    test('bare + "…2" both exist -> base word + 3', () {
      expect(nextSnackName(['點心', '點心2'], '點心'), '點心3');
    });

    test(
      'only "…2" exists (bare deleted) -> base word + 3, via max+1 not count',
      () {
        expect(nextSnackName(['點心2'], '點心'), '點心3');
      },
    );

    test('a renamed snack group ("下午茶") is ignored by numbering', () {
      expect(nextSnackName(['下午茶'], '點心'), '點心');
    });

    test('standard meal names are ignored by numbering', () {
      expect(nextSnackName(['breakfast', 'lunch', 'dinner'], '點心'), '點心');
    });

    test('a mix of standard meals, a renamed snack, and a bare snack', () {
      expect(nextSnackName(['breakfast', '下午茶', '點心'], '點心'), '點心2');
    });
  });
}
