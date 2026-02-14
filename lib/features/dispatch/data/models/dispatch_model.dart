import '../../domain/entities/dispatch.dart';

class DispatchModel extends Dispatch {
  DispatchModel({
    required super.id,
    required super.title,
    required super.location,
    required super.status,
    required super.createdAt,
  });

  factory DispatchModel.fromJson(Map<String, dynamic> json) {
    return DispatchModel(
      id: json['id'] as int,
      title: json['title'] as String,
      location: json['location'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'status': status,
      'created_at': createdAt,
    };
  }

  Dispatch toEntity() {
    return Dispatch(
      id: id,
      title: title,
      location: location,
      status: status,
      createdAt: createdAt,
    );
  }
}