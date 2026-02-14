import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/dispatch.dart';
import '../../domain/repositories/dispatch_repository.dart';
import '../datasources/dispatch_remote_datasource.dart';

class DispatchRepositoryImpl implements DispatchRepository {
  final DispatchRemoteDataSource remoteDataSource;

  DispatchRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Dispatch>>> getDispatchList() async {
    try {
      final dispatchModels = await remoteDataSource.getDispatchList();
      final dispatches = dispatchModels.map((model) => model.toEntity()).toList();
      return Right(dispatches);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Dispatch>> getDispatchById(int id) async {
    try {
      final dispatchModel = await remoteDataSource.getDispatchById(id);
      return Right(dispatchModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}