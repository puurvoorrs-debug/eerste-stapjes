import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  UserModel? _currentUserModel;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
    if (userDoc.exists) {
      setState(() {
        _currentUserModel = UserModel.fromDocument(userDoc);
        _nameController.text = _currentUserModel!.displayName;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String photoUrl = _currentUserModel?.photoUrl ?? '';

      if (_imageFile != null) {
        // Correctie: Een unieke bestandsnaam toevoegen om te voldoen aan de Storage Rule.
        final fileName = '${DateTime.now().toIso8601String()}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profile_pictures')
            .child(_currentUser.uid)
            .child(fileName);
        await storageRef.putFile(_imageFile!);
        photoUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).update({
        'displayName': _nameController.text,
        'photoUrl': photoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profiel bijgewerkt!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij het bijwerken van profiel: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accountinstellingen'),
      ),
      body: _currentUserModel == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : (_currentUserModel!.photoUrl.isNotEmpty
                                ? NetworkImage(_currentUserModel!.photoUrl)
                                : null) as ImageProvider?,
                        child: _imageFile == null && _currentUserModel!.photoUrl.isEmpty
                            ? const Icon(Icons.person, size: 60)
                            : null,
                      ),
                    ),
                    TextButton(onPressed: _pickImage, child: const Text('Wijzig profielfoto')),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Accountnaam',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Voer een accountnaam in';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Opslaan'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
