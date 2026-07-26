class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String role;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? '',
      role: data['role'] ?? '',
    );
  }
}
