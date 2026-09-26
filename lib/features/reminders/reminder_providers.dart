import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/reminder_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/reminders/reminder_models.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) {
    throw StateError('ReminderRepository senza sessione attiva');
  }
  return ReminderRepository(api);
});

/// Ultimo errore di un'azione sui promemoria (SnackBar).
final remindersActionErrorProvider =
    NotifierProvider<RemindersActionErrorNotifier, Object?>(
      RemindersActionErrorNotifier.new,
    );

final class RemindersActionErrorNotifier extends Notifier<Object?> {
  @override
  Object? build() => null;

  void clear() => state = null;
  void report(Object error) => state = error;
}

final remindersProvider =
    NotifierProvider.autoDispose<RemindersNotifier, AsyncValue<List<Reminder>>>(
      RemindersNotifier.new,
    );

final class RemindersNotifier extends Notifier<AsyncValue<List<Reminder>>> {
  bool _loading = false;

  @override
  AsyncValue<List<Reminder>> build() {
    Future.microtask(load);
    return const AsyncLoading();
  }

  Future<void> load() => _fetch(showLoading: true);

  /// Ricarica mantenendo la lista corrente (pull-to-refresh).
  Future<void> refresh() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    if (_loading) return;
    _loading = true;
    final repo = ref.read(reminderRepositoryProvider);
    if (showLoading) state = const AsyncLoading();
    try {
      final reminders = await repo.fetchPending();
      if (!ref.mounted) return;
      state = AsyncData(reminders);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (state.hasValue) {
        ref.read(remindersActionErrorProvider.notifier).report(e);
      } else {
        state = AsyncError(e, st);
      }
    } finally {
      _loading = false;
    }
  }

  /// Archivia ("fatto") il promemoria; sparisce dalla lista.
  Future<void> dismiss(int id) async {
    final repo = ref.read(reminderRepositoryProvider);
    ref.read(remindersActionErrorProvider.notifier).clear();
    try {
      await repo.dismiss(id);
      if (!ref.mounted) return;
      _removeLocally(id);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(remindersActionErrorProvider.notifier).report(e);
    }
  }

  Future<void> remove(int id) async {
    final repo = ref.read(reminderRepositoryProvider);
    ref.read(remindersActionErrorProvider.notifier).clear();
    try {
      await repo.deleteReminder(id);
      if (!ref.mounted) return;
      _removeLocally(id);
    } catch (e) {
      if (!ref.mounted) return;
      ref.read(remindersActionErrorProvider.notifier).report(e);
    }
  }

  void _removeLocally(int id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}
