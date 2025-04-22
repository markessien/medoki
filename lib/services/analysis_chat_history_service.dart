import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert'; // For JSON encoding/decoding

class AnalysisChatHistoryService {
  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    // Store the history in a dedicated subdirectory
    final historyDir = Directory('${directory.path}/medoki_chat_history');
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return File('${historyDir.path}/analysis_chat_history.json');
  }

  Future<List<String>> loadHistory() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) {
        return []; // Return empty list if file doesn't exist
      }
      // Read the file content
      final contents = await file.readAsString();
      // Decode the JSON string into a List<String>
      final List<dynamic> decoded = json.decode(contents);
      return decoded.cast<String>();
    } catch (e) {
      // If encountering an error, return an empty list
      print("Error loading analysis chat history: $e");
      return [];
    }
  }

  Future<File> saveHistory(List<String> messages) async {
    final file = await _getLocalFile();
    // Encode the List<String> to a JSON string
    final String encoded = json.encode(messages);
    // Write the JSON string to the file
    return file.writeAsString(encoded);
  }
}
