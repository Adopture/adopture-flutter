import 'package:flutter/widgets.dart';

/// Observes app lifecycle changes and triggers callbacks.
class LifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onAppOpened;
  final VoidCallback onAppBackgrounded;

  bool _isRegistered = false;

  LifecycleObserver({
    required this.onAppOpened,
    required this.onAppBackgrounded,
  });

  /// Registers the observer with the widgets binding.
  void register() {
    if (_isRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
  }

  /// Unregisters the observer.
  void unregister() {
    if (!_isRegistered) return;
    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onAppOpened();
      case AppLifecycleState.paused:
        onAppBackgrounded();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }
}
