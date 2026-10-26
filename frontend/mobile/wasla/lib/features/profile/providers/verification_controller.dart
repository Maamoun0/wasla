import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/national_id_validator.dart';
import '../../auth/providers/auth_provider.dart';

enum VerificationStatus { idle, loading, success, error }

class VerificationState {
  final String fullName;
  final String nationalId;
  final File? frontIdFile;
  final File? backIdFile;
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
      currentStep: currentStep ?? this.currentStep,
      status: status ?? this.status,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      existingVerification: existingVerification != null ? existingVerification() : this.existingVerification,
      isFetchingExisting: isFetchingExisting ?? this.isFetchingExisting,
    );
  }
}

class VerificationController extends StateNotifier<VerificationState> {
  final SupabaseClient _client;
  final String? _userId;
  final ImagePicker _picker = ImagePicker();

  VerificationController(this._client, this._userId) : super(VerificationState()) {
    fetchExistingVerification();
  }

  // Fetch the latest verification request from the database
  Future<void> fetchExistingVerification() async {
    if (_userId == null) return;
    state = state.copyWith(isFetchingExisting: true);

    try {
      final response = await _client
          .from('user_verifications')
          // Explicit columns: the HMAC and code hash are not readable by clients.
          .select('id, status, created_at, decided_at, national_id_last4')
          .eq('user_id', _userId)
          .eq('type', 'national_id')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        state = state.copyWith(
          existingVerification: () => response.first,
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
        imageQuality: 80,   // Compress native output to 80% quality
        maxWidth: 1600,     // Downscale larger dimension to 1600px
      );

      if (capturedFile == null) return; // User cancelled

      final file = File(capturedFile.path);

      if (stepIndex == 1) {
        state = state.copyWith(frontIdFile: () => file);
      } else if (stepIndex == 2) {
        state = state.copyWith(backIdFile: () => file);
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
        state.backIdFile == null) {
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

      // Invoke submit-kyc-request
      final response = await _client.functions.invoke(
        'submit-kyc-request',
        body: {
          'full_name': state.fullName.trim(),
          // Plain ID over TLS; the server keeps only the last 4 digits and an HMAC.
          'national_id': NationalIdValidator.normalize(state.nationalId),
          'front_image': base64Front,
          'back_image': base64Back,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map ? (response.data['error'] ?? 'حدث خطأ ما') : 'فشل إرسال طلب التحقق';
        throw Exception(errorMsg);
      }

      state = state.copyWith(
        status: VerificationStatus.success,
        errorMessage: () => null,
      );
      await fetchExistingVerification();
    } catch (e) {
      state = state.copyWith(
        status: VerificationStatus.error,
        errorMessage: () => 'فشل إرسال طلب التحقق: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }
}

// ── Providers ────────────────────────────────────────────────────
final verificationControllerProvider =
    StateNotifierProvider.autoDispose<VerificationController, VerificationState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return VerificationController(client, userId);
});
