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
    required String ownerId,
  }) async {
    await FirebaseFirestore.instance.collection('items').add({
      'image': imageUrl,
      'name': name,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'date_lost': DateTime.now().toIso8601String(),
      'owner_id': ownerId,
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

  // Messaging
  static Future<String> getOrCreateChatId(String userA, String userB) async {
    final users = [userA, userB]..sort();
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('users', isEqualTo: users)
        .limit(1)
        .get();

    if (chatQuery.docs.isNotEmpty) {
      return chatQuery.docs.first.id;
    } else {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
        'users': users,
        'created_at': FieldValue.serverTimestamp(),
      });
      return chatDoc.id;
    }
  }

  static Stream<QuerySnapshot> getUserChatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: userId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots();
  }

  static Future<void> sendMessage({
    required String chatId,
    required String fromUserId,
    required String toUserId,
    required String text,
  }) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'from': fromUserId,
      'to': toUserId,
      'text': text,
      'sent_at': FieldValue.serverTimestamp(),
    });
  }
}
