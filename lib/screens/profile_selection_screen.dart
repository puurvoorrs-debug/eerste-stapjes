import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import '../models/profile.dart';
import 'create_profile_screen.dart';
import 'calendar_screen.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
          ),
          // Black Overlay
          Container(
            color: Colors.black.withAlpha(128),
          ),
          // Main Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                const Text(
                  'Eerste stapjes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Pacifico',
                    fontSize: 48,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black54,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                Consumer<ProfileProvider>(
                  builder: (context, provider, child) {
                    if (provider.profiles.isEmpty) {
                      return const Center(
                        child: Text(
                          'Maak een profiel aan om te beginnen.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      );
                    }
                    return SizedBox(
                      height: 200, // Adjust height to fit CircleAvatar and text
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: provider.profiles.length,
                        itemBuilder: (context, index) {
                          final profile = provider.profiles[index];
                          return _buildProfileItem(context, profile);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                _buildAddProfileButton(context),
                const Spacer(flex: 2),
              ],
            ),
          ),
          // Logout Button
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

  Widget _buildProfileItem(BuildContext context, Profile profile) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarScreen(profile: profile),
          ),
        );
      },
      child: Container(
        width: 150, // Fixed width for each item
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
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
                // Edit button as shown in the example image
                GestureDetector(
                  onTap: () {
                    // Navigate to CreateProfileScreen to edit, assuming it handles an optional profile parameter
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CreateProfileScreen(profile: profile)));
                  },
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: Colors.black87,
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
                shadows: [
                   Shadow(
                    blurRadius: 4.0,
                    color: Colors.black87,
                    offset: Offset(1.0, 1.0),
                  ),
                ]
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProfileButton(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
      label: const Text(
        'Nog een profiel aanmaken',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateProfileScreen()));
      },
    );
  }
}
