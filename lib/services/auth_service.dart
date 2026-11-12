import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _ready = false;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> _init() async {
    if (_ready) return;
    await _google.initialize();
    _ready = true;
  }

  /// Returns true when signed in, false if the user cancelled.
  Future<bool> signInWithGoogle() async {
    await _init();
    try {
      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _init();
    await _google.signOut();
    await _auth.signOut();
  }
}
