import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase ainda não foi configurado. Execute "flutterfire configure" '
      'e tente novamente.',
    );
  }
}
