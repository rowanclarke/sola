import 'dart:io';
import 'dart:convert'; // Import for json encoding/decoding
import 'package:sola/domain/models/session_model.dart';

class SessionRepository {
  final File sessionFile;

  SessionRepository(this.sessionFile);

  Future<SessionModel?> loadSession() async {
    if (await sessionFile.exists()) {
      try {
        final String jsonString = await sessionFile.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        return SessionModel.fromJson(jsonMap);
      } catch (e) {
        print('Error loading session: $e'); // Log error
        return null;
      }
    }
    return null;
  }

  Future<void> saveSession(SessionModel session) async {
    final String jsonString = jsonEncode(session.toJson());
    await sessionFile.writeAsString(jsonString);
  }
}
