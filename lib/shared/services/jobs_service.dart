import 'package:cloud_firestore/cloud_firestore.dart';

class JobsService {
  final _db = FirebaseFirestore.instance;

  // Stream temps réel de tous les jobs
  Stream<QuerySnapshot> getJobs() {
    return _db
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Un seul job
  Future<DocumentSnapshot> getJob(String jobId) {
    return _db.collection('jobs').doc(jobId).get();
  }

  // Créer un job (employeur)
  Future<void> createJob(Map<String, dynamic> data) {
    return _db.collection('jobs').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}