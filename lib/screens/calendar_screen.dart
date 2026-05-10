import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'photo_detail_screen.dart';
import 'followers_screen.dart';
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
  CalendarFormat _calendarFormat = CalendarFormat.week;
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
    if (widget.profile.id == null) return;

    _entriesSubscription = FirebaseFirestore.instance
        .collection('profiles')
        .doc(widget.profile.id!)
        .collection('daily_entries')
        .snapshots()
        .listen((snapshot) {
      final newEntries = <DateTime, DailyEntry>{};
      for (var doc in snapshot.docs) {
        try {
          final date = DateTime.parse(doc.id);
          newEntries[date] = DailyEntry.fromMap(doc.data());
        } catch (e, s) {
          developer.log("Error parsing date: ${doc.id}", name: 'calendar_screen', error: e, stackTrace: s);
        }
      }
      if (mounted) {
        setState(() {
          _entries = newEntries;
        });
      }
    });
  }

  // NIEUW: Logica om swipe te verwerken
  void _handleHorizontalSwipe(DragEndDetails details) {
    if (details.primaryVelocity == 0 || _selectedDay == null || _entries.isEmpty) return;

    final sortedDates = _entries.keys.toList()..sort((a, b) => a.compareTo(b));
    final currentIndex = sortedDates.indexWhere((d) => isSameDay(d, _selectedDay!));

    if (currentIndex == -1) return; // Geen entry voor de geselecteerde dag

    int newIndex = currentIndex;
    if (details.primaryVelocity! < 0) { // Swipe naar links (volgende)
      newIndex = (currentIndex + 1).clamp(0, sortedDates.length - 1);
    } else if (details.primaryVelocity! > 0) { // Swipe naar rechts (vorige)
      newIndex = (currentIndex - 1).clamp(0, sortedDates.length - 1);
    }

    if (newIndex != currentIndex) {
      final newDate = sortedDates[newIndex];
      setState(() {
        _selectedDay = newDate;
        _focusedDay = newDate; // Focus de kalender ook op de nieuwe dag
      });
    }
  }

  Future<void> _showAddPhotoDialog() async {
    if (_selectedDay == null || widget.profile.id == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid != widget.profile.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alleen de eigenaar kan foto\'s toevoegen.')),
      );
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final description = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voeg een beschrijving toe'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(labelText: 'Beschrijving (optioneel)'),
            maxLines: 3,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(descriptionController.text);
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );

    if (description != null) {
      final provider = Provider.of<ProfileProvider>(context, listen: false);
      try {
        await provider.addPhotoToProfile(
          widget.profile.id!,
          _selectedDay!,
          File(pickedFile.path),
          description: description,
        );
      } catch (e) {
        if (mounted) {
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

  void _navigateToDetailScreen() {
    if (_selectedDay == null || _entries.isEmpty) return;

    final validEntries = Map<DateTime, DailyEntry>.from(_entries)..removeWhere((key, value) => value == null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoDetailScreen(
          profile: widget.profile,
          entries: validEntries,
          initialDate: _selectedDay!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _entriesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.profile.ownerId;

    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.profiles.firstWhere((p) => p.id == widget.profile.id, orElse: () => widget.profile);
        final dailyEntry = _selectedDay != null ? _getEventsForDay(_selectedDay!).firstOrNull : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(profile.name),
            actions: [
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.people_alt_outlined),
                  tooltip: 'Volgers',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FollowersScreen(profile: profile)),
                    );
                  },
                ),
              if (isOwner && profile.shareCode != null)
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Deel Profiel',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profile.shareCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deelbare code gekopieerd!')),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.star),
                onPressed: () async {
                  final selectedDate = await Navigator.push<DateTime>(
                    context,
                    MaterialPageRoute(builder: (context) => FavoritesScreen(profile: profile, entries: _entries)),
                  );
                  if (selectedDate != null && mounted) {
                    setState(() {
                      _selectedDay = selectedDate;
                      _focusedDay = selectedDate;
                    });
                  }
                },
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateProfileScreen(profile: profile)),
                    ).then((_) => setState(() {}));
                  },
                ),
              IconButton(
                icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => themeProvider.toggleTheme(!themeProvider.isDarkMode),
              ),
            ],
          ),
          body: NotificationListener<OverscrollNotification>(
            onNotification: (notification) {
              if (notification.overscroll > 20 && dailyEntry != null) {
                _navigateToDetailScreen();
                return true;
              }
              return false;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                    calendarFormat: _calendarFormat,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Maand',
                      CalendarFormat.twoWeeks: '2 Weken',
                      CalendarFormat.week: 'Week',
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: true,
                      formatButtonShowsNext: false,
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withAlpha(128),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty || currentUser == null) return null;
                        final entry = events.first as DailyEntry;
                        final bool isFavorited = entry.isFavoritedBy(currentUser.uid);

                        return Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amber.withAlpha(178), width: 1.5)),
                                width: 30,
                                height: 30,
                              ),
                              if (isFavorited)
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
                  _selectedDay != null ? 'Moment van ${DateFormat('d MMMM yyyy', 'nl_NL').format(_selectedDay!)}' : 'Kies een dag',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 15),
                // NIEUW: GestureDetector om de swipe-actie te vangen
                GestureDetector(
                  onHorizontalDragEnd: _handleHorizontalSwipe,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (dailyEntry != null) {
                            _navigateToDetailScreen();
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              height: 500, // Increased height for larger image
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: dailyEntry != null
                                  ? Hero(
                                      tag: 'photo_${_selectedDay!.toIso8601String().split('T').first}',
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Image.network(
                                          dailyEntry.photoUrl,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) {
                                            return progress == null ? child : const Center(child: CircularProgressIndicator());
                                          },
                                          errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.error, color: Colors.red, size: 50)),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.photo_library_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 60),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Geen foto voor deze dag',
                                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                            if (dailyEntry != null)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    color: Colors.black.withOpacity(0.05), // Subtle darkening so the white bubble pops
                                  ),
                                ),
                              ),
                            if (dailyEntry != null)
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 16,
                                child: _buildAnimatedLatestComment(_selectedDay!.toIso8601String().split('T').first),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (dailyEntry != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dailyEntry.description.isNotEmpty)
                                  Text(
                                    dailyEntry.description,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  )
                                else
                                  Text(
                                    'Geen beschrijving toegevoegd.',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(153)),
                                  ),
                                const Divider(height: 20),
                                _buildStatsRow(dailyEntry),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
          ),
          floatingActionButton: isOwner
              ? FloatingActionButton(
                  tooltip: 'Foto toevoegen',
                  onPressed: _showAddPhotoDialog,
                  child: const Icon(Icons.camera_alt),
                )
              : null,
        );
      },
    );
  }

  Widget _buildAnimatedLatestComment(String dateString) {
    return _AnimatedGlassComment(
      profileId: widget.profile.id!,
      dateString: dateString,
    );
  }

  Widget _buildStatsRow(DailyEntry dailyEntry) {
    final dateString = _selectedDay!.toIso8601String().split('T').first;
    final commentsStream = FirebaseFirestore.instance
        .collection('profiles')
        .doc(widget.profile.id)
        .collection('daily_entries')
        .doc(dateString)
        .collection('comments')
        .snapshots();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(Icons.favorite, color: Colors.red[300], size: 18),
        const SizedBox(width: 4),
        Text('${dailyEntry.likes.length}'),
        const SizedBox(width: 16),
        StreamBuilder<QuerySnapshot>(
          stream: commentsStream,
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Row(
              children: [
                Icon(Icons.comment, color: Colors.grey[600], size: 18),
                const SizedBox(width: 4),
                Text('$count'),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnimatedGlassComment extends StatefulWidget {
  final String profileId;
  final String dateString;

  const _AnimatedGlassComment({required this.profileId, required this.dateString});

  @override
  State<_AnimatedGlassComment> createState() => _AnimatedGlassCommentState();
}

class _AnimatedGlassCommentState extends State<_AnimatedGlassComment> with SingleTickerProviderStateMixin {
  late AnimationController _wiggleController;
  Timer? _hideTimer;
  String? _currentCommentId;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void didUpdateWidget(_AnimatedGlassComment oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset animatie en timer wanneer de datum verandert (andere post geswiped)
    if (oldWidget.dateString != widget.dateString) {
      _hideTimer?.cancel();
      _currentCommentId = null;
      setState(() {
        _isVisible = true;
      });
    }
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startTimer(String commentId) {
    if (_currentCommentId != commentId) {
      _currentCommentId = commentId;
      _isVisible = true;
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isVisible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('profiles')
          .doc(widget.profileId)
          .collection('daily_entries')
          .doc(widget.dateString)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final commentDocs = snapshot.data!.docs;
        final docIds = commentDocs.map((d) => d.id).join(',');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startTimer(docIds);
        });

        Widget content;
        if (!_isVisible) {
          content = const SizedBox.shrink(key: ValueKey('empty'));
        } else {
          content = Wrap(
            alignment: WrapAlignment.center,
            spacing: 8.0,
            runSpacing: 8.0,
            children: commentDocs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final userName = data['userName'] ?? 'Gebruiker';
              final commentText = data['commentText'] ?? '';
              final userPhotoUrl = data['userPhotoUrl'] as String?;
              
              return AnimatedBuilder(
                animation: _wiggleController,
                builder: (context, child) {
                  final phase = index * (math.pi / 2);
                  final sinValue = math.sin((_wiggleController.value * 2 * math.pi) + phase);
                  final angle = sinValue * 0.05; // Subtiele wiggle
                  final translateY = sinValue * 4.0;
                  return Transform.translate(
                    offset: Offset(0, translateY),
                    child: Transform.rotate(
                      angle: angle,
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color?.withOpacity(0.6) ?? Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Theme.of(context).primaryColor,
                            backgroundImage: userPhotoUrl != null && userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
                            child: userPhotoUrl == null || userPhotoUrl.isEmpty ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  commentText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: content,
        );
      },
    );
  }
}
