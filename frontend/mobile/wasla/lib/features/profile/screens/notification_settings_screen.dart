import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _prefs = {
    'watchlist_matches': true,
    'ad_status_updates': true,
    'special_offers': true,
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user != null && user['notification_preferences'] != null) {
        setState(() {
          _prefs = Map<String, dynamic>.from(user['notification_preferences']);
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePref(String key, bool value) async {
    final updatedPrefs = Map<String, dynamic>.from(_prefs);
    updatedPrefs[key] = value;
    
    // Optimistic update
    setState(() => _prefs = updatedPrefs);

    try {
      final client = ref.read(supabaseClientProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        await client.from('users').update({
          'notification_preferences': updatedPrefs,
        }).eq('id', userId);
        ref.invalidate(currentUserProvider);
      }
    } catch (e) {
      // Revert on error
      setState(() => _prefs[key] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحديث الإعدادات', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('إعدادات الإشعارات'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary600))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSwitchTile(
                    title: 'تنبيهات البحث (Watchlist)',
                    subtitle: 'إشعارات عند توفر إعلانات تطابق بحثك المحفوظ',
                    value: _prefs['watchlist_matches'] ?? true,
                    onChanged: (v) => _updatePref('watchlist_matches', v),
                    icon: Icons.notifications_active_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    title: 'تحديثات حالة الإعلان',
                    subtitle: 'إشعارات عند قبول أو رفض إعلانك من قبل الإدارة',
                    value: _prefs['ad_status_updates'] ?? true,
                    onChanged: (v) => _updatePref('ad_status_updates', v),
                    icon: Icons.campaign_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildSwitchTile(
                    title: 'عروض خاصة وتحديثات',
                    subtitle: 'إشعارات حول الميزات الجديدة والعروض الحصرية',
                    value: _prefs['special_offers'] ?? true,
                    onChanged: (v) => _updatePref('special_offers', v),
                    icon: Icons.local_offer_outlined,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary600),
        ),
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.neutral500),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary600,
      ),
    );
  }
}
