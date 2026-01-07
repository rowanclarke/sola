import 'dart:io';

/// Provides low-level access to the device's file system for reading and writing data.
class FileDatasource {
  /// Reads data from a specified file path as a String.
  Future<String> readData(String filePath) {
    throw UnimplementedError();
  }

  /// Writes data (String) to a specified file path.
  Future<void> writeData(String filePath, String data) {
    throw UnimplementedError();
  }

  /// Checks if a file exists at the specified path.
  Future<bool> fileExists(String filePath) {
    throw UnimplementedError();
  }

  /// Lists the contents (files and directories) of a given directory path.
  /// Returns a list of file system entity paths.
  Future<List<String>> listDirectory(String directoryPath) {
    throw UnimplementedError();
  }
}
