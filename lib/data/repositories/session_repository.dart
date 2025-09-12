import 'dart:io';

class SessionRepository {
  final File sessionFile;

  SessionRepository(this.sessionFile);

  Future<String?> getSession() async {
    if (await sessionFile.exists()) {
      return await sessionFile.readAsString();
    }
    return null;
  }

  Future<void> saveSession(String session) async {
    await sessionFile.writeAsString(session);
  }
}
