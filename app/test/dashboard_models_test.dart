import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/features/dashboard/dashboard_models.dart';

void main() {
  group('DashboardData.fromJson', () {
    test('parses a full dashboard payload', () {
      final json = <String, dynamic>{
        'upcomingEvents': [
          {
            'id': 1,
            'title': 'Riunione',
            'start_datetime': '2026-09-20T10:00:00',
            'all_day': 0,
            'location': 'Sala',
            'color': '#007AFF',
          },
        ],
        'urgentTasks': [
          {
            'id': 10,
            'title': 'Paga bolletta',
            'priority': 'urgent',
            'status': 'open',
            'due_date': '2026-09-20',
            'due_time': '18:00',
            'assigned_name': 'Mama',
          },
        ],
        'openTaskCount': 7,
        'overdueTaskCount': 2,
        'pinnedNotes': [
          {'id': 20, 'title': 'WIFI', 'content': 'password: 1234', 'pinned': 1},
        ],
        'pinnedNotesCount': 1,
        'shoppingLists': [
          {
            'id': 30,
            'name': 'Supermarket',
            'open_count': 2,
            'total_count': 5,
            'items': [
              {'id': 31, 'name': 'Latte', 'quantity': '2', 'is_checked': 0},
              {'id': 32, 'name': 'Pane', 'is_checked': 0},
            ],
          },
        ],
        'shoppingOpenCount': 2,
        'shoppingOpenLists': 1,
      };

      final d = DashboardData.fromJson(json);

      expect(d.upcomingEvents, hasLength(1));
      expect(d.upcomingEvents.first.title, 'Riunione');
      expect(d.upcomingEvents.first.allDay, isFalse);
      expect(d.urgentTasks.first.title, 'Paga bolletta');
      expect(d.urgentTasks.first.priority, 'urgent');
      expect(d.openTaskCount, 7);
      expect(d.overdueTaskCount, 2);
      expect(d.pinnedNotes.first.pinned, isTrue);
      expect(d.pinnedNotesCount, 1);
      expect(d.shoppingLists.first.name, 'Supermarket');
      expect(d.shoppingLists.first.openCount, 2);
      expect(d.shoppingLists.first.items.first.name, 'Latte');
      expect(d.shoppingOpenCount, 2);
      expect(d.shoppingOpenLists, 1);
    });

    test('handles missing/empty fields gracefully', () {
      final d = DashboardData.fromJson(<String, dynamic>{});
      expect(d.upcomingEvents, isEmpty);
      expect(d.urgentTasks, isEmpty);
      expect(d.openTaskCount, isNull);
      expect(d.pinnedNotes, isEmpty);
      expect(d.pinnedNotesCount, 0);
      expect(d.shoppingLists, isEmpty);
      expect(d.shoppingOpenCount, isNull);
    });

    test('ignores non-list values', () {
      final d = DashboardData.fromJson({'upcomingEvents': 'nonsense'});
      expect(d.upcomingEvents, isEmpty);
    });

    test('parses int-like values as int', () {
      final d = DashboardData.fromJson({'openTaskCount': '3'});
      // Le stringhe numeriche NON sono int: restano null (comportamento esplicito).
      expect(d.openTaskCount, isNull);
      final d2 = DashboardData.fromJson({'openTaskCount': 3});
      expect(d2.openTaskCount, 3);
    });
  });

  group('item models', () {
    test('DashTask defaults', () {
      final t = DashTask.fromJson({'id': 5, 'title': 'X'});
      expect(t.priority, 'none');
      expect(t.status, 'open');
      expect(t.dueDate, isNull);
    });

    test('DashEvent all_day bool from int', () {
      expect(
        DashEvent.fromJson({'id': 1, 'title': 'A', 'all_day': 1}).allDay,
        isTrue,
      );
      expect(
        DashEvent.fromJson({'id': 1, 'title': 'A', 'all_day': 0}).allDay,
        isFalse,
      );
    });

    test('DashShoppingItem quantity optional', () {
      final i = DashShoppingItem.fromJson({'id': 1, 'name': 'Latte'});
      expect(i.quantity, isNull);
      expect(i.isChecked, isFalse);
    });
  });
}
