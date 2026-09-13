class AudioModel {
  final String id;
  final String name;
  final String userId;
  final String? userName;
  final String audioUrl;
  final String thumbnailImageUrl;
  final String visibility;
  final DateTime? createdAt;

  AudioModel({
    required this.id,
    required this.name,
    required this.userId,
    this.userName,
    required this.audioUrl,
    required this.thumbnailImageUrl,
    required this.visibility,
    this.createdAt,
  });

  factory AudioModel.fromJson(Map<String, dynamic> json) {
    String uName = 'Unknown Artist';
    String uId = '';

    if (json['userId'] is Map) {
      uId = json['userId']['_id'] ?? json['userId']['id'] ?? '';
      uName = json['userId']['name'] ?? 'Unknown Artist';
    } else if (json['userId'] is String) {
      uId = json['userId'];
    }

    return AudioModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Untitled Audio',
      userId: uId,
      userName: uName,
      audioUrl: json['audioUrl'] ?? '',
      thumbnailImageUrl: json['thumbnailImageUrl'] ?? '',
      visibility: json['visibility'] ?? 'public',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'userName': userName,
      'audioUrl': audioUrl,
      'thumbnailImageUrl': thumbnailImageUrl,
      'visibility': visibility,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
