import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/post_ad/models/draft_ad.dart';
import 'package:wasla/features/post_ad/providers/post_ad_wizard_provider.dart';

void main() {
  group('DraftAd Model Tests', () {
    test('DraftAd copyWith updates fields correctly', () {
      const draft = DraftAd(title: 'العنوان القديم');
      final updated = draft.copyWith(title: 'العنوان الجديد');
      expect(updated.title, 'العنوان الجديد');
    });

    test('DraftImage equality and copyWith works', () {
      final img = DraftImage(id: '1', localFile: File('test.jpg'), isCover: false);
      final updated = img.copyWith(isCover: true);
      expect(updated.isCover, true);
      expect(updated.id, '1');
    });
  });

  group('PostAdWizardNotifier Tests', () {
    late PostAdWizardNotifier notifier;

    setUp(() {
      notifier = PostAdWizardNotifier();
    });

    test('reset() clears state', () {
      notifier.setTitle('إعلان شقة جديد');
      notifier.reset();
      expect(notifier.state.draft.title, '');
      expect(notifier.state.currentStep, WizardStep.category);
    });

    test('setCategory() clears dynamicFieldValues when category changes', () {
      // Set initial category and field values
      notifier.setCategory(1, 'عقارات');
      notifier.updateField('rooms', 3);
      expect(notifier.state.draft.dynamicFieldValues['rooms'], 3);

      // Change category to a new one
      notifier.setCategory(2, 'سيارات');
      expect(notifier.state.draft.dynamicFieldValues.isEmpty, true);
      expect(notifier.state.draft.categoryId, 2);
    });

    test('setCategory() keeps dynamicFieldValues when category is the same', () {
      notifier.setCategory(1, 'عقارات');
      notifier.updateField('rooms', 3);

      notifier.setCategory(1, 'عقارات');
      expect(notifier.state.draft.dynamicFieldValues['rooms'], 3);
    });

    test('isStepValid() for Details Step validation (Limits & Required Fields)', () {
      // 1. Initial empty state is invalid
      expect(notifier.isStepValid(WizardStep.details), false);

      // 2. Title length limits (10 to 80 characters)
      notifier.setTitle('أقل9حرف'); // 7 chars
      notifier.setDescription('وصف طويل جداً ومناسب للقبول بأكثر من عشرين حرفاً');
      expect(notifier.isStepValid(WizardStep.details), false);

      notifier.setTitle('هذا العنوان صحيح ومناسب ومستوفي للشروط'); // 39 chars
      expect(notifier.isStepValid(WizardStep.details), true);

      notifier.setTitle('أ' * 81); // 81 chars
      expect(notifier.isStepValid(WizardStep.details), false);

      // Reset valid title
      notifier.setTitle('عنوان صحيح مناسب للإعلان');

      // 3. Description length limits (20 to 1000 characters)
      notifier.setDescription('قصير جداً'); // 9 chars
      expect(notifier.isStepValid(WizardStep.details), false);

      notifier.setDescription('وصف تفصيلي صحيح ومناسب يزيد عن العشرين حرفاً بكثير'); // 50 chars
      expect(notifier.isStepValid(WizardStep.details), true);

      notifier.setDescription('أ' * 1001); // 1001 chars
      expect(notifier.isStepValid(WizardStep.details), false);

      // Reset valid description
      notifier.setDescription('وصف تفصيلي صحيح ومناسب يزيد عن العشرين حرفاً بكثير');

      // 4. Required dynamic fields validation
      expect(notifier.isStepValid(WizardStep.details, requiredDynamicFieldIds: ['area']), false);

      notifier.updateField('area', 120);
      expect(notifier.isStepValid(WizardStep.details, requiredDynamicFieldIds: ['area']), true);
    });

    test('isStepValid() for Location and Price Step validation', () {
      notifier.setStep(WizardStep.location);
      
      // 1. City must be present
      expect(notifier.isStepValid(WizardStep.location), false);

      notifier.setLocation(cityId: 2);
      notifier.setPriceType(PriceType.fixed);
      
      // 2. Price must be > 0 if price type is fixed
      notifier.setPrice(-100);
      expect(notifier.isStepValid(WizardStep.location), false);

      notifier.setPrice(1500000);
      expect(notifier.isStepValid(WizardStep.location), true);

      // 3. Price is not required if price type is free
      notifier.setPriceType(PriceType.free);
      expect(notifier.isStepValid(WizardStep.location), true);
    });

    test('reorderImages() updates cover photo correctly', () {
      final file1 = File('image1.jpg');
      final file2 = File('image2.jpg');
      
      notifier.addImage(file1);
      notifier.addImage(file2);

      expect(notifier.state.draft.images[0].localFile, file1);
      expect(notifier.state.draft.images[0].isCover, true);
      expect(notifier.state.draft.images[1].localFile, file2);
      expect(notifier.state.draft.images[1].isCover, false);

      // Reorder items: move item 0 to position 1
      notifier.reorderImages(0, 2);

      // Now item 1 should be at position 0 and be the cover
      expect(notifier.state.draft.images[0].localFile, file2);
      expect(notifier.state.draft.images[0].isCover, true);
      expect(notifier.state.draft.images[1].localFile, file1);
      expect(notifier.state.draft.images[1].isCover, false);
    });

    test('tempDraftId is generated and changes on reset()', () {
      final initialId = notifier.state.draft.tempDraftId;
      expect(initialId.isNotEmpty, true);

      notifier.reset();
      final resetId = notifier.state.draft.tempDraftId;
      expect(resetId.isNotEmpty, true);
      expect(resetId != initialId, true);
    });

    test('isStepValid() for Location and Price Step validation (limits check)', () {
      notifier.setStep(WizardStep.location);
      notifier.setLocation(cityId: 2);
      notifier.setPriceType(PriceType.fixed);

      // Price limit checks
      notifier.setPrice(0);
      expect(notifier.isStepValid(WizardStep.location), false);

      notifier.setPrice(-5);
      expect(notifier.isStepValid(WizardStep.location), false);

      notifier.setPrice(99999999);
      expect(notifier.isStepValid(WizardStep.location), true);

      notifier.setPrice(100000000); // 100M limit
      expect(notifier.isStepValid(WizardStep.location), false);
    });

    test('isStepValid() for Photos Step validation', () async {
      final uploaded = <String>[];
      final signedIn = PostAdWizardNotifier(
        userId: 'user-1',
        uploader: (path, file) async {
          uploaded.add(path);
          return 'https://example.test/storage/v1/object/public/ads/$path';
        },
      );
      signedIn.setStep(WizardStep.photos);
      expect(signedIn.isStepValid(WizardStep.photos), false);

      signedIn.addImage(File('test.jpg'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(signedIn.isStepValid(WizardStep.photos), true);
      // Images go into the uploader's own folder, which storage policies require.
      expect(uploaded.single, startsWith('user-1/${signedIn.state.draft.tempDraftId}/'));
      signedIn.dispose();
    });

    test('uploading without a signed-in user fails instead of faking success', () async {
      notifier.addImage(File('test.jpg'));
      await Future.delayed(const Duration(milliseconds: 50));

      final img = notifier.state.draft.images.single;
      expect(img.remoteUrl, isNull);
      expect(img.uploadError, isNotNull);
      expect(notifier.isStepValid(WizardStep.photos), false);
    });
  });
}
