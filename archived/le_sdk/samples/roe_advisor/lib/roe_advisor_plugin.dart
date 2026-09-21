import 'package:flutter/material.dart';
import 'package:lattice_common/lattice_common.dart' show LatticeColorScheme;
import 'package:le_sdk/le_sdk.dart';

class RoeAdvisorPlugin extends LatticeEdgeExtension {
  @override
  String get id => 'roe_advisor';

  @override
  String get name => 'ROE Advisor';

  @override
  String get description => 'Rules of engagement decision support';

  @override
  IconData get icon => Icons.shield;

  @override
  ExtensionDisplayMode get defaultDisplayMode => ExtensionDisplayMode.panel;

  @override
  Widget build(ExtensionContext context) => _RoeAdvisorPanel(context: context);
}

/// The ROE card content that gets injected as the system prompt.
/// In a real deployment this would be loaded from a config file or
/// fetched from a server. This sample uses a representative example.
const _roeSystemPrompt = '''
You are an ROE (Rules of Engagement) advisor for a military unit. Answer questions about engagement decisions based ONLY on these rules. If a situation is ambiguous, say so and recommend requesting clarification from higher command.

Be direct and concise. Start with the bottom line (ENGAGE / DO NOT ENGAGE / REQUEST GUIDANCE) then explain the reasoning.

ROE CARD — OPERATION DEMO SHIELD

HOSTILE ACT / HOSTILE INTENT
- Personnel who commit a hostile act or demonstrate hostile intent may be engaged in self-defense.
- Hostile act: attack or use of force against US/coalition forces, designated persons, or property.
- Hostile intent: threat of imminent use of force against US/coalition forces.

DECLARED HOSTILE FORCES
- Forces designated hostile by competent authority may be engaged on sight.
- Current declared hostile forces: none designated at this time.

POSITIVE IDENTIFICATION (PID)
- PID is REQUIRED before engagement. PID means reasonable certainty that the target is a legitimate military target.
- Uniform alone is NOT sufficient for PID in this AO.
- Weapons possession alone is NOT sufficient for PID (local population may be armed).
- Combination of indicators required: weapons + threatening behavior + context.

ESCALATION OF FORCE
All engagements must follow EOF procedures when tactically feasible:
1. SHOUT — verbal warning in local language
2. SHOW — show weapon / demonstrate intent to use force
3. SHOVE — physically restrain / block
4. SHOOT TO WARN — warning shot into safe area
5. SHOOT TO ELIMINATE — aimed fire to stop the threat

PROPORTIONALITY
- Force used must be proportional to the threat.
- Minimum force necessary to eliminate the threat.
- Cease fire when threat is neutralized.

PROTECTED PERSONS AND PLACES
- Do NOT engage: medical personnel/facilities, religious sites, schools, clearly marked civilian infrastructure.
- Presence of hostile forces in/near protected sites does NOT automatically authorize engagement.
- Request guidance from higher if hostile forces use protected sites.

COLLATERAL DAMAGE
- CDE (Collateral Damage Estimation) required for any engagement expected to cause collateral damage.
- Engagements with estimated civilian casualties require approval from battalion commander or above.

DETENTION
- Persons may be detained if they pose a security threat.
- All detainees must be treated humanely per Geneva Conventions.
- Report all detentions to higher within 1 hour.

REPORTING
- Report all engagements to higher immediately.
''';

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class _RoeAdvisorPanel extends StatefulWidget {
  final ExtensionContext context;
  const _RoeAdvisorPanel({required this.context});

  @override
  State<_RoeAdvisorPanel> createState() => _RoeAdvisorPanelState();
}

class _RoeAdvisorPanelState extends State<_RoeAdvisorPanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _isStreaming = false;
  String _streamingContent = '';
  bool _micListening = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _dictate() async {
    if (_micListening || _isStreaming) return;
    setState(() => _micListening = true);
    try {
      final text = await widget.context.speech.dictate();
      if (text != null && text.isNotEmpty && mounted) {
        _inputController.text = text;
        await _send();
      }
    } finally {
      if (mounted) setState(() => _micListening = false);
    }
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isStreaming) return;

    setState(() {
      _messages.add(_ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _inputController.clear();
      _isStreaming = true;
      _streamingContent = '';
    });
    _scrollToBottom();

    try {
      // Build conversation history for multi-turn context
      final messages = <ChatCompletionMessage>[
        const ChatCompletionMessage(
          role: 'system',
          content: _roeSystemPrompt,
        ),
        for (final msg in _messages)
          ChatCompletionMessage(role: msg.role, content: msg.content),
      ];

      final stream = widget.context.ai.chat.completions.createStream(
        ChatCompletionRequest(
          messages: messages,
          stream: true,
          hostTools: false, // ROE advice is self-contained, no entity/map tools needed
        ),
      );

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        for (final choice in chunk.choices) {
          if (choice.delta.content != null) {
            buffer.write(choice.delta.content);
            if (mounted) {
              setState(() => _streamingContent = buffer.toString());
              _scrollToBottom();
            }
          }
        }
      }

      if (!mounted) return;

      final response = buffer.toString().trim();
      if (response.isNotEmpty) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: response,
            timestamp: DateTime.now(),
          ));
          _streamingContent = '';
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            content: 'Error: $e',
            timestamp: DateTime.now(),
          ));
          _streamingContent = '';
        });
      }
    } finally {
      if (mounted) setState(() => _isStreaming = false);
    }
  }

  Future<void> _clearChat() async {
    await widget.context.ai.clearHistory();
    setState(() {
      _messages.clear();
      _streamingContent = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield, size: 16, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ROE ADVISOR — OP DEMO SHIELD',
                  style: TextStyle(
                    color: colors.textLabel,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (_messages.isNotEmpty)
                SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: _isStreaming ? null : _clearChat,
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: colors.inactive,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: _messages.isEmpty && _streamingContent.isEmpty
              ? _buildEmptyState(colors)
              : ListView.builder(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _messages.length +
                      (_streamingContent.isNotEmpty ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i < _messages.length) {
                      return _buildMessage(_messages[i], colors);
                    }
                    // Streaming message
                    return _buildStreamingMessage(colors);
                  },
                ),
        ),

        // Input area
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Mic button
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed:
                        (_micListening || _isStreaming) ? null : _dictate,
                    icon: _micListening
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.accent,
                            ),
                          )
                        : Icon(Icons.mic, color: colors.accent, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.background,
                      side: BorderSide(color: colors.borderActive),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Text input
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _inputController,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Describe the situation...',
                        hintStyle: TextStyle(
                          color: colors.inactive,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: colors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.borderActive),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.borderActive),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.accent),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    onPressed: _isStreaming ? null : _send,
                    icon: _isStreaming
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.accent,
                            ),
                          )
                        : Icon(Icons.send, color: colors.accent, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: colors.background,
                      side: BorderSide(color: colors.borderActive),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(LatticeColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, size: 48, color: colors.inactive),
            const SizedBox(height: 16),
            Text(
              'ROE Decision Support',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Describe a tactical situation and get\nROE guidance based on the current\nrules of engagement card.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Quick scenario buttons
            _buildQuickPrompt(
              colors,
              'Armed individual approaching checkpoint',
            ),
            const SizedBox(height: 6),
            _buildQuickPrompt(
              colors,
              'Receiving fire from near a school',
            ),
            const SizedBox(height: 6),
            _buildQuickPrompt(
              colors,
              'Suspected IED, civilians nearby',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(LatticeColorScheme colors, String text) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _isStreaming
            ? null
            : () {
                _inputController.text = text;
                _send();
              },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colors.borderActive),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg, LatticeColorScheme colors) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? colors.accent.withOpacity(0.15)
                  : colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: isUser
                  ? null
                  : Border.all(color: colors.border, width: 1),
            ),
            child: Text(
              msg.content,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingMessage(LatticeColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.accent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _streamingContent,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
