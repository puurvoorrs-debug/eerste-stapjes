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

import 'package:google_fonts/google_fonts.dart';
import '../models/profile.dart';
import '../providers/locale_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/sketchy_components.dart';
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

  Color get _textColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A);
  }

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
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _userImageFile = File(pickedFile.path);
        _userPhotoUrl = null;
      });
    }
  }

  Future<void> _pickBabyImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
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
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .set({
          'uid': _currentUser.uid,
          'displayName':
              _currentUser.displayName ?? context.tr('Gebruiker', 'User'),
          'photoUrl': _currentUser.photoURL ?? '',
          'onboardingCompleted': true,
          'language': Provider.of<LocaleProvider>(context, listen: false)
              .locale
              .languageCode,
        });
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          SketchyPageRoute(
              page: const ProfileSelectionScreen()),
        );
      }
    } catch (e) {
      _showSnackbar(context.tr(
          'Fout bij het opslaan van account: $e', 'Error saving account: $e'));
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
      _showSnackbar(
          context.tr('Voer a.u.b. je naam in', 'Please enter your name'));
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
        'uid': _currentUser.uid,
        'displayName': _userNameController.text.trim(),
        'photoUrl': finalPhotoUrl,
        'language': Provider.of<LocaleProvider>(context, listen: false)
            .locale
            .languageCode,
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
      _showSnackbar(context.tr(
          'Fout bij het opslaan van profiel: $e', 'Error saving profile: $e'));
    }
  }

  Future<void> _submitFollowRequest() async {
    final code = _followCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _followErrorMessage = context.tr('Voer een geldige volgcode in.',
            'Please enter a valid follow code.');
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _followErrorMessage = null;
    });

    try {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
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
              _followErrorMessage = context.tr(
                  'Je hebt al een openstaand volgverzoek voor dit profiel.',
                  'You already have a pending follow request for this profile.');
              break;
            case 'already_following':
              _followErrorMessage = context.tr('Je volgt dit profiel al.',
                  'You are already following this profile.');
              break;
            case 'own_profile':
              _followErrorMessage = context.tr(
                  'Je kunt je eigen profiel niet volgen.',
                  'You cannot follow your own profile.');
              break;
            case 'invalid_code':
            default:
              _followErrorMessage = context.tr(
                  'Ongeldige code. Controleer de code en probeer het opnieuw.',
                  'Invalid code. Please check the code and try again.');
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _followErrorMessage = context.tr(
            'Er is een fout opgetreden: $e', 'An error occurred: $e');
      });
    }
  }

  Future<void> _createBabyProfileAndContinue() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 1. Mark onboarding as completed
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
        'onboardingCompleted': true,
      }, SetOptions(merge: true));

      // 2. Create the baby profile
      final babyProfile = Profile(
        name: _babyNameController.text.trim(),
        dateOfBirth: _babyDateOfBirth ?? DateTime.now(),
        profileImage: _babyImageFile,
        ownerId: _currentUser.uid,
      );

      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
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
      _showSnackbar(context.tr('Fout bij het aanmaken van babyprofiel: $e',
          'Error creating baby profile: $e'));
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
    if (_currentPage == 0) return const SizedBox(width: 44);
    return SketchyBackButton(onPressed: _goBack);
  }

  Widget _buildPageIndicator() {
    final path = _activePath;
    final activeIndex = path.indexOf(_currentPage);
    if (activeIndex == -1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(path.length, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 20.0 : 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: isActive ? _textColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _textColor,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFootstepsRow({required bool top}) {
    const leftFoot = 'assets/images/logo_left_foot.svg';
    const rightFoot = 'assets/images/logo_right_foot.svg';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: top
          ? [
              SvgPicture.asset(leftFoot, height: 60, colorFilter: const ColorFilter.mode(Color(0xFFFDC55E), BlendMode.srcIn)),
              SvgPicture.asset(rightFoot, height: 60, colorFilter: const ColorFilter.mode(Color(0xFFE35B30), BlendMode.srcIn)),
              SvgPicture.asset(leftFoot, height: 60, colorFilter: const ColorFilter.mode(Color(0xFF92BCE3), BlendMode.srcIn)),
            ]
          : [
              SvgPicture.asset(rightFoot, height: 60, colorFilter: const ColorFilter.mode(Color(0xFFE35B30), BlendMode.srcIn)),
              SvgPicture.asset(leftFoot, height: 60, colorFilter: const ColorFilter.mode(Color(0xFFFDC55E), BlendMode.srcIn)),
              SvgPicture.asset(rightFoot, height: 60, colorFilter: const ColorFilter.mode(Color(0xFF5C9E76), BlendMode.srcIn)),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with brand logo and page dots
            if (_currentPage > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBackButton(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/images/Eerste stapjes - Logo nieuw oranje.svg',
                          height: 32,
                          colorFilter: ColorFilter.mode(_textColor, BlendMode.srcIn),
                        ),
                        const SizedBox(height: 8),
                        _buildPageIndicator(),
                      ],
                    ),
                    const SizedBox(width: 44), // Balances the back button
                  ],
                ),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Page 0: Welcome / Intro Page
                  _buildIntroPage(theme),

                  // Page 1: Path Option Selection (Create or Follow)
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

  // Page 0: Intro (Mockup 2)
  Widget _buildIntroPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildFootstepsRow(top: true),
          const SizedBox(height: 60),
          Text(
            context.tr('Welkom bij', 'Welcome to'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SvgPicture.asset(
            'assets/images/Eerste stapjes - Logo nieuw oranje.svg',
            height: 64,
            colorFilter: ColorFilter.mode(_textColor, BlendMode.srcIn),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              context.tr(
                'Leg iedere stap van je kleintje vast met al je dierbaren.',
                'Record every stop of your little one with all  your loved ones.',
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: _textColor.withOpacity(0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 60),
          _buildFootstepsRow(top: false),
          const SizedBox(height: 60),
          if (_isLoading)
            const CircularProgressIndicator()
          else ...[
            SketchyButton(
              label: context.tr('Ik ben nieuw hier', 'I am new here'),
              fillColor: const Color(0xFFF38B4B),
              textColor: Colors.white,
              borderColor: _textColor,
              onPressed: () {
                _navigateToPage(1); // Go to Page 1
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _saveDefaultUserAndContinue,
              child: Text(
                context.tr('Ik ben al bekend met de app', 'I am already familiar with the app'),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF38B4B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Page 1: Path Option (Mockup 1)
  Widget _buildPathOptionPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            context.tr('Laten we beginnen', 'Let\'s get started'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Wat wil je doen?', 'What do you want to do?'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),

          SketchyRadioButton(
            selected: _selectedPath == 'create',
            title: context.tr('Baby profiel aanmaken', 'Create baby profile'),
            subtitle: context.tr(
              'Houd zelf momenten en mijlpalen van je baby bij in een kalender.',
              'Keep track of your baby\'s moments and milestones yourself in a calendar.',
            ),
            leading: const Icon(Icons.baby_changing_station, color: Color(0xFFF38B4B), size: 28),
            onTap: () {
              setState(() {
                _selectedPath = 'create';
              });
            },
          ),
          const SizedBox(height: 20),

          SketchyRadioButton(
            selected: _selectedPath == 'follow',
            title: context.tr('Profiel volgen', 'Follow profile'),
            subtitle: context.tr(
              'Volg de avonturen en stapjes van een baby van familie of vrienden.',
              'Follow the adventures and steps of a baby of family or friends.',
            ),
            leading: const Icon(Icons.people_alt, color: Color(0xFFF38B4B), size: 28),
            onTap: () {
              setState(() {
                _selectedPath = 'follow';
              });
            },
          ),

          const SizedBox(height: 60),

          SketchyButton(
            label: context.tr('Verder', 'Continue'),
            fillColor: const Color(0xFFF38B4B),
            textColor: Colors.white,
            onPressed: _selectedPath == null
                ? null
                : () {
                    _navigateToPage(2); // Go to User Name (F1)
                  },
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              context.tr('Je kunt op een later moment altijd wisselen', 'You can always switch at a later moment'),
              style: TextStyle(
                fontSize: 12,
                color: _textColor.withOpacity(0.5),
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
          const SizedBox(height: 10),
          Text(
            context.tr('Wat is jouw naam?', 'What is your name?'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 36),
          SketchyTextField(
            controller: _userNameController,
            labelText: context.tr('Jouw Naam', 'Your Name'),
            hintText: context.tr('Vul je voornaam en achternaam in', 'Enter your first and last name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 60),
          SketchyButton(
            label: context.tr('Volgende', 'Next'),
            fillColor: const Color(0xFFF38B4B),
            textColor: Colors.white,
            onPressed: () {
              if (_userNameController.text.trim().isEmpty) {
                _showSnackbar(context.tr('Voer a.u.b. een naam in.', 'Please enter a name.'));
              } else {
                _navigateToPage(3); // User Photo page (F2)
              }
            },
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Profielfoto uploaden', 'Upload profile photo'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
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
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: _textColor.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 48),

          GestureDetector(
            onTap: _pickUserImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.cardTheme.color
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFFEFEBE9).withOpacity(0.15)
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(70),
                    child: _userImageFile != null
                        ? Image.file(_userImageFile!, fit: BoxFit.cover)
                        : _userPhotoUrl != null
                            ? Image.network(_userPhotoUrl!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey[100],
                                child: Icon(Icons.person, size: 70, color: _textColor),
                              ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF38B4B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _pickUserImage,
            child: Text(
              context.tr('Kies andere foto uit galerij', 'Choose another photo from gallery'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF38B4B),
              ),
            ),
          ),
          const SizedBox(height: 60),

          if (_isLoading)
            const CircularProgressIndicator()
          else
            SketchyButton(
              label: context.tr('Opslaan en doorgaan', 'Save and continue'),
              fillColor: const Color(0xFFF38B4B),
              textColor: Colors.white,
              onPressed: _saveUserAndContinue,
            ),
        ],
      ),
    );
  }

  // Page 4: Follow Path - Enter Code
  Widget _buildFollowCodePage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            context.tr('Volgcode invoeren', 'Enter follow code'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Als je een code hebt gekregen van de ouders, kun je deze hieronder invullen.',
              'If you have received a code from the parents, you can enter it below.',
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),

          // Custom Sketchy Choice Chips
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _hasFollowCode = true),
                  child: SketchyContainer(
                    padding: 12,
                    fillColor: _hasFollowCode ? const Color(0xFFFFF1DC) : Colors.white,
                    borderColor: _textColor,
                    borderRadius: 10.0,
                    showShadow: _hasFollowCode,
                    shadowOffset: 2.0,
                    child: Center(
                      child: Text(
                        context.tr('Ja, ik heb een code', 'Yes, I have a code'),
                        style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _hasFollowCode = false;
                    _followErrorMessage = null;
                  }),
                  child: SketchyContainer(
                    padding: 12,
                    fillColor: !_hasFollowCode ? const Color(0xFFFFF1DC) : Colors.white,
                    borderColor: _textColor,
                    borderRadius: 10.0,
                    showShadow: !_hasFollowCode,
                    shadowOffset: 2.0,
                    child: Center(
                      child: Text(
                        context.tr('Nee, nog niet', 'No, not yet'),
                        style: TextStyle(fontWeight: FontWeight.bold, color: _textColor),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          if (_hasFollowCode) ...[
            SketchyTextField(
              controller: _followCodeController,
              labelText: context.tr('Unieke Volgcode', 'Unique Follow Code'),
              hintText: context.tr('Bijv. ABCXYZ', 'E.g. ABCXYZ'),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_followErrorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _followErrorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 48),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SketchyButton(
                label: context.tr('Aanvraag doen', 'Submit request'),
                fillColor: const Color(0xFFF38B4B),
                textColor: Colors.white,
                onPressed: _submitFollowRequest,
              ),
          ] else ...[
            SketchyContainer(
              borderColor: _textColor,
              borderRadius: 0.0,
              padding: 16.0,
              showShadow: false,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF38B4B), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Geen probleem! Je kunt later op het hoofdscherm altijd alsnog een code invoeren om een babyprofiel te volgen.',
                        'No problem! You can always enter a code on the main screen later to follow a baby profile.',
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            SketchyButton(
              label: context.tr('Volgende', 'Next'),
              fillColor: const Color(0xFFF38B4B),
              textColor: Colors.white,
              onPressed: () {
                _navigateToPage(5); // Go to success page (F4)
              },
            ),
          ],
        ],
      ),
    );
  }

  // Page 5: Follow Success
  Widget _buildFollowSuccessPage(ThemeData theme) {
    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            SketchyContainer(
              padding: 24,
              borderRadius: 80,
              fillColor: const Color(0xFFFFF1DC),
              borderColor: _textColor,
              showShadow: false,
              child: const Icon(Icons.check_circle_outline, color: Color(0xFFF38B4B), size: 80),
            ),
            const SizedBox(height: 36),
            Text(
              context.tr(
                _hasFollowCode ? 'Verzoek verzonden!' : 'Bijna klaar!',
                _hasFollowCode ? 'Request sent!' : 'Almost ready!',
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
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
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: _textColor.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
            ),
            const Spacer(),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              SketchyButton(
                label: context.tr('Afronden', 'Finish'),
                fillColor: const Color(0xFFF38B4B),
                textColor: Colors.white,
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                  });
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .set({
                      'onboardingCompleted': true,
                    }, SetOptions(merge: true));
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        SketchyPageRoute(page: const ProfileSelectionScreen()),
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
          const SizedBox(height: 10),
          Text(
            context.tr('Naam van de baby', 'Name of the baby'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Vul de naam in van jullie kindje om zijn of haar profiel aan te maken.',
              'Enter your baby\'s name to create his or her profile.',
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 36),
          SketchyTextField(
            controller: _babyNameController,
            labelText: context.tr('Naam', 'Name'),
            hintText: context.tr('Bijv. Sophie, Liam, Zoë', 'E.g. Sophie, Liam, Zoë'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 60),
          SketchyButton(
            label: context.tr('Volgende', 'Next'),
            fillColor: const Color(0xFFF38B4B),
            textColor: Colors.white,
            onPressed: () {
              if (_babyNameController.text.trim().isEmpty) {
                _showSnackbar(context.tr('Voer a.u.b. de naam van het kindje in.', 'Please enter the baby\'s name.'));
              } else {
                _navigateToPage(7); // Birthdate screen (B2)
              }
            },
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
          const SizedBox(height: 10),
          Text(
            context.tr('Wanneer is $babyName geboren?', 'When was $babyName born?'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Dit helpt ons om de leeftijden bij de foto\'s goed te berekenen.',
              'This helps us calculate the ages for the photos correctly.',
            ),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 36),

          GestureDetector(
            onTap: () => _selectBabyBirthDate(context),
            child: SketchyContainer(
              fillColor: Colors.white,
              borderColor: _textColor,
              borderRadius: 12.0,
              padding: 16.0,
              showShadow: false,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFFF38B4B)),
                  const SizedBox(width: 16),
                  Text(
                    _babyDateOfBirth == null
                        ? context.tr('Kies Geboortedatum', 'Choose Date of Birth')
                        : DateFormat('dd MMMM yyyy', context.tr('nl_NL', 'en_US')).format(_babyDateOfBirth!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _babyDateOfBirth == null ? Colors.grey[500] : _textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),

          SketchyButton(
            label: context.tr('Volgende', 'Next'),
            fillColor: const Color(0xFFF38B4B),
            textColor: Colors.white,
            onPressed: () {
              if (_babyDateOfBirth == null) {
                _showSnackbar(context.tr('Kies a.u.b. de geboortedatum.', 'Please choose the date of birth.'));
              } else {
                _navigateToPage(8); // Photo screen (B3)
              }
            },
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Profielfoto uploaden', 'Upload profile photo'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr('Upload een profielfoto voor $babyName.', 'Upload a profile photo for $babyName.'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: _textColor.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(height: 48),

          GestureDetector(
            onTap: _pickBabyImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.cardTheme.color
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFFEFEBE9).withOpacity(0.15)
                          : Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(70),
                    child: _babyImageFile != null
                        ? Image.file(_babyImageFile!, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey[100],
                            child: Icon(Icons.child_care, size: 70, color: _textColor),
                          ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF38B4B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _pickBabyImage,
            child: Text(
              context.tr('Kies foto uit galerij', 'Choose photo from gallery'),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF38B4B),
              ),
            ),
          ),
          const SizedBox(height: 60),

          SketchyButton(
            label: context.tr('Volgende', 'Next'),
            fillColor: const Color(0xFFF38B4B),
            textColor: Colors.white,
            onPressed: () {
              _navigateToPage(9); // Explanation screen (B4)
            },
          ),
        ],
      ),
    );
  }

  // Page 9: Baby Profile - Calendar Explanation (Mockup 5 frame style)
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
          const SizedBox(height: 10),
          Text(
            context.tr('Kalender vullen', 'Fill calendar'),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 24),

          // Double Sketchy Frame (representing Mockup 5 photo style)
          SketchyContainer(
            borderColor: _textColor,
            borderRadius: 0.0,
            padding: 20.0,
            showShadow: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Het kan natuurlijk zo zijn dat $babyName niet vandaag is geboren.',
                    'It could of course be that $babyName was not born today.',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Jullie mogen op de dagen vanaf $formattedBirthdate tot de dag van vandaag alvast de kalender vullen met een foto van die dag.',
                    'You can already fill the calendar with a photo for each day from $formattedBirthdate up to today.',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: _textColor.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Daarna kunnen jullie iedere dag 1 foto van de dag toevoegen, zo houd je makkelijk en veilig jullie familie en vrienden geupdate en houd je een fotodagboek bij van $babyName!',
                    'After that, you can add 1 photo of the day every day. This keeps your family and friends updated easily and securely, and builds a photo diary of $babyName!',
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: _textColor.withOpacity(0.8),
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
            SketchyButton(
              label: context.tr('Profiel aanmaken', 'Create profile'),
              fillColor: const Color(0xFFF38B4B),
              textColor: Colors.white,
              onPressed: _createBabyProfileAndContinue,
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
            const SizedBox(height: 10),
            Text(
              context.tr('Unieke Volgcode', 'Unique Follow Code'),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Deel deze unieke code met familie en vrienden waarmee jullie $babyName zijn of haar eerste stapjes willen delen.',
                'Share this unique code with family and friends you want to share $babyName\'s first steps with.',
              ),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: _textColor.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Share Code Display inside a Sketchy Container
            SketchyContainer(
              fillColor: theme.brightness == Brightness.dark
                  ? const Color(0xFFFFF1DC).withOpacity(0.15)
                  : const Color(0xFFFFF1DC),
              borderColor: _textColor,
              borderRadius: 0.0,
              padding: 24.0,
              showShadow: false,
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
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  SketchyButton(
                    label: context.tr(_isCopied ? 'Gekopieerd!' : 'Kopieer code', _isCopied ? 'Copied!' : 'Copy code'),
                    fillColor: _isCopied ? Colors.green[400] : Colors.white,
                    textColor: _isCopied ? Colors.white : _textColor,
                    icon: Icon(
                      _isCopied ? Icons.check : Icons.copy,
                      color: _isCopied ? Colors.white : _textColor,
                      size: 20,
                    ),
                    showShadow: false,
                    height: 48,
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
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Security Info in a Sketchy Container
            SketchyContainer(
              borderColor: _textColor,
              borderRadius: 0.0,
              padding: 16.0,
              showShadow: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFF38B4B), size: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      context.tr(
                        'Personen die willen volgen voeren de volg code in, maar jullie moeten altijd het volgverzoek nog accepteren. Dit is een extra beveiligingsstap.',
                        'People who want to follow must enter the follow code, but you must always approve the follow request. This is an extra security step.',
                      ),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _textColor,
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
              style: TextStyle(
                fontSize: 12,
                color: _textColor.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),

            SketchyButton(
              label: context.tr('Aan de slag!', 'Get started!'),
              fillColor: const Color(0xFFF38B4B),
              textColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  SketchyPageRoute(page: const ProfileSelectionScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
