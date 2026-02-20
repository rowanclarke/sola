import 'package:flutter/foundation.dart';
import 'package:sola/core/models/session_model.dart';

/// Manages and provides observable access to the current application session state.
/// Notifies listeners whenever the session state changes.
class SessionState extends ChangeNotifier {
  SessionModel _session;

  SessionState({required SessionModel initialSession})
      : _session = initialSession;

  SessionModel get session => _session;

  void updateSession(SessionModel newSession) {
    _session = newSession;
    notifyListeners();
  }
}
