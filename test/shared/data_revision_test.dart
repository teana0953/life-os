import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/data_revision.dart';

void main() {
  group('DataRevision', () {
    test('starts at revision 0', () {
      expect(DataRevision().revision, 0);
    });

    test('bump increments the revision and notifies listeners', () {
      final revision = DataRevision();
      var notified = 0;
      revision.addListener(() => notified++);

      revision.bump();

      expect(revision.revision, 1);
      expect(notified, 1);

      revision.bump();

      expect(revision.revision, 2);
      expect(notified, 2);
    });
  });
}
