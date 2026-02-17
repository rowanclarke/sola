import 'dart:typed_data';

/// FileService provides low-level access to the device's file system.
/// Handles reading, writing, and checking file existence for persistence operations.
class FileService {
  /// Reads data from a file at the specified path.
  /// Returns the file contents as a string.
  Future<String> readFile(String filePath) {
    throw UnimplementedError();
  }

  /// Writes data to a file at the specified path.
  /// Creates the file if it doesn't exist; overwrites if it does.
  Future<void> writeFile(String filePath, String data) {
    throw UnimplementedError();
  }

  /// Reads binary data from a file at the specified path.
  Future<Uint8List> readBytes(String filePath) {
    throw UnimplementedError();
  }

  /// Writes binary data to a file at the specified path.
  /// Creates the file if it doesn't exist; overwrites if it does.
  Future<void> writeBytes(String filePath, Uint8List data) {
    throw UnimplementedError();
  }

  /// Checks whether a file exists at the specified path.
  Future<bool> fileExists(String filePath) {
    throw UnimplementedError();
  }

  /// Lists the contents of a directory.
  Future<List<String>> listDirectory(String directoryPath) {
    throw UnimplementedError();
  }

  /// Deletes a file at the specified path.
  Future<void> deleteFile(String filePath) {
    throw UnimplementedError();
  }
}
