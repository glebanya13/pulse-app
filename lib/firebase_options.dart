/// Generated from Firebase Console configs for project `pulse-by`.
/// Re-run `flutterfire configure --project=pulse-by` if you add platforms
/// or regenerate google-services.json / GoogleService-Info.plist.
library;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for Pulse Firebase.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAlzqoM0R1gEVWcgsLBt-OLySEm32z-Y94',
    appId: '1:197143610455:android:2141f8686b84361fb4cf12',
    messagingSenderId: '197143610455',
    projectId: 'pulse-by',
    storageBucket: 'pulse-by.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBR_zalgDDwSx9mFpW0sDt6TkGboE_0z7s',
    appId: '1:197143610455:ios:b301588372d18c6ab4cf12',
    messagingSenderId: '197143610455',
    projectId: 'pulse-by',
    storageBucket: 'pulse-by.firebasestorage.app',
    iosClientId:
        '197143610455-sbdrcs61v4lm5mpinj30barg2jehdnft.apps.googleusercontent.com',
    iosBundleId: 'by.pulse.app',
  );
}
