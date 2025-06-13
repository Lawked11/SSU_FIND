import 'package:flutter/material.dart';

class MessagesPage extends StatefulWidget {
  final String? initialChatName;
  final String? initialMessage;

  const MessagesPage({Key? key, this.initialChatName, this.initialMessage})
      : super(key: key);

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final List<Map<String, String>> _chats = [];

  @override
  void initState() {
    super.initState();
    // If an initial chat is provided, add it.
    if (widget.initialChatName != null && widget.initialMessage != null) {
      _chats.add({
        'name': widget.initialChatName!,
        'message': widget.initialMessage!,
      });
    }
  }

  void _addNewChat(String name, String message) {
    setState(() {
      _chats.add({'name': name, 'message': message});
    });
  }

  void _showNewChatDialog() {
    final nameController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Chat Name'),
            ),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'First Message'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                _addNewChat(
                    nameController.text.trim(), messageController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A92),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2A92),
        title: const Text('Messages', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showNewChatDialog,
          ),
        ],
      ),
      body: _chats.isEmpty
          ? const Center(
              child: Text(
                'No messages yet!',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                return Card(
                  color: Colors.white.withOpacity(0.05),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(chat['name'] ?? '',
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(chat['message'] ?? '',
                        style: const TextStyle(color: Colors.white70)),
                    leading: const Icon(Icons.chat, color: Colors.white),
                  ),
                );
              },
            ),
    );
  }
}
