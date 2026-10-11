import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final String phone;
  final String accountId;
  final String? profilePicBase64;
  final DateTime? lastPasswordChange;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    required this.phone,
    required this.accountId,
    this.profilePicBase64,
    this.lastPasswordChange,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    DateTime? lastChange;
    if (data['last_password_change'] is Timestamp) {
      lastChange = (data['last_password_change'] as Timestamp).toDate();
    }

    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      fullName: data['full_name'] ?? '',
      role: data['role'] ?? '',
      phone: data['phone'] ?? '',
      accountId: data['account_id'] ?? '',
      profilePicBase64: data['profile_pic_base64'],
      lastPasswordChange: lastChange,
    );
  }
}
