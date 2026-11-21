/// Validações do formulário de login (mensagens em linguagem simples).
abstract final class LoginValidators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _octet = RegExp(r'^(0|[1-9][0-9]{0,2})$');
  static final RegExp _numericHost = RegExp(r'^[0-9.]+$');
  static final RegExp _hostLabel = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
    caseSensitive: false,
  );

  static const invalidServerAddress =
      'Informe um endereço válido, como 192.168.1.25:3333 ou https://meu-backend.onrender.com.';

  static String? serverAddress(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Informe o endereço do servidor.';
    return parseServerAddress(value!) == null ? invalidServerAddress : null;
  }

  static Uri? parseServerAddress(String value) {
    final text = value.trim();
    if (text.isEmpty || RegExp(r'[\s\\@]').hasMatch(text)) return null;
    final explicitScheme = text.contains('://');
    final address = explicitScheme ? text : 'http://$text';
    final authority = address.split('://').last.split('/').first;
    final uri = Uri.tryParse(address);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        authority.endsWith(':') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.port < 1 ||
        uri.port > 65535 ||
        !const {'', '/', '/api', '/api/'}.contains(uri.path)) {
      return null;
    }
    final host = uri.host;
    final ipv6 = host.contains(':');
    final ipv4 = _numericHost.hasMatch(host);
    final parts = host.split('.');
    if (ipv4) {
      if (parts.length != 4 ||
          !parts.every(
            (part) => _octet.hasMatch(part) && int.parse(part) <= 255,
          )) {
        return null;
      }
    } else if (!ipv6 && !parts.every(_hostLabel.hasMatch)) {
      return null;
    }
    final useHttps =
        !explicitScheme &&
        !authority.contains(':') &&
        !ipv4 &&
        !ipv6 &&
        host != 'localhost';
    return uri.replace(scheme: useHttps ? 'https' : uri.scheme, path: '/api');
  }

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe o e-mail.';
    if (!_email.hasMatch(text)) {
      return 'E-mail inválido. Exemplo: nome@exemplo.com.';
    }
    return null;
  }

  /// A senha não é aparada nem alterada: espaços fazem parte dela.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Informe a senha.';
    return null;
  }
}
