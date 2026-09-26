import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/birthday_repository.dart';

import 'utils/in_memory_storage.dart';

final class _RoutingAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> routes = [];
  final List<RequestOptions> requests = [];

  void addRoute(String method, String path, Object body) {
    routes.add({'method': method, 'path': path, 'body': body});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    for (final r in routes) {
      if (r['method'] == options.method && r['path'] == options.path) {
        return ResponseBody.fromString(
          jsonEncode(r['body']),
          200,
          headers: const {
            'content-type': ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'data': <Object>[]}),
      200,
      headers: const {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  YuvomiApi apiWith(_RoutingAdapter adapter) {
    final api = YuvomiApi(
      baseUrl: 'http://test.local',
      sessions: SessionManager(InMemoryStorage()),
    );
    api.dio.httpClientAdapter = adapter;
    return api;
  }

  test('fetchBirthdays parses and sorts by days_until', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/birthdays', {
      'data': [
        {
          'id': 1,
          'name': 'Zia',
          'birth_date': '1980-01-01',
          'days_until': 30,
          'next_age': 46,
        },
        {
          'id': 2,
          'name': 'Marco',
          'birth_date': '2015-06-01',
          'days_until': 0,
          'next_age': 11,
        },
      ],
    });
    final repo = BirthdayRepository(apiWith(adapter));
    final birthdays = await repo.fetchBirthdays();

    expect(birthdays.first.name, 'Marco');
    expect(birthdays.first.daysUntil, 0);
    expect(birthdays[1].nextAge, 46);
  });

  test('createBirthday posts name, birth_date and notes', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/birthdays', {
      'data': {
        'id': 5,
        'name': 'Luca',
        'birth_date': '1990-03-04',
        'days_until': 12,
      },
    });
    final repo = BirthdayRepository(apiWith(adapter));
    final created = await repo.createBirthday(
      name: 'Luca',
      birthDate: '1990-03-04',
    );

    expect(created.id, 5);
    expect(adapter.requests.first.data, {
      'name': 'Luca',
      'birth_date': '1990-03-04',
    });
  });

  test('updateBirthday PUTs the fields', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PUT', '/api/v1/birthdays/5', {
      'data': {
        'id': 5,
        'name': 'Luca',
        'birth_date': '1990-03-04',
        'notes': 'cugino',
      },
    });
    final repo = BirthdayRepository(apiWith(adapter));
    await repo.updateBirthday(
      5,
      name: 'Luca',
      birthDate: '1990-03-04',
      notes: 'cugino',
    );

    expect(adapter.requests.first.method, 'PUT');
    expect(adapter.requests.first.data, {
      'name': 'Luca',
      'birth_date': '1990-03-04',
      'notes': 'cugino',
    });
  });

  test('deleteBirthday issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/birthdays/5', {});
    final repo = BirthdayRepository(apiWith(adapter));
    await repo.deleteBirthday(5);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/birthdays/5');
  });
}
