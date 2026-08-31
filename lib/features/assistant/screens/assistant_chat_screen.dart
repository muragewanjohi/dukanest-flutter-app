import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../core/navigation/in_app_link.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/assistant_chat_provider.dart';

/// DukaNest AI Assistant — Flutter Phase 2/3 (see IMPLEMENTATION_TRACKER.md,
/// "UI — Dashboard AI Assistant on Flutter"), reached from the center
/// bottom-nav tab. Talks to POST /api/v1/mobile/assistant/chat (data_query,
/// help_question, next_steps, business_advice, configuration_guidance).
/// A configuration_guidance reply targeting product_intake switches the
/// provider into product-intake mode, which drives
/// POST /api/v1/mobile/products/ai-intake turn by turn and creates the
/// product for real on completion — see assistant_chat_provider.dart.
class AssistantChatScreen extends ConsumerStatefulWidget {
  const AssistantChatScreen({super.key});

  @override
  ConsumerState<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends ConsumerState<AssistantChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _send([String? overrideText]) {
    final text = overrideText ?? _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(assistantChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _openLink(String href) async {
    final trimmed = href.trim();
    if (trimmed.isEmpty) return;

    // Store-configuration links (theme, payments, delivery, …) open the native
    // screen instead of the website — whether the backend hands us an app path,
    // a /dashboard/* URL, or a help article about a config task.
    final inAppRoute = resolveInAppRoute(trimmed);
    if (inAppRoute != null) {
      if (mounted) context.push(inAppRoute);
      return;
    }

    if (trimmed.startsWith('http')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    if (mounted) context.push(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantChatProvider);
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Personal Assistant'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length + (state.loading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.messages.length) {
                    return _ThinkingBubble();
                  }
                  return _MessageBubble(
                    message: state.messages[index],
                    onLinkTap: _openLink,
                  );
                },
              ),
            ),
            if (state.messages.length == 1 && !state.loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: assistantSuggestedPrompts
                      .map((p) => ActionChip(
                            label: Text(p),
                            backgroundColor: AppTheme.surfaceContainerLow,
                            side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                            onPressed: () => _send(p),
                          ))
                      .toList(),
                ),
              ),
            _InputBar(
              controller: _inputController,
              loading: state.loading,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onLinkTap});

  final AssistantMessage message;
  final void Function(String href) onLinkTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bubbleColor = isUser
        ? AppTheme.primary
        : (message.isError ? AppTheme.errorContainer : AppTheme.surfaceContainerLow);
    final textColor = isUser
        ? Colors.white
        : (message.isError ? AppTheme.onErrorContainer : AppTheme.secondary);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
            if (message.citedArticles.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.citedArticles.map((a) => GestureDetector(
                    onTap: () => onLinkTap(a['url'] as String? ?? ''),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${a['title']} →',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )),
            ],
            if (message.nextSteps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.nextSteps.map((s) {
                  return GestureDetector(
                    onTap: () => onLinkTap(s['href'] as String? ?? ''),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        color: AppTheme.primary.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        '${s['cta']} →',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('Thinking…', style: TextStyle(color: AppTheme.neutral, fontSize: 14)),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.loading, required this.onSend});

  final TextEditingController controller;
  final bool loading;
  final void Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !loading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Ask about your store…',
                filled: true,
                fillColor: AppTheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: loading ? null : () => onSend(),
            icon: const Icon(Icons.arrow_upward_rounded),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
