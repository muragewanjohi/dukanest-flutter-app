import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme.dart';
import '../../../core/widgets/dashboard_app_bar.dart';
import '../providers/onboarding_chat_provider.dart';

/// Onboarding AI Chat (OC.3) — the Flutter mirror of web's
/// dashboard/onboarding/chat/onboarding-chat-client.tsx. Reachable after
/// registration (see OC.4 wiring in register_screen.dart) or later from the
/// More menu; never a blocking gate — every state below offers a way
/// through to the dashboard (OC.2's "additive, not a replacement" scope,
/// OC.5's fail-soft escape hatch).
class OnboardingChatScreen extends ConsumerStatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  ConsumerState<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends ConsumerState<OnboardingChatScreen> {
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

  void _send() {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    ref.read(onboardingChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _continueToDashboard() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingChatProvider);
    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: const DashboardAppBar(title: 'Tell us about your store'),
      body: SafeArea(
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(OnboardingChatState state) {
    if (state.contextLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    // Already told us — mirrors web's "already told us about {storeName}"
    // summary state, shown instead of restarting the conversation.
    if (state.knownNiche != null && state.messages.isEmpty) {
      return _SummaryCard(
        storeName: state.storeName,
        niche: state.knownNiche!,
        onContinue: _continueToDashboard,
      );
    }

    if (state.done) {
      return _DoneCard(saved: state.saved, onContinue: _continueToDashboard);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.messages.length + (state.loading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.messages.length) {
                return const _ThinkingBubble();
              }
              return _MessageBubble(message: state.messages[index]);
            },
          ),
        ),
        if (state.errored)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _continueToDashboard,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(
                  'Skip for now — continue to Dashboard',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        _InputBar(
          controller: _inputController,
          loading: state.loading,
          onSend: _send,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.storeName, required this.niche, required this.onContinue});

  final String? storeName;
  final String niche;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.mpesaGreen, size: 48),
            const SizedBox(height: 16),
            Text(
              storeName != null && storeName!.isNotEmpty
                  ? "You've already told us about $storeName"
                  : "You've already told us about your store",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.secondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Focus: $niche',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Continue to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.saved, required this.onContinue});

  final bool saved;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              saved ? Icons.check_circle_rounded : Icons.info_rounded,
              color: saved ? AppTheme.mpesaGreen : AppTheme.neutral,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              saved
                  ? "Thanks — we've saved that for you."
                  : "Thanks! We couldn't save that just now, but you're all set to continue.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.secondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Continue to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final OnboardingChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bubbleColor = isUser ? AppTheme.primary : AppTheme.surfaceContainerLow;
    final textColor = isUser ? Colors.white : AppTheme.secondary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(16)),
        child: Text(message.text, style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

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
  final VoidCallback onSend;

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
                hintText: 'Type your answer…',
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
            onPressed: loading ? null : onSend,
            icon: const Icon(Icons.arrow_upward_rounded),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
