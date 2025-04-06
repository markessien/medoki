import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// 1. State Model
class SelectedFileState {
  final String? path;
  final String? name;
  final int? size;

  const SelectedFileState({this.path, this.name, this.size});

  // Optional: Add copyWith for easier state updates if needed later
  SelectedFileState copyWith({String? path, String? name, int? size}) {
    return SelectedFileState(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
    );
  }
}

// 2. StateNotifier
class SelectedFileNotifier extends StateNotifier<SelectedFileState> {
  // Initialize with no file selected
  SelectedFileNotifier() : super(const SelectedFileState());

  Future<void> selectFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileStat = await file.stat();
        state = SelectedFileState(
          path: filePath,
          name: p.basename(filePath),
          size: fileStat.size,
        );
      } else {
        // File doesn't exist, clear state
        clearSelection();
        // Optionally: throw error or log
      }
    } catch (e) {
      // Error occurred, clear state
      clearSelection();
      // Optionally: rethrow, log, or show error to user via another provider
      print("Error selecting file: $e");
    }
  }

  void clearSelection() {
    state = const SelectedFileState(); // Reset to initial empty state
  }
}

// 3. Provider Definition
final selectedFileProvider =
    StateNotifierProvider<SelectedFileNotifier, SelectedFileState>((ref) {
      return SelectedFileNotifier();
    });
