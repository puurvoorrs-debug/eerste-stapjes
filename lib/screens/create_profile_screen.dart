import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF5C3A3A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5C3A3A),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('U moet ingelogd zijn om een profiel op te slaan')));
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout bij opslaan: $e')));
          }          
        }
       
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kies alsjeblieft een geboortedatum', style: TextStyle(color: Colors.white))),
        );
      }
    }
  }

  void _deleteProfile() async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profiel Verwijderen?'),
        content: const Text('Weet je zeker dat je dit profiel wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
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
            SnackBar(content: Text('Fout bij verwijderen van profiel: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.profile != null ? 'Profiel Bewerken' : 'Nieuw Profiel',
          style: const TextStyle(fontFamily: 'Pacifico', color: Colors.white, fontSize: 24),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.profile != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteProfile,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                        image: _profileImage != null 
                          ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                          : _profileImageUrl != null
                            ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _profileImage == null && _profileImageUrl == null ? const Icon(Icons.photo_camera, color: Colors.white70) : null,
                    ),
                    const SizedBox(width: 15),
                    const Text('Kies Profielfoto', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                )
              ),
              const SizedBox(height: 40),
              const Text('Naam', style: TextStyle(color: Colors.white, fontSize: 16)),
              TextFormField(
                initialValue: _name,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.only(top: 10, bottom: 2),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                validator: (value) => value!.isEmpty ? 'Voer een naam in' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 30),
              const Text('Geboortedatum:', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 10),
              GestureDetector(
                 onTap: () => _selectDate(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _dateOfBirth == null
                          ? 'Kies Geboortedatum'
                          : DateFormat('dd MMMM yyyy', 'nl_NL').format(_dateOfBirth!),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Profiel Opslaan',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
