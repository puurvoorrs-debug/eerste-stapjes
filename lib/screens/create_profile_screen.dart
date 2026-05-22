import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';

class CreateProfileScreen extends StatefulWidget {
  final Profile? profile;

  const CreateProfileScreen({super.key, this.profile});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String _name;
  late DateTime? _dateOfBirth;
  File? _profileImage;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _name = widget.profile!.name;
      _dateOfBirth = widget.profile!.dateOfBirth;
      _profileImageUrl = widget.profile!.profileImageUrl;
    } else {
      _name = '';
      _dateOfBirth = null;
      _profileImage = null;
      _profileImageUrl = null;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
        _profileImageUrl = null; // Clear existing image url if new image is picked
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
      _formKey.currentState!.save();

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('U moet ingelogd zijn om een profiel op te slaan', 'You must be logged in to save a profile'))));
        return;
      }

      if (_dateOfBirth != null) {
        final profileData = Profile(
          id: widget.profile?.id,
          name: _name,
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
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Fout bij opslaan', 'Error saving')}: $e')));
          }          
        }
       
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Kies alsjeblieft een geboortedatum', 'Please choose a date of birth'))),
        );
      }
    }
  }

  void _deleteProfile() async {
    final theme = Theme.of(context);
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Profiel Verwijderen?', 'Delete Profile?')),
        content: Text(context.tr('Weet je zeker dat je dit profiel wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.', 'Are you sure you want to delete this profile? This action cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Annuleren', 'Cancel'), style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Verwijderen', 'Delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.profile != null) {
      try {
        await Provider.of<ProfileProvider>(context, listen: false).deleteProfile(widget.profile!.id!);
        if (mounted) {
          // Pop twice to get back to the profile selection screen
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.tr('Fout bij verwijderen van profiel', 'Error deleting profile')}: $e')),
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
        title: Text(widget.profile != null ? context.tr('Profiel Bewerken', 'Edit Profile') : context.tr('Nieuw Profiel', 'New Profile')),
        actions: [
          if (widget.profile != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Colors.red,
              onPressed: _deleteProfile,
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
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          image: _profileImage != null 
                            ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                            : _profileImageUrl != null
                              ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _profileImage == null && _profileImageUrl == null 
                          ? Icon(Icons.person, size: 60, color: Colors.grey[400]) 
                          : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(context.tr('Naam', 'Name'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(
                  hintText: context.tr('Bijv. Sophie', 'e.g. Sophie'),
                ),
                validator: (value) => value!.isEmpty ? context.tr('Voer een naam in', 'Please enter a name') : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 24),
              Text(context.tr('Geboortedatum', 'Date of birth'), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                 onTap: () => _selectDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: theme.inputDecorationTheme.fillColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? context.tr('Kies Geboortedatum', 'Choose Date of Birth')
                        : DateFormat('dd MMMM yyyy', context.tr('nl_NL', 'en_US')).format(_dateOfBirth!),
                    style: TextStyle(
                      fontSize: 16,
                      color: _dateOfBirth == null ? Colors.grey[500] : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(context.tr('Profiel Opslaan', 'Save Profile'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
