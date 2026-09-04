class Profile {
  final String id;

  String name;
  String? avatarUrl;

  Profile({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }
}