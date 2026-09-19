import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';
import 'package:yuvomigo/core/auth/session_manager.dart';
import 'package:yuvomigo/data/repositories/task_repository.dart';
import 'package:yuvomigo/features/tasks/task_models.dart';

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
            headers: const {'content-type': ['application/json']});
      }
    }
    return ResponseBody.fromString(jsonEncode({'data': <Object>[]}), 200,
        headers: const {'content-type': ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  YuvomiApi apiWith(_RoutingAdapter adapter) {
    final api = YuvomiApi(
        baseUrl: 'http://test.local',
        sessions: SessionManager(InMemoryStorage()));
    api.dio.httpClientAdapter = adapter;
    return api;
  }

  test('fetchTasks parses and sorts by due date', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('GET', '/api/v1/tasks', {
      'data': [
        {'id': 1, 'title': 'senza data', 'status': 'open'},
        {'id': 2, 'title': 'prima', 'status': 'open', 'due_date': '2026-09-01'},
        {'id': 3, 'title': 'poi', 'status': 'open', 'due_date': '2026-12-01'},
      ],
    });
    final repo = TaskRepository(apiWith(adapter));
    final tasks = await repo.fetchTasks();

    expect(tasks, hasLength(3));
    expect(tasks.first.id, 2); // 2026-09-01 prima
    expect(tasks[1].id, 3);
    expect(tasks[2].id, 1); // senza data ultima
  });

  test('createTask posts the payload', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('POST', '/api/v1/tasks',
        {'data': {'id': 7, 'title': 'compra', 'status': 'open'}});
    final repo = TaskRepository(apiWith(adapter));
    final created = await repo.createTask(title: 'compra');

    expect(created.id, 7);
    expect(adapter.requests.first.data['title'], 'compra');
  });

  test('setStatus PATCHes the status wire value', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('PATCH', '/api/v1/tasks/7/status',
        {'data': {'id': 7, 'title': 'compra', 'status': 'done'}});
    final repo = TaskRepository(apiWith(adapter));
    final updated = await repo.setStatus(7, TaskStatus.done);

    expect(updated.status, TaskStatus.done);
    expect(adapter.requests.first.data, {'status': 'done'});
  });

  test('deleteTask issues a DELETE', () async {
    final adapter = _RoutingAdapter();
    adapter.addRoute('DELETE', '/api/v1/tasks/7', {});
    final repo = TaskRepository(apiWith(adapter));
    await repo.deleteTask(7);

    expect(adapter.requests.first.method, 'DELETE');
    expect(adapter.requests.first.path, '/api/v1/tasks/7');
  });
}
