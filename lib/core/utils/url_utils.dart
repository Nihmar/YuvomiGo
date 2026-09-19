/// Normalizza l'URL del server inserito dall'utente.
///
/// - rimuove spazi e slash finale
/// - se manca lo schema lo precede con `http://`
/// - accetta solo `http` e `https`
String normalizeServerUrl(String input) {
  var url = input.trim();
  if (url.isEmpty) {
    throw const FormatException('Inserisci l\'URL del server.');
  }
  if (!url.contains('://')) {
    url = 'http://$url';
  }
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  final uri = Uri.parse(url);
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw const FormatException(
      'Lo schema deve essere http:// o https://.',
    );
  }
  if (uri.host.isEmpty) {
    throw const FormatException('URL non valido: manca l\'host.');
  }
  return url;
}

/// Valida senza eccezioni (per il validator dei form Material).
String? validateServerUrl(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Inserisci l\'URL del server.';
  }
  try {
    normalizeServerUrl(value);
  } on FormatException {
    return 'URL non valido (http:// o https://).';
  }
  return null;
}
