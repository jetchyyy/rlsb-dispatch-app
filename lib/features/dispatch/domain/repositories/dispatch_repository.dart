import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dispatch.dart';

abstract class DispatchRepository {
  Future<Either<Failure, List<Dispatch>>> getDispatchList();
  Future<Either<Failure, Dispatch>> getDispatchById(int id);
}