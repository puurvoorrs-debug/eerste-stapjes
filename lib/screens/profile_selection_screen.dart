import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import '../models/profile.dart';
import '../models/app_exception.dart';
import '../widgets/animated_sketchy_icons.dart';
import '../widgets/sketchy_components.dart';
import 'create_profile_screen.dart';
import 'calendar_screen.dart';
import 'account_settings_screen.dart';
import 'notifications_screen.dart';
import 'onboarding_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  void _showIncompleteProfileDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Profiel Incompleet', 'Profile Incomplete')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Annuleren', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                SketchyPageRoute(
                    page: const AccountSettingsScreen()),
              );
            },
            child: Text(context.tr('Naar Instellingen', 'To Settings')),
          ),
        ],
      ),
    );
  }

  void _showFollowDialog(BuildContext context) {
    final codeController = TextEditingController();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Profiel Volgen', 'Follow Profile')),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            labelText:
                dialogContext.tr('Voer de unieke code in', 'Enter the unique code'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Annuleren', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final result =
                    await profileProvider.followProfile(codeController.text);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  String message;
                  switch (result) {
                    case 'request_sent':
                      message = context.tr(
                          'Volgverzoek verstuurd! Je krijgt toegang zodra de eigenaar dit goedkeurt.',
                          'Follow request sent! You will get access once the owner approves it.');
                      break;
                    case 'already_requested':
                      message = context.tr(
                          'Je hebt al een openstaand volgverzoek voor dit profiel.',
                          'You already have a pending follow request for this profile.');
                      break;
                    case 'already_following':
                      message = context.tr('Je volgt dit profiel al.',
                          'You are already following this profile.');
                      break;
                    case 'own_profile':
                      message = context.tr(
                          'Je kunt je eigen profiel niet volgen.',
                          'You cannot follow your own profile.');
                      break;
                    case 'invalid_code':
                    default:
                      message = context.tr(
                          'Ongeldige code. Controleer de code en probeer het opnieuw.',
                          'Invalid code. Please check the code and try again.');
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              } on IncompleteProfileException catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  final translatedMessage = e.message.contains('niet gevonden')
                      ? context.tr('Gebruikersprofiel niet gevonden.',
                          'User profile not found.')
                      : context.tr(
                          'Update je profiel met een naam en foto om anderen te volgen.',
                          'Update your profile with a name and photo to follow others.');
                  _showIncompleteProfileDialog(context, translatedMessage);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.tr(
                            'Er is een onbekende fout opgetreden.',
                            'An unknown error occurred.'))),
                  );
                }
              }
            },
            child: Text(dialogContext.tr('Volgen', 'Follow')),
          ),
        ],
      ),
    );
  }

  void _showUnfollowDialog(BuildContext context, Profile profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Profiel Ontvolgen', 'Unfollow Profile')),
        content: Text(dialogContext.tr(
            'Weet je zeker dat je ${profile.name} wilt ontvolgen? Je kunt de momenten van dit profiel dan niet meer bekijken.',
            'Are you sure you want to unfollow ${profile.name}? You will no longer be able to view the moments of this profile.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Annuleren', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
            onPressed: () async {
              try {
                final profileProvider =
                    Provider.of<ProfileProvider>(context, listen: false);
                await profileProvider.unfollowProfile(profile.id!);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.tr('Je bent gestopt met volgen.',
                            'You stopped following.'))),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(context.tr(
                            'Er is een onbekende fout opgetreden.',
                            'An unknown error occurred.'))),
                  );
                }
              }
            },
            child: Text(dialogContext.tr('Ontvolgen', 'Unfollow')),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authService = AuthService();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('Uitloggen', 'Logout')),
        content: Text(dialogContext.tr('Weet je zeker dat je wilt uitloggen?',
            'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.tr('Annuleren', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[300],
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              await authService.signOut();
            },
            child: Text(dialogContext.tr('Uitloggen', 'Logout')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A);

    // Get display name or default to user
    final displayName = currentUser?.displayName?.split(' ').first ??
        context.tr('Gebruiker', 'User');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, displayName),
            Expanded(
              child: Consumer<ProfileProvider>(
                builder: (context, provider, child) {
                  if (provider.profiles.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.tr('Welkom!', 'Welcome!'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SvgPicture.asset(
                              'assets/images/Eerste stapjes - Logo nieuw oranje.svg',
                              height: 64,
                              colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.tr(
                                'Maak een eigen profiel aan om momenten bij te houden, of volg iemand om zijn of haar momenten te bekijken.',
                                'Create your own profile to keep track of moments, or follow someone to view their moments.',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 36),
                            // Nieuw profiel aanmaken
                            SketchyButton(
                              label: context.tr('Nieuw profiel aanmaken', 'Create new profile'),
                              fillColor: const Color(0xFFF38B4B),
                              textColor: Colors.white,
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                 Navigator.push(
                                   context,
                                   SketchyPageRoute(
                                     page: const OnboardingScreen(initialPage: 6),
                                   ),
                                 );
                              },
                            ),
                            const SizedBox(height: 16),
                            // Profiel volgen
                            SketchyButton(
                              label: context.tr('Profiel volgen', 'Follow profile'),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              onPressed: () => _showFollowDialog(context),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final ownProfiles = provider.profiles
                      .where((p) => p.ownerId == currentUser?.uid)
                      .toList();
                  final followedProfiles = provider.profiles
                      .where((p) => p.ownerId != currentUser?.uid)
                      .toList();

                  // If the user has no own profiles but does follow profiles,
                  // show the followed profiles prominently (large card style).
                  final bool hasOwnProfiles = ownProfiles.isNotEmpty;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          if (hasOwnProfiles) ...[
                            // --- Normal layout when user has own profiles ---
                            Text(
                              context.tr('Mijn Profielen', 'My Profiles'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildOwnProfilesSection(ownProfiles, context),
                            const SizedBox(height: 32),
                            if (followedProfiles.isNotEmpty) ...[
                              Text(
                                context.tr(
                                    'Gevolgde Profielen', 'Followed Profiles'),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              _buildFollowedProfilesSection(
                                  followedProfiles, context),
                            ],
                          ] else if (followedProfiles.isNotEmpty) ...[
                            // --- Prominent layout when user only follows profiles ---
                            Text(
                              context.tr(
                                  'Gevolgde Profielen', 'Followed Profiles'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildFollowedProfilesProminentSection(
                                followedProfiles, context),
                          ],
                          const SizedBox(height: 16),
                          _buildTipOfTheDayCard(context),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Only show the bottom follow-button when the user already has
            // at least one profile (own or followed). New users see the
            // buttons inside the empty-state instead.
            Consumer<ProfileProvider>(
              builder: (context, provider, _) {
                if (provider.profiles.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildFollowProfileButton(context, theme),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String name) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SketchyContainer(
        padding: 0,
        borderColor: const Color(0xFF2D2B2A),
        borderRadius: 0.0,
        showShadow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('Hoi, $name 👋', 'Hi, $name 👋'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  _buildNotificationBell(context),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: context.tr('Instellingen', 'Settings'),
                    child: AnimatedSettingsIcon(
                      color: theme.colorScheme.onSurface,
                      onTap: () {
                        Navigator.push(
                          context,
                          SketchyPageRoute(
                            page: const AccountSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: context.tr('Uitloggen', 'Logout'),
                    child: AnimatedLogoutIcon(
                      color: theme.colorScheme.onSurface,
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return _AnimatedNotificationBell(
          unreadCount: unreadCount,
          onTap: () {
            Navigator.push(
              context,
              SketchyPageRoute(
                  page: const NotificationsScreen()),
            );
          },
        );
      },
    );
  }

  Widget _buildOwnProfilesSection(
      List<Profile> profiles, BuildContext context) {
    return SizedBox(
      height: 280, // Increased height for larger cards
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: profiles.length + 1,
        itemBuilder: (context, index) {
          if (index == profiles.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: _buildNewProfileCard(context),
            );
          }
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 16.0),
            child: _buildProfileCard(context, profiles[index]),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Profile profile) {

    return ScaleOnTap(
      onTap: () {
        Navigator.push(
            context,
            SketchyPageRoute(
                page: CalendarScreen(profile: profile)));
      },
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFEFEBE9).withOpacity(0.15)
                : Colors.grey[200]!,
            width: 1.0,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: profile.profileImageUrl != null &&
                      profile.profileImageUrl!.isNotEmpty
                  ? Image.network(
                      profile.profileImageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                      child: Icon(Icons.person,
                          size: 80, color: Theme.of(context).colorScheme.onSurface),
                    ),
            ),
            // Clean bottom overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFEFEBE9).withOpacity(0.15)
                          : Colors.grey[200]!,
                      width: 1.0,
                    ),
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            profile.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('Bekijk', 'View'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit button
                    ScaleOnTap(
                      onTap: () {
                        Navigator.push(
                          context,
                          SketchyPageRoute(
                            page: CreateProfileScreen(profile: profile),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                : Colors.grey[300]!,
                            width: 1.0,
                          ),
                        ),
                        child: Icon(Icons.edit_outlined,
                            size: 16, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewProfileCard(BuildContext context) {
    return ScaleOnTap(
      onTap: () {
        Navigator.push(
          context,
          SketchyPageRoute(
            page: const OnboardingScreen(initialPage: 6),
          ),
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFF1DC).withOpacity(0.15)
              : const Color(0xFFFFF1DC),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFFF1DC).withOpacity(0.3)
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 36, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(height: 8),
            Text(
              context.tr('Nieuw\nprofiel', 'New\nprofile'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows followed profiles in the large horizontal card style, used when
  /// the user has no own profiles so followed profiles are the primary focus.
  Widget _buildFollowedProfilesProminentSection(
      List<Profile> profiles, BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: profiles.length + 1,
        itemBuilder: (context, index) {
          // Last item = "Nieuw profiel" card
          if (index == profiles.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: _buildNewProfileCard(context),
            );
          }

          final profile = profiles[index];

          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 16.0),
            child: ScaleOnTap(
              onTap: () {
                Navigator.push(
                    context,
                    SketchyPageRoute(
                        page: CalendarScreen(profile: profile)));
              },
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFEFEBE9).withOpacity(0.15)
                        : Colors.grey[200]!,
                    width: 1.0,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: profile.profileImageUrl != null &&
                              profile.profileImageUrl!.isNotEmpty
                          ? Image.network(
                              profile.profileImageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                              child: Icon(Icons.person,
                                  size: 80, color: Theme.of(context).colorScheme.onSurface),
                            ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 90,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                  : Colors.grey[200]!,
                              width: 1.0,
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                        ),
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    profile.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.tr('Gevolgde baby', 'Followed baby'),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showUnfollowDialog(context, profile),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.red[950]?.withOpacity(0.3)
                                      : Colors.red[50],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red[200]!,
                                    width: 1.0,
                                  ),
                                ),
                                child: Icon(Icons.person_remove_outlined,
                                    size: 16, color: Colors.red[300]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowedProfilesSection(
      List<Profile> profiles, BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profiles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return ScaleOnTap(
          onTap: () {
            Navigator.push(
                context,
                SketchyPageRoute(
                    page: CalendarScreen(profile: profile)));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFEFEBE9).withOpacity(0.15)
                    : Colors.grey[200]!,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFEFEBE9).withOpacity(0.15)
                          : Colors.grey[200]!,
                      width: 1.0,
                    ),
                    image: profile.profileImageUrl != null &&
                            profile.profileImageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(profile.profileImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: profile.profileImageUrl == null ||
                          profile.profileImageUrl!.isEmpty
                      ? Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      Text(
                        context.tr('Bekijk profiel', 'View profile'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (index == 0)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF38B4B),
                      shape: BoxShape.circle,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  color: Colors.red[300],
                  tooltip: context.tr('Ontvolgen', 'Unfollow'),
                  onPressed: () {
                    _showUnfollowDialog(context, profile);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowProfileButton(BuildContext context, ThemeData theme) {
    return SketchyButton(
      label: context.tr('Profiel volgen', 'Follow profile'),
      icon: const Icon(Icons.person_add_alt_1_outlined),
      onPressed: () => _showFollowDialog(context),
    );
  }

  Future<List<String>> _loadTips(BuildContext context) async {
    try {
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      final isEnglish = localeProvider.locale.languageCode == 'en';
      final fileName = isEnglish ? 'Tips_en.txt' : 'Tips.txt';
      final fileContent = await DefaultAssetBundle.of(context)
          .loadString('assets/tips/$fileName');
      final lines = fileContent.split('\n');
      final List<String> parsedTips = [];
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith('💤') ||
            trimmed.startsWith('🍽️') ||
            trimmed.startsWith('🧸') ||
            trimmed.startsWith('🛠️') ||
            trimmed.startsWith('❤️')) {
          continue;
        }
        parsedTips.add(trimmed);
      }
      return parsedTips;
    } catch (e) {
      final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
      final isEnglish = localeProvider.locale.languageCode == 'en';
      return [
        isEnglish
            ? "Tip of the day: Enjoy the pace of your own baby. Every child develops in their own unique way and speed. Comparing is not necessary!"
            : "Tip van de dag: Geniet van het tempo van jouw eigen baby. Elk kind ontwikkelt zich op zijn eigen unieke manier en snelheid. Vergelijken is nergens voor nodig!"
      ];
    }
  }

  Widget _buildTipOfTheDayCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<List<String>>(
      future: _loadTips(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final tips = snapshot.data!;
        // Rotate deterministically per day
        final dayOfYear = DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays;
        final tipIndex = dayOfYear % tips.length;
        final rawTip = tips[tipIndex];

        // Clean redundant prefix
        var tipText = rawTip;
        if (tipText.startsWith('Tip van de dag:')) {
          tipText = tipText.substring(15).trim();
        } else if (tipText.startsWith('Tip van de dag :')) {
          tipText = tipText.substring(16).trim();
        } else if (tipText.startsWith('Tip of the day:')) {
          tipText = tipText.substring(15).trim();
        } else if (tipText.startsWith('Tip of the day :')) {
          tipText = tipText.substring(16).trim();
        }

        return SketchyContainer(
          fillColor: isDark ? const Color(0xFF1E2C23) : const Color(0xFFE8F3ED),
          borderColor: Colors.transparent,
          borderRadius: 16.0,
          padding: 16.0,
          showShadow: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: isDark ? const Color(0xFF8BBCA0) : const Color(0xFF5C9E76),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Tip van de dag', 'Tip of the day'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFEFEBE9) : const Color(0xFF2D2B2A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tipText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark
                            ? const Color(0xFFEFEBE9).withOpacity(0.85)
                            : const Color(0xFF2D2B2A).withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedNotificationBell extends StatefulWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _AnimatedNotificationBell({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  State<_AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState extends State<_AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _wiggleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _wiggleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: -0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.15, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 30,
      ),
    ]).animate(_controller);

    if (widget.unreadCount > 0) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedNotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unreadCount > 0 && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.unreadCount == 0 && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconData = widget.unreadCount > 0
        ? Icons.notifications_active_outlined
        : Icons.notifications_none_outlined;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _wiggleAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: widget.unreadCount > 0 ? _wiggleAnimation.value : 0.0,
              alignment: Alignment.topCenter,
              child: child,
            );
          },
          child: IconButton(
            icon: Icon(iconData),
            onPressed: widget.onTap,
            tooltip: context.tr('Meldingen', 'Notifications'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        if (widget.unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  widget.unreadCount > 9 ? '9+' : widget.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
