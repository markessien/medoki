import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the set of file paths added during the current session.
class NewlyAddedFilesNotifier extends StateNotifier<Set<String>> {
  NewlyAddedFilesNotifier() : super({});

  /// Adds a file path to the set of newly added files.
  void addFile(String filePath) {
    if (!state.contains(filePath)) {
      state = {...state, filePath};
    }
  }

  /// Adds multiple file paths to the set.
  void addFiles(Iterable<String> filePaths) {
    final newPaths = filePaths.where((path) => !state.contains(path)).toSet();
    if (newPaths.isNotEmpty) {
      state = {...state, ...newPaths};
    }
  }

  /// Clears the set (e.g., on app restart, though state is usually lost anyway).
  void clear() {
    state = {};
  }
}

/// Provider for accessing and modifying the set of newly added file paths.
final newlyAddedFilesProvider =
    StateNotifierProvider<NewlyAddedFilesNotifier, Set<String>>(
      (ref) => NewlyAddedFilesNotifier(),
    );
