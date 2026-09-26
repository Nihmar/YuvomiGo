import 'package:yuvomigo/core/api/api_error.dart';
import 'package:yuvomigo/core/api/yuvomi_api.dart';

/// Preferenze rilevanti per il client (sottoinsieme di `GET /preferences`).
final class AppPreferences {
  const AppPreferences({
    this.currency = 'EUR',
    this.holidayCountry,
    this.holidaySubdivision,
    this.holidayShowPublic = true,
    this.holidayShowSchool = true,
  });

  final String currency;
  final String? holidayCountry;
  final String? holidaySubdivision;
  final bool holidayShowPublic;
  final bool holidayShowSchool;

  factory AppPreferences.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AppPreferences(
      currency: data['currency'] as String? ?? 'EUR',
      holidayCountry: data['holiday_country'] as String?,
      holidaySubdivision: data['holiday_subdivision'] as String?,
      holidayShowPublic: data['holiday_show_public'] != false,
      holidayShowSchool: data['holiday_show_school'] != false,
    );
  }
}

/// Un paese disponibile per le festività.
final class HolidayCountry {
  const HolidayCountry({required this.isoCode, required this.name});

  final String isoCode;
  final String name;

  factory HolidayCountry.fromJson(Map<String, dynamic> json) => HolidayCountry(
    isoCode: json['isoCode'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );
}

/// Repository delle preferenze di istanza/utente.
base class PreferencesRepository {
  PreferencesRepository(this._api);

  final YuvomiApi _api;

  Future<AppPreferences> fetch() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/preferences',
      );
      return AppPreferences.fromJson(res.data ?? const <String, dynamic>{});
    });
  }

  /// Aggiorna solo le chiavi presenti nel [patch].
  Future<AppPreferences> update(Map<String, dynamic> patch) {
    return mapApiErrors(() async {
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/api/v1/preferences',
        data: patch,
      );
      return AppPreferences.fromJson(res.data ?? const <String, dynamic>{});
    });
  }

  /// Paesi selezionabili per le festività.
  Future<List<HolidayCountry>> fetchHolidayCountries() {
    return mapApiErrors(() async {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/api/v1/preferences/holidays/countries',
      );
      final data = res.data?['data'];
      final raw = data is List ? data : const <dynamic>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(HolidayCountry.fromJson)
          .toList();
    });
  }
}
