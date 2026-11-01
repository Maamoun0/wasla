import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/national_id_validator.dart';
import '../../../data/repositories/kyc_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/supabase/function_errors.dart';

enum VerificationStatus { idle, loading, success, error }

class VerificationState {
  final String fullName;
  final String nationalId;
  final File? frontIdFile;
  final File? backIdFile;
  /// Selfie for the moderator to compare with the card (FR-1.4, manual review).
  final File? selfieFile;
  final int currentStep;
  final VerificationStatus status;
  final String? errorMessage;
  final Map<String, dynamic>? existingVerification;
  final bool isFetchingExisting;

  VerificationState({
    this.fullName = '',
    this.nationalId = '',
    this.frontIdFile,
    this.backIdFile,
    this.selfieFile,
    this.currentStep = 0,
    this.status = VerificationStatus.idle,
    this.errorMessage,
    this.existingVerification,
    this.isFetchingExisting = false,
  });

  VerificationState copyWith({
    String? fullName,
    String? nationalId,
    File? Function()? frontIdFile,
    File? Function()? backIdFile,
    File? Function()? selfieFile,
    int? currentStep,
    VerificationStatus? status,
    String? Function()? errorMessage,
    Map<String, dynamic>? Function()? existingVerification,
    bool? isFetchingExisting,
  }) {
    return VerificationState(
      fullName: fullName ?? this.fullName,
      nationalId: nationalId ?? this.nationalId,
      frontIdFile: frontIdFile != null ? frontIdFile() : this.frontIdFile,
      backIdFile: backIdFile != null ? backIdFile() : this.backIdFile,
      selfieFile: selfieFile != null ? selfieFile() : this.selfieFile,
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      existingVerification: existingVerification != null ? existingVerification() : this.existingVerification,
      isFetchingExisting: isFetchingExisting ?? this.isFetchingExisting,
    );
  }
}

/// Wizard steps: 0 data, 1 card front, 2 card back, 3 selfie, 4 review.
const selfieStep = 3;
const reviewStep = 4;

class VerificationController extends StateNotifier<VerificationState> {
  final KycRepository _repository;
  final String? _userId;
  final ImagePicker _picker = ImagePicker();

  VerificationController(this._repository, this._userId) : super(VerificationState()) {
    fetchExistingVerification();
  }

  // Fetch the latest verification request from the database
  Future<void> fetchExistingVerification() async {
    if (_userId == null) return;
    state = state.copyWith(isFetchingExisting: true);

    try {
      final latest = await _repository.latestRequest(_userId);

      if (latest != null) {
        state = state.copyWith(
          existingVerification: () => latest,
          isFetchingExisting: false,
        );
      } else {
        state = state.copyWith(
          existingVerification: () => null,
          isFetchingExisting: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: () => 'فشل تحميل بيانات التحقق السابقة',
        isFetchingExisting: false,
      );
    }
  }

  // Set inputs
  void setFullName(String name) {
    state = state.copyWith(fullName: name);
  }

  void setNationalId(String id) {
    state = state.copyWith(nationalId: id);
  }

  // Set the current wizard step
  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  // Capture image via Camera
  Future<void> captureImage(int stepIndex) async {
    try {
      final XFile? capturedFile = await _picker.pickImage(
        source: ImageSource.camera,
        // The selfie uses the front camera.
        preferredCameraDevice: stepIndex == selfieStep ? CameraDevice.front : CameraDevice.rear,
        imageQuality: 80,   // Compress native output to 80% quality
        maxWidth: 1600,     // Downscale larger dimension to 1600px
      );

      if (capturedFile == null) return; // User cancelled

      final file = File(capturedFile.path);

      if (stepIndex == 1) {
        state = state.copyWith(frontIdFile: () => file);
      } else if (stepIndex == 2) {
        state = state.copyWith(backIdFile: () => file);
      } else if (stepIndex == selfieStep) {
        state = state.copyWith(selfieFile: () => file);
      }
    } catch (e) {
      state = state.copyWith(
        status: VerificationStatus.error,
        errorMessage: () => 'فشل التقاط الصورة: $e',
      );
    }
  }

  // Clear specific captured image
  void clearImage(int stepIndex) {
    if (stepIndex == 1) {
      state = state.copyWith(frontIdFile: () => null);
    } else if (stepIndex == 2) {
      state = state.copyWith(backIdFile: () => null);
    } else if (stepIndex == selfieStep) {
      state = state.copyWith(selfieFile: () => null);
    }
  }

  // Reset the wizard state to start over
  void resetWizard() {
    state = VerificationState(
      existingVerification: null,
    );
  }

  // Upload documents via submit-kyc-request Edge Function
  Future<void> submitVerification() async {
    if (_userId == null || 
        state.fullName.trim().isEmpty ||
        state.nationalId.trim().isEmpty ||
        state.frontIdFile == null ||
        state.backIdFile == null ||
        state.selfieFile == null) {
      state = state.copyWith(
        status: VerificationStatus.error,
        errorMessage: () => 'يرجى إكمال كافة البيانات والتقاط الصور المطلوبة أولاً.',
      );
      return;
    }

    final nationalIdError = NationalIdValidator.validate(state.nationalId);
    if (nationalIdError != null) {
      state = state.copyWith(
        status: VerificationStatus.error,
        errorMessage: () => nationalIdError,
      );
      return;
    }

    state = state.copyWith(status: VerificationStatus.loading);

    try {
      // Read bytes and convert to base64
      final frontBytes = await state.frontIdFile!.readAsBytes();
      final backBytes = await state.backIdFile!.readAsBytes();
      final base64Front = base64Encode(frontBytes);
      final base64Back = base64Encode(backBytes);
      final base64Selfie = base64Encode(await state.selfieFile!.readAsBytes());

      // Invoke submit-kyc-request
      await _repository.submit({
          'full_name': state.fullName.trim(),
          // Plain ID over TLS; the server keeps only the last 4 digits and an HMAC.
          'national_id': NationalIdValidator.normalize(state.nationalId),
          'front_image': base64Front,
          'back_image': base64Back,
          'selfie_image': base64Selfie,
        },
      );

      state = state.copyWith(
        status: VerificationStatus.success,
        errorMessage: () => null,
      );
      await fetchExistingVerification();
    } catch (e) {
      state = state.copyWith(
        status: VerificationStatus.error,
        errorMessage: () => functionErrorMessage(e, fallback: 'فشل إرسال طلب التحقق. تحقق من اتصالك وحاول مرة أخرى.'),
      );
    }
  }
}

// ── Providers ────────────────────────────────────────────────────
final verificationControllerProvider =
    StateNotifierProvider.autoDispose<VerificationController, VerificationState>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return VerificationController(ref.watch(kycRepositoryProvider), userId);
});
