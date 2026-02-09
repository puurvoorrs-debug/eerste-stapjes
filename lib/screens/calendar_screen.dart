import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import 'favorites_screen.dart';
import 'create_profile_screen.dart';
import 'dart:developer' as developer;

class CalendarScreen extends StatefulWidget {
  final Profile profile;

  const CalendarScreen({super.key, required this.profile});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  Map<DateTime, DailyEntry> _entries = {};
  StreamSubscription? _entriesSubscription;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now.isAfter(widget.profile.dateOfBirth) ? now : widget.profile.dateOfBirth;
    _selectedDay = _focusedDay;
    _listenToAllEntries();
  }

  void _listenToAllEntries() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.profile.id == null) return;

    _entriesSubscription = FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .collection('profiles').doc(widget.profile.id!)
        .collection('daily_entries')
        .snapshots()
        .listen((snapshot) {
      final newEntries = <DateTime, DailyEntry>{};
      for (var doc in snapshot.docs) {
        try {
          final date = DateTime.parse(doc.id);
          newEntries[date] = DailyEntry.fromMap(doc.data());
        } catch (e, s) {
          developer.log("Error parsing date from document ID: ${doc.id}", name: 'calendar_screen', error: e, stackTrace: s);
        }
      }
      if (mounted) {
        setState(() {
          _entries = newEntries;
        });
      }
    });
  }

  Future<void> _pickImageForSelectedDay() async {
    if (_selectedDay == null || widget.profile.id == null) return;

    final provider = Provider.of<ProfileProvider>(context, listen: false);
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      try {
        await provider.addPhotoToProfile(widget.profile.id!, widget.profile.name, _selectedDay!, File(pickedFile.path));
      } catch (e) {
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fout bij uploaden: $e")));
        }
      }
    }
  }

  List<DailyEntry> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final entry = _entries[normalizedDay];
    return entry != null ? [entry] : [];
  }

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.profiles.firstWhere((p) => p.id == widget.profile.id, orElse: () => widget.profile);
        final dailyEntry = _selectedDay != null ? _getEventsForDay(_selectedDay!).firstOrNull : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(profile.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.star),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FavoritesScreen(profile: profile, entries: _entries)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateProfileScreen(profile: profile)),
                  ).then((_) => setState((){}));
                },
              ),
              IconButton(
                icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  themeProvider.toggleTheme(!themeProvider.isDarkMode);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TableCalendar(
                    locale: 'nl_NL',
                    firstDay: profile.dateOfBirth,
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    onDaySelected: (selectedDay, focusedDay) {
                      if (selectedDay.isAfter(DateTime.now())) return;
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurface),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                      weekendStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                    ),
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      weekendTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      outsideTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(102)),
                       todayDecoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                    ),
                     calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                         if (events.isEmpty) return null;
                        final entry = events.first as DailyEntry;
                        return Center(
                          child: Stack(
                            alignment: Alignment.center,
                             children: [
                               Container(
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber.withAlpha(178), width: 1.5)),
                                 width: 30,
                                 height: 30,
                              ),
                              if (entry.isFavorite)
                                const Positioned(
                                  right: 1,
                                  top: 1,
                                  child: Icon(Icons.star, color: Colors.amber, size: 10),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  _selectedDay != null
                      ? 'Foto voor ${DateFormat('d MMMM yyyy', 'nl_NL').format(_selectedDay!)}'
                      : 'Kies een dag',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                Stack(
                  children: [
                    Container(
                      height: 350,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: dailyEntry != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                                dailyEntry.photoUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  return progress == null ? child : const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.error, color: Colors.red, size: 50)),
                              ),
                          )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.photo_library_outlined, color: Theme.of(context).colorScheme.onSurface.withAlpha(153), size: 60),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Geen foto voor deze dag',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153), fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (dailyEntry != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            dailyEntry.isFavorite ? Icons.star : Icons.star_border,
                            color: dailyEntry.isFavorite ? Colors.amber : Colors.white,
                            size: 30,
                            shadows: [Shadow(color: Colors.black.withAlpha(128), blurRadius: 4)],
                          ),
                          onPressed: () {
                            provider.toggleFavorite(profile.id!, _selectedDay!);
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Foto toevoegen',
            onPressed: _pickImageForSelectedDay,
            child: const Icon(Icons.camera_alt),
          ),
        );
      },
    );
  }
}
