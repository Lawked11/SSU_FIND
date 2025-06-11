import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagePage extends StatefulWidget {
  final String? initialChatId;
  final String? peerUserId;
  final String? peerItemName;

  const MessagePage(
      {Key? key, this.initialChatId, this.peerUserId, this.peerItemName})
      : super(key: key);

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  String? currentChatId;
  String? peerUserId;
  String? peerItemName;
  final TextEditingController _msgController = TextEditingController();
  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    currentChatId = widget.initialChatId;
    peerUserId = widget.peerUserId;
    peerItemName = widget.peerItemName;
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty ||
        currentUser == null ||
        currentChatId == null ||
        peerUserId == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(currentChatId!)
        .collection('messages')
        .add({
      'from': currentUser!.uid,
      'to': peerUserId!,
      'text': text,
      'sent_at': FieldValue.serverTimestamp(),
    });
    _msgController.clear();
  }

  Widget _buildChatList() {
    if (currentUser == null)
      return const Center(
          child: Text('Not logged in', style: TextStyle(color: Colors.white)));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: currentUser!.uid)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        final chats = snapshot.data?.docs ?? [];
        if (chats.isEmpty) {
          return const Center(
            child: Text(
              'No conversations yet',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) =>
              const Divider(color: Colors.white12, height: 1),
          itemCount: chats.length,
          itemBuilder: (context, i) {
            final chat = chats[i];
            final users = List<String>.from(chat['users'] ?? []);
            final peerId = users.firstWhere((id) => id != currentUser!.uid,
                orElse: () => "Unknown");
            return ListTile(
              leading: const Icon(Icons.person, color: Colors.white),
              title: Text('Chat with: $peerId',
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text('Tap to open chat',
                  style: const TextStyle(color: Colors.white54)),
              onTap: () {
                setState(() {
                  currentChatId = chat.id;
                  peerUserId = peerId;
                  peerItemName = null;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessages() {
    if (currentChatId == null || currentUser == null || peerUserId == null)
      return _buildChatList();
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .doc(currentChatId!)
                .collection('messages')
                .orderBy('sent_at')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }
              final messages = snapshot.data?.docs ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text('No messages yet. Say hello!',
                      style: TextStyle(color: Colors.white70)),
                );
              }
              return ListView.builder(
                reverse: false,
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final isMe = msg['from'] == currentUser!.uid;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.blue[300] : Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text'],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: const Color(0xFF0B2A92),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showChat = currentChatId != null && peerUserId != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A92),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2A92),
        title: Text(
          showChat
              ? 'Chat with: $peerUserId${peerItemName != null ? " ($peerItemName)" : ""}'
              : 'Messages',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: showChat
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    currentChatId = null;
                    peerUserId = null;
                    peerItemName = null;
                  });
                },
              )
            : null,
      ),
      body: _buildMessages(),
    );
  }
}
