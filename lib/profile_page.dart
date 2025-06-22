import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _profileImageUrl = '';

  List<Map<String, dynamic>> _claimedItems = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadClaimedItems();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      final user = _auth.currentUser;
      if (user != null) {
        _email = user.email ?? '';

        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          _firstName = data['firstName'] ?? '';
          _lastName = data['lastName'] ?? '';
          _profileImageUrl = data['profileImageUrl'] ?? '';
        } else {
          await _createUserDocument(user);
        }

        _firstNameController.text = _firstName;
        _lastNameController.text = _lastName;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadClaimedItems() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('claimed_items')
        .get();
    setState(() {
      _claimedItems = snapshot.docs
          .map((doc) => doc.data())
          .toList()
          .cast<Map<String, dynamic>>();
    });
  }

  Future<void> _createUserDocument(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'firstName': user.displayName?.split(' ').first ?? '',
      'lastName': (() {
        final name = user.displayName;
        if (name == null) return '';
        final parts = name.split(' ');
        return parts.length > 1 ? parts.last : '';
      })(),
      'profileImageUrl': user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name cannot be empty')),
      );
      return;
    }

    try {
      setState(() => _isSaving = true);

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        _firstName = _firstNameController.text.trim();
        _lastName = _lastNameController.text.trim();

        setState(() => _isEditing = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadClaimedItems(); // refresh claimed items after save
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    _firstNameController.text = _firstName;
    _lastNameController.text = _lastName;
    setState(() => _isEditing = false);
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;

      // Use pushNamedAndRemoveUntil to prevent going back to profile with system back button
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileHeader(double screenWidth) {
    final isWide = screenWidth > 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: isWide ? 80 : 60,
          backgroundColor: Colors.white.withOpacity(0.2),
          backgroundImage: _profileImageUrl.isNotEmpty
              ? NetworkImage(_profileImageUrl)
              : null,
          child: _profileImageUrl.isEmpty
              ? Icon(
                  Icons.person,
                  size: isWide ? 80 : 60,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                '${_firstName.isNotEmpty ? _firstName : 'First Name'} ${_lastName.isNotEmpty ? _lastName : 'Last Name'}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isWide ? 32 : 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _isEditing = true);
              },
              child: !_isEditing
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B2A92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Edit Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _email,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm(double screenWidth) {
    if (!_isEditing) return const SizedBox.shrink();

    final isWide = screenWidth > 600;
    return Container(
      margin: EdgeInsets.all(isWide ? 32 : 16),
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0B2A92), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Profile Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: isWide ? 22 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'First Name',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _firstNameController,
            enabled: _isEditing,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your first name',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0B2A92)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Last Name',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lastNameController,
            enabled: _isEditing,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your last name',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF0B2A92)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Email',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              _email,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : _cancelEdit,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaimedItemsList(double screenWidth) {
    if (_claimedItems.isEmpty) return const SizedBox.shrink();

    final isWide = screenWidth > 600;
    final imgSize = isWide ? 80.0 : 64.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32.0 : 16.0, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Claimed Items",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: isWide ? 22 : 18,
              ),
            ),
          ),
        ),
        ..._claimedItems.map((item) {
          return Container(
            width: double.infinity,
            margin:
                EdgeInsets.symmetric(horizontal: isWide ? 32 : 16, vertical: 8),
            padding: EdgeInsets.all(isWide ? 18 : 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                item['image'] != null && item['image'] != ''
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['image'],
                          width: imgSize,
                          height: imgSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: imgSize,
                            height: imgSize,
                            color: Colors.green.withOpacity(0.12),
                            child: Icon(Icons.inventory,
                                color: Colors.green, size: imgSize / 2),
                          ),
                        ),
                      )
                    : Container(
                        width: imgSize,
                        height: imgSize,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory,
                            color: Colors.green, size: imgSize / 2),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isWide ? 18 : 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['dateClaimed'] != null
                            ? DateFormat('MMM dd, yyyy - hh:mm a')
                                .format(DateTime.parse(item['dateClaimed']))
                            : '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Item Retrieved / Claimed",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: isWide ? 15 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPageWidth = screenWidth > 800 ? 600.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFF0B2A92),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                child: Container(
                  width: maxPageWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildProfileHeader(screenWidth),
                      const SizedBox(height: 20),
                      _buildClaimedItemsList(screenWidth),
                      const SizedBox(height: 32),
                      _buildProfileForm(screenWidth),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
