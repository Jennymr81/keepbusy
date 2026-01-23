// lib/pages/home_page.dart

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:isar/isar.dart';

import '../data/db.dart';
import '../models/event_models.dart';
import '../repositories/local/saved_repository_isar.dart';
import '../utils/file_utils.dart';
import '../utils/profile_label.dart';
import '../widgets/image_helpers.dart';

// Pages
import 'calendar_page.dart';
import 'event_details_page.dart';
import 'event_entry_form_page.dart';
import 'profiles_page.dart';
import 'saved_page.dart';
import 'search_page.dart';

// Profiles
import '../models/profile.dart';
import '../models/profile_color_ext.dart';
import '../repositories/local/profiles_repository_isar.dart';

// ✅ Profile preview popup (import as a prefix so it can NEVER collide / “not be found”)
import '../widgets/profile_preview_dialog_kb.dart' as profilePreview;




///HELPERS///
ImageProvider savedImageProvider(String? path) {
  final p = (path ?? '').trim();

  // ✅ Use an asset you KNOW exists (avoids the profile_placeholder.png error)
  const fallback = AssetImage('assets/keepbusy_logo.png');

  if (p.isEmpty) return fallback;
  if (p.startsWith('http')) return NetworkImage(p);
  if (p.startsWith('assets/')) return AssetImage(p);

  // If it's some other string, just fall back safely for now.
  return fallback;
}

/* =========================
 * HOME (navigation + hero)
 * ========================= */
class KeepBusyHomePage extends StatefulWidget {
  const KeepBusyHomePage({super.key});

  @override
  State<KeepBusyHomePage> createState() => _KeepBusyHomePageState();
}

class _KeepBusyHomePageState extends State<KeepBusyHomePage> {
  /// === PROFILES (USING ISAR SERVICE) ===
  List<Profile> _profiles = [];
  List<Event> _events = [];

  // in-memory favorites / selected (by event Id)
  final Set<Id> _favoriteEventIds = <Id>{};
  final Set<Id> _selectedEventIds = <Id>{};

  // eventId -> (sessionIndex -> set of profile indexes into _profiles)
  Map<Id, Map<int, Set<int>>> _sessionSelections = {};

  int idx = 0;

  void showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reloadEvents() async {
    final isar = await getIsar();
    final fresh = await isar.events.where().findAll();

    if (!mounted) return;
    setState(() => _events = fresh);
  }

  // Load persisted session selections from local storage
  Future<void> _loadSessionSelectionsFromPrefs() async {
    try {
      final loaded = await SavedRepositoryIsar.load();

      if (!mounted) return;
      setState(() {
        _favoriteEventIds
          ..clear()
          ..addAll(loaded.favoriteEventIds);

        _sessionSelections = loaded.sessionSelections;

        // keep _selectedEventIds in sync with saved sessions
        _selectedEventIds
          ..clear()
          ..addAll(_sessionSelections.keys);
      });
    } catch (e, st) {
      debugPrint('Failed to load saved state: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  

  // Save current selections to local storage
  Future<void> _saveSessionSelectionsToPrefs() async {
    try {
      await SavedRepositoryIsar.save(
        favoriteEventIds: _favoriteEventIds,
        sessionSelections: _sessionSelections,
      );
    } catch (e, st) {
      debugPrint('Failed to save saved state: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  void _toggleFavoriteEvent(Event e, bool isFav) {
    setState(() {
      if (isFav) {
        _favoriteEventIds.add(e.id);
      } else {
        _favoriteEventIds.remove(e.id);
      }
    });

    _saveSessionSelectionsToPrefs(); // persist favorites too
  }

  void _toggleSelectedEvent(Event e, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedEventIds.add(e.id);
      } else {
        _selectedEventIds.remove(e.id);
        // Optional: if unselecting the whole event should also clear saved sessions:
        // _sessionSelections.remove(e.id);
      }
    });

    _saveSessionSelectionsToPrefs();
  }

  ///////////**** CSV EXPORT ****//////////////////
  Future<void> _exportEventsToCsv() async {
    final isar = await getIsar();
    final events = await isar.events.where().findAll();

    final header = <String>[
      'id',
      'title',
      'date',
      'city',
      'state',
      'zip',
      'ageMin',
      'ageMax',
      'cost',
      'fee',
      'shortDescription',
    ];

    final rows = events.map((e) {
      final dateStr = e.date == null ? '' : e.date!.toIso8601String().split('T').first;

      return <String?>[
        e.id.toString(),
        e.title,
        dateStr,
        e.city,
        e.state,
        e.zip,
        e.ageMin?.toString(),
        e.ageMax?.toString(),
        e.cost?.toString(),
        e.fee?.toString(),
        e.shortDescription,
      ];
    }).toList();

    final csv = FileUtils.buildCsv(header: header, rows: rows);

    // 1) Copy to clipboard
    await Clipboard.setData(ClipboardData(text: csv));

    // 2) Save to Downloads (not on web)
    String? savedPath;
    if (!kIsWeb) {
      final file = await FileUtils.writeTextToDownloads(
        fileName: 'keepbusy_events.csv',
        contents: csv,
      );
      savedPath = file.path;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedPath == null
              ? 'Events CSV copied. In Google Sheets: Data → Split text to columns (comma).'
              : 'Events CSV saved: $savedPath',
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initDb();
    _loadSessionSelectionsFromPrefs();
  }

  Future<void> _initDb() async {
    await ProfilesRepositoryIsar
.init(); // Initializes Isar
    final profiles = await ProfilesRepositoryIsar
.loadProfiles();

    if (!mounted) return;
    setState(() => _profiles = profiles);

    await _initDbAndLoad(); // loads events
  }

  Future<void> _handleSave(Profile profile) async {
    await ProfilesRepositoryIsar
.saveProfile(profile);

    setState(() {
      final index = _profiles.indexWhere((p) => p.id == profile.id);
      if (index >= 0) {
        _profiles[index] = profile;
      } else {
        _profiles.add(profile);
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  Future<void> _handleDelete(Profile profile) async {
    // 1) Pull a fresh list from DB (so we have real ids)
    final all = await ProfilesRepositoryIsar
.loadProfiles();
    debugPrint('DELETE REQUEST: id=${profile.id}, first=${profile.firstName}');

    // 2) Try to find the target row to delete
    Profile? target;

    // Prefer match by id if present
    if (profile.id > 0) {
      for (final p in all) {
        if (p.id == profile.id) {
          target = p;
          break;
        }
      }
    }

    // Fallback: match by stable fields
    bool sameStr(String? a, String? b) => (a ?? '').trim() == (b ?? '').trim();
    if (target == null) {
      for (final p in all) {
        final same =
            sameStr(p.firstName, profile.firstName) &&
            sameStr(p.lastName, profile.lastName) &&
            p.birthdate == profile.birthdate &&
            sameStr(p.nickname, profile.nickname);
        if (same) {
          target = p;
          break;
        }
      }
    }

    // 3) If we still can't identify it, tell the user and bail
    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not locate this profile to delete')),
      );
      return;
    }

    // 4) Delete that ONE row by id
    await ProfilesRepositoryIsar
.deleteProfile(target);

    // 5) Reload from DB so UI matches exactly
    final fresh = await ProfilesRepositoryIsar
.loadProfiles();
    if (!mounted) return;
    setState(() => _profiles = fresh);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile deleted')),
    );
  }

  // === EVENTS DATABASE ===
  Future<void> _initDbAndLoad() async {
    try {
      final isar = await getIsar();

      final cnt = await isar.events.count();
      debugPrint('KEEPBUSY(Home): events in DB = $cnt');

      final events = await isar.events.where().findAll();
      for (final e in events) {
        await e.slotIds.load();
      }

      if (!mounted) return;
      setState(() => _events = events);
    } catch (e, st) {
      debugPrint('initDb failed: $e');
      debugPrintStack(stackTrace: st);
      showSnack('Init failed: $e');
    }
  }

  void _handleEventDeletedFromSearch(Id deletedId) {
    setState(() {
      _events.removeWhere((ev) => ev.id == deletedId);
      _favoriteEventIds.remove(deletedId);
      _selectedEventIds.remove(deletedId);
      _sessionSelections.remove(deletedId);
    });

    _saveSessionSelectionsToPrefs();
  }

  Future<Event?> _loadEventWithSlots(Id id) async {
    final isar = await getIsar();
    final ev = await isar.events.get(id);
    if (ev != null) await ev.slotIds.load();
    return ev;
  }

  void _addEvent() async {
    final created = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute(
        builder: (_) => EventEntryFormPage(
          profiles: _profiles,
          existing: null,
        ),
      ),
    );
    if (created == null) return;

    final newEvent = created['event'] as Event;
    final newSlots = created['slots'] as List<EventSlot>;

    final isar = await getIsar();
    await isar.writeTxn(() async {
      final id = await isar.events.put(newEvent);
      for (final s in newSlots) {
        final sid = await isar.eventSlots.put(s);
        final slot = await isar.eventSlots.get(sid);
        if (slot != null) newEvent.slotIds.add(slot);
      }
      await newEvent.slotIds.save();
      await isar.events.put(newEvent..id = id);
    });

    if (!mounted) return;
    setState(() => _events.add(newEvent));
    showSnack('Event created');
  }

  static const _dest = [
    (Icons.home, 'Home'),
    (Icons.people, 'Profiles'),
    (Icons.calendar_today, 'Calendar'),
    (Icons.bookmark, 'Saved'),
    (Icons.search, 'Search'),
  ];

  @override
  Widget build(BuildContext context) {
    Widget page;

    switch (idx) {
      case 0:
        page = _home();
        break;

      case 1:
        page = ProfilesPage(
          profiles: _profiles,
          onUpdate: (index, updated) async {
  await _handleSave(updated);
  final fresh = await ProfilesRepositoryIsar.loadProfiles();
  if (!mounted) return;
  setState(() => _profiles = fresh);
},

          onAdd: (newProfile) async {
            await ProfilesRepositoryIsar
.saveProfile(newProfile);
            final fresh = await ProfilesRepositoryIsar
.loadProfiles();
            if (!mounted) return;
            setState(() => _profiles = fresh);
          },
          onDelete: (p) async {
            await _handleDelete(p);
          },
        );
        break;

      case 2:
        page = CalendarPage(
          profiles: _profiles,
          events: _events,
          onOpenProfile: (p) async {
            final result = await Navigator.push<Profile?>(
              context,
              MaterialPageRoute(
                builder: (_) => EditProfilePage(
                  profile: p,
                  onSave: _handleSave,
                ),
              ),
            );

            if (result == null) {
              await _handleDelete(p);
              return;
            }

            if (!mounted) return;
            setState(() {
              final i = _profiles.indexWhere((x) => x.id == result.id);
              if (i >= 0) {
                _profiles[i] = result;
              } else {
                _profiles.add(result);
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile saved')),
            );
          },
          onAddEvent: _addEvent,
          sessionSelections: _sessionSelections,
        );
        break;

      case 3:
        final savedEvents = _events.where((e) {
          final m = _sessionSelections[e.id];
          return m != null && m.isNotEmpty;
        }).toList();

        page = SavedPage(
          profiles: _profiles,
          events: savedEvents,
          sessionSelectionsByEvent: _sessionSelections,
          onOpenEvent: (e) async {
            final full = await _loadEventWithSlots(e.id);
            if (full == null) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event not found')),
              );
              await _reloadEvents();
              return;
            }

            final selIndexOK = (e.profileIndex >= 0 && e.profileIndex < _profiles.length);
            final sel = selIndexOK ? _profiles[e.profileIndex] : (_profiles.isNotEmpty ? _profiles.first : null);

            if (!context.mounted) return;

            final eventId = full.id;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsPage(
                  event: full,
                  profile: sel,
                  profiles: _profiles,
                  sessionSelections: _sessionSelections[eventId] ?? const <int, Set<int>>{},
                  onUpdateSessionSelections: (map) {
                    setState(() {
                      if (map.isEmpty) {
                        _sessionSelections.remove(eventId);
                        _selectedEventIds.remove(eventId);
                      } else {
                        _sessionSelections[eventId] = {
                          for (final entry in map.entries) entry.key: Set<int>.from(entry.value),
                        };
                        _selectedEventIds.add(eventId);
                      }
                    });
                    _saveSessionSelectionsToPrefs();
                  },
                ),
              ),
            );
          },
          onUnselectSession: (eventId, sessionIndex) {
            setState(() {
              final map = _sessionSelections[eventId];
              if (map == null) return;

              map.remove(sessionIndex);
              if (map.isEmpty) {
                _sessionSelections.remove(eventId);
                _selectedEventIds.remove(eventId);
              }
            });
            _saveSessionSelectionsToPrefs();
          },
        );
        break;

      case 4:
        page = SimpleSearchPage(
          profiles: _profiles,
          events: _events,
          loadById: _loadEventWithSlots,
          favoriteEventIds: _favoriteEventIds,
          selectedEventIds: _selectedEventIds,
          onToggleFavorite: _toggleFavoriteEvent,
          onToggleSelected: _toggleSelectedEvent,
          onEventDeleted: _handleEventDeletedFromSearch,
          onOpenEvent: (e) async {
            final full = await _loadEventWithSlots(e.id);
            if (full == null) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event not found')),
              );
              await _reloadEvents();
              return;
            }

            final selIndexOK = (e.profileIndex >= 0 && e.profileIndex < _profiles.length);
            final sel = selIndexOK ? _profiles[e.profileIndex] : (_profiles.isNotEmpty ? _profiles.first : null);

            if (!context.mounted) return;

            final eventId = full.id;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsPage(
                  event: full,
                  profile: sel,
                  profiles: _profiles,
                  sessionSelections: _sessionSelections[eventId] ?? const <int, Set<int>>{},
                  onUpdateSessionSelections: (map) {
                    setState(() {
                      _sessionSelections[eventId] = {
                        for (final entry in map.entries) entry.key: Set<int>.from(entry.value),
                      };
                    });
                    _saveSessionSelectionsToPrefs();
                  },
                ),
              ),
            );
          },
        );
        break;

      default:
        page = _home();
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 720;

        final appBar = AppBar(
          title: const Text('KeepBusy'),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export events to CSV',
              onPressed: _exportEventsToCsv,
            ),
          ],
        );

        if (wide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: idx,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in _dest)
                        NavigationRailDestination(
                          icon: Icon(d.$1),
                          label: Text(d.$2),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                    ],
                    onDestinationSelected: (i) => setState(() => idx = i),
                  ),
                ),
                Expanded(child: page),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: page,
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            destinations: [
              for (final d in _dest) NavigationDestination(icon: Icon(d.$1), label: d.$2),
            ],
            onDestinationSelected: (i) => setState(() => idx = i),
          ),
        );
      },
    );
  }
  
// ==============================
// HOME WIDGETS (SCROLL AREA)
// ==============================
Widget _home() => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Center(
          // ✅ centers the entire "page content area"
          child: ConstrainedBox(
            // ✅ keeps layout nice on wide screens
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),

// ✅ logo centered, small, above the tagline
Center(
  child: Image.asset(
    'assets/keepbusy_logo.png',
    height: 34, // small like before (adjust 30–42 if you want)
    fit: BoxFit.contain,
  ),
),

const SizedBox(height: 6),

Text(
  'Community Classes & Events',
  textAlign: TextAlign.center,
  style: Theme.of(context).textTheme.headlineMedium,
),
const SizedBox(height: 12),

                // ✅ Frosted header search (FULL toolbar like search page)
                // ✅ No hero image behind it
                QuickSearchBar(
                  profiles: _profiles,
                  compact: false,
                  showToolbar: true, // Sort / Advanced / Favorites / Selected
                ),
          

            const SizedBox(height: 18),

             // ===== PROFILES PREVIEW (responsive + pictures) =====
_DashSection(
  title: 'Profiles',
  trailing: TextButton(
    onPressed: () => setState(() => idx = 1),
    child: const Text('See all'),
  ),
  child: _profiles.isEmpty
      ? _EmptyDashCard(
          text: 'No profiles yet. Add one to get started.',
          buttonText: 'Add profile',
          onTap: () => setState(() => idx = 1),
        )
      : Align(
    alignment: Alignment.centerLeft,
    child: _ResponsiveHCarousel(
      itemCount: (_profiles.length > 12) ? 12 : _profiles.length,

      // ✅ tighter even on wide screens
      itemWidth: 140,
      itemHeight: 200,

      twoUpOnNarrow: true,
      gap: 4,                 // ✅ smaller spacing
      arrowGutter: 38,        // ✅ use less “wasted” side space

      buildItem: (i) {
        final p = _profiles[i];
        return _MiniProfileCard(
  label: profileLabel(p),
  color: p.color,
  imageProvider: savedImageProvider(_profileImagePath(p)),
onTap: () {
  profilePreview.openProfilePreviewDialog(
    context: context,
    profile: p,
    color: p.color,
    avatarProvider: savedImageProvider(_profileImagePath(p)),
  );
},


);
      },
    ),
  ),



),

const SizedBox(height: 18),

// ===== CALENDAR PREVIEW (ONLY week strips, no extra title/cards) =====
_DashSection(
  title: 'Calendar',
  trailing: TextButton(
    onPressed: () => setState(() => idx = 2),
    child: const Text('Open'),
  ),
  child: _sessionSelections.isEmpty
      ? _EmptyDashCard(
          text: 'No saved sessions yet.',
          buttonText: 'Go to search',
          onTap: () => setState(() => idx = 4),
        )
      : _ResponsiveWeekStrip(
          focusDate: DateTime.now(),
          itemsByDay: _pipsByDayForHomeWeekPreview(),
          onTap: () => setState(() => idx = 2),
        ),
),

const SizedBox(height: 18),

// ===== SAVED PREVIEW (smaller cards + image, responsive) =====
_DashSection(
  title: 'Saved Sessions',
  trailing: TextButton(
    onPressed: () => setState(() => idx = 3),
    child: const Text('See all'),
  ),
  child: () {
    final savedEvents = _events.where((e) {
      final m = _sessionSelections[e.id];
      return m != null && m.isNotEmpty;
    }).toList();

    if (savedEvents.isEmpty) {
      return _EmptyDashCard(
        text: 'Nothing saved yet. Select sessions from an event.',
        buttonText: 'Find events',
        onTap: () => setState(() => idx = 4),
      );
    }

    final take = savedEvents.take(10).toList();

    return Align(
  alignment: Alignment.centerLeft,
  child: _ResponsiveHCarousel(
  itemCount: take.length,
  itemWidth: 230,
  itemHeight: 240,
  gap: 12,
  arrowGutter: 30,
  wrapOnWide: false,                 // ✅ no stacking on iPad widths
  fadeColor: const Color(0xFFF6F0ED), // ✅ same fade effect as calendar
  buildItem: (i) {
    final e = take[i];
    final summary = _savedEventSummaryForHome(e);
    return _MiniSavedQuickCard(
      title: e.title,
      imageProvider: eventImageProvider(e),
      dateLine: summary.dateLine,
      timeLine: summary.timeLine,
      whoLine: summary.whoLine,
      onView: () => setState(() => idx = 3),
    );
  },
  )
);

  }(),
),

            ],
          ),
        ),
      ),
      ),
);

  /// Week preview pips for the HOME page.
  ///
  /// IMPORTANT: _sessionSelections is Map<Id, Map<int, Set<int>>>
  /// which means: event -> sessionIndex -> set(profileIndex).
  /// It does NOT contain dates, so we place pips on TODAY for now.
  /// Later we can map sessionIndex -> EventSlot date(s).
  Map<DateTime, List<DayPip>> _pipsByDayForHomeWeekPreview() {
  final out = <DateTime, List<DayPip>>{};
  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);

  for (final entry in _sessionSelections.entries) {
    final eventId = entry.key;
    final perSession = entry.value; // Map<int, Set<int>>

    // Find the event (safe)
    Event? ev;
    try {
      ev = _events.firstWhere((x) => x.id == eventId);
    } catch (_) {
      ev = null;
    }

    // Pick a color (safe)
    Color c = const Color(0xFF6FC7BE);
    try {
      final maybe = (ev as dynamic).color;
      if (maybe is Color) c = maybe;
    } catch (_) {}

    final title = (ev?.title ?? 'Saved event');

    // NOTE: your saved-state does not store real dates yet, so we place items on TODAY.
    // Add one line per saved sessionIndex (keeps list readable)
    for (final sessIndex in perSession.keys) {
      (out[todayKey] ??= <DayPip>[]).add(
        DayPip(
          color: c,
          title: title,
          tooltip: 'Session $sessIndex',
        ),
      );
    }
  }

  // Cap for visuals in the week strip (the widget will show "+X more" if needed)
  if ((out[todayKey]?.length ?? 0) > 12) {
    out[todayKey] = out[todayKey]!.take(12).toList();
  }

  return out;
}



  _SavedSummary _savedEventSummaryForHome(Event e) {
  final perSession = _sessionSelections[e.id];
  final sessionsCount = perSession?.length ?? 0;

  // who line: up to 2 names
  final names = <String>{};
  if (perSession != null) {
    for (final set in perSession.values) {
      for (final pi in set) {
        if (pi >= 0 && pi < _profiles.length) {
          names.add(profileLabel(_profiles[pi]));
        }
      }
    }
  }

  final who = names.isEmpty
      ? 'For: —'
      : 'For: ${names.take(2).join(', ')}${names.length > 2 ? ' +' : ''}';

  // date/day
  String dateLine = sessionsCount == 1 ? '1 session saved' : '$sessionsCount sessions saved';
  try {
    if (e.date != null) {
      final d = e.date!;
      const dow = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      dateLine = '${dow[d.weekday - 1]} • ${mon[d.month - 1]} ${d.day}';
    }
  } catch (_) {}

  // time (best-effort)
  String timeLine = '';
  try {
    final dynamic st = (e as dynamic).startTime;
    final dynamic et = (e as dynamic).endTime;
    if (st != null && et != null) timeLine = '$st – $et';
  } catch (_) {}

  return _SavedSummary(dateLine: dateLine, timeLine: timeLine, whoLine: who);
}

String? _profileImagePath(Profile p) {
  final d = p as dynamic;

  // Try common field names without breaking compile if they don’t exist
  try {
    final v = d.imagePath;
    if (v is String && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}

  try {
    final v = d.avatarPath;
    if (v is String && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}

  try {
    final v = d.photoPath;
    if (v is String && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}

  return null;
}


} // ✅ closes class _KeepBusyHomePageState

/// =====================================================
/// BELOW HERE: OUTSIDE the State class
/// =====================================================

class _SavedSummary {
  const _SavedSummary({
    required this.dateLine,
    required this.timeLine,
    required this.whoLine,
  });

  final String dateLine;
  final String timeLine;
  final String whoLine;
}

class _DashSection extends StatelessWidget {
  const _DashSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(
            title,
            style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _EmptyDashCard extends StatelessWidget {
  const _EmptyDashCard({
    required this.text,
    required this.buttonText,
    required this.onTap,
  });

  final String text;
  final String buttonText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onTap, child: Text(buttonText)),
        ],
      ),
    );
  }
}

// Kept (even if not used on Home right now) so nothing breaks elsewhere.
class _MiniInfoCard extends StatelessWidget {
  const _MiniInfoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: .08)),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

// ==============================
// HOME PAGE HELPERS (Carousel + Cards + Profile image provider)
// Paste this ONCE in home_page.dart (outside other widgets/classes)
// ==============================

/// Responsive carousel:
/// - Default: always horizontal scroll (no stacking)
/// - Shows LEFT/RIGHT arrows as soon as content overflows
/// - If twoUpOnNarrow=true: exactly 2 items show on phones and are centered
class _ResponsiveHCarousel extends StatefulWidget {
  const _ResponsiveHCarousel({
    required this.itemCount,
    required this.buildItem,
    required this.itemWidth,
    required this.itemHeight,
    this.twoUpOnNarrow = false,
    this.centerTwoUpOnNarrow = true,
    this.gap = 10,
    this.arrowGutter = 44,
    this.showScrollArrow = true,
    this.fadeColor,
    this.wrapOnWide = false, // keep false so carousels never "stack"
    this.wideWrapBreakpoint = 1100,
  });

  final int itemCount;
  final Widget Function(int i) buildItem;

  final double itemWidth;
  final double itemHeight;

  final bool twoUpOnNarrow;
  final bool centerTwoUpOnNarrow;

  final double gap;
  final double arrowGutter;
  final bool showScrollArrow;

  final Color? fadeColor;

  final bool wrapOnWide;
  final double wideWrapBreakpoint;

  @override
  State<_ResponsiveHCarousel> createState() => _ResponsiveHCarouselState();
}

class _ResponsiveHCarouselState extends State<_ResponsiveHCarousel> {
  final ScrollController _ctl = ScrollController();

  bool get _canLeft => _ctl.hasClients && _ctl.offset > 1;
  bool get _canRight =>
      _ctl.hasClients && _ctl.offset < (_ctl.position.maxScrollExtent - 1);

  void _scrollBy(double dx) {
    if (!_ctl.hasClients) return;
    final max = _ctl.position.maxScrollExtent;
    final target = (_ctl.offset + dx).clamp(0.0, max);
    _ctl.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadeBase =
        widget.fadeColor ?? Theme.of(context).scaffoldBackgroundColor;

    return LayoutBuilder(
      builder: (context, c) {
        final gap = widget.gap;
        final gutter = widget.arrowGutter;

        // Compute item width
        final double effectiveWidth;
        if (widget.twoUpOnNarrow && c.maxWidth < 700) {
          effectiveWidth = ((c.maxWidth - gap) / 2).clamp(140.0, 240.0);
        } else {
          effectiveWidth = widget.itemWidth;
        }

        // Optional wrap mode (off by default)
        final allowWrap =
            widget.wrapOnWide && c.maxWidth >= widget.wideWrapBreakpoint;

        if (allowWrap) {
          return Wrap(
            alignment: WrapAlignment.start,
            spacing: gap,
            runSpacing: gap,
            children: [
              for (int i = 0; i < widget.itemCount; i++)
                SizedBox(
                  width: widget.itemWidth,
                  height: widget.itemHeight,
                  child: widget.buildItem(i),
                ),
            ],
          );
        }

        // Determine overflow (arrows appear as soon as content is clipped)
        final totalContent = (widget.itemCount * effectiveWidth) +
            ((widget.itemCount - 1).clamp(0, 999) * gap);
        final needsScroll = totalContent > c.maxWidth + 1;

        // Base side padding:
        // - Profiles/saved: if 2-up on narrow, center the two items
        // - Otherwise start at left like calendar
        double baseSidePad = 0;

        if (widget.twoUpOnNarrow &&
            c.maxWidth < 700 &&
            widget.centerTwoUpOnNarrow) {
          final twoWidth = (effectiveWidth * 4) + gap;
          baseSidePad = ((c.maxWidth - twoWidth) / 4).clamp(0.0, 999.0);
        } else {
          baseSidePad = 0;
        }

        // If arrows are shown, add gutter so buttons don't cover content
        final sidePad = (needsScroll && widget.showScrollArrow)
            ? (baseSidePad + gutter)
            : baseSidePad;

        return SizedBox(
          height: widget.itemHeight,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  if (mounted) setState(() {});
                  return false;
                },
                child: ListView.separated(
                  controller: _ctl,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.itemCount,
                  padding: EdgeInsets.symmetric(horizontal: sidePad),
                  separatorBuilder: (_, __) => SizedBox(width: gap),
                  itemBuilder: (_, i) => SizedBox(
                    width: effectiveWidth,
                    height: widget.itemHeight,
                    child: widget.buildItem(i),
                  ),
                ),
              ),

              if (needsScroll && widget.showScrollArrow) ...[
                // LEFT fade panel
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: gutter,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            fadeBase.withOpacity(0.75),
                            fadeBase.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // RIGHT fade panel
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: gutter,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            fadeBase.withOpacity(0.75),
                            fadeBase.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // LEFT arrow
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: _canLeft ? 1 : 0.25,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _canLeft
                              ? () => _scrollBy(-(effectiveWidth + gap))
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // RIGHT arrow
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Opacity(
                      opacity: _canRight ? 1 : 0.25,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _canRight
                              ? () => _scrollBy(effectiveWidth + gap)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Calendar week strip: uses WeekColumnsPreview but hides the header/title
class _ResponsiveWeekStrip extends StatelessWidget {
  const _ResponsiveWeekStrip({
    required this.focusDate,
    required this.itemsByDay,
    required this.onTap,
  });

  final DateTime focusDate;
  final Map<DateTime, List<DayPip>> itemsByDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: WeekColumnsPreview(
        focusDate: focusDate,
        itemsByDay: itemsByDay,
        showHeader: false,
        showScrollArrow: true,
        dayCardHeight: 190,
        maxLinesPerDay: 3,
      ),
    );
  }
}

class _MiniProfileCard extends StatelessWidget {
  const _MiniProfileCard({
    required this.label,
    required this.color,
    required this.imageProvider,
    required this.onTap,
  });

  final String label;
  final Color color;
  final ImageProvider imageProvider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundImage: imageProvider,
                backgroundColor: const Color(0xFFEFEFEF),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'View profile',
              style: t.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF0B6F66),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSavedQuickCard extends StatelessWidget {
  const _MiniSavedQuickCard({
    required this.title,
    required this.imageProvider,
    required this.dateLine,
    required this.timeLine,
    required this.whoLine,
    required this.onView,
  });

  final String title;
  final ImageProvider imageProvider;
  final String dateLine;
  final String timeLine;
  final String whoLine;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: .08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 98,
              width: double.infinity,
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFEFE7DA)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            dateLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          if (timeLine.trim().isNotEmpty)
            Text(
              timeLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          Text(
            whoLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                child: const Text('View event'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/* =========================
 * QUICK SEARCH BAR (frosted)
 * Home header preview: includes Search-page style controls row
 * ========================= */
class QuickSearchBar extends StatefulWidget {
  const QuickSearchBar({
    super.key,
    required this.profiles,
    this.compact = false,

    /// Set true on Home page header to show Sort / Advanced / Favorites / Selected
    this.showToolbar = true,
  });

  final List<Profile> profiles;
  final bool compact;
  final bool showToolbar;

  @override
  State<QuickSearchBar> createState() => _QuickSearchBarState();
}

class _QuickSearchBarState extends State<QuickSearchBar> {
  final _whatCtrl = TextEditingController();
  final _whereCtrl = TextEditingController();

  String _sort = 'Soonest';
  bool _favoritesOnly = false;
  bool _selectedOnly = false;

  @override
  void dispose() {
    _whatCtrl.dispose();
    _whereCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final what = _whatCtrl.text.trim();
    final where = _whereCtrl.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Searching: $what  •  $where')),
    );
  }

  void _openAdvancedFiltersPreview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Advanced Filters (preview)')),
    );
  }

  Widget _pillButton({
    required Widget child,
    required VoidCallback onPressed,
    bool outlined = true,
  }) {
    final cs = Theme.of(context).colorScheme;

    final style = outlined
        ? OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.black.withValues(alpha: 0.14)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          )
        : FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          );

    return SizedBox(
      height: 44,
      child: outlined
          ? OutlinedButton(onPressed: onPressed, style: style, child: child)
          : FilledButton(onPressed: onPressed, style: style, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Keep your sizing logic
    final fieldH = widget.compact ? 56.0 : 48.0;
    final gap = widget.compact ? 8.0 : 10.0;
    final double? btnWidth = widget.compact ? null : 140.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 680; // wider breakpoint so toolbar stays nice

              Widget field({
                required TextEditingController ctrl,
                required String hint,
                required IconData icon,
              }) {
                return SizedBox(
                  height: fieldH,
                  child: TextField(
                    controller: ctrl,
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: Icon(icon),
                      hintText: hint,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.15)),
                      ),
                    ),
                  ),
                );
              }

              final btn = SizedBox(
                height: fieldH,
                width: btnWidth,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    backgroundColor: cs.primary,
                  ),
                ),
              );

              // Toolbar row (Search-page style controls)
              Widget toolbarRow() {
                final row = Row(
                  children: [
                    // Sort
                    Text('Sort by', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 8),

                    SizedBox(
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.14)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sort,
                              items: const [
                                DropdownMenuItem(value: 'Soonest', child: Text('Soonest')),
                                DropdownMenuItem(value: 'Closest', child: Text('Closest')),
                                DropdownMenuItem(value: 'Lowest price', child: Text('Lowest price')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _sort = v);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Advanced Filters
                    _pillButton(
                      outlined: true,
                      onPressed: _openAdvancedFiltersPreview,
                      child: const Row(
                        children: [
                          Icon(Icons.tune, size: 18),
                          SizedBox(width: 8),
                          Text('Advanced Filters'),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Favorites
                    _pillButton(
                      outlined: true,
                      onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
                      child: Row(
                        children: [
                          Icon(_favoritesOnly ? Icons.favorite : Icons.favorite_border, size: 18),
                          const SizedBox(width: 8),
                          const Text('Favorites'),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Selected sessions
                    _pillButton(
                      outlined: true,
                      onPressed: () => setState(() => _selectedOnly = !_selectedOnly),
                      child: Row(
                        children: [
                          Icon(_selectedOnly ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
                          const SizedBox(width: 8),
                          const Text('Selected sessions'),
                        ],
                      ),
                    ),
                  ],
                );

                // On narrow screens, make the toolbar horizontally scrollable (so it still matches the Search page feel)
                if (isNarrow) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: row,
                  );
                }
                return row;
              }

              // ===== Layout =====
              if (isNarrow) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field(ctrl: _whatCtrl, hint: 'Search classes & events', icon: Icons.search),
                    SizedBox(height: gap),
                    field(ctrl: _whereCtrl, hint: 'City or ZIP', icon: Icons.place_outlined),
                    SizedBox(height: gap),
                    Align(alignment: Alignment.center, child: btn),

                    if (widget.showToolbar) ...[
                      const SizedBox(height: 10),
                      toolbarRow(),
                    ],
                  ],
                );
              }

              // Wide row (like your screenshot 1 look)
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: field(ctrl: _whatCtrl, hint: 'Search classes & events', icon: Icons.search),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        flex: 4,
                        child: field(ctrl: _whereCtrl, hint: 'City or ZIP', icon: Icons.place_outlined),
                      ),
                      SizedBox(width: gap),
                      btn,
                    ],
                  ),

                  if (widget.showToolbar) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: toolbarRow(),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}


// ==============================
// Week Columns Preview (local)
// Put this at the VERY bottom of home_page.dart (outside all classes)
// ==============================


@immutable
class DayPip {
  const DayPip({
    required this.color,
    this.title,
    this.subtitle,
    this.tooltip,
  });

  final Color color;
  final String? title;     // event title (optional)
  final String? subtitle;  // time or extra info (optional)
  final String? tooltip;
}

class WeekColumnsPreview extends StatefulWidget {
  const WeekColumnsPreview({
    super.key,
    required this.focusDate,
    required this.itemsByDay,
    this.onTapDay,
    this.onTapHeader,
    this.headerTitle = 'MY EVENTS',
    this.showHeader = true,

    // ✅ configurable
    this.showScrollArrow = true,
    this.dayCardHeight = 190,
    this.maxLinesPerDay = 2, // ✅ show 2 items then "X more"
  });

  final DateTime focusDate;

  /// Key MUST be date-only (year, month, day). Values are “pips” (events) to show.
  final Map<DateTime, List<DayPip>> itemsByDay;

  final void Function(DateTime day)? onTapDay;
  final VoidCallback? onTapHeader;

  final String headerTitle;
  final bool showHeader;

  final bool showScrollArrow;
  final double dayCardHeight;
  final int maxLinesPerDay;

  static DateTime d0(DateTime x) => DateTime(x.year, x.month, x.day);

  static DateTime startOfWeekMonday(DateTime d) {
    final day = d0(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static const dow = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  static String dateLabel(DateTime d) => '${mon[d.month - 1]} ${d.day}';

  @override
  State<WeekColumnsPreview> createState() => _WeekColumnsPreviewState();
}

class _WeekColumnsPreviewState extends State<WeekColumnsPreview> {
  final ScrollController _ctl = ScrollController();

  bool _canLeft = false;
  bool _canRight = true;

  void _recalc() {
    if (!_ctl.hasClients) return;
    final p = _ctl.position;
    final left = p.pixels > 2;
    final right = p.pixels < (p.maxScrollExtent - 2);
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _scrollBy(double dx) {
    if (!_ctl.hasClients) return;
    final max = _ctl.position.maxScrollExtent;
    final target = (_ctl.offset + dx).clamp(0.0, max);
    _ctl.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_recalc);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalc());
  }

  @override
  void dispose() {
    _ctl.removeListener(_recalc);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = WeekColumnsPreview.startOfWeekMonday(widget.focusDate);
    final days = List.generate(7, (i) => WeekColumnsPreview.d0(start.add(Duration(days: i))));

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 900;
        final colW = isWide ? 170.0 : 160.0;


final gap = 10.0; // whatever your day-card right margin/spacing is
final total = (7 * colW) + (6 * gap); // 7 cards + 6 gaps
final needsScroll = total > c.maxWidth + 1;

        Widget strip() {
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F0ED),
              borderRadius: BorderRadius.vertical(
                top: widget.showHeader ? Radius.zero : const Radius.circular(14),
                bottom: const Radius.circular(14),
              ),
            ),
            child: Stack(
              children: [
                // ✅ add padding so arrows don't cover content
                // ✅ NO reserved padding (removes solid gutters). We overlay fades + arrows instead.
SingleChildScrollView(
  controller: _ctl,
  scrollDirection: Axis.horizontal,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final day in days)
        _DayColumnCard(
          width: colW,
          height: widget.dayCardHeight,
          dowLabel: WeekColumnsPreview.dow[day.weekday - 1],
          dateLabel: WeekColumnsPreview.dateLabel(day),
          items: widget.itemsByDay[WeekColumnsPreview.d0(day)] ?? const <DayPip>[],
          maxLines: widget.maxLinesPerDay,
          onTap: widget.onTapDay == null ? null : () => widget.onTapDay!(day),
        ),
    ],
  ),
),

// ✅ translucent LEFT fade (so you can still see the card underneath)
if (needsScroll && widget.showScrollArrow)
  Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: 44,
    child: IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFFF6F0ED).withValues(alpha: 0.75),
              const Color(0xFFF6F0ED).withValues(alpha: 0.00),
            ],
          ),
        ),
      ),
    ),
  ),

// ✅ translucent RIGHT fade
if (needsScroll && widget.showScrollArrow)
  Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: 44,
    child: IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              const Color(0xFFF6F0ED).withValues(alpha: 0.75),
              const Color(0xFFF6F0ED).withValues(alpha: 0.00),
            ],
          ),
        ),
      ),
    ),
  ),


                // ✅ LEFT edge fade (transparent)
if (needsScroll && widget.showScrollArrow)
  Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      child: Container(
        width: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFFF6F0ED).withValues(alpha: 0.18),
              const Color(0xFFF6F0ED).withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ),
  ),

// ✅ RIGHT edge fade (transparent)
if (needsScroll && widget.showScrollArrow)
  Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      child: Container(
        width: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              const Color(0xFFF6F0ED).withValues(alpha: 0.18),
              const Color(0xFFF6F0ED).withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    ),
  ),


                // ✅ LEFT arrow
                if (needsScroll && widget.showScrollArrow)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _canLeft ? () => _scrollBy(-240) : null,
                        ),
                      ),
                    ),
                  ),

                // ✅ RIGHT arrow
                if (needsScroll && widget.showScrollArrow)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 1,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _canRight ? () => _scrollBy(240) : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        if (!widget.showHeader) return strip();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0B6F66),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.headerTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (widget.onTapHeader != null)
                    InkWell(
                      onTap: widget.onTapHeader,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.chevron_right, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            strip(),
          ],
        );
      },
    );
  }
}

class _DayColumnCard extends StatelessWidget {
  const _DayColumnCard({
    required this.width,
    required this.height,
    required this.dowLabel,
    required this.dateLabel,
    required this.items,
    required this.maxLines,
    this.onTap,
  });

  final double width;
  final double height;
  final String dowLabel;
  final String dateLabel;
  final List<DayPip> items;
  final int maxLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final shown = items.take(maxLines).toList();
    final remaining = (items.length - shown.length).clamp(0, 999);

    Widget line(DayPip pip) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 18,
              height: 6,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: pip.color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pip.title ?? 'Saved',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if ((pip.subtitle ?? '').isNotEmpty)
                    Text(
                      pip.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7D7A78),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final card = Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DED8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DAY pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7DED8)),
            ),
            child: Text(
              dowLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            dateLabel,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),

          const SizedBox(height: 10),

          if (items.isEmpty)
  Text(
    'No saved',
    style: theme.textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF7D7A78),
      fontWeight: FontWeight.w600,
    ),
  ),


          // ✅ prevents overflow and keeps "X more" visible
          Expanded(
            child: items.isEmpty
                ? const SizedBox()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final pip in shown) line(pip),
                      if (remaining > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '$remaining more',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFF7D7A78),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: card,
    );
  }
}


