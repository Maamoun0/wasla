import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/draft_ad.dart';

class PostAdWizardState extends Equatable {
  final DraftAd draft;
  final WizardStep currentStep;
  final bool isSubmitting;
  final String? errorMessage;

  const PostAdWizardState({
    this.draft = const DraftAd(),
    this.currentStep = WizardStep.category,
    this.isSubmitting = false,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [draft, currentStep, isSubmitting, errorMessage];

  PostAdWizardState copyWith({
    DraftAd? draft,
    WizardStep? currentStep,
    bool? isSubmitting,
    String? Function()? errorMessage,
  }) {
    return PostAdWizardState(
      draft: draft ?? this.draft,
      currentStep: currentStep ?? this.currentStep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// Uploads one ad image and returns its public URL.
/// Paths are `{userId}/{draftId}/{imageId}.jpg`: storage policies only allow
/// writes inside the caller's own `{userId}/` folder.
typedef AdImageUploader = Future<String> Function(String path, File file);

AdImageUploader supabaseAdImageUploader(SupabaseClient client) => (path, file) async {
      await client.storage.from('ads').upload(
            path,
            file,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      return client.storage.from('ads').getPublicUrl(path);
    };

class PostAdWizardNotifier extends StateNotifier<PostAdWizardState> {
  final SupabaseClient? _client;
  final String? _userId;
  final AdImageUploader? _uploader;

  PostAdWizardNotifier({
    SupabaseClient? client,
    String? userId,
    AdImageUploader? uploader,
  })  : _client = client,
        _userId = userId,
        _uploader = uploader ?? (client != null ? supabaseAdImageUploader(client) : null),
        super(PostAdWizardState(
          draft: DraftAd(tempDraftId: const Uuid().v4()),
        ));

  // Reset the wizard state
  void reset() {
    state = PostAdWizardState(
      draft: DraftAd(tempDraftId: const Uuid().v4()),
    );
  }

  // Set selected category
  void setCategory(int categoryId, String? nameAr) {
    final currentDraft = state.draft;
    
    // Clear dynamicFieldValues if the category actually changes
    final isNewCategory = currentDraft.categoryId != categoryId;
    final updatedFieldValues = isNewCategory ? <String, dynamic>{} : currentDraft.dynamicFieldValues;

    state = state.copyWith(
      draft: currentDraft.copyWith(
        categoryId: () => categoryId,
        categoryNameAr: () => nameAr,
        dynamicFieldValues: updatedFieldValues,
      ),
    );
  }

  // Set ad type (offering or seeking)
  void setAdType(String adType) {
    state = state.copyWith(
      draft: state.draft.copyWith(adType: adType),
    );
  }

  // Set title
  void setTitle(String title) {
    state = state.copyWith(
      draft: state.draft.copyWith(title: title),
    );
  }

  // Set description
  void setDescription(String desc) {
    state = state.copyWith(
      draft: state.draft.copyWith(description: desc),
    );
  }

  // Update dynamic field value
  void updateField(String fieldId, dynamic value) {
    final updatedFields = Map<String, dynamic>.from(state.draft.dynamicFieldValues);
    if (value == null || (value is String && value.trim().isEmpty)) {
      updatedFields.remove(fieldId);
    } else {
      updatedFields[fieldId] = value;
    }

    state = state.copyWith(
      draft: state.draft.copyWith(dynamicFieldValues: updatedFields),
    );
  }

  // Add captured/picked image and trigger background upload
  void addImage(File imageFile) {
    final currentImages = List<DraftImage>.from(state.draft.images);
    final id = '${DateTime.now().millisecondsSinceEpoch}_${currentImages.length}';
    
    // Set isCover to true if this is the first image
    final isCover = currentImages.isEmpty;

    currentImages.add(DraftImage(
      id: id,
      localFile: imageFile,
      isCover: isCover,
    ));

    state = state.copyWith(
      draft: state.draft.copyWith(images: currentImages),
    );

    // Start upload in background
    uploadImage(id);
  }

  // Helper to update state of a specific image by ID
  void _updateImageState(
    String imgId, {
    bool? isUploading,
    double? uploadProgress,
    String? Function()? uploadError,
    String? Function()? remoteUrl,
  }) {
    final currentImages = state.draft.images.map((img) {
      if (img.id == imgId) {
        return img.copyWith(
          isUploading: isUploading,
          uploadProgress: uploadProgress,
          uploadError: uploadError,
          remoteUrl: remoteUrl,
        );
      }
      return img;
    }).toList();

    state = state.copyWith(
      draft: state.draft.copyWith(images: currentImages),
    );
  }

  // Upload an image to Supabase storage bucket 'ads'
  Future<void> uploadImage(String imgId) async {
    final uploader = _uploader;
    final userId = _userId;

    final imageIndex = state.draft.images.indexWhere((img) => img.id == imgId);
    if (imageIndex == -1) return;

    final img = state.draft.images[imageIndex];
    final file = img.localFile;
    if (file == null) return;

    if (uploader == null || userId == null) {
      _updateImageState(
        imgId,
        isUploading: false,
        uploadProgress: 0.0,
        uploadError: () => 'يجب تسجيل الدخول لرفع الصور',
      );
      return;
    }

    _updateImageState(
      imgId,
      isUploading: true,
      uploadProgress: 0.0,
      uploadError: () => null,
    );

    // Approximate progress for the UI (the upload call does not report progress).
    double progress = 0.0;
    final progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (progress < 0.9) {
        progress += 0.1;
        _updateImageState(imgId, uploadProgress: progress);
      } else {
        timer.cancel();
      }
    });

    try {
      final remoteUrl = await uploader('$userId/${state.draft.tempDraftId}/$imgId.jpg', file);
      progressTimer.cancel();
      _updateImageState(
        imgId,
        isUploading: false,
        uploadProgress: 1.0,
        remoteUrl: () => remoteUrl,
        uploadError: () => null,
      );
    } catch (e) {
      progressTimer.cancel();
      _updateImageState(
        imgId,
        isUploading: false,
        uploadProgress: 0.0,
        uploadError: () => e.toString(),
      );
    }
  }

  // Retry upload for a failed image
  Future<void> retryUploadImage(String imgId) async {
    await uploadImage(imgId);
  }

  // Remove image by index and delete it from Supabase storage if uploaded
  Future<void> removeImage(int index) async {
    if (index < 0 || index >= state.draft.images.length) return;

    final currentImages = List<DraftImage>.from(state.draft.images);
    final removed = currentImages.removeAt(index);

    // If we removed the cover image and there are still images left, set the first one as cover
    if (removed.isCover && currentImages.isNotEmpty) {
      currentImages[0] = currentImages[0].copyWith(isCover: true);
    }

    state = state.copyWith(
      draft: state.draft.copyWith(images: currentImages),
    );

    // Delete from Supabase Storage if it was uploaded
    final client = _client;
    final userId = _userId;
    if (client != null && userId != null && removed.remoteUrl != null) {
      try {
        final path = '$userId/${state.draft.tempDraftId}/${removed.id}.jpg';
        await client.storage.from('ads').remove([path]);
      } catch (e) {
        debugPrint('Error deleting image from storage: $e');
      }
    }
  }

  // Reorder images list and ensure the first one is marked as cover
  void reorderImages(int oldIndex, int newIndex) {
    final currentImages = List<DraftImage>.from(state.draft.images);
    if (oldIndex < 0 || oldIndex >= currentImages.length) return;
    if (newIndex < 0 || newIndex > currentImages.length) return;

    // Adjust newIndex if moving item down
    int correctedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      correctedNewIndex -= 1;
    }

    final item = currentImages.removeAt(oldIndex);
    currentImages.insert(correctedNewIndex, item);

    // Update cover flags: first item is cover, others are not
    for (int i = 0; i < currentImages.length; i++) {
      currentImages[i] = currentImages[i].copyWith(isCover: i == 0);
    }

    state = state.copyWith(
      draft: state.draft.copyWith(images: currentImages),
    );
  }

  // Set location coordinates and IDs
  void setLocation({
    required int cityId,
    String? cityNameAr,
    int? districtId,
    String? districtNameAr,
    double? latitude,
    double? longitude,
  }) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        cityId: () => cityId,
        cityNameAr: () => cityNameAr ?? state.draft.cityNameAr,
        districtId: () => districtId,
        districtNameAr: () => districtNameAr ?? state.draft.districtNameAr,
        latitude: () => latitude,
        longitude: () => longitude,
      ),
    );
  }

  // Set price type
  void setPriceType(PriceType priceType) {
    final updatedPrice = priceType == PriceType.free ? null : state.draft.price;
    state = state.copyWith(
      draft: state.draft.copyWith(
        priceType: priceType,
        price: () => updatedPrice,
      ),
    );
  }

  // Set price value
  void setPrice(double? price) {
    state = state.copyWith(
      draft: state.draft.copyWith(price: () => price),
    );
  }

  // Navigate to wizard step
  void setStep(WizardStep step) {
    state = state.copyWith(currentStep: step);
  }

  // Check if a specific step is valid
  bool isStepValid(WizardStep step, {List<String> requiredDynamicFieldIds = const []}) {
    final draft = state.draft;
    switch (step) {
      case WizardStep.category:
        return draft.categoryId != null;

      case WizardStep.details:
        final isTitleValid = draft.title.trim().length >= 10 && draft.title.trim().length <= 80;
        final isDescValid = draft.description.trim().length >= 20 && draft.description.trim().length <= 1000;
        
        // Validate required dynamic fields
        bool areFieldsValid = true;
        for (final fieldId in requiredDynamicFieldIds) {
          final val = draft.dynamicFieldValues[fieldId];
          if (val == null || (val is String && val.trim().isEmpty)) {
            areFieldsValid = false;
            break;
          }
        }
        return isTitleValid && isDescValid && areFieldsValid;

      case WizardStep.photos:
        // Check if there is at least one successfully uploaded image
        return draft.images.any((img) => img.remoteUrl != null);

      case WizardStep.location:
        final hasLocation = draft.cityId != null;
        final isPriceValid = draft.priceType == PriceType.free ||
            (draft.price != null && draft.price! > 0 && draft.price! < 100000000);
        return hasLocation && isPriceValid;

      case WizardStep.preview:
        return true;
    }
  }

  // Publish the ad using create-ad Edge Function
  Future<String?> publishAd() async {
    final client = _client;
    if (client == null) {
      throw Exception('SupabaseClient is not initialized.');
    }

    state = state.copyWith(isSubmitting: true, errorMessage: () => null);
    try {
      final draft = state.draft;
      
      final body = {
        'temp_draft_id': draft.tempDraftId,
        'category_id': draft.categoryId,
        'title': draft.title,
        'description': draft.description,
        'ad_type': draft.adType,
        'price': draft.price,
        'price_type': draft.priceType.value,
        'city_id': draft.cityId,
        'district_id': draft.districtId,
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'images': draft.images
            .where((img) => img.remoteUrl != null)
            .map((img) => {
                  'url': img.remoteUrl,
                  'is_primary': img.isCover,
                  'sort_order': draft.images.indexOf(img),
                })
            .toList(),
        'dynamic_fields': draft.dynamicFieldValues,
      };

      final response = await client.functions.invoke(
        'create-ad',
        body: body,
      );

      if (response.status != 200) {
        final data = response.data;
        String errMsg = 'فشل نشر الإعلان';
        if (data is Map) {
          errMsg = data['error'] ?? data['message'] ?? errMsg;
        }
        throw Exception(errMsg);
      }

      final resData = response.data;
      String? adId;
      if (resData is Map) {
        adId = resData['ad_id']?.toString();
      }

      state = state.copyWith(isSubmitting: false);
      return adId;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: () => e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }
}

// Provider definition
final postAdWizardProvider = StateNotifierProvider.autoDispose<PostAdWizardNotifier, PostAdWizardState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return PostAdWizardNotifier(client: client, userId: userId);
});

