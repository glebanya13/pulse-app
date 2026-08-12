import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Signs in with Google or Apple via Firebase Auth and returns the Firebase
/// ID token to exchange for our own JWTs on the Nest backend.
///
/// Firebase is only the IdP here - user rows live in Postgres.
/// Client configs and Admin SDK must use the same project (`pulse-by`).
class FirebaseSocialAuth {
  FirebaseSocialAuth({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleReady = false;

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  Future<SocialSignInResult> signInWithGoogle() async {
    await _ensureGoogle();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google Sign-In did not return an ID token');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await _auth.signInWithCredential(credential);
      return _requireIdToken(userCred.user, name: userCred.user?.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseSocialAuthCancelled();
      }
      rethrow;
    }
  }

  Future<SocialSignInResult> signInWithApple() async {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);
      final appleCred = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      if (appleCred.identityToken == null) {
        throw StateError('Apple Sign-In did not return an identity token');
      }
      final oauth = OAuthProvider('apple.com').credential(
        idToken: appleCred.identityToken,
        rawNonce: rawNonce,
        // Recent firebase_auth versions reject the credential as
        // "Invalid OAuth response from apple.com" without this - the
        // authorizationCode must be forwarded as the access token.
        accessToken: appleCred.authorizationCode,
      );
      final userCred = await _auth.signInWithCredential(oauth);
      // Apple only hands back givenName/familyName out-of-band on the
      // user's very first authorization - never inside the identity token,
      // and never again on subsequent sign-ins. Grab it now or lose it.
      final appleName = [appleCred.givenName, appleCred.familyName]
          .where((p) => p != null && p.trim().isNotEmpty)
          .join(' ')
          .trim();
      return _requireIdToken(
        userCred.user,
        name: appleName.isEmpty ? null : appleName,
        appleAuthorizationCode: appleCred.authorizationCode,
      );
    }

    // Android: Firebase Auth Apple provider (enable in Firebase console).
    if (Platform.isAndroid) {
      final userCred = await _auth.signInWithProvider(AppleAuthProvider());
      return _requireIdToken(userCred.user, name: userCred.user?.displayName);
    }

    throw UnsupportedError('Apple Sign-In is not supported on this platform');
  }

  Future<SocialSignInResult> _requireIdToken(
    User? user, {
    String? name,
    String? appleAuthorizationCode,
  }) async {
    final token = await user?.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw StateError('Firebase Auth did not return an ID token');
    }
    return SocialSignInResult(
      idToken: token,
      name: name,
      appleAuthorizationCode: appleAuthorizationCode,
    );
  }

  Future<void> signOutLocal() async {
    await _ensureGoogle();
    await Future.wait([
      _auth.signOut(),
      GoogleSignIn.instance.signOut(),
    ]);
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

class FirebaseSocialAuthCancelled implements Exception {
  @override
  String toString() => 'Вход отменён';
}

class SocialSignInResult {
  const SocialSignInResult({
    required this.idToken,
    this.name,
    this.appleAuthorizationCode,
  });

  final String idToken;
  final String? name;
  final String? appleAuthorizationCode;
}
