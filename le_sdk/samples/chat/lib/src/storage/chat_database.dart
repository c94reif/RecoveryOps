import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/peer.dart';
import '../models/message.dart';

/// SQLite database for chat persistence.
class ChatDatabase {
  static const _dbName = 'lattice_chat.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE config (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE peers (
        device_id TEXT PRIMARY KEY,
        callsign TEXT NOT NULL,
        ip TEXT NOT NULL,
        tcp_port INTEGER NOT NULL,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        is_online INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        from_device_id TEXT NOT NULL,
        from_callsign TEXT,
        type TEXT NOT NULL,
        body TEXT,
        audio_path TEXT,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'sent',
        is_read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_messages_conv_ts ON messages (conversation_id, timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_messages_read ON messages (is_read)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE messages ADD COLUMN from_callsign TEXT');
    }
  }

  // --- Config ---

  Future<String?> getConfig(String key) async {
    final db = await database;
    final rows = await db.query('config', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setConfig(String key, String value) async {
    final db = await database;
    await db.insert('config', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Peers ---

  Future<void> upsertPeer(Peer peer) async {
    final db = await database;
    await db.insert('peers', peer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Peer>> getAllPeers() async {
    final db = await database;
    final rows = await db.query('peers', orderBy: 'last_seen DESC');
    return rows.map(Peer.fromMap).toList();
  }

  Future<Peer?> getPeer(String deviceId) async {
    final db = await database;
    final rows =
        await db.query('peers', where: 'device_id = ?', whereArgs: [deviceId]);
    if (rows.isEmpty) return null;
    return Peer.fromMap(rows.first);
  }

  Future<void> markPeerOffline(String deviceId) async {
    final db = await database;
    await db.update('peers', {'is_online': 0},
        where: 'device_id = ?', whereArgs: [deviceId]);
  }

  Future<void> markAllPeersOffline() async {
    final db = await database;
    await db.update('peers', {'is_online': 0});
  }

  // --- Messages ---

  Future<void> insertMessage(Message msg) async {
    final db = await database;
    await db.insert('messages', msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateMessageStatus(String id, MessageStatus status) async {
    final db = await database;
    await db.update('messages', {'status': status.name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Message>> getMessages(String conversationId,
      {int limit = 100, int offset = 0}) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Message.fromMap).toList().reversed.toList();
  }

  Future<Message?> getLastMessage(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Message.fromMap(rows.first);
  }

  Future<int> getUnreadCount(String conversationId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE conversation_id = ? AND is_read = 0',
      [conversationId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<int> getTotalUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE is_read = 0',
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<void> markConversationRead(String conversationId) async {
    final db = await database;
    await db.update('messages', {'is_read': 1},
        where: 'conversation_id = ? AND is_read = 0',
        whereArgs: [conversationId]);
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await database;
    await db.delete('messages',
        where: 'conversation_id = ?', whereArgs: [conversationId]);
  }

  Future<void> deleteAllMessages() async {
    final db = await database;
    await db.delete('messages');
  }

  /// Get all conversations with their last message and unread count.
  Future<List<Map<String, dynamic>>> getConversationSummaries() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT m.conversation_id,
             m.body AS last_body,
             m.from_callsign AS last_from,
             m.timestamp AS last_ts,
             (SELECT COUNT(*) FROM messages u
              WHERE u.conversation_id = m.conversation_id AND u.is_read = 0) AS unread,
             (SELECT COUNT(*) FROM messages s
              WHERE s.conversation_id = m.conversation_id AND s.from_device_id = 'system') AS has_system_msg
      FROM messages m
      INNER JOIN (
        SELECT conversation_id, MAX(timestamp) AS max_ts
        FROM messages GROUP BY conversation_id
      ) g ON m.conversation_id = g.conversation_id AND m.timestamp = g.max_ts
      ORDER BY m.timestamp DESC
    ''');
    return rows;
  }

  /// Get unread messages across all conversations.
  Future<List<Message>> getUnreadMessages({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'is_read = 0',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(Message.fromMap).toList();
  }

  // --- Cleanup ---

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
