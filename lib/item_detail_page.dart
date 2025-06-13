import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'constants.dart';
import 'messages_page.dart';
import 'profile_page.dart';

class ItemDetailPage extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String description;
  final dynamic dateLost;
  final String documentId;
  final String? publicId;

  const ItemDetailPage({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.dateLost,
    required this.documentId,
    this.publicId,
  });

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  bool _isOwner = false;
  String? _currentUid;
  bool _isClaimed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkOwnerAndClaimed();
  }

  Future<void> _checkOwnerAndClaimed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final itemDoc = await FirebaseFirestore.instance
          .collection('items')
          .doc(widget.documentId)
          .get();
      final itemData = itemDoc.data();
      if (itemData != null) {
        setState(() {
          _isOwner = itemData['owner'] == user.uid;
          _currentUid = user.uid;
          _isClaimed = itemData['claimed'] == true;
        });
      }
    }
  }

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

  Future<String> _getUsername(String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      return data?['username'] ?? "User";
    }
    return "User";
  }

  Future<void> _goToMessages(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to chat")),
      );
      return;
    }

    final itemDoc = await FirebaseFirestore.instance
        .collection('items')
        .doc(widget.documentId)
        .get();
    if (!itemDoc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item not found")),
      );
      return;
    }
    final itemData = itemDoc.data();
    final ownerId = itemData?['owner'];

    if (ownerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Item owner not found")),
      );
      return;
    }

    final myUid = currentUser.uid;
    final participantIds = [myUid, ownerId]..sort();

    // Try to find existing chat
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('itemId', isEqualTo: widget.documentId)
        .where('participants', arrayContains: myUid)
        .get();

    String? chatId;

    for (var doc in chatQuery.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.length == participantIds.length &&
          participants.toSet().containsAll(participantIds)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId == null) {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').add({
        'itemId': widget.documentId,
        'itemName': widget.name,
        'participants': participantIds,
        'created_at': FieldValue.serverTimestamp(),
      });
      chatId = chatDoc.id;
    }

    // Find the name of the OTHER user (not me)
    String otherUid = (ownerId == myUid)
        ? participantIds.firstWhere((id) => id != myUid, orElse: () => myUid)
        : ownerId;
    String otherUserName = await _getUsername(otherUid);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          chatId: chatId!,
          otherUserName: otherUserName,
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

  Future<void> _itemFound(BuildContext context) async {
    if (_currentUid == null) return;
    setState(() {
      _loading = true;
    });

    final firestore = FirebaseFirestore.instance;
    final claimedData = {
      'image': widget.imageUrl,
      'name': widget.name,
      'dateClaimed': DateTime.now().toIso8601String(),
      'itemId': widget.documentId,
    };

    final userClaimedItemRef = firestore
        .collection('users')
        .doc(_currentUid)
        .collection('claimed_items')
        .doc(widget.documentId);

    final itemRef = firestore.collection('items').doc(widget.documentId);

    final userItemRef = firestore
        .collection('users')
        .doc(_currentUid)
        .collection('items')
        .doc(widget.documentId);

    try {
      // Step 1: Save claimed info
      await userClaimedItemRef.set(claimedData);

      // Step 2: Find all chats for this item
      final chatsQuery = await firestore
          .collection('chats')
          .where('itemId', isEqualTo: widget.documentId)
          .get();

      // Step 3: Delete all chats and their messages for this item
      for (var chatDoc in chatsQuery.docs) {
        // Delete all messages in subcollection
        final messagesSnapshot =
            await chatDoc.reference.collection('messages').get();
        for (var msg in messagesSnapshot.docs) {
          await msg.reference.delete();
        }
        // Delete the chat itself
        await chatDoc.reference.delete();
      }

      // Step 4: Delete the item from global and user subcollection
      await itemRef.delete();
      await userItemRef.delete();

      setState(() {
        _isClaimed = true;
        _loading = false;
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error completing item found: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.name,
          style: const TextStyle(color: Colors.white),
        ),
        actions: _isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmation(context),
                ),
                if (!_isClaimed)
                  IconButton(
                    icon: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.green,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.verified, color: Colors.green),
                    tooltip: 'Item Found',
                    onPressed: _loading ? null : () => _itemFound(context),
                  ),
              ]
            : [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.imageUrl,
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
                    widget.name,
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
                    widget.description,
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
                    _formatDetailDate(widget.dateLost),
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
            if (_isClaimed)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: const Text(
                  'This item has been claimed!',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _goToMessages(context),
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
