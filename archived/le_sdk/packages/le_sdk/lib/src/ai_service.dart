// ---------------------------------------------------------------------------
// AI service interface
// ---------------------------------------------------------------------------

abstract class AiService {
  AiChatCompletions get chat;

  /// Signal the host to clear any conversation state for this extension.
  ///
  /// Implementations may be stateless (messages passed per-request), in which
  /// case this is a no-op. Callers should also clear their own local message
  /// history.
  Future<void> clearHistory();
}

abstract class AiChatCompletions {
  AiCompletions get completions;
}

abstract class AiCompletions {
  Stream<ChatCompletionChunk> createStream(ChatCompletionRequest request);
  Future<ChatCompletion> create(ChatCompletionRequest request);
}

// ---------------------------------------------------------------------------
// Request types
// ---------------------------------------------------------------------------

/// A message in a chat completion request.
class ChatCompletionMessage {
  final String role;
  final String? content;
  final String? name;
  final String? toolCallId;
  final List<ToolCallData>? toolCalls;

  const ChatCompletionMessage({
    required this.role,
    this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        if (content != null) 'content': content,
        if (name != null) 'name': name,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((t) => t.toJson()).toList(),
      };

  factory ChatCompletionMessage.fromJson(Map<String, dynamic> json) =>
      ChatCompletionMessage(
        role: json['role'] as String,
        content: json['content'] as String?,
        name: json['name'] as String?,
        toolCallId: json['tool_call_id'] as String?,
        toolCalls: json['tool_calls'] != null
            ? (json['tool_calls'] as List<dynamic>)
                .map((t) => ToolCallData.fromJson(t as Map<String, dynamic>))
                .toList()
            : null,
      );
}

/// A tool call within a message or delta.
class ToolCallData {
  final int? index;
  final String? id;
  final String? type;
  final ToolCallFunction? function;

  const ToolCallData({
    this.index,
    this.id,
    this.type,
    this.function,
  });

  Map<String, dynamic> toJson() => {
        if (index != null) 'index': index,
        if (id != null) 'id': id,
        if (type != null) 'type': type,
        if (function != null) 'function': function!.toJson(),
      };

  factory ToolCallData.fromJson(Map<String, dynamic> json) => ToolCallData(
        index: json['index'] as int?,
        id: json['id'] as String?,
        type: json['type'] as String?,
        function: json['function'] != null
            ? ToolCallFunction.fromJson(
                json['function'] as Map<String, dynamic>)
            : null,
      );
}

/// The function portion of a tool call.
class ToolCallFunction {
  final String? name;
  final String? arguments;

  const ToolCallFunction({
    this.name,
    this.arguments,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (arguments != null) 'arguments': arguments,
      };

  factory ToolCallFunction.fromJson(Map<String, dynamic> json) =>
      ToolCallFunction(
        name: json['name'] as String?,
        arguments: json['arguments'] as String?,
      );
}

/// A chat completion request sent to [AiCompletions].
class ChatCompletionRequest {
  final List<ChatCompletionMessage> messages;
  final bool stream;
  final bool hostTools;

  const ChatCompletionRequest({
    required this.messages,
    this.stream = false,
    this.hostTools = true,
  });

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': stream,
        'hostTools': hostTools,
      };

  factory ChatCompletionRequest.fromJson(Map<String, dynamic> json) =>
      ChatCompletionRequest(
        messages: (json['messages'] as List<dynamic>)
            .map((m) =>
                ChatCompletionMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        stream: json['stream'] as bool? ?? false,
        hostTools: json['hostTools'] as bool? ?? json['host_tools'] as bool? ?? true,
      );
}

// ---------------------------------------------------------------------------
// Non-streaming response types
// ---------------------------------------------------------------------------

/// A complete (non-streaming) chat completion response.
class ChatCompletion {
  final String id;
  final String object;
  final List<ChatChoice> choices;

  const ChatCompletion({
    required this.id,
    this.object = 'chat.completion',
    required this.choices,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'object': object,
        'choices': choices.map((c) => c.toJson()).toList(),
      };

  factory ChatCompletion.fromJson(Map<String, dynamic> json) => ChatCompletion(
        id: json['id'] as String,
        object: json['object'] as String? ?? 'chat.completion',
        choices: (json['choices'] as List<dynamic>)
            .map((c) => ChatChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// A single choice in a [ChatCompletion].
class ChatChoice {
  final int index;
  final ChatCompletionMessage message;
  final String? finishReason;

  const ChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'message': message.toJson(),
        if (finishReason != null) 'finish_reason': finishReason,
      };

  factory ChatChoice.fromJson(Map<String, dynamic> json) => ChatChoice(
        index: json['index'] as int,
        message: ChatCompletionMessage.fromJson(
            json['message'] as Map<String, dynamic>),
        finishReason: json['finish_reason'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Streaming response types
// ---------------------------------------------------------------------------

/// A streaming chat completion chunk.
class ChatCompletionChunk {
  final String id;
  final String object;
  final List<ChatChunkChoice> choices;

  const ChatCompletionChunk({
    required this.id,
    this.object = 'chat.completion.chunk',
    required this.choices,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'object': object,
        'choices': choices.map((c) => c.toJson()).toList(),
      };

  factory ChatCompletionChunk.fromJson(Map<String, dynamic> json) =>
      ChatCompletionChunk(
        id: json['id'] as String,
        object: json['object'] as String? ?? 'chat.completion.chunk',
        choices: (json['choices'] as List<dynamic>)
            .map((c) => ChatChunkChoice.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// A single choice in a [ChatCompletionChunk].
class ChatChunkChoice {
  final int index;
  final ChatCompletionDelta delta;
  final String? finishReason;

  const ChatChunkChoice({
    required this.index,
    required this.delta,
    this.finishReason,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'delta': delta.toJson(),
        if (finishReason != null) 'finish_reason': finishReason,
      };

  factory ChatChunkChoice.fromJson(Map<String, dynamic> json) =>
      ChatChunkChoice(
        index: json['index'] as int,
        delta: ChatCompletionDelta.fromJson(
            json['delta'] as Map<String, dynamic>),
        finishReason: json['finish_reason'] as String?,
      );
}

/// Incremental content in a streaming [ChatCompletionChunk].
class ChatCompletionDelta {
  final String? role;
  final String? content;
  final List<ToolCallData>? toolCalls;

  const ChatCompletionDelta({
    this.role,
    this.content,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() => {
        if (role != null) 'role': role,
        if (content != null) 'content': content,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((t) => t.toJson()).toList(),
      };

  factory ChatCompletionDelta.fromJson(Map<String, dynamic> json) =>
      ChatCompletionDelta(
        role: json['role'] as String?,
        content: json['content'] as String?,
        toolCalls: json['tool_calls'] != null
            ? (json['tool_calls'] as List<dynamic>)
                .map((t) => ToolCallData.fromJson(t as Map<String, dynamic>))
                .toList()
            : null,
      );
}
