import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/data/repositories/schedule_repository.dart';
import 'package:yuvomigo/features/dashboard/dashboard_providers.dart';
import 'package:yuvomigo/features/schedule/schedule_models.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final api = ref.watch(yuvomiApiProvider);
  if (api == null) throw StateError('ScheduleRepository senza sessione attiva');
  return ScheduleRepository(api);
});

/// Turni della settimana che inizia nel lunedì [weekKey] ('YYYY-MM-DD').
final scheduleWeekProvider = FutureProvider.family
    .autoDispose<List<ScheduleEntry>, String>((ref, weekKey) async {
      final repo = ref.watch(scheduleRepositoryProvider);
      final monday = DateTime.parse(weekKey);
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      String key(DateTime date) =>
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      return repo.fetchRange(key(monday), key(sunday));
    });

/// Membri del household (nome/colore per ogni turno).
final scheduleMembersProvider =
    FutureProvider.autoDispose<List<ScheduleMember>>((ref) async {
      final repo = ref.watch(scheduleRepositoryProvider);
      return repo.fetchMembers();
    });
