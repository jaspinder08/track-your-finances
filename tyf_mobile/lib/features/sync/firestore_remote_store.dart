import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'sync_engine.dart';

/// Stores rows at `users/{uid}/{collection}/{id}`, each stamped with the
/// server's write time in `server_updated_at` (used to pull only changes).
class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  static const _serverTime = 'server_updated_at';

  /// Firestore allows 500 writes per batch.
  static const _batchSize = 400;

  /// Offline, Firestore queues writes and the commit never completes, so
  /// give up and leave the rows pending for the next try.
  static const _timeout = Duration(seconds: 20);

  @override
  String? get uid {
    final u = _auth.currentUser;
    return u == null || u.isAnonymous ? null : u.uid;
  }

  CollectionReference<Map<String, dynamic>> _col(String c) =>
      _db.collection('users').doc(uid).collection(c);

  @override
  Future<List<RemoteRow>> pull(String collection, DateTime? since) async {
    Query<Map<String, dynamic>> q = _col(collection);
    if (since != null) {
      q = q.where(_serverTime, isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await q
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    return [
      for (final d in snap.docs)
        if (d.data()[_serverTime] case final Timestamp t)
          RemoteRow(Map.of(d.data())..remove(_serverTime), t.toDate()),
    ];
  }

  @override
  Future<void> push(String collection, List<Map<String, Object?>> rows) async {
    final col = _col(collection);
    for (var i = 0; i < rows.length; i += _batchSize) {
      final batch = _db.batch();
      for (final r in rows.skip(i).take(_batchSize)) {
        batch.set(col.doc(r['id'] as String), {
          ...r,
          _serverTime: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit().timeout(_timeout);
    }
  }
}
