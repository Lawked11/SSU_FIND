import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'firestore_service.dart';
import 'message_page.dart';

class ItemDetailPage extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String description;
  final dynamic dateLost;
  final String documentId;
  final String? publicId;
  final String ownerId;

  const ItemDetailPage({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.dateLost,
    required this.documentId,
    this.publicId,
    required this.ownerId,
  });

  String _formatDetailDate(dynamic timestamp) {
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

    return DateFormat('EEEE, MMMM dd, yyyy\nhh:mm a').format(dateTime);
  }

  Future<void> _openChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You must be logged in to contact the owner'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No owner is associated with this item.'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (currentUser.uid == ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('You can\'t contact yourself!'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    final chatId =
        await FirestoreService.getOrCreateChatId(currentUser.uid, ownerId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagePage(
          initialChatId: chatId,
          peerUserId: ownerId,
          peerItemName: name,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 300,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image,
                            color: Colors.white70, size: 64),
                        Text('Failed to load image',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Item Name',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white70, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Date & Time Lost',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatDetailDate(dateLost),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (ownerId.isEmpty || (currentUser?.uid == ownerId))
                    ? null
                    : () => _openChat(context),
                icon: const Icon(Icons.contact_phone),
                label: const Text('Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
