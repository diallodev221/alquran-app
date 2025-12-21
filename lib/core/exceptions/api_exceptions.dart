/// Exceptions personnalisées pour la gestion des erreurs API
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException(String message) : super('Erreur réseau: $message');
}

class TimeoutException extends ApiException {
  TimeoutException()
    : super('Délai d\'attente dépassé. Veuillez vérifier votre connexion.');
}

class ServerException extends ApiException {
  final int? statusCode;
  ServerException(String message, {this.statusCode})
    : super('Erreur serveur: $message');
}

class CacheException extends ApiException {
  CacheException(String message) : super('Erreur cache: $message');
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super('Non trouvé: $message');
}
