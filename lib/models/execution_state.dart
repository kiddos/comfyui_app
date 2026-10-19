import 'dart:typed_data';

enum ExecutionStatus {
  idle,
  connecting,
  submitting,
  queued,
  executing,
  downloading,
  saving,
  completed,
  error,
}

class ExecutionProgress {
  final ExecutionStatus status;
  final String statusMessage;
  final int currentStep;
  final int totalSteps;
  final String? currentNodeTitle;
  final String? promptId;
  final Uint8List? resultImageBytes;
  final String? savedImagePath;
  final String? errorMessage;

  const ExecutionProgress({
    this.status = ExecutionStatus.idle,
    this.statusMessage = '',
    this.currentStep = 0,
    this.totalSteps = 0,
    this.currentNodeTitle,
    this.promptId,
    this.resultImageBytes,
    this.savedImagePath,
    this.errorMessage,
  });

  double get progressFraction {
    if (status == ExecutionStatus.completed) return 1.0;
    if (totalSteps > 0 && currentStep >= 0) {
      return (currentStep / totalSteps).clamp(0.0, 1.0);
    }
    switch (status) {
      case ExecutionStatus.connecting:
        return 0.05;
      case ExecutionStatus.submitting:
        return 0.1;
      case ExecutionStatus.queued:
        return 0.15;
      case ExecutionStatus.downloading:
        return 0.9;
      case ExecutionStatus.saving:
        return 0.95;
      default:
        return 0.0;
    }
  }

  bool get isRunning =>
      status == ExecutionStatus.connecting ||
      status == ExecutionStatus.submitting ||
      status == ExecutionStatus.queued ||
      status == ExecutionStatus.executing ||
      status == ExecutionStatus.downloading ||
      status == ExecutionStatus.saving;

  ExecutionProgress copyWith({
    ExecutionStatus? status,
    String? statusMessage,
    int? currentStep,
    int? totalSteps,
    String? currentNodeTitle,
    String? promptId,
    Uint8List? resultImageBytes,
    String? savedImagePath,
    String? errorMessage,
  }) {
    return ExecutionProgress(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      currentNodeTitle: currentNodeTitle ?? this.currentNodeTitle,
      promptId: promptId ?? this.promptId,
      resultImageBytes: resultImageBytes ?? this.resultImageBytes,
      savedImagePath: savedImagePath ?? this.savedImagePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
