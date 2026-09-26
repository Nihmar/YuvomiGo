import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/birthday_repository.dart';
import 'package:yuvomigo/features/birthdays/birthday_models.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';

final birthdayRepositoryProvider = Provider<BirthdayRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) {
    throw StateError('BirthdayRepository senza sessione attiva');
  }
  return BirthdayRepository(api);
});

/// Ultimo errore di un'azione sui compleanni (SnackBar).
final birthdaysActionErrorProvider =
    NotifierProvider<BirthdaysActionErrorNotifier, Object?>(
      BirthdaysActionErrorNotifier.new,
    );

final class BirthdaysActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

final birthdaysProvider =
    NotifierProvider.autoDispose<BirthdaysNotifier, AsyncValue<List<Birthday>>>(
      BirthdaysNotifier.new,
    );

final class BirthdaysNotifier extends Notifier<AsyncValue<List<Birthday>>> {
  bool _loading = false;

  @override
  AsyncValue<List<Birthday>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo la lista corrente (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (!ref.mounted) return;
    if (_loading) return;
    _loading = true;
    final repo = ref.read(birthdayRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final birthdays = await repo.fetchBirthdays();
      if (!ref.mounted) return;
      state = AsyncData(birthdays);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(birthdaysActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Crea il compleanno; ritorna false se fallisce (dialog aperto).
  Future<bool> add({
    required String name,
    required String birthDate,
    String? notes,
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(birthdayRepositoryProvider);
    ref.read(birthdaysActionErrorProvider.notifier).clear();
    try {
      await repo.createBirthday(name: name, birthDate: birthDate, notes: notes);
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(birthdaysActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  /// Aggiorna il compleanno; ritorna false se fallisce.
  Future<bool> update(
    int id, {
    required String name,
    required String birthDate,
    String? notes,
  }) async {
    if (!ref.mounted) return false;
    final repo = ref.read(birthdayRepositoryProvider);
    ref.read(birthdaysActionErrorProvider.notifier).clear();
    try {
      await repo.updateBirthday(
        id,
        name: name,
        birthDate: birthDate,
        notes: notes,
      );
      if (!ref.mounted) return true;
      await _fetch(showLoading: false);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      ref.read(birthdaysActionErrorProvider.notifier).report(e);
      return false;
    }
  }

  Future<void> remove(int id) async {
    if (!ref.mounted) return;
    final repo = ref.read(birthdayRepositoryProvider);
    ref.read(birthdaysActionErrorProvider.notifier).clear();
    try {
      await repo.deleteBirthday(id);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.where((b) => b.id != id).toList());
      }
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(birthdaysActionErrorProvider.notifier).report(e);
    }
  }
}
