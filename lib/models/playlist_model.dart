class PlaylistModel {
  final String id;
  final String name;
  final String visibility;
  final String userId;
  final String? userName;
  final String imageUrl;
  final DateTime? createdAt;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.visibility,
    required this.userId,
    this.userName,
    required this.imageUrl,
    this.createdAt,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    String uName = 'Unknown User';
    String uId = '';

    if (json['userId'] is Map) {
      uId = json['userId']['_id'] ?? json['userId']['id'] ?? '';
      uName = json['userId']['name'] ?? 'Unknown User';
    } else if (json['userId'] is String) {
      uId = json['userId'];
    }

    return PlaylistModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Untitled Playlist',
      visibility: json['visibility'] ?? 'public',
      userId: uId,
      userName: uName,
      imageUrl: json['imageUrl'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'visibility': visibility,
      'userId': userId,
      'userName': userName,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
