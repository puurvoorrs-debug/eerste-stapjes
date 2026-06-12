import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/sketchy_components.dart';

class CreateProfileScreen extends StatefulWidget {
  final Profile? profile;

  const CreateProfileScreen({super.key, this.profile});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TextEditingController _nameController;
  late DateTime? _dateOfBirth;
  File? _profileImage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile?.name ?? '');
    if (widget.profile != null) {
      _dateOfBirth = widget.profile!.dateOfBirth;
      _profileImageUrl = widget.profile!.profileImageUrl;
    } else {
      _dateOfBirth = null;
      _profileImage = null;
      _profileImageUrl = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _profileImageUrl =
            null; // Clear existing image url if new image is picked
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              onSurface: theme.colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr(
                'U moet ingelogd zijn om een profiel op te slaan',
                'You must be logged in to save a profile'))));
        return;
      }

      if (_dateOfBirth != null) {
        final profileData = Profile(
          id: widget.profile?.id,
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth!,
          profileImage: _profileImage,
          profileImageUrl: _profileImageUrl,
          // Assign owner and preserve follower/share info on update
          ownerId: widget.profile?.ownerId ?? user.uid,
          followers: widget.profile?.followers ?? [],
          shareCode: widget.profile?.shareCode,
        );

        final provider = Provider.of<ProfileProvider>(context, listen: false);
        try {
          if (widget.profile != null) {
            await provider.updateProfile(widget.profile!.id!, profileData);
          } else {
            // The provider's addProfile method will set the final ownerId and generate the shareCode
            await provider.addProfile(profileData);
          }
          if (mounted) {
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '${context.tr('Fout bij opslaan', 'Error saving')}: $e')));
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.tr('Kies alsjeblieft een geboortedatum',
                  'Please choose a date of birth'))),
        );
      }
    }
  }

  void _deleteProfile() async {
    final theme = Theme.of(context);
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFFEFEBE9).withOpacity(0.15)
                  : Colors.grey[300]!,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Profiel Verwijderen?', 'Delete Profile?'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  'Weet je zeker dat je dit profiel wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.',
                  'Are you sure you want to delete this profile? This action cannot be undone.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: SketchyButton(
                      label: context.tr('Annuleren', 'Cancel'),
                      fillColor: Colors.white,
                      onPressed: () => Navigator.of(context).pop(false),
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SketchyButton(
                      label: context.tr('Verwijderen', 'Delete'),
                      fillColor: Colors.red,
                      textColor: Colors.white,
                      borderColor: Colors.red,
                      onPressed: () => Navigator.of(context).pop(true),
                      height: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && widget.profile != null) {
      try {
        await Provider.of<ProfileProvider>(context, listen: false)
            .deleteProfile(widget.profile!.id!);
        if (mounted) {
          // Pop twice to get back to the profile selection screen
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${context.tr('Fout bij verwijderen van profiel', 'Error deleting profile')}: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile != null
            ? context.tr('Profiel Bewerken', 'Edit Profile')
            : context.tr('Nieuw Profiel', 'New Profile')),
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.all(6.0),
                child: SketchyBackButton(
                  onPressed: () => Navigator.maybePop(context),
                ),
              )
            : null,
        actions: [
          if (widget.profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
              child: SketchyIconButton(
                icon: Icons.delete_outline,
                color: Colors.red,
                borderColor: Colors.red,
                size: 40.0,
                onPressed: _deleteProfile,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                : Colors.grey[200]!,
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 120,
                            height: 120,
                            color: theme.cardTheme.color,
                            child: _profileImage != null
                                ? Image.file(_profileImage!, fit: BoxFit.cover)
                                : _profileImageUrl != null
                                    ? Image.network(_profileImageUrl!, fit: BoxFit.cover)
                                    : Icon(Icons.person,
                                        size: 60, color: Colors.grey[400]),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primaryColor,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2.0,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.camera_alt,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SketchyTextField(
                controller: _nameController,
                labelText: context.tr('Naam', 'Name'),
                hintText: context.tr('Bijv. Sophie', 'e.g. Sophie'),
                validator: (value) => value!.isEmpty
                    ? context.tr('Voer een naam in', 'Please enter a name')
                    : null,
              ),
              const SizedBox(height: 24),
              Text(context.tr('Geboortedatum', 'Date of birth'),
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFFEFEBE9).withOpacity(0.35)
                          : const Color(0xFF2D2B2A).withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? context.tr(
                            'Kies Geboortedatum', 'Choose Date of Birth')
                        : DateFormat(
                                'dd MMMM yyyy', context.tr('nl_NL', 'en_US'))
                            .format(_dateOfBirth!),
                    style: TextStyle(
                      fontSize: 16,
                      color: _dateOfBirth == null
                          ? Colors.grey[500]
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SketchyButton(
                onPressed: _saveProfile,
                label: context.tr('Profiel Opslaan', 'Save Profile'),
                fillColor: theme.primaryColor,
                textColor: Colors.white,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
