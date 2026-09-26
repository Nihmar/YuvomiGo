import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yuvomigo/core/widgets/error_retry_tile.dart';
import 'package:yuvomigo/core/widgets/period_bar.dart';
import 'package:yuvomigo/core/utils/color_utils.dart';
import 'package:yuvomigo/core/utils/date_utils.dart';
import 'package:yuvomigo/features/schedule/schedule_models.dart';
import 'package:yuvomigo/features/schedule/schedule_providers.dart';

/// Schermata Turni: settimana lavorativa del household (sola lettura).
final class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

final class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  static const _scrollPhysics = AlwaysScrollableScrollPhysics();

  DateTime _week = mondayOf(DateTime.now());

  String get _weekKey => dateKey(_week);

  String get _weekLabel {
    final locale = Localizations.localeOf(context).toString();
    final end = DateTime(_week.year, _week.month, _week.day + 6);
    return '${DateFormat('d MMM', locale).format(_week)} – '
        '${DateFormat('d MMM', locale).format(end)}';
  }

  void _shiftWeek(int days) {
    setState(() {
      _week = DateTime(_week.year, _week.month, _week.day + days);
    });
  }

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(scheduleWeekProvider(_weekKey));
    final members = ref.watch(scheduleMembersProvider).value ?? const [];
    final names = {for (final member in members) member.id: member};

    return Scaffold(
      appBar: AppBar(title: const Text('Turni')),
      body: Column(
        children: [
          PeriodBar(
            label: _weekLabel,
            onPrevious: () => _shiftWeek(-7),
            onNext: () => _shiftWeek(7),
            onToday: () => setState(() => _week = mondayOf(DateTime.now())),
            previousTooltip: 'Settimana precedente',
            nextTooltip: 'Settimana successiva',
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(scheduleWeekProvider(_weekKey));
                ref.invalidate(scheduleMembersProvider);
                try {
                  await ref.read(scheduleWeekProvider(_weekKey).future);
                } catch (_) {
                  // L'errore è già nello stato del provider.
                }
              },
              child: week.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: _scrollPhysics,
                  padding: const EdgeInsets.all(16),
                  children: [
                    ErrorRetryTile(
                      message: 'Impossibile caricare i turni.',
                      detail: e.toString(),
                      onRetry: () =>
                          ref.invalidate(scheduleWeekProvider(_weekKey)),
                    ),
                  ],
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return ListView(
                      physics: _scrollPhysics,
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          'Nessun turno in questa settimana.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );
                  }
                  return _ScheduleList(entries: entries, members: names);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.entries, required this.members});

  final List<ScheduleEntry> entries;
  final Map<int, ScheduleMember> members;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final groups = <String, List<ScheduleEntry>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.dateKey, () => []).add(entry);
    }
    final dates = groups.keys.toList()..sort();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              _dayLabel(date, locale),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          for (final entry in groups[date]!..sort(compareScheduleEntries))
            _EntryTile(entry: entry, member: members[entry.userId]),
        ],
      ],
    );
  }

  String _dayLabel(String date, String locale) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return DateFormat('EEEE d MMMM', locale).format(parsed);
  }
}

final class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.member});

  final ScheduleEntry entry;
  final ScheduleMember? member;

  @override
  Widget build(BuildContext context) {
    final color = entry.isFree
        ? Theme.of(context).colorScheme.outlineVariant
        : parseHexColor(entry.shiftType?.color) ??
              Theme.of(context).colorScheme.primaryContainer;
    final parts = <String>[
      if (member != null) member!.displayName,
      if (entry.timeLabel.isNotEmpty) entry.timeLabel,
      if (entry.note?.isNotEmpty == true) entry.note!,
      if (entry.source == 'extra') 'extra',
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(
          entry.isFree ? Icons.beach_access_outlined : Icons.work_outline,
          size: 20,
          color: Colors.white,
        ),
      ),
      title: Text(
        entry.label,
        style: entry.isFree ? TextStyle(color: Colors.grey.shade600) : null,
      ),
      subtitle: Text(parts.join(' · ')),
    );
  }
}
