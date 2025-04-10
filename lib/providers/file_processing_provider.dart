import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:collection'; // For UnmodifiableMapView

/// Enum representing the AI processing status of a file.
enum ProcessingStatus {
  pending, // Waiting to be processed
  processing, // Actively being processed by AI
  completed, // Successfully processed
  failed, // Processing attempted but failed
  none, // Not applicable or status unknown (default)
}

/// Represents the detailed status of a file's processing.
typedef FileProcessingDetail =
    ({
      ProcessingStatus status,
      String? detailMessage, // e.g., "Transcribing...", "Summarizing..."
    });

/// Manages the detailed processing status of individual files.
class FileProcessingStatusNotifier
    extends StateNotifier<Map<String, FileProcessingDetail>> {
  FileProcessingStatusNotifier() : super({});

  /// Sets the status and optionally the detail message for a given file path.
  void setStatus(String filePath, ProcessingStatus status, [String? detail]) {
    // Clear detail when status is not 'processing'
    final message = (status == ProcessingStatus.processing) ? detail : null;
    state = {...state, filePath: (status: status, detailMessage: message)};
  }

  /// Sets the status for multiple files.
  void setStatuses(Map<String, ProcessingStatus> statuses) {
    final Map<String, FileProcessingDetail> newStatuses = {};
    statuses.forEach((path, status) {
      // Assume null detail for bulk setting, usually for 'pending'
      newStatuses[path] = (status: status, detailMessage: null);
    });
    state = {...state, ...newStatuses};
  }

  /// Removes the status entry for a file path (e.g., when deleted).
  void removeStatus(String filePath) {
    final newState = {...state};
    newState.remove(filePath);
    state = newState;
  }

  /// Removes status entries for multiple files.
  void removeStatuses(Set<String> filePaths) {
    final newState = {...state};
    for (final path in filePaths) {
      newState.remove(path);
    }
    state = newState;
  }

  /// Clears all statuses.
  void clearAll() {
    state = {};
  }

  /// Gets the detailed status for a file, returning a default if not found.
  FileProcessingDetail getDetailedStatus(String filePath) {
    return state[filePath] ??
        (status: ProcessingStatus.none, detailMessage: null);
  }
}

/// Provider for accessing and modifying file processing statuses.
///
/// Holds a map where keys are file paths and values are [FileProcessingDetail].
final fileProcessingStatusProvider = StateNotifierProvider<
  FileProcessingStatusNotifier,
  Map<String, FileProcessingDetail>
>((ref) => FileProcessingStatusNotifier());

/// Provider that returns an unmodifiable view of the detailed processing status map.
/// Useful for widgets that only need to read the detailed statuses.
final fileProcessingStatusMapProvider =
    Provider<UnmodifiableMapView<String, FileProcessingDetail>>((ref) {
      final statusMap = ref.watch(fileProcessingStatusProvider);
      return UnmodifiableMapView(statusMap);
    });
