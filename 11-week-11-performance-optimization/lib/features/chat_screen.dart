import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = [
    'Ringkasan konsep Riverpod & Offline-First di Flutter',
    'Checklist persiapan presentasi proyek mobile',
    'Catatan rapat pembagian tugas tim minggu 10',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _promptController.text).trim();
    if (text.isEmpty) return;
    if (preset == null) {
      _promptController.clear();
    }
    _scrollToBottom();
    await ref.read(aiChatProvider.notifier).sendPrompt(text);
    _scrollToBottom();
  }

  Future<void> _saveNote(int index) async {
    await ref.read(aiChatProvider.notifier).saveNoteFromMessage(index);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catatan AI berhasil disimpan ke daftar catatan.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatProvider.select((s) => s.messages));
    final isGenerating = ref.watch(
      aiChatProvider.select((s) => s.isGenerating),
    );
    final usage = ref.watch(aiDailyUsageProvider).value ?? 0;
    final offline = ref.watch(forceOfflineProvider);
    final maxQuota = ref.read(aiServiceProvider).maxDailyRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Note Assistant'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                offline ? Icons.cloud_off : Icons.auto_awesome,
                size: 16,
              ),
              label: Text(
                offline ? 'Offline' : 'Kuota $usage/$maxQuota',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (messages.isNotEmpty)
            IconButton(
              tooltip: 'Bersihkan chat',
              onPressed: () => ref.read(aiChatProvider.notifier).clearChat(),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (offline)
            MaterialBanner(
              content: const Text(
                'Mode offline aktif. AI cloud dinonaktifkan; gunakan fallback lokal untuk membuat draf catatan.',
              ),
              leading: const Icon(Icons.cloud_off),
              actions: [
                TextButton(
                  onPressed: () => setForceOffline(ref, false),
                  child: const Text('Matikan Offline'),
                ),
              ],
            ),
          Expanded(
            child: messages.isEmpty && !isGenerating
                ? _EmptyChatView(
                    quickPrompts: _quickPrompts,
                    onSelectPrompt: _send,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length + (isGenerating ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const _StreamingBubble();
                      }
                      final msg = messages[index];
                      if (msg.isUser) {
                        return RepaintBoundary(child: _UserBubble(text: msg.text));
                      }
                      if (msg.isError) {
                        return RepaintBoundary(
                          child: _ErrorBubble(
                            errorText: msg.text,
                            onUseFallback: msg.failedPrompt == null
                                ? null
                                : () async {
                                    await ref
                                        .read(aiChatProvider.notifier)
                                        .generateWithFallback(
                                          msg.failedPrompt!,
                                        );
                                    _scrollToBottom();
                                  },
                          ),
                        );
                      }
                      return RepaintBoundary(
                        child: _AiNoteBubble(
                          message: msg,
                          onSave: () => _saveNote(index),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('ai_chat_input'),
                    controller: _promptController,
                    enabled: !isGenerating,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Tulis topik atau ide catatan untuk AI...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('ai_chat_send_btn'),
                  onPressed: isGenerating ? null : () => _send(),
                  icon: isGenerating
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Buat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({
    required this.quickPrompts,
    required this.onSelectPrompt,
  });

  final List<String> quickPrompts;
  final ValueChanged<String> onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Icon(
          Icons.auto_awesome,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Auto-Generate Notes dengan AI',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Ketik topik, materi kuliah, atau ide singkat. AI akan menyusunnya menjadi catatan terstruktur yang siap disimpan ke SQLite lokal.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Contoh prompt cepat:',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickPrompts
              .map(
                (prompt) => ActionChip(
                  avatar: const Icon(Icons.bolt, size: 16),
                  label: Text(prompt),
                  onPressed: () => onSelectPrompt(prompt),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

class _StreamingBubble extends ConsumerWidget {
  const _StreamingBubble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(aiChatProvider.select((s) => s.streamingPreview));
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, right: 48),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text.isEmpty ? 'Menyusun catatan...' : text,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiNoteBubble extends StatelessWidget {
  const _AiNoteBubble({required this.message, required this.onSave});

  final ChatMessage message;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = message.generatedNote;
    if (note == null) {
      return const SizedBox.shrink();
    }

    final badgeLabel = note.isFallback
        ? 'Offline Fallback'
        : (note.fromCache ? 'Local Cache' : 'AI Generated');

    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12, right: 32),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    note.isFallback ? Icons.offline_bolt : Icons.auto_awesome,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      badgeLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(note.body, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('save_ai_note_btn'),
                  onPressed: message.isSaved ? null : onSave,
                  icon: Icon(
                    message.isSaved ? Icons.check : Icons.bookmark_add_outlined,
                  ),
                  label: Text(
                    message.isSaved ? 'Tersimpan' : 'Simpan ke Catatan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    required this.errorText,
    this.onUseFallback,
  });

  final String errorText;
  final VoidCallback? onUseFallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        color: theme.colorScheme.errorContainer,
        margin: const EdgeInsets.only(bottom: 12, right: 32),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Layanan AI Tidak Tersedia',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                errorText,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              if (onUseFallback != null) ...[
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: const Key('use_fallback_btn'),
                  onPressed: onUseFallback,
                  icon: const Icon(Icons.offline_bolt),
                  label: const Text('Gunakan Fallback Lokal'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
