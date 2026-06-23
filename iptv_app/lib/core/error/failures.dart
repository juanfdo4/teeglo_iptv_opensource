import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server Failure']);
}

class LocalStorageFailure extends Failure {
  const LocalStorageFailure([super.message = 'Local Storage Failure']);
}

class ParsingFailure extends Failure {
  const ParsingFailure([super.message = 'Parsing Failure']);
}
