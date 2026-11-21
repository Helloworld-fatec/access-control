import 'package:dio/dio.dart';

import '../../../core/network/interceptors/retry_interceptor.dart';

class TerminalLocation {
  TerminalLocation.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      label = [
        json['building'],
        json['entrance'],
        json['door'],
        json['turnstile'],
        json['description'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' · ');

  final String id;
  final String label;
}

class Terminal {
  Terminal.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = json['name'] as String,
      locationId = json['locationId'] as String,
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      location = json['location'] is Map<String, dynamic>
          ? TerminalLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null;

  final String id;
  final String name;
  final String locationId;
  final double latitude;
  final double longitude;
  final TerminalLocation? location;
}

class TerminalPage {
  TerminalPage.fromJson(Map<String, dynamic> json)
    : items = (json['data'] as List)
          .cast<Map<String, dynamic>>()
          .map(Terminal.fromJson)
          .toList(),
      totalPages = json['totalPages'] as int;

  final List<Terminal> items;
  final int totalPages;
}

class TerminalsRepository {
  TerminalsRepository(this._dio);

  final Dio _dio;

  Future<TerminalPage> list({required int page, String? locationId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/terminals',
      queryParameters: {'page': page, 'locationId': ?locationId},
    );
    return TerminalPage.fromJson(response.data!);
  }

  Future<List<TerminalLocation>> listLocations() async {
    final locations = <TerminalLocation>[];
    var page = 1;
    int totalPages;
    do {
      final response = await _dio.get<Map<String, dynamic>>(
        '/locations',
        queryParameters: {'page': page, 'pageSize': 100},
      );
      final data = response.data!;
      locations.addAll(
        (data['data'] as List).cast<Map<String, dynamic>>().map(
          TerminalLocation.fromJson,
        ),
      );
      totalPages = data['totalPages'] as int;
      page++;
    } while (page <= totalPages);
    return locations;
  }

  Future<Terminal> get(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/terminals/$id');
    return Terminal.fromJson(response.data!);
  }

  Future<String> create(Map<String, Object> fields) =>
      _issueCode('/terminals', data: fields);

  Future<void> update(String id, Map<String, Object> fields) async {
    await _dio.put<void>('/terminals/$id', data: fields);
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/terminals/$id');
  }

  Future<String> rotateCode(String id) =>
      _issueCode('/terminals/$id/rotate-key');

  Future<String> _issueCode(String path, {Map<String, Object>? data}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(extra: {RetryInterceptor.skipRetryKey: true}),
    );
    return response.data!['apiKey'] as String;
  }
}
