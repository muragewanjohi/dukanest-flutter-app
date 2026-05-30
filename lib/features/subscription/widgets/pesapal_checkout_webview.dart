import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_app_bar.dart';

/// Hosted checkout: loads [redirectUrl] from `POST …/subscription/pesapal/initiate`.
class PesapalCheckoutWebView extends StatefulWidget {
  const PesapalCheckoutWebView({
    super.key,
    required this.redirectUrl,
    this.title = 'Checkout',
  });

  final String redirectUrl;
  final String title;

  /// Pushes fullscreen checkout; pops with `true` when merchant taps Done or back.
  static Future<bool?> push(
    BuildContext context, {
    required String redirectUrl,
    String title = 'Checkout',
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => PesapalCheckoutWebView(
          redirectUrl: redirectUrl,
          title: title,
        ),
      ),
    );
  }

  @override
  State<PesapalCheckoutWebView> createState() => _PesapalCheckoutWebViewState();
}

class _PesapalCheckoutWebViewState extends State<PesapalCheckoutWebView> {
  late final WebViewController _controller;
  double _progress = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    final uri = Uri.tryParse(widget.redirectUrl.trim());
    final initialUri = uri ?? Uri.parse('about:blank');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p / 100),
          onUrlChange: (change) => _maybeComplete(change.url),
          onNavigationRequest: (req) {
            if (_isCompletionUrl(req.url)) {
              _complete();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(initialUri);
  }

  /// PesaPal redirects back to the merchant callback (carrying an
  /// `OrderTrackingId`) once the payment flow finishes. Detect that to close
  /// the sheet automatically instead of relying on the manual "Done" tap.
  bool _isCompletionUrl(String? url) {
    if (url == null) return false;
    final u = url.toLowerCase();
    // Never treat the initial hosted-checkout URL as completion.
    if (u == widget.redirectUrl.trim().toLowerCase()) return false;
    const markers = [
      'ordertrackingid',
      'pesapal_transaction_tracking_id',
      'payment/callback',
      'payment-callback',
      'paymentcallback',
      'subscription/success',
      'subscription/callback',
      'status=completed',
      'paymentstatus=completed',
    ];
    return markers.any(u.contains);
  }

  void _maybeComplete(String? url) {
    if (_isCompletionUrl(url)) _complete();
  }

  void _complete() {
    if (_completed || !mounted) return;
    _completed = true;
    Navigator.of(context).pop<bool>(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: DashboardAppBar(
        title: widget.title,
        automaticallyImplyLeading: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop<bool>(true),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_progress > 0 && _progress < 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
