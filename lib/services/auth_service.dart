import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'web_helper.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUserData(String uid) async {
    if (uid.trim().isEmpty) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (e) {
      print("Error getting user data: $e");
    }
    return null;
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    if (uid.trim().isEmpty) return;
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      print("Error updating user data: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    reloadPage();
  }
}
