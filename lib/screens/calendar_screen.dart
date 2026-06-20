import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/locale_provider.dart';
import '../models/profile.dart';
import '../widgets/animated_footsteps_circle.dart';
import '../widgets/sketchy_components.dart';
import '../models/daily_entry.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import 'favorites_screen.dart';
import 'create_profile_screen.dart';
import 'photo_detail_screen.dart';
import 'followers_screen.dart';
import '../widgets/animated_sketchy_icons.dart';
import 'dart:developer' as developer;

class CalendarScreen extends StatefulWidget {
  final Profile profile;

  const CalendarScreen({super.key, required this.profile});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  Map<DateTime, DailyEntry> _entries = {};
  StreamSubscription? _entriesSubscription;
  late PageController _pageController;

  late AnimationController _menuAnimationController;
  late Animation<double> _menuAnimation;
  bool _isMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now.isAfter(widget.profile.dateOfBirth)
        ? now
        : widget.profile.dateOfBirth;
    _selectedDay = _focusedDay;
    _listenToAllEntries();

    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuAnimation = CurvedAnimation(
      parent: _menuAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final dob = widget.profile.dateOfBirth;
    final firstDay = DateTime(dob.year, dob.month, dob.day);
    final initialPage = _daysBetween(firstDay, _selectedDay!);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _menuAnimationController.dispose();
    _entriesSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
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
          developer.log("Error parsing date: ${doc.id}",
              name: 'calendar_screen', error: e, stackTrace: s);
        }
      }
      if (mounted) {
        setState(() {
          _entries = newEntries;
        });
      }
    });
  }



  Future<void> _showAddPhotoDialog() async {
    if (_selectedDay == null || widget.profile.id == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.uid != widget.profile.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.tr(
                'Alleen de eigenaar kan foto\'s toevoegen.',
                'Only the owner can add photos.'))),
      );
      return;
    }

    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final description = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SketchyContainer(
          borderRadius: 24,
          padding: 20,
          fillColor: Theme.of(context).cardTheme.color,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Voeg een beschrijving toe', 'Add a description'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: SketchyTextField(
                  controller: descriptionController,
                  labelText: context.tr(
                      'Beschrijving (optioneel)', 'Description (optional)'),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: SketchyButton(
                      label: context.tr('Annuleren', 'Cancel'),
                      fillColor: Colors.white,
                      onPressed: () => Navigator.of(context).pop(),
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SketchyButton(
                      label: context.tr('Opslaan', 'Save'),
                      fillColor: Theme.of(context).primaryColor,
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.of(context).pop(descriptionController.text);
                      },
                      height: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "${context.tr('Fout bij uploaden', 'Error uploading')}: $e")));
        }
      }
    }
  }

  int _daysBetween(DateTime from, DateTime to) {
    final fromUtc = DateTime.utc(from.year, from.month, from.day);
    final toUtc = DateTime.utc(to.year, to.month, to.day);
    return toUtc.difference(fromUtc).inDays;
  }

  List<DailyEntry> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final entry = _entries[normalizedDay];
    return entry != null ? [entry] : [];
  }

  void _navigateToDetailScreen() {
    if (_selectedDay == null || _entries.isEmpty) return;

    final validEntries = Map<DateTime, DailyEntry>.from(_entries)
      ..removeWhere((key, value) => value == null);

    Navigator.push(
      context,
      SketchyPageRoute(
        page: PhotoDetailScreen(
          profile: widget.profile,
          entries: validEntries,
          initialDate: _selectedDay!,
        ),
      ),
    );
  }

  void _showShareCodeDialog(BuildContext context, Profile profile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool copied = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: SketchyContainer(
                borderRadius: 24,
                padding: 20,
                showShadow: false,
                fillColor: Theme.of(context).cardTheme.color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('Deel profiel van ${profile.name}',
                          'Share ${profile.name}\'s profile'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr(
                        'Deel deze unieke code met familie of vrienden zodat zij de stapjes van ${profile.name} kunnen volgen:',
                        'Share this unique code with family or friends so they can follow ${profile.name}\'s steps:',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SketchyContainer(
                      padding: 12,
                      borderRadius: 16,
                      fillColor: Theme.of(context).primaryColor.withOpacity(0.08),
                      showShadow: false,
                      borderColor: Theme.of(context).primaryColor.withOpacity(0.5),
                      child: Center(
                        child: SelectableText(
                          profile.shareCode ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: SketchyButton(
                            label: context.tr('Sluiten', 'Close'),
                            fillColor: Colors.white,
                            onPressed: () => Navigator.of(context).pop(),
                            height: 48,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SketchyButton(
                            label: copied
                                ? context.tr('Gekopieerd!', 'Copied!')
                                : context.tr('Kopieer code', 'Copy code'),
                            fillColor: Theme.of(context).primaryColor,
                            textColor: Colors.white,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: profile.shareCode!));
                              setState(() {
                                copied = true;
                              });
                              Future.delayed(const Duration(seconds: 2), () {
                                if (context.mounted) {
                                  setState(() {
                                    copied = false;
                                  });
                                }
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr(
                                      'Deelbare code gekopieerd naar klembord!',
                                      'Shareable code copied to clipboard!')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            height: 48,
                            icon: Icon(
                              copied ? Icons.check : Icons.copy_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser?.uid == widget.profile.ownerId;

    return Consumer<ProfileProvider>(
      builder: (context, provider, child) {
        final profile = provider.profiles.firstWhere(
            (p) => p.id == widget.profile.id,
            orElse: () => widget.profile);
        final dailyEntry = _selectedDay != null
            ? _getEventsForDay(_selectedDay!).firstOrNull
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Text(profile.name),
            leading: Navigator.canPop(context)
                ? Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: SketchyBackButton(
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  )
                : null,
            actions: [
              if (isOwner)
                _buildAnimatedActions(profile, isOwner)
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Tooltip(
                    message: context.tr('Favorieten', 'Favorites'),
                    child: AnimatedStarIcon(
                      isFilled: true,
                      onTap: () async {
                        final selectedDate = await Navigator.push<DateTime>(
                          context,
                          SketchyPageRoute(
                              page:
                                  FavoritesScreen(profile: profile, entries: _entries)),
                        );
                        if (selectedDate != null && mounted) {
                          setState(() {
                            _selectedDay = selectedDate;
                            _focusedDay = selectedDate;
                          });
                          final dob = widget.profile.dateOfBirth;
                          final firstDay = DateTime(dob.year, dob.month, dob.day);
                          final pageIndex = _daysBetween(firstDay, selectedDate);
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(pageIndex);
                          }
                        }
                      },
                    ),
                  ),
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
                  SketchyContainer(
                    padding: 8.0,
                    fillColor: Theme.of(context).cardTheme.color,
                    borderRadius: 0.0,
                    showShadow: false,
                    child: TableCalendar(
                      locale: context.tr('nl_NL', 'en_US'),
                      firstDay: profile.dateOfBirth,
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        if (selectedDay.isAfter(DateTime.now())) return;
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        final dob = widget.profile.dateOfBirth;
                        final firstDay = DateTime(dob.year, dob.month, dob.day);
                        final pageIndex = _daysBetween(firstDay, selectedDay);
                        if (_pageController.hasClients) {
                          final currentPage = _pageController.page?.round() ?? 0;
                          if ((pageIndex - currentPage).abs() <= 3) {
                            _pageController.animateToPage(
                              pageIndex,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            );
                          } else {
                            _pageController.jumpToPage(pageIndex);
                          }
                        }
                      },
                      calendarFormat: _calendarFormat,
                      availableCalendarFormats: {
                        CalendarFormat.month: context.tr('Maand', 'Month'),
                        CalendarFormat.twoWeeks:
                            context.tr('2 Weken', '2 Weeks'),
                        CalendarFormat.week: context.tr('Week', 'Week'),
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
                          if (events.isEmpty || currentUser == null) {
                            return null;
                          }
                          final entry = events.first as DailyEntry;
                          final bool isFavorited =
                              entry.isFavoritedBy(currentUser.uid);

                          return Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.amber.withAlpha(178),
                                          width: 1.5)),
                                  width: 30,
                                  height: 30,
                                ),
                                if (isFavorited)
                                  const Positioned(
                                    right: 1,
                                    top: 1,
                                    child: Icon(Icons.star,
                                        color: Colors.amber, size: 10),
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
                        ? '${context.tr('Moment van', 'Moment of')} ${DateFormat('d MMMM yyyy', context.tr('nl_NL', 'en_US')).format(_selectedDay!)}'
                        : context.tr('Kies een dag', 'Choose a day'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 15),
                  // PageView.builder to support swipe gesture following the finger
                  SizedBox(
                    height: 500,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _daysBetween(
                              DateTime(profile.dateOfBirth.year, profile.dateOfBirth.month, profile.dateOfBirth.day),
                              DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 365))) + 1,
                      onPageChanged: (index) {
                        final dob = widget.profile.dateOfBirth;
                        final firstDay = DateTime(dob.year, dob.month, dob.day);
                        final newDate = firstDay.add(Duration(days: index));
                        if (newDate.isAfter(DateTime.now())) {
                          _pageController.jumpToPage(_daysBetween(firstDay, DateTime.now()));
                          return;
                        }
                        setState(() {
                          _selectedDay = newDate;
                          _focusedDay = newDate;
                        });
                      },
                      itemBuilder: (context, index) {
                        final dob = widget.profile.dateOfBirth;
                        final firstDay = DateTime(dob.year, dob.month, dob.day);
                        final pageDay = firstDay.add(Duration(days: index));
                        final pageEntry = _getEventsForDay(pageDay).firstOrNull;

                        final now = DateTime.now();
                        final isToday = isSameDay(pageDay, now);
                        final isAfterNudgeTime = now.hour > 7 || (now.hour == 7 && now.minute >= 30);
                        final todayStr = now.toIso8601String().split('T').first;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ScaleOnTap(
                            onTap: () {
                              if (pageEntry != null) {
                                _navigateToDetailScreen();
                              }
                            },
                            child: pageEntry != null
                                ? Hero(
                                    tag: 'photo_${pageDay.toIso8601String().split('T').first}',
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                              : Colors.grey[200]!,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: Container(
                                          height: 500,
                                          width: double.infinity,
                                          color: Theme.of(context).cardTheme.color,
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: Image.network(
                                                  pageEntry.photoUrl,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, progress) {
                                                    return progress == null
                                                        ? child
                                                        : const Center(
                                                            child: AnimatedFootstepsCircle(
                                                                size: 60, showCircle: false),
                                                          );
                                                  },
                                                  errorBuilder: (context, error, stack) =>
                                                      const Center(
                                                          child: Icon(Icons.error,
                                                              color: Colors.red, size: 50)),
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: Container(
                                                  color: Colors.black.withOpacity(0.05),
                                                ),
                                              ),
                                              Positioned(
                                                bottom: 16,
                                                left: 16,
                                                right: 16,
                                                child: _buildAnimatedLatestComment(
                                                    pageDay.toIso8601String().split('T').first),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    height: 500,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardTheme.color,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                            : Colors.grey[200]!,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.photo_library_outlined,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                              size: 60),
                                          const SizedBox(height: 10),
                                          Text(
                                            context.tr(
                                                'Geen foto voor deze dag',
                                                'No photo for this day'),
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                                fontSize: 16),
                                          ),
                                          if (isToday && isAfterNudgeTime && !isOwner) ...[
                                            const SizedBox(height: 24),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 40.0),
                                              child: StreamBuilder<DocumentSnapshot>(
                                                stream: FirebaseFirestore.instance
                                                    .collection('profiles')
                                                    .doc(widget.profile.id)
                                                    .collection('nudges')
                                                    .doc(todayStr)
                                                    .snapshots(),
                                                builder: (context, snapshot) {
                                                  final hasNudged = snapshot.hasData &&
                                                      snapshot.data!.exists &&
                                                      List<String>.from((snapshot.data!.data() as Map<String, dynamic>?)?['nudgeSenders'] ?? [])
                                                          .contains(currentUser?.uid);

                                                  return SketchyButton(
                                                    label: hasNudged
                                                        ? context.tr('Por verstuurd', 'Nudge sent')
                                                        : context.tr('Geef een por', 'Send a nudge'),
                                                    icon: Icon(
                                                      hasNudged ? Icons.check : Icons.touch_app,
                                                      color: hasNudged ? Colors.grey[600] : Colors.white,
                                                    ),
                                                    fillColor: hasNudged ? Colors.grey[300] : Theme.of(context).primaryColor,
                                                    textColor: hasNudged ? Colors.grey[600]! : Colors.white,
                                                    onPressed: hasNudged
                                                        ? null
                                                        : () async {
                                                            try {
                                                              await provider.sendNudge(widget.profile.id!, now);
                                                              if (context.mounted) {
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      context.tr('Por verstuurd!', 'Nudge sent!'),
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            } catch (e) {
                                                              if (context.mounted) {
                                                                ScaffoldMessenger.of(context).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      "${context.tr('Fout bij versturen van por', 'Error sending nudge')}: $e",
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            }
                                                          },
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (dailyEntry != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFEFEBE9).withOpacity(0.15)
                                : Colors.grey[200]!,
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dailyEntry.description.isNotEmpty)
                              Text(
                                dailyEntry.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              )
                            else
                              Text(
                                context.tr(
                                    'Geen beschrijving toegevoegd.',
                                    'No description added.'),
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(153)),
                              ),
                            const Divider(height: 20),
                            _buildStatsRow(dailyEntry),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
          floatingActionButton: isOwner
              ? FloatingActionButton(
                  onPressed: _showAddPhotoDialog,
                  tooltip: context.tr('Foto toevoegen', 'Add photo'),
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 28,
                  ),
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

  Widget _buildAnimatedActions(Profile profile, bool isOwner) {
    return AnimatedBuilder(
      animation: _menuAnimation,
      builder: (context, child) {
        final double animValue = _menuAnimation.value;

        // Build active menu items in order from left to right:
        // [Followers, Share, Favorites, Edit]
        final List<Widget> menuItems = [];

        if (isOwner) {
          menuItems.add(
            Tooltip(
              message: context.tr('Volgers', 'Followers'),
              child: AnimatedFollowersIcon(
                onTap: () {
                  Navigator.push(
                    context,
                    SketchyPageRoute(
                        page: FollowersScreen(profile: profile)),
                  );
                },
              ),
            ),
          );
        }

        if (isOwner && profile.shareCode != null) {
          menuItems.add(
            Tooltip(
              message: context.tr('Deel Profiel', 'Share Profile'),
              child: AnimatedShareIcon(
                onTap: () => _showShareCodeDialog(context, profile),
              ),
            ),
          );
        }

        menuItems.add(
          Tooltip(
            message: context.tr('Favorieten', 'Favorites'),
            child: AnimatedStarIcon(
              isFilled: true,
              onTap: () async {
                final selectedDate = await Navigator.push<DateTime>(
                  context,
                  SketchyPageRoute(
                      page:
                          FavoritesScreen(profile: profile, entries: _entries)),
                );
                if (selectedDate != null && mounted) {
                  setState(() {
                    _selectedDay = selectedDate;
                    _focusedDay = selectedDate;
                  });
                  final dob = widget.profile.dateOfBirth;
                  final firstDay = DateTime(dob.year, dob.month, dob.day);
                  final pageIndex = _daysBetween(firstDay, selectedDate);
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(pageIndex);
                  }
                }
              },
            ),
          ),
        );

        if (isOwner) {
          menuItems.add(
            Tooltip(
              message: context.tr('Bewerk Profiel', 'Edit Profile'),
              child: AnimatedPencilIcon(
                onTap: () {
                  Navigator.push(
                    context,
                    SketchyPageRoute(
                        page:
                            CreateProfileScreen(profile: profile)),
                  ).then((_) => setState(() {}));
                },
              ),
            ),
          );
        }

        final List<Widget> animatedButtons = [];
        final int count = menuItems.length;

        for (int i = 0; i < count; i++) {
          final widgetItem = menuItems[i];
          final double itemWidth = animValue * 48.0;
          final double opacity = animValue.clamp(0.0, 1.0);

          animatedButtons.add(
            Opacity(
              opacity: opacity,
              child: SizedBox(
                width: itemWidth,
                height: 48,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 48,
                    maxWidth: 48,
                    alignment: Alignment.center,
                    child: widgetItem,
                  ),
                ),
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...animatedButtons,
            IconButton(
              tooltip: _isMenuExpanded
                  ? context.tr('Sluit menu', 'Close menu')
                  : context.tr('Open menu', 'Open menu'),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return RotationTransition(
                    turns: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: Icon(
                  _isMenuExpanded ? Icons.close : Icons.menu,
                  key: ValueKey<bool>(_isMenuExpanded),
                ),
              ),
              onPressed: () {
                setState(() {
                  _isMenuExpanded = !_isMenuExpanded;
                  if (_isMenuExpanded) {
                    _menuAnimationController.forward();
                  } else {
                    _menuAnimationController.reverse();
                  }
                });
              },
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedGlassComment extends StatefulWidget {
  final String profileId;
  final String dateString;

  const _AnimatedGlassComment(
      {required this.profileId, required this.dateString});

  @override
  State<_AnimatedGlassComment> createState() => _AnimatedGlassCommentState();
}

class _AnimatedGlassCommentState extends State<_AnimatedGlassComment>
    with SingleTickerProviderStateMixin {
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
              final userName =
                  data['userName'] ?? context.tr('Gebruiker', 'User');
              final commentText = data['commentText'] ?? '';
              final userPhotoUrl = data['userPhotoUrl'] as String?;

              return AnimatedBuilder(
                animation: _wiggleController,
                builder: (context, child) {
                  final phase = index * (math.pi / 2);
                  final sinValue =
                      math.sin((_wiggleController.value * 2 * math.pi) + phase);
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                                .cardTheme
                                .color
                                ?.withOpacity(0.6) ??
                            Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 1.0),
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
                            backgroundImage:
                                userPhotoUrl != null && userPhotoUrl.isNotEmpty
                                    ? NetworkImage(userPhotoUrl)
                                    : null,
                            child: userPhotoUrl == null || userPhotoUrl.isEmpty
                                ? const Icon(Icons.person,
                                    size: 14, color: Colors.white)
                                : null,
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
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  commentText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.8),
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
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutBack)),
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
