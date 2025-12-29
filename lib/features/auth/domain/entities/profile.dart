class UserProfile {
  final String id;
  final String? email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final String? age;
  final String? phone;
  final String? gender;
  final String? bio;
  final bool isPublic;

  UserProfile({
    required this.id,
    this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.age,
    this.phone,
    this.gender,
    this.bio,
    this.isPublic = true,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
      age: json['age'],
      phone: json['phone'],
      gender: json['gender'],
      bio: json['bio'],
      isPublic: json['is_public'] ?? true,
    );
  }
}
