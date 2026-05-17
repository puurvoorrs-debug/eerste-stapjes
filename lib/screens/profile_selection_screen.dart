import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import '../models/profile.dart';
import '../models/app_exception.dart';
import 'create_profile_screen.dart';
import 'calendar_screen.dart';
import 'account_settings_screen.dart';
import 'notifications_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  void _showIncompleteProfileDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profiel Incompleet'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
              );
            },
            child: const Text('Naar Instellingen'),
          ),
        ],
      ),
    );
  }

  void _showFollowDialog(BuildContext context) {
    final codeController = TextEditingController();
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profiel Volgen'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Voer de unieke code in',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final result = await profileProvider.followProfile(codeController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  String message;
                  switch (result) {
                    case 'request_sent':
                      message = 'Volgverzoek verstuurd! Je krijgt toegang zodra de eigenaar dit goedkeurt.';
                      break;
                    case 'already_requested':
                      message = 'Je hebt al een openstaand volgverzoek voor dit profiel.';
                      break;
                    case 'already_following':
                      message = 'Je volgt dit profiel al.';
                      break;
                    case 'own_profile':
                      message = 'Je kunt je eigen profiel niet volgen.';
                      break;
                    case 'invalid_code':
                    default:
                      message = 'Ongeldige code. Controleer de code en probeer het opnieuw.';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              } on IncompleteProfileException catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showIncompleteProfileDialog(context, e.message);
                }
              } catch (e) {
                 if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Er is een onbekende fout opgetreden.')),
                  );
                }
              }
            },
            child: const Text('Volgen'),
          ),
        ],
      ),
    );
  }

  void _showUnfollowDialog(BuildContext context, Profile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profiel Ontvolgen'),
        content: Text('Weet je zeker dat je ${profile.name} wilt ontvolgen? Je kunt de momenten van dit profiel dan niet meer bekijken.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
            onPressed: () async {
              try {
                final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
                await profileProvider.unfollowProfile(profile.id!);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Je bent gestopt met volgen.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Er is een onbekende fout opgetreden.')),
                  );
                }
              }
            },
            child: const Text('Ontvolgen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    // Get display name or default to user
    final displayName = currentUser?.displayName?.split(' ').first ?? 'Gebruiker';

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
                            SvgPicture.asset(
                              'assets/images/Statische_logo_voor_app_icon.svg',
                              width: 80,
                              height: 80,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Welkom!',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Maak een eigen profiel aan om momenten bij te houden, of volg iemand om zijn of haar momenten te bekijken.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 36),
                            // Nieuw profiel aanmaken
                            FilledButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Nieuw profiel aanmaken'),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateProfileScreen()));
                              },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(double.infinity, 54),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Profiel volgen
                            OutlinedButton.icon(
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                              label: const Text('Profiel volgen'),
                              onPressed: () => _showFollowDialog(context),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 54),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final ownProfiles = provider.profiles.where((p) => p.ownerId == currentUser?.uid).toList();
                  final followedProfiles = provider.profiles.where((p) => p.ownerId != currentUser?.uid).toList();

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
                            const Text(
                              'Mijn Profielen',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildOwnProfilesSection(ownProfiles, context),
                            const SizedBox(height: 32),
                            if (followedProfiles.isNotEmpty) ...[
                              const Text(
                                'Gevolgde Profielen',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              _buildFollowedProfilesSection(followedProfiles, context),
                            ],
                          ] else if (followedProfiles.isNotEmpty) ...[
                            // --- Prominent layout when user only follows profiles ---
                            const Text(
                              'Gevolgde Profielen',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildFollowedProfilesProminentSection(followedProfiles, context),
                          ],
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
    final authService = AuthService();
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withOpacity(0.7) ?? Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Hoi, $name 👋',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Row(
            children: [
              _buildNotificationBell(context),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
                },
                tooltip: 'Instellingen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.logout_outlined),
                onPressed: () async {
                  await authService.signOut();
                },
                tooltip: 'Uitloggen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
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

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                );
              },
              tooltip: 'Meldingen',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOwnProfilesSection(List<Profile> profiles, BuildContext context) {
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
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarScreen(profile: profile)));
      },
      child: Container(
        width: 200, // Increased width
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: profile.profileImageUrl != null && profile.profileImageUrl!.isNotEmpty
                  ? Image.network(
                      profile.profileImageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 80, color: Colors.grey),
                    ),
            ),
            // Glassmorphism overlay for bottom text
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color?.withOpacity(0.6) ?? Colors.white.withOpacity(0.6),
                      border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              right: 56, // Leave space for edit button
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Bekijk momenten',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CreateProfileScreen(profile: profile)));
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateProfileScreen()));
      },
      child: Container(
        width: 120, // Slightly wider
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary, // The blush peach color
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 40, color: theme.primaryColor),
            const SizedBox(height: 8),
            Text(
              'Nieuw\nprofiel',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows followed profiles in the large horizontal card style, used when
  /// the user has no own profiles so followed profiles are the primary focus.
  Widget _buildFollowedProfilesProminentSection(List<Profile> profiles, BuildContext context) {
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
          final theme = Theme.of(context);

          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarScreen(profile: profile)));
              },
              child: Container(
                width: 200,
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: profile.profileImageUrl != null && profile.profileImageUrl!.isNotEmpty
                          ? Image.network(
                              profile.profileImageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 80, color: Colors.grey),
                            ),
                    ),
                    // Glassmorphism overlay for bottom text
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 100,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color?.withOpacity(0.6) ?? Colors.white.withOpacity(0.6),
                              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 16,
                      right: 56,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            profile.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Bekijk momenten',
                            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Unfollow button (bottom-right)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: GestureDetector(
                        onTap: () => _showUnfollowDialog(context, profile),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red[300],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_remove_outlined, size: 20, color: Colors.white),
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

  Widget _buildFollowedProfilesSection(List<Profile> profiles, BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: profiles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarScreen(profile: profile)));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profile.profileImageUrl != null && profile.profileImageUrl!.isNotEmpty
                      ? NetworkImage(profile.profileImageUrl!)
                      : null,
                  child: profile.profileImageUrl == null || profile.profileImageUrl!.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Bekijk profiel', // Ideally shows "Nieuwe update" or "2 dagen geleden"
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Indicator dot for updates (placeholder logic: always show for first, hide for others for demo)
                if (index == 0)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  color: Colors.red[300],
                  tooltip: 'Ontvolgen',
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
    return OutlinedButton.icon(
      icon: const Icon(Icons.person_add_alt_1_outlined),
      label: const Text('Profiel volgen'),
      onPressed: () => _showFollowDialog(context),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56), // Full width
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
