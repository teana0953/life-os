import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:life_os/contexts/finance/domain/exposure_settings_repository.dart';
import 'package:life_os/contexts/finance/domain/networth_exposure.dart';
import 'package:life_os/contexts/finance/infrastructure/shared_preferences_exposure_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'factors survive recreation, isolate users/accounts, and support unclassifying',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesExposureSettingsRepository(prefs);
      await store.write('a:b', 'account:/1', ExposureFactor.leveraged2);
      await store.write('a:b', 'cash', ExposureFactor.cash);
      await store.write('a', 'b:account:/1', ExposureFactor.leveraged3);
      final recreated = SharedPreferencesExposureSettingsRepository(
        await SharedPreferences.getInstance(),
      );
      expect(await recreated.read('a:b'), {
        'account:/1': ExposureFactor.leveraged2,
        'cash': ExposureFactor.cash,
      });
      expect(await recreated.read('a'), {
        'b:account:/1': ExposureFactor.leveraged3,
      });
      expect(await recreated.read('other'), isEmpty);
      await recreated.write('a:b', 'cash', null);
      expect(await store.read('a:b'), {
        'account:/1': ExposureFactor.leveraged2,
      });
    },
  );

  test('corrupt, future and malformed factors remain unknown', () async {
    SharedPreferences.setMockInitialValues({
      'networth.exposure.v1:u:ok': 1,
      'networth.exposure.v1:u:cash': 0,
      'networth.exposure.v1:u:future': 4,
      'networth.exposure.v1:u:negative': -1,
      'networth.exposure.v1:u:string': '2',
      'networth.exposure.v1:u:%ZZ': 2,
    });
    final store = SharedPreferencesExposureSettingsRepository(
      await SharedPreferences.getInstance(),
    );
    expect(await store.read('u'), {
      'ok': ExposureFactor.unleveraged,
      'cash': ExposureFactor.cash,
    });
  });

  for (final throwsError in [false, true]) {
    test(
      'failed platform save ($throwsError) does not survive a settings reread',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        SharedPreferencesStorePlatform.instance = _FailedStore(throwsError);
        final store = SharedPreferencesExposureSettingsRepository(prefs);
        await expectLater(
          store.write('u', 'asset', ExposureFactor.leveraged2),
          throwsA(isA<Exception>()),
        );
        expect(await store.read('u'), isEmpty);
        SharedPreferences.setMockInitialValues({});
      },
    );
  }
}

class _FailedStore extends SharedPreferencesStorePlatform {
  final bool throwsError;
  _FailedStore(this.throwsError);
  @override
  bool get isMock => true;
  @override
  Future<Map<String, Object>> getAll() async => {};
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throwsError) throw const ExposureSettingsFailure();
    return false;
  }

  @override
  Future<bool> remove(String key) => setValue('', key, 0);
  @override
  Future<bool> clear() async => false;
}
