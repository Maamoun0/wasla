import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class DynamicFieldBuilder extends StatelessWidget {
  const DynamicFieldBuilder({
    super.key,
    required this.field,
    required this.currentValue,
    required this.onChanged,
  });

  final Map<String, dynamic> field;
  final dynamic currentValue;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = field['field_type'] as String;
    final label = field['label_ar'] as String? ?? field['field_name'] as String;
    final isRequired = field['is_required'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutral800,
                ),
              ),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          _buildInputField(context, type, label, isRequired),
        ],
      ),
    );
  }

  Widget _buildInputField(BuildContext context, String type, String label, bool isRequired) {
    switch (type) {
      case 'text':
        return TextFormField(
          initialValue: currentValue as String? ?? '',
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'أدخل $label',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: isRequired
              ? (val) => val == null || val.trim().isEmpty ? 'هذا الحقل مطلوب' : null
              : null,
        );

      case 'number':
        return TextFormField(
          initialValue: currentValue?.toString() ?? '',
          keyboardType: TextInputType.number,
          onChanged: (val) {
            final parsed = double.tryParse(val);
            onChanged(parsed);
          },
          decoration: InputDecoration(
            hintText: 'أدخل $label (أرقام فقط)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: isRequired
              ? (val) => val == null || val.trim().isEmpty ? 'هذا الحقل مطلوب' : null
              : null,
        );

      case 'select':
        final rawOptions = field['options'];
        final List<String> options = rawOptions != null ? List<String>.from(rawOptions) : [];
        return DropdownButtonFormField<String>(
          value: options.contains(currentValue) ? currentValue as String : null,
          items: options
              .map((opt) => DropdownMenuItem(
                    value: opt,
                    child: Text(opt, style: const TextStyle(fontFamily: 'Cairo')),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'اختر $label',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: isRequired
              ? (val) => val == null ? 'هذا الحقل مطلوب' : null
              : null,
        );

      case 'boolean':
        final isChecked = currentValue as bool? ?? false;
        return InkWell(
          onTap: () => onChanged(!isChecked),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.neutral200),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isChecked ? 'نعم' : 'لا',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: AppColors.neutral800,
                  ),
                ),
                Switch.adaptive(
                  value: isChecked,
                  onChanged: onChanged,
                  activeColor: AppColors.primary600,
                ),
              ],
            ),
          ),
        );

      case 'range':
        // For range, currentValue is expected to be Map<String, double?> like {'min': x, 'max': y}
        final Map<String, dynamic> rangeMap = currentValue is Map<String, dynamic>
            ? Map<String, dynamic>.from(currentValue)
            : {'min': null, 'max': null};

        final minController = TextEditingController(text: rangeMap['min']?.toString() ?? '');
        final maxController = TextEditingController(text: rangeMap['max']?.toString() ?? '');

        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: minController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  rangeMap['min'] = parsed;
                  
                  // Validation: if min > max, trigger error/onChanged state
                  onChanged(rangeMap);
                },
                decoration: const InputDecoration(
                  hintText: 'من',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (val) {
                  if (isRequired && (val == null || val.isEmpty)) return 'مطلوب';
                  final parsedMin = double.tryParse(val ?? '');
                  final parsedMax = rangeMap['max'] as double?;
                  if (parsedMin != null && parsedMax != null && parsedMin > parsedMax) {
                    return 'يجب أن يكون أقل من أو يساوي الحد الأقصى';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppSizes.md),
            const Text('إلى', style: TextStyle(fontFamily: 'Cairo', color: AppColors.neutral500)),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: TextFormField(
                controller: maxController,
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  rangeMap['max'] = parsed;
                  onChanged(rangeMap);
                },
                decoration: const InputDecoration(
                  hintText: 'إلى',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (val) {
                  if (isRequired && (val == null || val.isEmpty)) return 'مطلوب';
                  final parsedMax = double.tryParse(val ?? '');
                  final parsedMin = rangeMap['min'] as double?;
                  if (parsedMin != null && parsedMax != null && parsedMin > parsedMax) {
                    return 'يجب أن يكون أكبر من أو يساوي الحد الأدنى';
                  }
                  return null;
                },
              ),
            ),
          ],
        );

      case 'multi_select':
        // For multi_select, currentValue is expected to be a List<String>
        final List<String> selectedValues = currentValue is List
            ? List<String>.from(currentValue)
            : [];
        final rawOptions = field['options'];
        final List<String> options = rawOptions != null ? List<String>.from(rawOptions) : [];

        return FormField<List<String>>(
          initialValue: selectedValues,
          validator: isRequired
              ? (val) => val == null || val.isEmpty ? 'هذا الحقل مطلوب' : null
              : null,
          builder: (formState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: options.map((opt) {
                    final isSelected = selectedValues.contains(opt);
                    return FilterChip(
                      label: Text(
                        opt,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: isSelected ? AppColors.white : AppColors.neutral800,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary600,
                      checkmarkColor: AppColors.white,
                      onSelected: (selected) {
                        final updatedList = List<String>.from(selectedValues);
                        if (selected) {
                          updatedList.add(opt);
                        } else {
                          updatedList.remove(opt);
                        }
                        formState.didChange(updatedList);
                        onChanged(updatedList);
                      },
                    );
                  }).toList(),
                ),
                if (formState.hasError) ...[
                  const SizedBox(height: 6),
                  Text(
                    formState.errorText!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontFamily: 'Cairo'),
                  ),
                ],
              ],
            );
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
