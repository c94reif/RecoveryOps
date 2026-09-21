import 'package:flutter_test/flutter_test.dart';
import 'package:le_sdk/le_sdk.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ChatCompletionMessage serialization
  // ---------------------------------------------------------------------------

  group('ChatCompletionMessage', () {
    test('round-trip basic message', () {
      const msg = ChatCompletionMessage(role: 'user', content: 'Hello');
      final json = msg.toJson();
      expect(json['role'], 'user');
      expect(json['content'], 'Hello');
      expect(json.containsKey('tool_call_id'), isFalse);
      expect(json.containsKey('tool_calls'), isFalse);

      final restored = ChatCompletionMessage.fromJson(json);
      expect(restored.role, 'user');
      expect(restored.content, 'Hello');
      expect(restored.toolCallId, isNull);
      expect(restored.toolCalls, isNull);
    });

    test('round-trip message with tool_call_id', () {
      const msg = ChatCompletionMessage(
        role: 'tool',
        content: 'result',
        toolCallId: 'call_abc',
      );
      final json = msg.toJson();
      expect(json['tool_call_id'], 'call_abc');

      final restored = ChatCompletionMessage.fromJson(json);
      expect(restored.toolCallId, 'call_abc');
    });

    test('round-trip message with tool_calls', () {
      final msg = ChatCompletionMessage(
        role: 'assistant',
        toolCalls: [
          ToolCallData(
            index: 0,
            id: 'call_1',
            type: 'function',
            function: const ToolCallFunction(
              name: 'get_weather',
              arguments: '{"location":"NYC"}',
            ),
          ),
        ],
      );
      final json = msg.toJson();
      expect(json.containsKey('content'), isFalse);
      expect((json['tool_calls'] as List).length, 1);

      final restored = ChatCompletionMessage.fromJson(json);
      expect(restored.toolCalls, isNotNull);
      expect(restored.toolCalls!.length, 1);
      expect(restored.toolCalls!.first.id, 'call_1');
      expect(restored.toolCalls!.first.function!.name, 'get_weather');
      expect(restored.toolCalls!.first.function!.arguments, '{"location":"NYC"}');
    });

    test('optional fields absent when null', () {
      const msg = ChatCompletionMessage(role: 'system');
      final json = msg.toJson();
      expect(json.containsKey('content'), isFalse);
      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('tool_call_id'), isFalse);
      expect(json.containsKey('tool_calls'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ToolCallData / ToolCallFunction serialization
  // ---------------------------------------------------------------------------

  group('ToolCallData', () {
    test('round-trip full tool call', () {
      final tc = ToolCallData(
        index: 1,
        id: 'call_x',
        type: 'function',
        function: const ToolCallFunction(name: 'foo', arguments: '{}'),
      );
      final json = tc.toJson();
      final restored = ToolCallData.fromJson(json);
      expect(restored.index, 1);
      expect(restored.id, 'call_x');
      expect(restored.type, 'function');
      expect(restored.function!.name, 'foo');
      expect(restored.function!.arguments, '{}');
    });

    test('optional fields absent when null', () {
      const tc = ToolCallData();
      final json = tc.toJson();
      expect(json.containsKey('index'), isFalse);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('type'), isFalse);
      expect(json.containsKey('function'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // ChatCompletionRequest serialization
  // ---------------------------------------------------------------------------

  group('ChatCompletionRequest', () {
    test('round-trip with defaults', () {
      final req = ChatCompletionRequest(
        messages: [const ChatCompletionMessage(role: 'user', content: 'Hi')],
      );
      final json = req.toJson();
      expect(json['stream'], isFalse);
      expect(json['host_tools'], isTrue);

      final restored = ChatCompletionRequest.fromJson(json);
      expect(restored.stream, isFalse);
      expect(restored.hostTools, isTrue);
      expect(restored.messages.length, 1);
      expect(restored.messages.first.content, 'Hi');
    });

    test('default stream=false', () {
      final req = ChatCompletionRequest(messages: []);
      expect(req.stream, isFalse);
    });

    test('default hostTools=true', () {
      final req = ChatCompletionRequest(messages: []);
      expect(req.hostTools, isTrue);
    });

    test('explicit stream=true round-trips', () {
      final req = ChatCompletionRequest(messages: [], stream: true, hostTools: false);
      final json = req.toJson();
      expect(json['stream'], isTrue);
      expect(json['host_tools'], isFalse);

      final restored = ChatCompletionRequest.fromJson(json);
      expect(restored.stream, isTrue);
      expect(restored.hostTools, isFalse);
    });

    test('fromJson falls back to defaults when keys absent', () {
      final json = <String, dynamic>{
        'messages': <dynamic>[],
      };
      final req = ChatCompletionRequest.fromJson(json);
      expect(req.stream, isFalse);
      expect(req.hostTools, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // ChatCompletion serialization
  // ---------------------------------------------------------------------------

  group('ChatCompletion', () {
    test('round-trip', () {
      final completion = ChatCompletion(
        id: 'cmpl-123',
        choices: [
          ChatChoice(
            index: 0,
            message: const ChatCompletionMessage(role: 'assistant', content: 'Hello!'),
            finishReason: 'stop',
          ),
        ],
      );
      final json = completion.toJson();
      expect(json['id'], 'cmpl-123');
      expect(json['object'], 'chat.completion');

      final restored = ChatCompletion.fromJson(json);
      expect(restored.id, 'cmpl-123');
      expect(restored.object, 'chat.completion');
      expect(restored.choices.length, 1);
      expect(restored.choices.first.index, 0);
      expect(restored.choices.first.message.content, 'Hello!');
      expect(restored.choices.first.finishReason, 'stop');
    });

    test('ChatChoice without finishReason omits key', () {
      final choice = ChatChoice(
        index: 0,
        message: const ChatCompletionMessage(role: 'assistant'),
      );
      final json = choice.toJson();
      expect(json.containsKey('finish_reason'), isFalse);

      final restored = ChatChoice.fromJson(json);
      expect(restored.finishReason, isNull);
    });

    test('default object value', () {
      final c = ChatCompletion(id: 'x', choices: []);
      expect(c.object, 'chat.completion');
    });
  });

  // ---------------------------------------------------------------------------
  // ChatCompletionChunk serialization
  // ---------------------------------------------------------------------------

  group('ChatCompletionChunk', () {
    test('round-trip content chunk', () {
      final chunk = ChatCompletionChunk(
        id: 'chunk-1',
        choices: [
          ChatChunkChoice(
            index: 0,
            delta: const ChatCompletionDelta(content: 'Hello'),
          ),
        ],
      );
      final json = chunk.toJson();
      expect(json['id'], 'chunk-1');
      expect(json['object'], 'chat.completion.chunk');

      final restored = ChatCompletionChunk.fromJson(json);
      expect(restored.id, 'chunk-1');
      expect(restored.object, 'chat.completion.chunk');
      expect(restored.choices.first.delta.content, 'Hello');
      expect(restored.choices.first.finishReason, isNull);
    });

    test('finish_reason present in final chunk', () {
      final chunk = ChatCompletionChunk(
        id: 'chunk-end',
        choices: [
          ChatChunkChoice(
            index: 0,
            delta: const ChatCompletionDelta(),
            finishReason: 'stop',
          ),
        ],
      );
      final json = chunk.toJson();
      final choices = json['choices'] as List;
      expect(choices.first['finish_reason'], 'stop');

      final restored = ChatCompletionChunk.fromJson(json);
      expect(restored.choices.first.finishReason, 'stop');
    });

    test('finish_reason absent from non-final chunk', () {
      final chunk = ChatCompletionChunk(
        id: 'chunk-mid',
        choices: [
          ChatChunkChoice(
            index: 0,
            delta: const ChatCompletionDelta(content: 'foo'),
          ),
        ],
      );
      final json = chunk.toJson();
      final choices = json['choices'] as List;
      expect((choices.first as Map).containsKey('finish_reason'), isFalse);
    });

    test('delta with tool_calls round-trips', () {
      final chunk = ChatCompletionChunk(
        id: 'chunk-tc',
        choices: [
          ChatChunkChoice(
            index: 0,
            delta: ChatCompletionDelta(
              role: 'assistant',
              toolCalls: [
                ToolCallData(
                  index: 0,
                  id: 'call_y',
                  type: 'function',
                  function: const ToolCallFunction(name: 'do_thing', arguments: ''),
                ),
              ],
            ),
          ),
        ],
      );
      final restored = ChatCompletionChunk.fromJson(chunk.toJson());
      final delta = restored.choices.first.delta;
      expect(delta.role, 'assistant');
      expect(delta.toolCalls, isNotNull);
      expect(delta.toolCalls!.first.id, 'call_y');
    });

    test('default object value', () {
      final c = ChatCompletionChunk(id: 'x', choices: []);
      expect(c.object, 'chat.completion.chunk');
    });
  });

  // ---------------------------------------------------------------------------
  // StubAiService via StubExtensionContext
  // ---------------------------------------------------------------------------

  group('StubAiService', () {
    late StubExtensionContext ctx;

    setUp(() {
      ctx = StubExtensionContext();
    });

    test('ai accessor is accessible', () {
      expect(ctx.ai, isNotNull);
    });

    test('clearHistory completes without error', () async {
      await expectLater(ctx.ai.clearHistory(), completes);
    });

    test('create returns canned response with stop finish reason', () async {
      final request = ChatCompletionRequest(
        messages: [const ChatCompletionMessage(role: 'user', content: 'test')],
      );
      final completion = await ctx.ai.chat.completions.create(request);
      expect(completion.id, isNotEmpty);
      expect(completion.choices.length, greaterThan(0));
      expect(completion.choices.first.message.role, 'assistant');
      expect(completion.choices.first.message.content, isNotEmpty);
      expect(completion.choices.first.finishReason, 'stop');
    });

    test('create returns a ChatCompletion', () async {
      final request = ChatCompletionRequest(messages: []);
      final result = await ctx.ai.chat.completions.create(request);
      expect(result, isA<ChatCompletion>());
    });

    test('createStream emits role chunk, content chunks, and stop chunk', () async {
      final request = ChatCompletionRequest(messages: []);
      final chunks = await ctx.ai.chat.completions.createStream(request).toList();

      expect(chunks.isNotEmpty, isTrue);

      // First chunk carries role
      final firstChunk = chunks.first;
      expect(firstChunk.choices.first.delta.role, 'assistant');

      // Last chunk has finishReason 'stop'
      final lastChunk = chunks.last;
      expect(lastChunk.choices.first.finishReason, 'stop');

      // Middle chunks carry content
      final contentChunks = chunks.skip(1).take(chunks.length - 2);
      for (final chunk in contentChunks) {
        expect(chunk.choices.first.delta.content, isNotNull);
        expect(chunk.choices.first.delta.content, isNotEmpty);
      }
    });

    test('createStream uses consistent id across all chunks', () async {
      final request = ChatCompletionRequest(messages: []);
      final chunks = await ctx.ai.chat.completions.createStream(request).toList();
      final firstId = chunks.first.id;
      for (final chunk in chunks) {
        expect(chunk.id, firstId);
      }
    });

    test('createStream final chunk has empty delta with stop', () async {
      final request = ChatCompletionRequest(messages: []);
      final chunks = await ctx.ai.chat.completions.createStream(request).toList();
      final lastChunk = chunks.last;
      expect(lastChunk.choices.first.finishReason, 'stop');
      expect(lastChunk.choices.first.delta.content, isNull);
      expect(lastChunk.choices.first.delta.role, isNull);
    });
  });
}
