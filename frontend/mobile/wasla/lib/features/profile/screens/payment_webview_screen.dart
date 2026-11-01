import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/payments_repository.dart';

class PaymentWebViewScreen extends ConsumerStatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.transactionId,
    required this.paymentType,
    this.referenceId,
  });

  final String paymentUrl;
  final String transactionId;
  final String paymentType; // 'ad_boost' or 'subscription'
  final String? referenceId;

  @override
  ConsumerState<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends ConsumerState<PaymentWebViewScreen> {
  late final WebViewController _webViewController;
  bool _isConfirming = false;
  bool _isPageLoading = true;
  RealtimeChannel? _realtimeChannel;
  Timer? _timeoutTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isPageLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isPageLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            
            // Check success redirect pattern
            if (request.url.startsWith('https://wasla.eg/payment/callback')) {
              final isSuccess = uri.queryParameters['success'] == 'true';
              if (isSuccess) {
                _startPaymentConfirmation();
              } else {
                _handlePaymentFailure();
              }
              return NavigationDecision.prevent;
            }
            
            // Check cancellation redirect pattern
            if (request.url.startsWith('https://wasla.eg/payment/cancel')) {
              _handlePaymentCancellation();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  // Handle success redirect callback (listen to DB updates)
  void _startPaymentConfirmation() {
    if (_isConfirming) return;
    setState(() {
      _isConfirming = true;
    });

    // Realtime transaction updates
    _realtimeChannel = ref.read(paymentsRepositoryProvider).watchTransaction(widget.transactionId, (status) {
      if (status == 'completed') {
        _handlePaymentSuccess();
      } else if (status == 'failed') {
        _handlePaymentFailure();
      }
    });

    // Set 45 seconds timeout timer
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      _handlePaymentTimeout();
    });
  }

  void _handlePaymentSuccess() {
    _cleanup();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.primary500),
            SizedBox(width: 8),
            Text('تم الدفع بنجاح', style: TextStyle(fontFamily: 'Cairo')),
          ],
        ),
        content: const Text(
          'تهانينا! تم تأكيد عمليتك وبدء التفعيل بنجاح.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Dismiss Dialog
              Navigator.of(context).pop(true); // Return true to previous screen
            },
            child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _handlePaymentFailure() {
    _cleanup();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('فشلت المعاملة', style: TextStyle(fontFamily: 'Cairo')),
          ],
        ),
        content: const Text(
          'نعتذر، لم نتمكن من إتمام عملية الدفع. يرجى التحقق من بيانات الدفع الخاصة بك وإعادة المحاولة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(false);
            },
            child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _handlePaymentCancellation() {
    _cleanup();
    if (!mounted) return;
    Navigator.of(context).pop(false); // Return false indicating cancellation
  }

  // 45 Seconds Timeout behavior (standard sandbox handling for Sprint 5)
  void _handlePaymentTimeout() {
    _cleanup();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.info_rounded, color: AppColors.accent500),
            SizedBox(width: 8),
            Text('المعاملة قيد المعالجة', style: TextStyle(fontFamily: 'Cairo')),
          ],
        ),
        content: const Text(
          'عملية الدفع قيد التأكيد حالياً من البنك. ستصلك إشعار فوري عند اكتمالها بنجاح.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(null); // Return null indicating pending/processing
            },
            child: const Text('موافق', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _statusSubscription?.cancel();
    if (_realtimeChannel != null) {
      final channel = _realtimeChannel!;
      _realtimeChannel = null;
      try {
        ref.read(paymentsRepositoryProvider).stopWatching(channel);
      } catch (_) {
        // Safe fallback if ref is already disposed
      }
    }
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back never pops directly: it cancels the payment (not while confirming).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isConfirming) return;
        _handlePaymentCancellation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'بوابة الدفع الآمنة',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              if (!_isConfirming) {
                _handlePaymentCancellation();
              }
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isPageLoading && !_isConfirming)
              const Center(
                child: CircularProgressIndicator(color: AppColors.primary500),
              ),
            if (_isConfirming)
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.primary500),
                          SizedBox(height: 20),
                          Text(
                            'جاري تأكيد الدفع...',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'يرجى عدم إغلاق التطبيق أو الرجوع للخلف',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
