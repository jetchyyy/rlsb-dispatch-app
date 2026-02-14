import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dispatch.dart';
import '../repositories/dispatch_repository.dart';

class GetDispatchList {
  final DispatchRepository repository;

  GetDispatchList(this.repository);

  Future<Either<Failure, List<Dispatch>>> call() async {
    return await repository.getDispatchList();
  }
}