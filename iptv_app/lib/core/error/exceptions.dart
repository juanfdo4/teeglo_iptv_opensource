class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'Server Error']);
}

class LocalStorageException implements Exception {
  final String message;
  LocalStorageException([this.message = 'Local Storage Error']);
}

class ParsingException implements Exception {
  final String message;
  ParsingException([this.message = 'Error parsing data']);
}
