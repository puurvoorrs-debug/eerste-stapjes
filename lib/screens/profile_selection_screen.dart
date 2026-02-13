import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import '../models/profile.dart';
import '../models/app_exception.dart'; // Importeer de custom exception
import 'create_profile_screen.dart';
import 'calendar_screen.dart';
import 'account_settings_screen.dart';

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
              Navigator.pop(context); // Sluit de huidige dialoog
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
                final success = await profileProvider.followProfile(codeController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(success
                          ? 'Je volgt nu dit profiel!'
                          : 'Ongeldige code of je bent al eigenaar van dit profiel.')));
                }
              } on IncompleteProfileException catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Sluit de volg-dialoog
                  _showIncompleteProfileDialog(context, e.message); // Toon de nieuwe dialoog
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

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withAlpha(128)),
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 40.0, bottom: 20.0),
                  child: Text(
                    'Eerste stapjes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pacifico',
                      fontSize: 48,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 8.0, color: Colors.black54, offset: Offset(2.0, 2.0)),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Consumer<ProfileProvider>(
                    builder: (context, provider, child) {
                      if (provider.profiles.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              'Maak of volg een profiel om te beginnen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                        );
                      }

                      final ownProfiles = provider.profiles.where((p) => p.ownerId == currentUser?.uid).toList();
                      final followedProfiles = provider.profiles.where((p) => p.ownerId != currentUser?.uid).toList();

                      return SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              if (ownProfiles.isNotEmpty)
                                _buildProfileSection('Mijn Profielen', ownProfiles, context, true),
                              if (followedProfiles.isNotEmpty)
                                _buildProfileSection('Gevolgde Profielen', followedProfiles, context, false),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0, top: 20.0),
                  child: Column(
                    children: [
                       _buildAddProfileButton(context),
                       const SizedBox(height: 10),
                       _buildFollowProfileButton(context),
                    ],
                  ),
                )
              ],
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen()));
              },
              tooltip: 'Accountinstellingen',
            ),
          ),
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 30),
              onPressed: () async {
                await authService.signOut();
              },
              tooltip: 'Uitloggen',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(String title, List<Profile> profiles, BuildContext context, bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          alignment: WrapAlignment.center,
          children: profiles.map((profile) => _buildProfileItem(context, profile, editable)).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildProfileItem(BuildContext context, Profile profile, bool editable) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CalendarScreen(profile: profile)));
      },
      child: SizedBox(
        width: 150,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withAlpha(204),
                  backgroundImage: profile.profileImageUrl != null && profile.profileImageUrl!.isNotEmpty
                      ? NetworkImage(profile.profileImageUrl!)
                      : null,
                  child: profile.profileImageUrl == null || profile.profileImageUrl!.isEmpty
                      ? const Icon(Icons.person, size: 80, color: Colors.grey)
                      : null,
                ),
                if (editable)
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: GestureDetector(
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(builder: (context) => CreateProfileScreen(profile: profile)));
                      },
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.edit, size: 22, color: Colors.black87),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              profile.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4.0, color: Colors.black87, offset: Offset(1.0, 1.0))]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProfileButton(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
      label: const Text('Nieuw profiel aanmaken', style: TextStyle(color: Colors.white70, fontSize: 16)),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateProfileScreen()));
      },
    );
  }

  Widget _buildFollowProfileButton(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.group_add_outlined, color: Colors.white70),
      label: const Text('Een profiel volgen', style: TextStyle(color: Colors.white70, fontSize: 16)),
      onPressed: () => _showFollowDialog(context),
    );
  }
}
