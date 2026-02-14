import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/dispatch_model.dart';

abstract class DispatchRemoteDataSource {
  Future<List<DispatchModel>> getDispatchList();
  Future<DispatchModel> getDispatchById(int id);
}

class DispatchRemoteDataSourceImpl implements DispatchRemoteDataSource {
  final ApiClient apiClient;

  DispatchRemoteDataSourceImpl(this.apiClient);

  @override
  Future<List<DispatchModel>> getDispatchList() async {
    try {
      // MOCK IMPLEMENTATION - Replace with real API call later
      await Future.delayed(const Duration(seconds: 1));

      // Mock data
      final mockData = [
        {
          "id": 1,
          "title": "Fire Incident",
          "location": "Zone 3",
          "status": "Active",
          "created_at": "2026-02-14"
        },
        {
          "id": 2,
          "title": "Flood Rescue",
          "location": "Barangay 5",
          "status": "Completed",
          "created_at": "2026-02-13"
        },
        {
          "id": 3,
          "title": "Medical Emergency",
          "location": "Downtown Area",
          "status": "Pending",
          "created_at": "2026-02-14"
        },
        {
          "id": 4,
          "title": "Road Accident",
          "location": "Highway 1",
          "status": "Active",
          "created_at": "2026-02-13"
        },
        {
          "id": 5,
          "title": "Building Evacuation",
          "location": "Mall Complex",
          "status": "Completed",
          "created_at": "2026-02-12"
        },
      ];

      return mockData
          .map((json) => DispatchModel.fromJson(json))
          .toList();

      // Real API implementation (commented out for now)
      /*
      final response = await apiClient.get(ApiConstants.dispatchListEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => DispatchModel.fromJson(json)).toList();
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Failed to fetch dispatches',
          statusCode: response.statusCode,
        );
      }
      */
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<DispatchModel> getDispatchById(int id) async {
    try {
      // MOCK IMPLEMENTATION - Replace with real API call later
      await Future.delayed(const Duration(milliseconds: 500));

      final dispatches = await getDispatchList();
      final dispatch = dispatches.firstWhere(
        (d) => d.id == id,
        orElse: () => throw ServerException(message: 'Dispatch not found'),
      );

      return dispatch;

      // Real API implementation (commented out for now)
      /*
      final response = await apiClient.get(
        ApiConstants.dispatchDetailEndpoint(id),
      );

      if (response.statusCode == 200) {
        return DispatchModel.fromJson(response.data['data']);
      } else {
        throw ServerException(
          message: response.data['message'] ?? 'Failed to fetch dispatch',
          statusCode: response.statusCode,
        );
      }
      */
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}