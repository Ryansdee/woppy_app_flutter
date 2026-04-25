import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // Stream pour écouter l'état de connexion en temps réel
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // Login
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Register
  Future<UserCredential> register({
    required String email,
    required String password,
    required String nom,
    required String role, // 'etudiant' ou 'employeur'
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Crée le doc user dans Firestore (comme dans ton app Next.js)
    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email,
      'nom': nom,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  // Logout
  Future<void> logout() async => await _auth.signOut();
}