import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'profile_selection_screen.dart';
import '../providers/locale_provider.dart';
import '../widgets/sketchy_components.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Vul de naam in met de Google-displaynaam als die bestaat
    if (_currentUser?.displayName != null) {
      _nameController.text = _currentUser!.displayName!;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
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
      String photoUrl = _currentUser.photoURL ?? '';

      // Als de gebruiker een nieuwe afbeelding heeft gekozen, upload deze dan
      if (_imageFile != null) {
        final fileName = '${DateTime.now().toIso8601String()}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profile_pictures')
            .child(_currentUser.uid)
            .child(fileName);
        await storageRef.putFile(_imageFile!);
        photoUrl = await storageRef.getDownloadURL();
      }

      // Sla de gebruikersinformatie op in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({
        'uid': _currentUser.uid,
        'displayName': _nameController.text,
        'photoUrl': photoUrl,
        'language': Provider.of<LocaleProvider>(context, listen: false)
            .locale
            .languageCode,
      });

      // Navigeer naar het volgende scherm
      if (mounted) {
        Navigator.of(context).pushReplacement(
          SketchyPageRoute(
              page: const ProfileSelectionScreen()),
        );
      }
    } catch (e) {
      // Toon een foutmelding
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${context.tr('Fout bij het opslaan van profiel', 'Error saving profile')}: $e')),
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
        title: Text(context.tr('Maak je account aan', 'Create your account')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_currentUser?.photoURL != null
                            ? NetworkImage(_currentUser!.photoURL!)
                            : null) as ImageProvider?,
                    child: _imageFile == null && _currentUser?.photoURL == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _pickImage,
                    child: Text(context.tr(
                        'Kies een profielfoto', 'Choose a profile picture'))),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: context.tr('Accountnaam', 'Account name'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.tr('Voer een accountnaam in',
                          'Please enter an account name');
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
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                    ),
                    child: Text(
                        context.tr('Opslaan en doorgaan', 'Save and continue')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
