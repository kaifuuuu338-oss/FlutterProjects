import 'package:flutter/material.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/services/sync_service.dart';

class SyncDebugScreen extends StatefulWidget {
  const SyncDebugScreen({super.key});

  @override
  State<SyncDebugScreen> createState() => _SyncDebugScreenState();
}

class _SyncDebugScreenState extends State<SyncDebugScreen> {
  final LocalDBService _localDB = LocalDBService();
  final SyncService _syncService = SyncService(LocalDBService());
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _addLog(String message) {
    debugPrint(message);
    setState(() {
      _logs += '$message\n';
    });
  }

  Future<void> _checkStatus() async {
    _logs = '';
    _addLog('🔍 CHECK LOCAL DATABASE STATUS\n');

    await _localDB.initialize();
    await _localDB.logDatabaseStats();

    final allChildren = _localDB.getAllChildren();
    _addLog('\n📋 ALL CHILDREN: ${allChildren.length}');
    for (var child in allChildren) {
      _addLog('  - ${child.childId}: ${child.childName}');
    }

    final unsyncedChildren = _localDB.getUnsyncedChildren();
    _addLog('\n⏳ UNSYNCED (pending): ${unsyncedChildren.length}');
    for (var child in unsyncedChildren) {
      _addLog('  - ${child.childId}: ${child.childName}');
    }
  }

  Future<void> _manualSync() async {
    _addLog('\n🔄 MANUAL SYNC TRIGGERED\n');
    await _syncService.syncPendingChildren();
    _addLog('\n✅ SYNC COMPLETE');
    _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Debug'),
        backgroundColor: Colors.red,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _checkStatus,
                  child: const Text('Check Status'),
                ),
                ElevatedButton(
                  onPressed: _manualSync,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Manual Sync'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _logs,
                    style: const TextStyle(
                      color: Colors.green,
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
