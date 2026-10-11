import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'pyrafull_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            docId TEXT,
            payload TEXT,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  // Add item to offline queue
  static Future<void> addToQueue(String type, String docId, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('offline_queue', {
      'type': type,
      'docId': docId,
      'payload': jsonEncode(payload),
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint("Offline: Added $type for $docId to local queue.");
  }

  // Sync queue to Firestore
  static Future<void> syncOfflineData() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint("Offline: No internet. Sync skipped.");
      return;
    }

    final db = await database;
    final List<Map<String, dynamic>> queue = await db.query('offline_queue');

    if (queue.isEmpty) {
      debugPrint("Offline: Queue is empty. Nothing to sync.");
      return;
    }

    debugPrint("Offline: Syncing ${queue.length} items...");

    for (var item in queue) {
      bool success = false;
      try {
        String type = item['type'];
        String docId = item['docId'];
        Map<String, dynamic> payload = jsonDecode(item['payload']);

        if (type == 'requirement') {
          await FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .collection('files')
              .add(payload);
          success = true;
        } else if (type == 'evidence') {
          await FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .collection('evidence')
              .add(payload);
          success = true;
        } else if (type == 'completion') {
          await FirebaseFirestore.instance
              .collection('inspection_requests')
              .doc(docId)
              .update(payload);
          success = true;
        }

        if (success) {
          await db.delete('offline_queue', where: 'id = ?', whereArgs: [item['id']]);
          debugPrint("Offline: Successfully synced item ${item['id']}");
        }
      } catch (e) {
        debugPrint("Offline: Failed to sync item ${item['id']}: $e");
      }
    }
  }

  static Future<int> getQueueCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM offline_queue'));
    return count ?? 0;
  }
}
