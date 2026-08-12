import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Bridges Riverpod's [authStateProvider] into a [Listenable] so go_router
/// can redirect to/from the auth flow whenever sign-in state changes.
class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(this._ref) {
    _isSignedIn = _ref.read(isSignedInProvider);
    _sub = _ref.listen<bool>(isSignedInProvider, (previous, next) {
      if (previous != next) {
        _isSignedIn = next;
        notifyListeners();
      }
    });
  }

  final Ref _ref;
  late final ProviderSubscription<bool> _sub;
  late bool _isSignedIn;

  bool get isSignedIn => _isSignedIn;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
