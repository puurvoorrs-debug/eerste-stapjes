import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../providers/profile_provider.dart';
import 'create_profile_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    // Widget voor een enkel profiel
    Widget buildProfileAvatar(Profile profile) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CalendarScreen(profile: profile)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundImage: profile.profileImage != null ? FileImage(profile.profileImage!) : null,
              child: profile.profileImage == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 15),
            Text(
              profile.name,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // Grote knop om een eerste profiel toe te voegen
    Widget buildAddFirstProfileButton() {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.black.withAlpha(102),
              child: const Icon(Icons.add, color: Colors.white, size: 50),
            ),
            const SizedBox(height: 15),
            const Text(
              'Profiel toevoegen',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }
    
    // Kleine knop om nog een profiel toe te voegen
    Widget buildAddAnotherProfileButton() {
       return TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateProfileScreen()),
          ),
          icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
          label: const Text('Nog een profiel aanmaken', style: TextStyle(color: Colors.white, fontSize: 16)),
        );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage("assets/images/background.jpg"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(128),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Mijn',
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 35,
                  color: Colors.white,
                ),
              ),
              const Text(
                'eerste stapjes',
                style: TextStyle(
                  fontFamily: 'Pacifico',
                  fontSize: 45,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 50),
              
              if (profileProvider.profiles.isEmpty)
                buildAddFirstProfileButton()
              else
                Column(
                  children: [
                    Wrap(
                      spacing: 30.0,
                      runSpacing: 30.0,
                      alignment: WrapAlignment.center,
                      children: profileProvider.profiles.map((p) => buildProfileAvatar(p)).toList(),
                    ),
                    const SizedBox(height: 30),
                    buildAddAnotherProfileButton(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
