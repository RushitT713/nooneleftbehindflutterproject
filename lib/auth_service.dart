import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in anonymously. Re-uses the existing anonymous account
  /// if the user has one, otherwise creates a new one.
  /// Persists the UID to SharedPreferences for reconnection.
  Future<User?> signInAnonymously() async {
    try {
      // If already signed in, return the existing user
      if (_auth.currentUser != null) {
        return _auth.currentUser;
      }

      UserCredential result = await _auth.signInAnonymously();
      final user = result.user;

      // Persist the UID
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('firebase_uid', user.uid);
      }

      return user;
    } catch (e) {
      print("Auth Error: ${e.toString()}");
      return null;
    }
  }

  /// Current user getter.
  User? get currentUser => _auth.currentUser;

  /// Returns the persisted UID even if Firebase hasn't loaded yet.
  Future<String?> getPersistedUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('firebase_uid');
  }
}