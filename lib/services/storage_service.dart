import 'package:shared_preferences/shared_preferences.dart';
import '../models/deck.dart';
import '../models/sync_models.dart';
import 'dart:convert';

class StorageService {
  static const String _decksKey = 'decks';
  static const String _syncServerUrlKey = 'sync_server_url';
  static const String _syncApiTokenKey = 'sync_api_token';
  static const String _defaultSyncServerUrl = 'https://ankiweb.net';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<List<Deck>> getDecks() async {
    final String? decksJson = _prefs.getString(_decksKey);
    if (decksJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(decksJson);
    return decoded.map((json) => Deck.fromJson(json)).toList();
  }

  Future<void> saveDecks(List<Deck> decks) async {
    final String encoded = jsonEncode(decks.map((d) => d.toJson()).toList());
    await _prefs.setString(_decksKey, encoded);
  }

  Future<SyncSettings> getSyncSettings() async {
    final serverUrl = _prefs.getString(_syncServerUrlKey) ?? _defaultSyncServerUrl;
    final apiToken = _prefs.getString(_syncApiTokenKey) ?? '';
    return SyncSettings(
      serverUrl: serverUrl,
      apiToken: apiToken,
    );
  }

  Future<void> saveSyncSettings(SyncSettings settings) async {
    await _prefs.setString(_syncServerUrlKey, settings.serverUrl.trim().isEmpty
        ? _defaultSyncServerUrl
        : settings.serverUrl.trim());
    await _prefs.setString(_syncApiTokenKey, settings.apiToken.trim());
  }
}
