import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  static Stream<QuerySnapshot> getItemsStream() {
    return FirebaseFirestore.instance
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Future<void> addItem({
    required String imageUrl,
    required String name,
    required String description,
  }) async {
    await FirebaseFirestore.instance.collection('items').add({
      'image': imageUrl,
      'name': name,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'date_lost': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteItem(String docId) async {
    await FirebaseFirestore.instance.collection('items').doc(docId).delete();
  }

  static String formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Invalid date';
      }
    } else {
      return 'Unknown date';
    }

    return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
  }
}
