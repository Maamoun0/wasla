import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_provider.g.dart';

@riverpod
class SettingsController extends _$SettingsController {
  static const String _dataSavingKey = 'data_saving_mode';

  @override
  FutureOr<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dataSavingKey) ?? false;
  }

  Future<void> toggleDataSaving(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataSavingKey, value);
    state = AsyncData(value);
  }
}
