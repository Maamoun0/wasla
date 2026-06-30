import 'dart:io';
import 'package:equatable/equatable.dart';

enum WizardStep {
  category,
  details,
  photos,
  location,
  preview,
}

enum PriceType {
  fixed,
  negotiable,
  free,
  perHour,
  perMonth;
  
  String get value {
    switch (this) {
      case PriceType.fixed: return 'fixed';
      case PriceType.negotiable: return 'negotiable';
      case PriceType.free: return 'free';
      case PriceType.perHour: return 'per_hour';
      case PriceType.perMonth: return 'per_month';
    }
  }
  
  static PriceType fromValue(String val) {
    return PriceType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => PriceType.fixed,
    );
  }
}

class DraftImage extends Equatable {
  final String id;
  final File? localFile;
  final String? remoteUrl;
  final bool isCover;
  final double uploadProgress;
  final String? uploadError;
  final bool isUploading;

  const DraftImage({
    required this.id,
    this.localFile,
    this.remoteUrl,
    this.isCover = false,
    this.uploadProgress = 0.0,
    this.uploadError,
    this.isUploading = false,
  });

  @override
  List<Object?> get props => [
        id,
        localFile,
        remoteUrl,
        isCover,
        uploadProgress,
        uploadError,
        isUploading,
      ];

  DraftImage copyWith({
    String? id,
    File? Function()? localFile,
    String? Function()? remoteUrl,
    bool? isCover,
    double? uploadProgress,
    String? Function()? uploadError,
    bool? isUploading,
  }) {
    return DraftImage(
      id: id ?? this.id,
      localFile: localFile != null ? localFile() : this.localFile,
      remoteUrl: remoteUrl != null ? remoteUrl() : this.remoteUrl,
      isCover: isCover ?? this.isCover,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadError: uploadError != null ? uploadError() : this.uploadError,
      isUploading: isUploading ?? this.isUploading,
    );
  }
}

class DraftAd extends Equatable {
  final String tempDraftId;
  final int? categoryId;
  final String? categoryNameAr;
  final String adType; // 'offering' | 'seeking'
  final String title;
  final String description;
  final double? price;
  final PriceType priceType;
  final int? cityId;
  final String? cityNameAr;
  final int? districtId;
  final String? districtNameAr;
  final double? latitude;
  final double? longitude;
  final List<DraftImage> images;
  final Map<String, dynamic> dynamicFieldValues;

  const DraftAd({
    this.tempDraftId = '',
    this.categoryId,
    this.categoryNameAr,
    this.adType = 'offering',
    this.title = '',
    this.description = '',
    this.price,
    this.priceType = PriceType.fixed,
    this.cityId,
    this.cityNameAr,
    this.districtId,
    this.districtNameAr,
    this.latitude,
    this.longitude,
    this.images = const [],
    this.dynamicFieldValues = const {},
  });

  @override
  List<Object?> get props => [
        tempDraftId,
        categoryId,
        categoryNameAr,
        adType,
        title,
        description,
        price,
        priceType,
        cityId,
        cityNameAr,
        districtId,
        districtNameAr,
        latitude,
        longitude,
        images,
        dynamicFieldValues,
      ];

  DraftAd copyWith({
    String? tempDraftId,
    int? Function()? categoryId,
    String? Function()? categoryNameAr,
    String? adType,
    String? title,
    String? description,
    double? Function()? price,
    PriceType? priceType,
    int? Function()? cityId,
    String? Function()? cityNameAr,
    int? Function()? districtId,
    String? Function()? districtNameAr,
    double? Function()? latitude,
    double? Function()? longitude,
    List<DraftImage>? images,
    Map<String, dynamic>? dynamicFieldValues,
  }) {
    return DraftAd(
      tempDraftId: tempDraftId ?? this.tempDraftId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      categoryNameAr: categoryNameAr != null ? categoryNameAr() : this.categoryNameAr,
      adType: adType ?? this.adType,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price != null ? price() : this.price,
      priceType: priceType ?? this.priceType,
      cityId: cityId != null ? cityId() : this.cityId,
      cityNameAr: cityNameAr != null ? cityNameAr() : this.cityNameAr,
      districtId: districtId != null ? districtId() : this.districtId,
      districtNameAr: districtNameAr != null ? districtNameAr() : this.districtNameAr,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      images: images ?? this.images,
      dynamicFieldValues: dynamicFieldValues ?? this.dynamicFieldValues,
    );
  }

  Map<String, dynamic> toPreviewAdModel(Map<String, dynamic> userProfile) {
    return {
      'title': title,
      'description': description,
      'price': price,
      'price_type': priceType.value,
      'ad_type': adType,
      'created_at': DateTime.now().toIso8601String(),
      'is_featured': false,
      'is_urgent': false,
      'ad_media': images.map((img) => {
        'url': img.remoteUrl ?? (img.localFile != null ? img.localFile!.path : ''),
        'is_primary': img.isCover,
      }).toList(),
      'users': {
        'full_name': userProfile['full_name'] ?? 'مستخدم Wasla',
        'avatar_url': userProfile['avatar_url'],
        'trust_score': userProfile['trust_score'] ?? 5.0,
        'is_id_verified': userProfile['is_id_verified'] ?? false,
        'phone': userProfile['phone'] ?? '',
      },
      'cities': {
        'name_ar': cityNameAr ?? '',
      },
      'districts': {
        'name_ar': districtNameAr ?? '',
      },
      'ad_fields': dynamicFieldValues.entries.map((e) => {
        'value_text': e.value.toString(),
        'category_fields': {
          'label_ar': e.key,
          'field_type': 'text',
        }
      }).toList(),
    };
  }
}
