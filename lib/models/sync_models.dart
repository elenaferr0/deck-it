class SyncSettings {
  final String serverUrl;
  final String apiToken;

  const SyncSettings({
    required this.serverUrl,
    required this.apiToken,
  });

  SyncSettings copyWith({
    String? serverUrl,
    String? apiToken,
  }) {
    return SyncSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      apiToken: apiToken ?? this.apiToken,
    );
  }
}

class CsvImportResult {
  final int decksCreated;
  final int cardsImported;

  const CsvImportResult({
    required this.decksCreated,
    required this.cardsImported,
  });
}

class AnkiSyncResult {
  final int decksImported;
  final int cardsImported;

  const AnkiSyncResult({
    required this.decksImported,
    required this.cardsImported,
  });
}
