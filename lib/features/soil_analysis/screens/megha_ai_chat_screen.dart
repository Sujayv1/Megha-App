import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_agent_widget.dart';
import '../../../models/visual_rag_models.dart';
import '../../../services/visual_rag_service.dart';
import '../../../services/voice_assistant_service.dart';
import '../services/megha_chat_storage_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_surface.dart';
import '../widgets/voice_mic_button.dart';

class MeghaAiChatScreen extends StatefulWidget {
  const MeghaAiChatScreen({super.key});

  @override
  State<MeghaAiChatScreen> createState() => _MeghaAiChatScreenState();
}

class _MeghaAiChatScreenState extends State<MeghaAiChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _inputScrollController = ScrollController();

  String _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
  String _currentSessionTitle = 'New Chat';

  List<ChatMessageModel> _messages = [];
  List<MeghaChatSession> _savedSessions = [];
  bool _isThinking = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryAndInit();
  }

  @override
  void dispose() {
    VoiceAssistantService.instance.stopSpeaking();
    VoiceAssistantService.instance.stopListening();
    _textController.dispose();
    _scrollController.dispose();
    _inputScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryAndInit() async {
    final sessions = await MeghaChatStorageService.instance.loadSessions();
    if (mounted) {
      setState(() {
        _savedSessions = sessions;
        _isLoadingHistory = false;
        if (sessions.isNotEmpty) {
          // Load most recent session
          _loadSession(sessions.first);
        } else {
          _startNewChat();
        }
      });
    }
  }

  Future<void> _startNewChat() async {
    final hasUserMsg = _messages.any((m) => m.role == 'user');
    if (hasUserMsg) {
      await _autoSaveCurrentSession();
    }

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final updatedSessions = await MeghaChatStorageService.instance
        .loadSessions();

    if (mounted) {
      setState(() {
        _savedSessions = updatedSessions;
        _currentSessionId = newId;
        _currentSessionTitle = 'New Chat';
        _messages = [
          ChatMessageModel(
            role: 'assistant',
            content:
                'Namaste! 🙏 I am Megha AI, your personal agricultural assistant. Ask me anything about farming, crops, soil health, mandi prices, or plant diseases!',
            timestamp: DateTime.now(),
          ),
        ];
      });
    }
  }

  Future<void> _loadSession(MeghaChatSession session) async {
    final hasUserMsg = _messages.any((m) => m.role == 'user');
    if (hasUserMsg && _currentSessionId != session.id) {
      await _autoSaveCurrentSession();
    }

    final updatedSessions = await MeghaChatStorageService.instance
        .loadSessions();
    if (mounted) {
      setState(() {
        _savedSessions = updatedSessions;
        _currentSessionId = session.id;
        _currentSessionTitle = session.title;
        _messages = List.from(session.messages);
      });
      _scrollToBottom();
    }
  }

  Future<void> _autoSaveCurrentSession() async {
    final hasUserMsg = _messages.any((m) => m.role == 'user');
    if (!hasUserMsg) return;

    // Generate title from first user message if needed
    String title = _currentSessionTitle;
    if (title == 'New Chat') {
      final firstUserMsg = _messages.firstWhere(
        (m) => m.role == 'user',
        orElse: () => _messages.first,
      );
      title = firstUserMsg.content.length > 28
          ? '${firstUserMsg.content.substring(0, 28)}...'
          : firstUserMsg.content;
      _currentSessionTitle = title;
    }

    final session = MeghaChatSession(
      id: _currentSessionId,
      title: title,
      updatedAt: DateTime.now(),
      messages: List.from(_messages),
    );

    await MeghaChatStorageService.instance.saveSession(session);
    final updatedList = await MeghaChatStorageService.instance.loadSessions();
    if (mounted) {
      setState(() {
        _savedSessions = updatedList;
      });
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    await MeghaChatStorageService.instance.deleteSession(sessionId);
    final updatedList = await MeghaChatStorageService.instance.loadSessions();
    if (mounted) {
      setState(() {
        _savedSessions = updatedList;
        if (_currentSessionId == sessionId) {
          if (updatedList.isNotEmpty) {
            _loadSession(updatedList.first);
          } else {
            _startNewChat();
          }
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _textController.text).trim();
    if (text.isEmpty || _isThinking) return;

    _textController.clear();

    final userMessage = ChatMessageModel(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isThinking = true;
    });

    _scrollToBottom();
    await _autoSaveCurrentSession();

    try {
      // Execute Visual RAG Backend Retrieval Pipeline (Qdrant Cloud & Gemini Vision)
      final ragResponse = await VisualRagService.instance.ask(text);

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessageModel(
              role: 'assistant',
              content: ragResponse.answer,
              timestamp: DateTime.now(),
              citations: ragResponse.citations.isNotEmpty
                  ? ragResponse.citations
                  : null,
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
        await _autoSaveCurrentSession();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessageModel(
              role: 'assistant',
              content:
                  '⚠️ Could not connect to the Visual RAG assistant. Please check your network connection and try again.',
              timestamp: DateTime.now(),
            ),
          );
          _isThinking = false;
        });
        _scrollToBottom();
        await _autoSaveCurrentSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgTop,
      endDrawer: _buildSidebarDrawer(context),
      body: Stack(
        children: [
          // ── Soft Ambient Background ──────────────────────────────────────
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgTop,
                    AppColors.bgMid,
                    AppColors.bgBottom,
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content Column ──────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: _isLoadingHistory
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.leafGreen,
                          ),
                        )
                      : _buildChatList(),
                ),
                if (_isThinking) _buildThinkingIndicator(),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar matching Risk Analysis styling + History Drawer Button ────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(7.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 16.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Megha AI',
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // New Chat Button
              GestureDetector(
                onTap: _startNewChat,
                child: Container(
                  padding: const EdgeInsets.all(7.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.leafGreen,
                    size: 16.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Open Chat History Sidebar Drawer Button
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(7.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.textPrimary,
                    size: 16.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chat History Sidebar Drawer (Fluid Liquid Glass) ───────────────────────

  Widget _buildSidebarDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassSurface(
        borderRadius: 0,
        blur: 24,
        opacity: 0.55,
        tint: AppColors.cardCream,
        borderWidth: 0,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.leafGreen.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.leafGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: AppColors.leafGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Chat History',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                        weight: 800,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Start New Chat Action Button (Fluid Glass)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: GlassCard(
                  tint: AppColors.leafGreen,
                  opacity: 0.90,
                  borderRadius: 16,
                  borderOpacity: 0.60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startNewChat();
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Start New Chat',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ),

              // Saved Conversations List
              Expanded(
                child: _savedSessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 38,
                              color: AppColors.textMuted.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No saved chats yet.\nAsk Megha AI a question!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: _savedSessions.length,
                        itemBuilder: (context, index) {
                          final session = _savedSessions[index];
                          final isSelected = session.id == _currentSessionId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              tint: isSelected
                                  ? AppColors.leafGreen
                                  : AppColors.cardCream,
                              opacity: isSelected ? 0.90 : 0.45,
                              borderRadius: 16,
                              borderOpacity: isSelected ? 0.60 : 0.22,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _loadSession(session);
                              },
                              child: Row(
                                children: [
                                  // Indicator / icon: White outside container, green icon for all items
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: isSelected
                                          ? null
                                          : Border.all(
                                              color: AppColors.leafGreen
                                                  .withValues(alpha: 0.25),
                                              width: 1.0,
                                            ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isSelected ? 0.12 : 0.05,
                                          ),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.chat_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                      size: 14,
                                      color: AppColors.leafGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          session.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.3,
                                            height: 1.3,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.leafGreen,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${session.messages.length} messages • ${_formatTimeAgo(session.updatedAt)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white.withValues(
                                                    alpha: 0.85,
                                                  )
                                                : AppColors.leafGreen
                                                    .withValues(alpha: 0.70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    onPressed: () => _deleteSession(session.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Chat List ──────────────────────────────────────────────────────────────

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.role == 'user';
        return _buildChatBubble(message, isUser);
      },
    );
  }

  Widget _buildChatBubble(ChatMessageModel message, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Megha AI Avatar: Dedicated ChatAvatarAgentWidget positioned close to the left edge
            const Padding(
              padding: EdgeInsets.only(right: 6, top: 2),
              child: ChatAvatarAgentWidget(width: 28, height: 28),
            ),
          ],
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isUser
                    ? MediaQuery.of(context).size.width * 0.76
                    : double.infinity,
              ),
              child: RepaintBoundary(
                child: GlassCard(
                  tint: isUser
                      ? AppColors.leafGreen.withValues(alpha: 0.16)
                      : AppColors.cardCream,
                  borderOpacity: 0.25,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MarkdownBody(
                        data: message.content,
                        selectable: true,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: GoogleFonts.poppins(
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                                height: 1.45,
                              ),
                              strong: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.leafGreen,
                              ),
                              listBullet: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.leafGreen,
                              ),
                              listIndent: 18,
                              listBulletPadding: const EdgeInsets.only(
                                right: 6,
                                top: 2,
                              ),
                              blockSpacing: 6,
                              h1: GoogleFonts.poppins(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w800,
                                color: AppColors.leafGreen,
                              ),
                              h2: GoogleFonts.poppins(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.leafGreen,
                              ),
                              h3: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.leafGreen,
                              ),
                              code: GoogleFonts.firaCode(
                                fontSize: 12.0,
                                color: AppColors.leafGreen,
                                backgroundColor:
                                    AppColors.leafGreen.withValues(
                                      alpha: 0.08,
                                    ),
                              ),
                              blockquote: GoogleFonts.poppins(
                                fontSize: 13.0,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: AppColors.leafGreen.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: const Border(
                                  left: BorderSide(
                                    color: AppColors.leafGreen,
                                    width: 3.5,
                                  ),
                                ),
                              ),
                              blockquotePadding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                            ),
                      ),
                      if (message.citations != null &&
                          message.citations!.isNotEmpty)
                        _buildCitationsWidget(message.citations!),
                      const SizedBox(height: 4),
                      if (isUser)
                        Text(
                          '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.poppins(
                            fontSize: 10.0,
                            fontWeight: FontWeight.w500,
                            color: AppColors.leafGreen.withValues(alpha: 0.8),
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                              style: GoogleFonts.poppins(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.leafGreen,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTtsSpeakerButton(message),
                                const SizedBox(width: 6),
                                _buildCopyButton(message.content),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            // Compact User Avatar Icon
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.leafGreen.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.leafGreen,
                  size: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0.0);
  }

  // ── TTS Voice Playback Button ───────────────────────────────────────────────

  Widget _buildTtsSpeakerButton(ChatMessageModel message) {
    final msgId =
        '${message.timestamp.millisecondsSinceEpoch}_${message.content.hashCode}';
    return ValueListenableBuilder<String?>(
      valueListenable: VoiceAssistantService.instance.currentlySpeakingId,
      builder: (context, speakingId, _) {
        final isSpeakingThis = speakingId == msgId;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            VoiceAssistantService.instance.speak(
              message.content,
              messageId: msgId,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSpeakingThis
                      ? Icons.stop_circle_rounded
                      : Icons.volume_up_rounded,
                  size: 13.5,
                  color: isSpeakingThis
                      ? Colors.redAccent
                      : AppColors.leafGreen.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 3.5),
                Text(
                  isSpeakingThis ? 'Stop' : 'Listen',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isSpeakingThis
                        ? Colors.redAccent
                        : AppColors.leafGreen.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Copy Answer Button ───────────────────────────────────────────────────────

  Widget _buildCopyButton(String textToCopy) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: textToCopy));
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            padding: EdgeInsets.zero,
            content: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.leafGreen.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.leafGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppColors.leafGreen,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Copied to clipboard',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy_rounded,
              size: 12.5,
              color: AppColors.leafGreen.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 3.5),
            Text(
              'Copy',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.leafGreen.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grounded Citations Widget (Clean & Minimal Text Only) ───────────────────

  Widget _buildCitationsWidget(List<DocumentCitation> citations) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                size: 13,
                color: AppColors.leafGreen,
              ),
              const SizedBox(width: 5),
              Text(
                'Sources (${citations.length})',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.leafGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: citations.map((c) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  c.formattedCitation,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Thinking Indicator ────────────────────────────────────────────────────

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const ChatAvatarAgentWidget(width: 30, height: 30),
          const SizedBox(width: 6),
          Flexible(
            child: GlassCard(
              tint: AppColors.cardCream,
              borderOpacity: 0.25,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Megha AI is analyzing...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.leafGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child:
                            Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.leafGreen,
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(
                                  delay: Duration(milliseconds: i * 200),
                                  duration: 600.ms,
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1.3, 1.3),
                                ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ── Input Bar with Multi-Line Auto-Expansion & Left-Side Voice Mic Button ──

  void _scrollInputToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_inputScrollController.hasClients) {
        _inputScrollController.animateTo(
          _inputScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left outside mic button with ripple pulse animation
          VoiceMicButton(
            textController: _textController,
            onSpeechCompleted: () {
              if (mounted) {
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
                _scrollInputToBottom();
              }
            },
          ),
          const SizedBox(width: 8),
          // Main glass auto-expanding text field container (ChatGPT style)
          Expanded(
            child: RepaintBoundary(
              child: GlassCard(
                tint: AppColors.cardCream,
                borderRadius: 20,
                borderOpacity: 0.25,
                padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 34,
                          maxHeight: 120,
                        ),
                        child: Scrollbar(
                          controller: _inputScrollController,
                          thumbVisibility: true,
                          radius: const Radius.circular(4),
                          thickness: 3.5,
                          child: TextField(
                            controller: _textController,
                            scrollController: _inputScrollController,
                            textAlignVertical: TextAlignVertical.center,
                            minLines: 1,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            scrollPhysics: const BouncingScrollPhysics(),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Talk to Megha AI',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 12.0,
                                color: AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (_) => _scrollInputToBottom(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      icon: const Icon(
                        Icons.send_rounded,
                        color: AppColors.leafGreen,
                        size: 18.5,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
