import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  bool _receiveNudges = true;
  String _versionString = '';

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVersionInfo();
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .get();
    if (userDoc.exists) {
      setState(() {
        _currentUserModel = UserModel.fromDocument(userDoc);
        _nameController.text = _currentUserModel!.displayName;
        _receiveNudges = _currentUserModel!.receiveNudges;
      });
    }
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _versionString = 'Versie ${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _versionString = 'Versie 2.5.0 (1)';
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .update({
        'displayName': _nameController.text,
        'photoUrl': photoUrl,
        'receiveNudges': _receiveNudges,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(context.tr('Profiel bijgewerkt!', 'Profile updated!'))),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${context.tr('Fout bij het bijwerken van profiel', 'Error updating profile')}: $e')),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Accountinstellingen', 'Account settings')),
      ),
      body: _currentUserModel == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                    : Colors.grey[200]!,
                                width: 1.5,
                              ),
                              image: _imageFile != null
                                  ? DecorationImage(
                                      image: FileImage(_imageFile!),
                                      fit: BoxFit.cover)
                                  : (_currentUserModel!.photoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                              _currentUserModel!.photoUrl),
                                          fit: BoxFit.cover)
                                      : null),
                            ),
                            child: _imageFile == null &&
                                    _currentUserModel!.photoUrl.isEmpty
                                ? Icon(Icons.person,
                                    size: 60, color: Colors.grey[400])
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 3),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.tr('Accountnaam', 'Account name'),
                          style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: context.tr('Jouw naam', 'Your name'),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('Voer een accountnaam in',
                              'Please enter an account name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.tr('Taal', 'Language'),
                          style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    Consumer<LocaleProvider>(
                      builder: (context, localeProvider, child) {
                        return DropdownButtonFormField<String>(
                          initialValue: localeProvider.locale.languageCode,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'nl',
                              child: Text(context.tr('Nederlands', 'Dutch')),
                            ),
                            DropdownMenuItem(
                              value: 'en',
                              child: Text(context.tr('Engels', 'English')),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              localeProvider.setLocale(Locale(val));
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.tr('Thema', 'Theme'),
                          style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return SwitchListTile.adaptive(
                          title: Text(context.tr('Donkere modus', 'Dark mode')),
                          value: themeProvider.isDarkMode,
                          onChanged: (val) {
                            themeProvider.toggleTheme(val);
                          },
                          secondary: Icon(
                            themeProvider.isDarkMode
                                ? Icons.dark_mode
                                : Icons.light_mode,
                            color: theme.primaryColor,
                          ),
                          contentPadding: EdgeInsets.zero,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(context.tr('Notificaties', 'Notifications'),
                          style: theme.textTheme.titleMedium),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: Text(context.tr('Ontvang \'por\' herinneringen', 'Receive poke reminders')),
                      value: _receiveNudges,
                      onChanged: (val) {
                        setState(() {
                          _receiveNudges = val;
                        });
                      },
                      secondary: Icon(
                        Icons.notifications_active,
                        color: theme.primaryColor,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 40),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: Text(context.tr('Opslaan', 'Save'),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    if (_versionString.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          _versionString,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
