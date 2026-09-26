import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/features/auth/auth_providers.dart';
import 'package:yuvomigo/features/theme/theme_controller.dart';

import 'utils/in_memory_storage.dart';

ProviderContainer _container(InMemoryStorage storage) => ProviderContainer(
  overrides: [secureStorageProvider.overrideWithValue(storage)],
);

void main() {
  group('ThemeController', () {
    test('default is the historic orange seed', () {
      final container = _container(InMemoryStorage());
      addTearDown(container.dispose);
      expect(container.read(themeControllerProvider), defaultThemeSeed);
    });

    test('select updates state and persists', () async {
      final storage = InMemoryStorage();
      final container = _container(storage);
      addTearDown(container.dispose);

      await container.read(themeControllerProvider.notifier).select(0xFF2196F3);

      expect(container.read(themeControllerProvider), 0xFF2196F3);
      expect(storage.data[themeSeedStorageKey], '4280391411');
    });

    test('load restores a valid persisted seed', () async {
      final storage = InMemoryStorage();
      storage.data[themeSeedStorageKey] = '4278225275'; // 0xFF00897B teal
      final container = _container(storage);
      addTearDown(container.dispose);

      // Il build avvia il load async: attendo che completi.
      container.read(themeControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(themeControllerProvider), 0xFF00897B);
    });

    test('load ignores unknown or garbage values', () async {
      for (final raw in ['not-a-number', '4278190080']) {
        final storage = InMemoryStorage();
        storage.data[themeSeedStorageKey] = raw;
        final container = _container(storage);
        addTearDown(container.dispose);

        container.read(themeControllerProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(
          container.read(themeControllerProvider),
          defaultThemeSeed,
          reason: raw,
        );
      }
    });
  });
}
