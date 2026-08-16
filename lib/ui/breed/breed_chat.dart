import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/morph_nlp.dart';
import '../../state/providers.dart';
import '../gallery/morph_detail_sheet.dart';
import '../widgets/common.dart';
import 'breed_result_view.dart';

/// The `.chat` card: suggestion chips, message list, composer.
///
/// The answers come from the rule-based Korean parser in [MorphNlp], not a
/// language model — the same behaviour as the web version.
class BreedChatCard extends ConsumerStatefulWidget {
  const BreedChatCard({super.key});

  @override
  ConsumerState<BreedChatCard> createState() => _BreedChatCardState();
}

class _BreedChatCardState extends ConsumerState<BreedChatCard> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = preset ?? _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(chatProvider.notifier).ask(text);
    _controller.clear();
    // Let the list rebuild before scrolling to the newly added answer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    return SectionCard(
      title: 'AI에게 물어보기',
      subtitle: '「릴리화이트랑 아잔틱 섞으면?」처럼 한국어로 물어보세요.',
      trailing: IconButton(
        onPressed: ref.read(chatProvider.notifier).reset,
        icon: const Icon(Icons.restart_alt, size: 18),
        color: AppColors.muted,
        tooltip: '대화 초기화',
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in MorphNlp.suggestions)
                _Chip(label: suggestion, onTap: () => _send(suggestion)),
            ],
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 240, maxHeight: 460),
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _MessageBubble(message: messages[index]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Composer(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: AppButton(label: '질문', onPressed: _send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label, style: AppText.sub.copyWith(fontSize: 12)),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('breed-chat-input'),
      controller: controller,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.send,
      style: AppText.body,
      cursorColor: AppColors.amber,
      decoration: InputDecoration(
        hintText: '예: 카푸치노랑 릴리 섞으면 뭐가 나와?',
        hintStyle: AppText.sub.copyWith(fontSize: 13.5),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.28),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.amber.withValues(alpha: 0.6)),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
    borderSide: BorderSide(color: color),
  );
}

/// A `.bubble` plus, for breeding answers, the offspring cards beneath it.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: message.isUser
            ? AppColors.amber
            : AppColors.lichen.withValues(alpha: 0.08),
        border: message.isUser ? null : Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Text(
        message.text,
        style: AppText.bubble.copyWith(
          color: message.isUser ? AppColors.onAmber : AppColors.cream,
          fontWeight: message.isUser ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: message.isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        bubble,
        if (message.answer != null) ...[
          const SizedBox(height: 10),
          _AnswerDetail(answer: message.answer!),
        ],
      ],
    );
  }
}

class _AnswerDetail extends StatelessWidget {
  const _AnswerDetail({required this.answer});

  final MorphAnswer answer;

  @override
  Widget build(BuildContext context) {
    return switch (answer.kind) {
      AnswerKind.breed => BreedResultView(result: answer.result!, dense: true),
      AnswerKind.info => _MorphInfoCard(answer: answer),
      AnswerKind.help => const SizedBox.shrink(),
    };
  }
}

class _MorphInfoCard extends StatelessWidget {
  const _MorphInfoCard({required this.answer});

  final MorphAnswer answer;

  @override
  Widget build(BuildContext context) {
    final morph = answer.morph!;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: () => showMorphDetail(context, morph),
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              SizedBox(width: 92, height: 72, child: MorphImage(morph: morph)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        morph.nameKo,
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        morph.inheritanceKo,
                        style: AppText.sub.copyWith(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
