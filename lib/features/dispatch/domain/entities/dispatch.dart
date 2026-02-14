class Dispatch {
  final int id;
  final String title;
  final String location;
  final String status;
  final String createdAt;

  Dispatch({
    required this.id,
    required this.title,
    required this.location,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
}