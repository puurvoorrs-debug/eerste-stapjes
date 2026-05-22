import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../providers/locale_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/animated_footsteps_circle.dart';
import 'profile_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final int? initialPage;
  const OnboardingScreen({super.key, this.initialPage});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  late final List<int> _pageHistory;
  late int _currentPage;
  bool _isLoading = false;

  // Path selection: 'create' or 'follow'
  String? _selectedPath;

  // User input variables (Follow path)
  final TextEditingController _userNameController = TextEditingController();
  File? _userImageFile;
  String? _userPhotoUrl;
  bool _hasFollowCode = false;
  final TextEditingController _followCodeController = TextEditingController();
  String? _followErrorMessage;

  // Baby profile variables (Create path)
  final TextEditingController _babyNameController = TextEditingController();
  DateTime? _babyDateOfBirth;
  File? _babyImageFile;
  Profile? _createdBabyProfile;

  // Copy status
  bool _isCopied = false;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? 0;
    _pageHistory = [widget.initialPage ?? 0];
    _pageController = PageController(initialPage: widget.initialPage ?? 0);
    if (widget.initialPage == 6) {
      _selectedPath = 'create';
    }
    if (_currentUser?.displayName != null) {
      _userNameController.text = _currentUser!.displayName!;
    }
    _userPhotoUrl = _currentUser?.photoURL;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _userNameController.dispose();
    _followCodeController.dispose();
    _babyNameController.dispose();
    super.dispose();
  }

  // Track active pages in each path
  List<int> get _activePath {
    if (_selectedPath == 'follow') {
      return [0, 1, 2, 3, 4, 5];
    } else if (_selectedPath == 'create') {
      return [0, 1, 2, 3, 6, 7, 8, 9, 10];
    } else {
      return [0, 1];
    }
  }

  double get _progress {
    final path = _activePath;
    final index = path.indexOf(_currentPage);
    if (index == -1) return 0.0;
    return (index + 1) / path.length;
  }

  void _navigateToPage(int pageIndex) {
    setState(() {
      _currentPage = pageIndex;
      _pageHistory.add(pageIndex);
    });
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _goBack() {
    if (_pageHistory.length > 1) {
      setState(() {
        _pageHistory.removeLast();
        _currentPage = _pageHistory.last;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  // File Picker Helpers
  Future<void> _pickUserImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _userImageFile = File(pickedFile.path);
        _userPhotoUrl = null;
      });
    }
  }

  Future<void> _pickBabyImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _babyImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectBabyBirthDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _babyDateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _babyDateOfBirth = picked;
      });
    }
  }

  // Database Action Helpers
  Future<void> _saveDefaultUserAndContinue() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (_currentUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).set({
          'uid': _currentUser.uid,
          'displayName': _currentUser.displayName ?? context.tr('Gebruiker', 'User'),
          'photoUrl': _currentUser.photoURL ?? '',
          'onboardingCompleted': true,
          'language': Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
        });
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
        );
      }
    } catch (e) {
      _showSnackbar(context.tr('Fout bij het opslaan van account: $e', 'Error saving account: $e'));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveUserAndContinue() async {
    if (_userNameController.text.trim().isEmpty) {
      _showSnackbar(context.tr('Voer a.u.b. je naam in', 'Please enter your name'));
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      String finalPhotoUrl = _userPhotoUrl ?? '';
      if (_userImageFile != null) {
        final fileName = '${DateTime.now().toIso8601String()}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_profile_pictures')
            .child(_currentUser!.uid)
            .child(fileName);
        await storageRef.putFile(_userImageFile!);
        finalPhotoUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
        'uid': _currentUser.uid,
        'displayName': _userNameController.text.trim(),
        'photoUrl': finalPhotoUrl,
        'language': Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
      }, SetOptions(merge: true));

      setState(() {
        _isLoading = false;
      });
      
      if (_selectedPath == 'create') {
        _navigateToPage(6); // Baby name screen (B1)
      } else {
        _navigateToPage(4); // Go to follow code screen
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar(context.tr('Fout bij het opslaan van profiel: $e', 'Error saving profile: $e'));
    }
  }

  Future<void> _submitFollowRequest() async {
    final code = _followCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _followErrorMessage = context.tr('Voer een geldige volgcode in.', 'Please enter a valid follow code.');
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _followErrorMessage = null;
    });

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final result = await profileProvider.followProfile(code);
      
      setState(() {
        _isLoading = false;
      });

      if (result == 'request_sent') {
        _navigateToPage(5); // Go to success page
      } else {
        setState(() {
          switch (result) {
            case 'already_requested':
              _followErrorMessage = context.tr('Je hebt al een openstaand volgverzoek voor dit profiel.', 'You already have a pending follow request for this profile.');
              break;
            case 'already_following':
              _followErrorMessage = context.tr('Je volgt dit profiel al.', 'You are already following this profile.');
              break;
            case 'own_profile':
              _followErrorMessage = context.tr('Je kunt je eigen profiel niet volgen.', 'You cannot follow your own profile.');
              break;
            case 'invalid_code':
            default:
              _followErrorMessage = context.tr('Ongeldige code. Controleer de code en probeer het opnieuw.', 'Invalid code. Please check the code and try again.');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _followErrorMessage = context.tr('Er is een fout opgetreden: $e', 'An error occurred: $e');
      });
    }
  }

  Future<void> _createBabyProfileAndContinue() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 1. Mark onboarding as completed
      await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));

      // 2. Create the baby profile
      final babyProfile = Profile(
        name: _babyNameController.text.trim(),
        dateOfBirth: _babyDateOfBirth ?? DateTime.now(),
        profileImage: _babyImageFile,
        ownerId: _currentUser.uid,
      );

      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final newProfile = await profileProvider.addProfile(babyProfile);

      setState(() {
        _createdBabyProfile = newProfile;
        _isLoading = false;
      });
      _navigateToPage(10); // Go to share code page B5
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackbar(context.tr('Fout bij het aanmaken van babyprofiel: $e', 'Error creating baby profile: $e'));
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // UI Component Builders
  Widget _buildBackButton() {
    if (_currentPage == 0) return const SizedBox(width: 48);
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: _goBack,
      tooltip: context.tr('Terug', 'Back'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildBackButton(),
                  const Spacer(),
                  if (_currentPage > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        context.tr(
                          'Stap ${_activePath.indexOf(_currentPage) + 1} van ${_activePath.length}',
                          'Step ${_activePath.indexOf(_currentPage) + 1} of ${_activePath.length}',
                        ),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Spacer(),
                  const SizedBox(width: 48), // To balance back button
                ],
              ),
            ),
            
            // Progress Bar
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: theme.colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                    minHeight: 6,
                  ),
                ),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 0: Familiar with Eerste Stapjes
                  _buildIntroPage(theme),

                  // Page 1: Create vs Follow Option
                  _buildPathOptionPage(theme),

                  // Page 2 (F1): Volgen - User Name
                  _buildUserNamePage(theme),

                  // Page 3 (F2): Volgen - User Photo
                  _buildUserPhotoPage(theme),

                  // Page 4 (F3): Volgen - Enter Code
                  _buildFollowCodePage(theme),

                  // Page 5 (F4): Volgen - Success
                  _buildFollowSuccessPage(theme),

                  // Page 6 (B1): Baby Name
                  _buildBabyNamePage(theme),

                  // Page 7 (B2): Baby Birthdate
                  _buildBabyBirthdatePage(theme),

                  // Page 8 (B3): Baby Photo
                  _buildBabyPhotoPage(theme),

                  // Page 9 (B4): Baby Explanation
                  _buildBabyExplanationPage(theme),

                  // Page 10 (B5): Baby Share Code
                  _buildBabyShareCodePage(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PAGES IMPLEMENTATION ---

  // Page 0: Intro
  Widget _buildIntroPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const AnimatedFootstepsCircle(size: 120),
          const SizedBox(height: 40),
          Text(
            context.tr('Welkom!', 'Welcome!'),
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('Ben je al bekend met Eerste stapjes?', 'Are you already familiar with First Steps?'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          if (_isLoading)
            const CircularProgressIndicator()
          else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: _saveDefaultUserAndContinue,
              child: Text(
                context.tr('Ja, ik ken het al', 'Yes, I am already familiar'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () {
                _navigateToPage(1); // Go to Page 1 (Option selection)
              },
              child: Text(
                context.tr('Nee, nog niet', 'No, not yet'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Page 1: Path Option
  Widget _buildPathOptionPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('Hoe wil je beginnen?', 'How do you want to start?'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Wil je zelf een baby profiel aanmaken of wil je een profiel volgen?',
              'Do you want to create a baby profile yourself or do you want to follow a profile?',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          
          // Create Profile Card
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedPath = 'create';
              });
              _navigateToPage(2); // Go to User Name (F1)
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.primaryColor, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.baby_changing_station, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Baby profiel aanmaken', 'Create baby profile'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                            'Houd zelf momenten en mijlpalen van je baby bij in een kalender.',
                            'Keep track of your baby\'s moments and milestones yourself in a calendar.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Follow Profile Card
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedPath = 'follow';
              });
              _navigateToPage(2); // User name screen (F1)
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.secondary, width: 2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people_alt, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Profiel volgen', 'Follow profile'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr(
                            'Volg de avonturen en stapjes van een baby van familie of vrienden.',
                            'Follow the adventures and steps of a baby of family or friends.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Page 2: User Name
  Widget _buildUserNamePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('Wat is jouw naam?', 'What is your name?'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              _selectedPath == 'create'
                  ? 'Vul je naam in zodat anderen weten wie je bent.'
                  : 'Vul je naam in zodat anderen weten wie je bent als je een profiel volgt.',
              _selectedPath == 'create'
                  ? 'Enter your name so others know who you are.'
                  : 'Enter your name so others know who you are when you follow a profile.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _userNameController,
            decoration: InputDecoration(
              hintText: context.tr('Vul je voornaam en achternaam in', 'Enter your first and last name'),
              labelText: context.tr('Naam', 'Name'),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: () {
              if (_userNameController.text.trim().isEmpty) {
                _showSnackbar(context.tr('Voer a.u.b. een naam in.', 'Please enter a name.'));
              } else {
                _navigateToPage(3); // User Photo page (F2)
              }
            },
            child: Text(context.tr('Volgende', 'Next'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Page 3: User Photo
  Widget _buildUserPhotoPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Upload een profielfoto', 'Upload a profile photo'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr(
                _selectedPath == 'create'
                    ? 'Voeg een profielfoto toe zodat je profiel herkenbaar is.'
                    : 'Voeg een profielfoto toe zodat degene die je volgt je makkelijk kan identificeren.',
                _selectedPath == 'create'
                    ? 'Add a profile photo so your profile is recognizable.'
                    : 'Add a profile photo so the person you follow can easily identify you.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          GestureDetector(
            onTap: _pickUserImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 3),
                    image: _userImageFile != null
                        ? DecorationImage(image: FileImage(_userImageFile!), fit: BoxFit.cover)
                        : _userPhotoUrl != null
                            ? DecorationImage(image: NetworkImage(_userPhotoUrl!), fit: BoxFit.cover)
                            : null,
                  ),
                  child: _userImageFile == null && _userPhotoUrl == null
                      ? Icon(Icons.person, size: 70, color: Colors.grey[400])
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(10),
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
          
          const SizedBox(height: 16),
          TextButton(
            onPressed: _pickUserImage,
            child: Text(context.tr('Kies andere foto uit galerij', 'Choose another photo from gallery')),
          ),

          const SizedBox(height: 60),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: _saveUserAndContinue,
              child: Text(context.tr('Opslaan en doorgaan', 'Save and continue'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // Page 4: Follow Path - Code Screen
  Widget _buildFollowCodePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('Heb je al een volg code gekregen?', 'Have you already received a follow code?'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Als je een code hebt gekregen van de ouders, kun je deze hieronder invullen.',
              'If you have received a code from the parents, you can enter it below.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          
          // Switch between "Yes" or "No" to code
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(context.tr('Ja, ik heb een code', 'Yes, I have a code'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  selected: _hasFollowCode,
                  onSelected: (selected) {
                    setState(() {
                      _hasFollowCode = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(context.tr('Nee, nog niet', 'No, not yet'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  selected: !_hasFollowCode,
                  onSelected: (selected) {
                    setState(() {
                      _hasFollowCode = false;
                      _followErrorMessage = null;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Code Input Field
          if (_hasFollowCode) ...[
            TextField(
              controller: _followCodeController,
              decoration: InputDecoration(
                labelText: context.tr('Unieke Volgcode', 'Unique Follow Code'),
                hintText: context.tr('Bijv. ABCXYZ', 'E.g. ABCXYZ'),
                errorText: _followErrorMessage,
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _followCodeController.clear(),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                onPressed: _submitFollowRequest,
                child: Text(context.tr('Aanvraag doen', 'Submit request'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.primaryColor, size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Geen probleem! Je kunt later op het hoofdscherm altijd alsnog een code invoeren om een babyprofiel te volgen.',
                        'No problem! You can always enter a code on the main screen later to follow a baby profile.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () {
                _navigateToPage(5); // Go to end page (F4)
              },
              child: Text(context.tr('Volgende', 'Next'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // Page 5: Follow Path - Success
  Widget _buildFollowSuccessPage(ThemeData theme) {
    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, color: theme.primaryColor, size: 80),
            ),
            const SizedBox(height: 32),
            Text(
              context.tr(
                _hasFollowCode ? 'Verzoek verzonden!' : 'Bijna klaar!',
                _hasFollowCode ? 'Request sent!' : 'Almost ready!',
              ),
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                context.tr(
                  _hasFollowCode
                      ? 'De eigenaar van het profiel wat je wilt volgen moet de aanvraag nog goedkeuren. Als dit is goedgekeurd krijg je een melding!'
                      : 'Veel plezier straks met het samen ontdekken van zijn of haar nieuwe stapjes!',
                  _hasFollowCode
                      ? 'The owner of the profile you want to follow must approve the request first. You will receive a notification once it is approved!'
                      : 'Have fun discovering his or her first steps together soon!',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
            ),
            if (_hasFollowCode) ...[
              const SizedBox(height: 24),
              Text(
                context.tr(
                  'Veel plezier straks met het samen ontdekken van zijn of haar nieuwe stapjes!',
                  'Have fun discovering his or her first steps together soon!',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                });
                try {
                  await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).set({
                    'onboardingCompleted': true,
                  }, SetOptions(merge: true));
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
                    );
                  }
                } catch (e) {
                  _showSnackbar(context.tr('Fout bij het afronden: $e', 'Error finishing: $e'));
                } finally {
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                }
              },
              child: Text(context.tr('Afronden', 'Finish'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Page 6: Baby Profile - Name
  Widget _buildBabyNamePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('Wat is jullie wondertje zijn of haar naam?', 'What is your little wonder\'s name?'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Vul de naam in van jullie kindje om zijn of haar profiel aan te maken.',
              'Enter your baby\'s name to create his or her profile.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _babyNameController,
            decoration: InputDecoration(
              hintText: context.tr('Bijv. Sophie, Liam, Zoë', 'E.g. Sophie, Liam, Zoë'),
              labelText: context.tr('Naam van de baby', 'Baby\'s name'),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: () {
              if (_babyNameController.text.trim().isEmpty) {
                _showSnackbar(context.tr('Voer a.u.b. de naam van het kindje in.', 'Please enter the baby\'s name.'));
              } else {
                _navigateToPage(7); // Birthdate screen (B2)
              }
            },
            child: Text(context.tr('Volgende', 'Next'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Page 7: Baby Profile - Birthdate
  Widget _buildBabyBirthdatePage(ThemeData theme) {
    final babyName = _babyNameController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('Wanneer is $babyName geboren?', 'When was $babyName born?'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Dit helpt ons om de leeftijden bij de foto\'s goed te berekenen.',
              'This helps us calculate the ages for the photos correctly.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          
          GestureDetector(
            onTap: () => _selectBabyBirthDate(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: theme.primaryColor),
                  const SizedBox(width: 16),
                  Text(
                    _babyDateOfBirth == null
                        ? context.tr('Kies Geboortedatum', 'Choose Date of Birth')
                        : DateFormat('dd MMMM yyyy', context.tr('nl_NL', 'en_US')).format(_babyDateOfBirth!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _babyDateOfBirth == null ? Colors.grey[500] : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: () {
              if (_babyDateOfBirth == null) {
                _showSnackbar(context.tr('Kies a.u.b. de geboortedatum.', 'Please choose the date of birth.'));
              } else {
                _navigateToPage(8); // Photo screen (B3)
              }
            },
            child: Text(context.tr('Volgende', 'Next'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Page 8: Baby Profile - Photo
  Widget _buildBabyPhotoPage(ThemeData theme) {
    final babyName = _babyNameController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Upload een profielfoto', 'Upload a profile photo'),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Upload een profielfoto voor $babyName.', 'Upload a profile photo for $babyName.'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          GestureDetector(
            onTap: _pickBabyImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 3),
                    image: _babyImageFile != null
                        ? DecorationImage(image: FileImage(_babyImageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _babyImageFile == null
                      ? Icon(Icons.child_care, size: 70, color: Colors.grey[400])
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(10),
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
          
          const SizedBox(height: 16),
          TextButton(
            onPressed: _pickBabyImage,
            child: Text(context.tr('Kies foto uit galerij', 'Choose photo from gallery')),
          ),

          const SizedBox(height: 60),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: () {
              _navigateToPage(9); // Explanation screen (B4)
            },
            child: Text(context.tr('Volgende', 'Next'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Page 9: Baby Profile - Calendar Explanation
  Widget _buildBabyExplanationPage(ThemeData theme) {
    final babyName = _babyNameController.text.trim();
    final formattedBirthdate = _babyDateOfBirth != null
        ? DateFormat('d MMMM yyyy', context.tr('nl_NL', 'en_US')).format(_babyDateOfBirth!)
        : context.tr('de geboortedatum', 'the date of birth');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            context.tr('Kalender vullen', 'Fill calendar'),
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.primaryColor.withOpacity(0.15), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Het kan natuurlijk zo zijn dat $babyName niet vandaag is geboren.',
                    'It could of course be that $babyName was not born today.',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Jullie mogen op de dagen vanaf $formattedBirthdate tot de dag van vandaag alvast de kalender vullen met een foto van die dag.',
                    'You can already fill the calendar with a photo for each day from $formattedBirthdate up to today.',
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Daarna kunnen jullie iedere dag 1 foto van de dag toevoegen, zo houd je makkelijk en veilig jullie familie en vrienden geupdate en houd je een fotodagboek bij van $babyName!',
                    'After that, you can add 1 photo of the day every day. This keeps your family and friends updated easily and securely, and builds a photo diary of $babyName!',
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: _createBabyProfileAndContinue,
              child: Text(context.tr('Profiel aanmaken', 'Create profile'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // Page 10: Baby Profile - Share Code
  Widget _buildBabyShareCodePage(ThemeData theme) {
    final babyName = _babyNameController.text.trim();
    final shareCode = _createdBabyProfile?.shareCode ?? '';

    return PopScope(
      canPop: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              context.tr('Unieke Volgcode', 'Unique Follow Code'),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Deel deze unieke code met familie en vrienden waarmee jullie $babyName zijn of haar eerste stapjes willen delen.',
                'Share this unique code with family and friends you want to share $babyName\'s first steps with.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Share Code Display Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: theme.primaryColor.withOpacity(0.2), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    context.tr('VOLGCODE', 'FOLLOW CODE'),
                    style: TextStyle(
                      color: theme.primaryColor,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shareCode,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Copy Button with Micro-Animation/State change
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareCode));
                      setState(() {
                        _isCopied = true;
                      });
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) {
                          setState(() {
                            _isCopied = false;
                          });
                        }
                      });
                    },
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _isCopied ? Icons.check : Icons.copy,
                        key: ValueKey<bool>(_isCopied),
                        size: 20,
                      ),
                    ),
                    label: Text(context.tr(_isCopied ? 'Gekopieerd!' : 'Kopieer code', _isCopied ? 'Copied!' : 'Copy code')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCopied ? Colors.green[400] : theme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Security Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: theme.colorScheme.secondary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Personen die willen volgen voeren de volg code in, maar jullie moeten altijd het volgverzoek nog accepteren. Dit is een extra beveiligingsstap.',
                        'People who want to follow must enter the follow code, but you must always approve the follow request. This is an extra security step.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Text(
              context.tr(
                'Je kunt je code altijd terug vinden in de menubalk bovenin binnen $babyName zijn of haar profielpagina.',
                'You can always find your code in the top menu bar on $babyName\'s profile page.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const ProfileSelectionScreen()),
                );
              },
              child: Text(context.tr('Aan de slag!', 'Get started!'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
