// lib/pages/search_page.dart

import 'dart:async';                  // StreamSubscription
import 'dart:io' show File;           // FileImage

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';      // FilteringTextInputFormatter, LengthLimiting…
import 'package:intl/intl.dart';             // DateFormat
import 'package:isar/isar.dart';             // Id, Isar

import 'package:keepbusy/data/db.dart';      // getIsar()
import 'package:keepbusy/models/profile.dart';
import 'package:keepbusy/models/event_models.dart';

import 'package:keepbusy/widgets/image_helpers.dart';
import 'event_entry_form_page.dart';

import 'package:geolocator/geolocator.dart';

import 'dart:math';


// ==============================
// Search helpers / constants
// (duplicated from main.dart for now)
// ==============================

const List<String> kSearchInterestOptions = [
  'Dance',
  'Youth sports',
  'Adult sports',
  'Fitness + wellness',
  'Art',
  'Computer programs',
  'STEM',
  'Music',
  'Theater',
  'Martial arts',
  'Language',
  'Tutoring',
  'Volunteering',
  'Outdoor',
  'Cooking',
  'Esports',
  'Other',
];

const List<String> kWeekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

TimeOfDay? minToTime(int? m) =>
    m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);

DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);

int _numWeeksFromDates(Set<DateTime> dates) {
  final buckets = <String>{};
  for (final raw in dates) {
    final dd = _d(raw);
    final monday = dd.subtract(Duration(days: (dd.weekday + 6) % 7));
    final weekNo =
        (monday.difference(DateTime(monday.year, 1, 1)).inDays ~/ 7) + 1;
    buckets.add('${monday.year}-W$weekNo');
  }
  return buckets.length;
}

Color? _profileColor(Profile? p) {
  if (p == null) return null;
  // TODO: when your Profile has a color field, return it here.
  return null;
}


enum SortOption { soonest, costLow, titleAZ, newest, relevant, closest }



// ==============================
// Simple Search (Quick cards)
// ==============================
class SimpleSearchPage extends StatefulWidget {
  const SimpleSearchPage({
    super.key,
    required this.profiles,
    required this.events,
    required this.onOpenEvent,
    required this.loadById,
    this.favoriteEventIds,
    this.selectedEventIds,
    this.onToggleFavorite,
    this.onToggleSelected,
    this.onEventDeleted,
  });

  final List<Profile> profiles;
  final List<Event> events;
  final void Function(Event e) onOpenEvent;
  final Future<Event?> Function(Id id)? loadById;

  // NEW: favorites / selected from the home page
  final Set<Id>? favoriteEventIds;
  final Set<Id>? selectedEventIds;

  // NEW: callbacks to mutate favorites / selected in the home page
  final void Function(Event e, bool isFavorite)? onToggleFavorite;
  final void Function(Event e, bool isSelected)? onToggleSelected;
 final void Function(Id deletedId)? onEventDeleted;


  @override
  State<SimpleSearchPage> createState() => _SimpleSearchPageState();
}



class _SimpleSearchPageState extends State<SimpleSearchPage> {
  String _query = '';
  late List<Event> _events;

    Isar? _isar;
  StreamSubscription<void>? _watch;

  SortOption _sort = SortOption.soonest;

// ---- Location state (needed for Closest / radius) ----
bool _locLoading = false;
String? _locError;
Position? _me;

// ---- Geo: miles between two lat/lng points ----
double _milesBetween(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMeters = 6371000.0;
  double toRad(double d) => d * pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);

  final a = (sin(dLat / 2) * sin(dLat / 2)) +
      cos(toRad(lat1)) * cos(toRad(lat2)) *
          (sin(dLon / 2) * sin(dLon / 2));

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  final meters = earthRadiusMeters * c;
  return meters / 1609.344;
}

// ---- Ensure we have user's device location (for Closest / radius) ----
Future<void> _ensureLocation() async {
  if (kIsWeb) return; // keep it simple for now
  if (_locLoading || _me != null) return;

  setState(() {
    _locLoading = true;
    _locError = null;
  });

  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      if (!mounted) return;
      setState(() {
        _locLoading = false;
        _locError = 'Location permission denied';
      });
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    if (!mounted) return;
    setState(() {
      _me = pos;
      _locLoading = false;
    });
  } catch (_) {
    if (!mounted) return;
    setState(() {
      _locLoading = false;
      _locError = 'Could not get location';
    });
  }
}

// ---- Relevance score for "Most relevant" sorting ----
int _relevanceScore(Event e, String qRaw) {
  final q = qRaw.trim().toLowerCase();
  if (q.isEmpty) return 0;

  final title = e.title.toLowerCase();
  final desc = (e.description ?? '').toLowerCase();
  final city = (e.city ?? '').toLowerCase();
  final interests = (e.interests ?? const <String>[]).join(' ').toLowerCase();

  int score = 0;

  // strong signals
  if (title.contains(q)) score += 50;
  if (title.startsWith(q)) score += 20;

  // medium signals
  if (desc.contains(q)) score += 15;
  if (city.contains(q)) score += 10;
  if (interests.contains(q)) score += 8;

  // token scoring (helps multi-word)
  final tokens = q.split(RegExp(r'\s+')).where((t) => t.length >= 2);
  for (final t in tokens) {
    if (title.contains(t)) score += 12;
    if (desc.contains(t)) score += 4;
    if (interests.contains(t)) score += 3;
  }

  return score;
}



      // ---- Filter state ----
  final TextEditingController _searchCtl = TextEditingController();
  final TextEditingController _zipCtl = TextEditingController();
  final TextEditingController _radiusCtl = TextEditingController();
  final TextEditingController _ageMinCtl = TextEditingController();
  final TextEditingController _ageMaxCtl = TextEditingController();
  final TextEditingController _costCtl = TextEditingController();


  int? _ageMin;      // 0–80+
  int? _ageMax;      // 0–80+
  double? _maxCost;  // "Cost under $___"

  // 1 = Monday ... 7 = Sunday
  final Set<int> _weekdayFilters = <int>{};

  // Interest labels from kSearchInterestOptions (limit 5)
  final Set<String> _interestFilters = <String>{};

    bool _onlyFavorites = false;
  bool _onlySelected = false;

  bool _showAdvanced = false;

  // Level filters (up to 2 at a time)
  final Set<String> _levelFilters = <String>{};
  static const List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];




  // age choices (3–18)
  final List<int> _ageOptions = List<int>.generate(16, (i) => 3 + i);


String? _firstImageLink(Event ev) {
  // 1) Prefer the model field if you added Event.imagePath
  try {
    final p = ev.imagePath;
    if (p != null && p.trim().isNotEmpty) return p.trim();
  } catch (_) {}

  // 2) Otherwise scan Links for an image
  try {
    for (final u in ev.links) {
      final l = u.toLowerCase();

      // App asset path
      if (l.startsWith('assets/')) return u;

      // Direct image URLs by extension
      final hasExt = l.endsWith('.jpg') || l.endsWith('.jpeg') ||
                     l.endsWith('.png') || l.endsWith('.webp') ||
                     l.endsWith('.gif');
      if (l.startsWith('http') && hasExt) return u;

      // Common storage/CDN URLs that often lack extensions
      final isStorageNoExt = l.startsWith('http') &&
          (l.contains('firebasestorage.googleapis.com') ||
           l.contains('supabase') ||
           l.contains('cloudfront') ||
           l.contains('cdn') ||
           l.contains('alt=media'));
      if (isStorageNoExt) return u;
    }
  } catch (_) {}

  // 3) None found
  return null;
}


@override
void initState() {
  super.initState();
  _events = List<Event>.from(widget.events);

  // On web, just use the events list passed in; skip Isar instance/watch.
  if (kIsWeb) return;

  _isar = Isar.getInstance(); // assumes Isar.open(...) ran at app start
  if (_events.isEmpty && _isar != null) {
    _loadFromIsar();
    // live updates when Events change
    _watch = _isar!.events.watchLazy().listen((_) => _loadFromIsar());
  }
}
Future<void> _loadFromIsar() async {
  try {
    final list = await _isar!.events.where().findAll();

    // IMPORTANT: load Isar link data (slots) so weekday filtering works
    for (final ev in list) {
      try {
        await ev.slotIds.load();
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _events = list);
  } catch (e) {
    // optional: debugPrint('Load from Isar failed: $e');
  }
}



@override
void didUpdateWidget(covariant SimpleSearchPage old) {
  super.didUpdateWidget(old);
  if (!identical(old.events, widget.events)) {
    setState(() => _events = List<Event>.from(widget.events));
  }
}


  @override
void dispose() {
  _watch?.cancel();
  _searchCtl.dispose();
  _zipCtl.dispose();
  _radiusCtl.dispose();
  _ageMinCtl.dispose();
  _ageMaxCtl.dispose();
  _costCtl.dispose();
  super.dispose();
}

  void _resetFilters() {
    setState(() {
      _searchCtl.clear();
      _zipCtl.clear();
      _radiusCtl.clear();
      _ageMinCtl.clear();
      _ageMaxCtl.clear();
      _costCtl.clear();
      _costCtl.dispose();


      _query = '';
      _ageMin = null;
      _ageMax = null;
      _maxCost = null;

        _weekdayFilters.clear();
      _interestFilters.clear();
      _onlyFavorites = false;
      _onlySelected = false;
      _levelFilters.clear();
    });
  }


Future<void> _openFiltersPopup() async {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 900;

  Widget content() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _resetFilters();
                    // keep popup open
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Scroll area (stacked blocks)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _filterCard(
                      context,
                      'Location + Age & Cost',
                      Column(
                        children: [
                          // ZIP + Radius
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _zipCtl,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(5),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'ZIP code',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: _radiusCtl,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Miles (radius)',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Age Min/Max + Cost under
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ageMinCtl,
                                  onChanged: (s) {
                                    setState(() {
                                      final v = int.tryParse(s.trim());
                                      _ageMin = (v != null && v >= 0) ? v : null;
                                    });
                                  },
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Min age',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _ageMaxCtl,
                                  onChanged: (s) {
                                    setState(() {
                                      final v = int.tryParse(s.trim());
                                      _ageMax = (v != null && v >= 0) ? v : null;
                                    });
                                  },
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Max age',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
  child: TextField(
    controller: _costCtl,
    onChanged: (s) {
      setState(() {
        final cleaned = s.replaceAll('\$', '').trim();
        _maxCost = double.tryParse(cleaned);
      });
    },
                                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: 'Cost under',
      prefixText: '\$',
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _filterCard(
                      context,
                      'Schedule & Class Level',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level (up to 2)',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _levels.map((label) {
                              final selected = _levelFilters.contains(label);
                              return FilterChip(
                                label: Text(label),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      if (_levelFilters.length < 2) {
                                        _levelFilters.add(label);
                                      }
                                    } else {
                                      _levelFilters.remove(label);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Days of week',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: List.generate(7, (i) {
                              final weekday = i + 1;
                              final label = kWeekdayShort[i];
                              final selected = _weekdayFilters.contains(weekday);
                              return FilterChip(
                                label: Text(label),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _weekdayFilters.add(weekday);
                                    } else {
                                      _weekdayFilters.remove(weekday);
                                    }
                                  });
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    _filterCard(
                      context,
                      'Interests',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose up to 5',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: kSearchInterestOptions.map((label) {
                              final selected = _interestFilters.contains(label);
                              return FilterChip(
                                label: Text(label),
                                selected: selected,
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      if (_interestFilters.length < 5) {
                                        _interestFilters.add(label);
                                      }
                                    } else {
                                      _interestFilters.remove(label);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
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

  if (isDesktop) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: content(),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.88,
        child: content(),
      ),
    );
  }
}


Widget _sectionHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
    ),
  );
}

Widget _filterCard(BuildContext context, String title, Widget child) {
  final theme = Theme.of(context);

  return Container(
    width: double.infinity, // ✅ forces same full-width block like Location
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, // ✅ left-align everything
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),

        // ✅ ensure child also takes full width (prevents “centered small card”)
        SizedBox(
          width: double.infinity,
          child: child,
        ),
      ],
    ),
  );
}



bool get _hasActiveFilters {
  if (_query.trim().isNotEmpty) return true;
  if (_zipCtl.text.trim().isNotEmpty) return true;
  if (_ageMin != null || _ageMax != null) return true;
  if (_maxCost != null) return true;
  if (_weekdayFilters.isNotEmpty) return true;
  if (_levelFilters.isNotEmpty) return true;
  if (_interestFilters.isNotEmpty) return true;
  if (_onlyFavorites) return true;
  return false;
}

String _ageChipLabel() {
  final a = _ageMin;
  final b = _ageMax;
  if (a == null && b == null) return '';
  if (a != null && b != null) {
    final lo = a < b ? a : b;
    final hi = a > b ? a : b;
    return lo == hi ? 'Age: $lo' : 'Age: $lo–$hi';
  }
  final one = a ?? b!;
  return 'Age: $one';
}

Widget _activeFilterChips() {
  if (!_hasActiveFilters) return const SizedBox.shrink();

  final chips = <Widget>[];

  // Search query
  final q = _query.trim();
  if (q.isNotEmpty) {
    chips.add(InputChip(
      label: Text('Search: "$q"'),
      onDeleted: () => setState(() {
        _query = '';
        _searchCtl.clear();
      }),
    ));
  }

  // Favorites / Selected
  if (_onlyFavorites) {
    chips.add(InputChip(
      label: const Text('Favorites'),
      onDeleted: () => setState(() => _onlyFavorites = false),
    ));
  }


  // ZIP
  final zip = _zipCtl.text.trim();
  if (zip.isNotEmpty) {
    chips.add(InputChip(
      label: Text('ZIP: $zip'),
      onDeleted: () => setState(() => _zipCtl.clear()),
    ));
  }

  // Age
  if (_ageMin != null || _ageMax != null) {
    chips.add(InputChip(
      label: Text(_ageChipLabel()),
      onDeleted: () => setState(() {
        _ageMin = null;
        _ageMax = null;
        _ageMinCtl.clear();
        _ageMaxCtl.clear();
      }),
    ));
  }

  // Max cost
  if (_maxCost != null) {
    final v = _maxCost!;
    final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    chips.add(InputChip(
      label: Text('Cost < \$$text'),
      onDeleted: () => setState(() {
        _maxCost = null;
        _costCtl.clear();
      }),
    ));
  }

  // Weekdays
  for (final w in (_weekdayFilters.toList()..sort())) {
    final label = (w >= 1 && w <= 7) ? kWeekdayShort[w - 1] : 'Day $w';
    chips.add(InputChip(
      label: Text(label),
      onDeleted: () => setState(() => _weekdayFilters.remove(w)),
    ));
  }

  // Levels
  for (final lvl in (_levelFilters.toList()..sort())) {
    chips.add(InputChip(
      label: Text(lvl),
      onDeleted: () => setState(() => _levelFilters.remove(lvl)),
    ));
  }

  // Interests (limit 5 already)
  for (final it in (_interestFilters.toList()..sort())) {
    chips.add(InputChip(
      label: Text(it),
      onDeleted: () => setState(() => _interestFilters.remove(it)),
    ));
  }


  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    ),
  );
}



  @override
  Widget build(BuildContext context) {
  final queryLower = _query.trim().toLowerCase();
final zip = _zipCtl.text.trim();
final ageMin = _ageMin;
final ageMax = _ageMax;

final radiusMiles = double.tryParse(_radiusCtl.text.trim());
final needsLocation = !kIsWeb && (_sort == SortOption.closest || (radiusMiles != null && radiusMiles > 0));

if (needsLocation && _me == null && !_locLoading) {
  WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
}

    final filtered = _events.where((e) {


      // Favorites-only filter
      if (_onlyFavorites) {
        final favs = widget.favoriteEventIds;
        if (favs == null || !favs.contains(e.id)) return false;
      }



      // 1) Free-text query on title + description
      if (queryLower.isNotEmpty) {
        final inTitle = e.title.toLowerCase().contains(queryLower);
        final inDesc  = (e.description ?? '').toLowerCase().contains(queryLower);
        if (!inTitle && !inDesc) return false;
      }

            // 2) ZIP code prefix match (e.g., "9174" → 91740, 91741, etc.)
      if (zip.isNotEmpty) {
        final evZip = (e.zip ?? '').trim();
        if (!evZip.startsWith(zip)) return false;
      }


                         // 3) Age filter – interpret Min/Max as the child's age (or age range)
      //
      // If user enters only Min (5), we treat it as "child is 5".
      // If user enters only Max, same idea.
      // If both Min & Max are set, we treat it as a child age range [childMin, childMax].
      //
      // We keep an event only if its age range overlaps the child's age range.
      if (ageMin != null || ageMax != null) {
        final evMin = e.ageMin;
        final evMax = e.ageMax;

        // If the event has no age data at all, hide it when user filters by age
        if (evMin == null && evMax == null) return false;

        // Child age range:
        //  - only Min set  => [Min, Min]
        //  - only Max set  => [Max, Max]
        //  - both set      => [min, max] (order doesn’t matter)
        int childMin;
        int childMax;
        if (ageMin != null && ageMax != null) {
          childMin = ageMin <= ageMax ? ageMin : ageMax;
          childMax = ageMax >= ageMin ? ageMax : ageMin;
        } else if (ageMin != null) {
          childMin = ageMin;
          childMax = ageMin;
        } else {
          // ageMax != null only
          childMin = ageMax!;
          childMax = ageMax!;
        }

        // Event range – if one side is missing, treat it as very open-ended
        final int rMin = evMin ?? childMin; // if no min, assume it can include the child
        final int rMax = evMax ?? childMax; // if no max, assume open-ended

        // If event range is entirely below or above the child range, hide it
        if (rMax < childMin || rMin > childMax) return false;
      }




      // 4) Cost filter – hide events with unknown cost when user filters by price
      if (_maxCost != null) {
        final cost = e.cost;

        // If user cares about price, and we don't know the cost, hide the event
        if (cost == null) return false;

        // Only keep events whose cost is <= the max
        if (cost > _maxCost!) return false;
      }

    // 4.5) Level filter (uses slot levels if available, otherwise event-level fallback)
if (_levelFilters.isNotEmpty) {
  final wanted = _levelFilters.map((s) => s.toLowerCase()).toSet();

  // Try to read level info from slots (if slotIds are loaded)
  final levels = <String>{};
  try {
    for (final s in e.slotIds) {
      final lvl = s.level?.trim();
      if (lvl != null && lvl.isNotEmpty) levels.add(lvl.toLowerCase());
    }
  } catch (_) {}

  // If we couldn't read slots (not loaded), fall back to nothing => hide event when filtering by level
  if (levels.isEmpty) return false;

  // Keep the event if ANY of its levels match the selected filters
  if (!levels.any(wanted.contains)) return false;
}



// 5) Weekday filter (uses slot dates, not just Event.date)
if (_weekdayFilters.isNotEmpty) {
  bool matches = false;

  try {
    // If slots are already loaded on this Event, use them
    final slots = e.slotIds.toList();
    for (final s in slots) {
      if (_weekdayFilters.contains(s.date.weekday)) {
        matches = true;
        break;
      }
    }
  } catch (_) {}

  // Fallback: if we couldn't read slots, fall back to Event.date
  if (!matches) {
    final d = e.date;
    if (d != null && _weekdayFilters.contains(d.weekday)) {
      matches = true;
    }
  }

  if (!matches) return false;
}



      // 6) Interests (simple intersection with event.interests)
      final evInterests = (e.interests ?? const <String>[]).map((s) => s.toLowerCase()).toList();
      if (_interestFilters.isNotEmpty) {
        final wanted = _interestFilters.map((s) => s.toLowerCase()).toSet();
        if (!evInterests.any(wanted.contains)) return false;
      }


      // 7) Favorites / Selected (uses optional sets of IDs if provided)
      if (_onlyFavorites || _onlySelected) {
        final favIds = widget.favoriteEventIds;
        final selIds = widget.selectedEventIds;

        if (_onlyFavorites && !(favIds?.contains(e.id) ?? false)) return false;
        if (_onlySelected && !(selIds?.contains(e.id) ?? false)) return false;
      }

      return true;
    }).toList();


filtered.sort((a, b) {
  DateTime farFuture = DateTime(3000);

  DateTime startDate(Event e) {
    try {
      if (e.slotIds.isNotEmpty) {
        final dates = e.slotIds.map((s) => s.date).toList()..sort();
        return dates.first;
      }
    } catch (_) {}
    return e.date ?? farFuture;
  }

  double cost(Event e) => e.cost ?? double.infinity;
  String title(Event e) => e.title.toLowerCase();

  switch (_sort) {
    case SortOption.soonest:
      return startDate(a).compareTo(startDate(b));

    case SortOption.costLow:
      return cost(a).compareTo(cost(b));

    case SortOption.titleAZ:
      return title(a).compareTo(title(b));

    case SortOption.newest:
      // Best available proxy without a createdAt field:
      // Isar ids generally increase as you add new items.
      return b.id.compareTo(a.id);

    case SortOption.relevant:
      // If no search text, fall back to soonest
      if (_query.trim().isEmpty) {
        return startDate(a).compareTo(startDate(b));
      }
      final sa = _relevanceScore(a, _query);
      final sb = _relevanceScore(b, _query);
      final byScore = sb.compareTo(sa); // higher first
      return byScore != 0 ? byScore : title(a).compareTo(title(b));

    case SortOption.closest:
      // We can't truly sort by distance until Events store lat/lng.
      // For now, keep behavior stable.
      return startDate(a).compareTo(startDate(b));
  }
});



    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
            child: Text('EVENT QUICK VIEW',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
                                                  const SizedBox(height: 8),

        // Search + quick toggles + sort + filters (responsive)
LayoutBuilder(
  builder: (context, c) {
    final theme = Theme.of(context);
    final isWide = c.maxWidth >= 980;

    Widget favChip() {
      final sel = _onlyFavorites;
      return FilterChip(
        selected: sel,
        onSelected: (v) => setState(() => _onlyFavorites = v),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sel ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            const Text('Favorites'),
          ],
        ),
      );
    }

    Widget selectedChip() {
      final sel = _onlySelected;
      return FilterChip(
        selected: sel,
        onSelected: (v) => setState(() => _onlySelected = v),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sel ? Icons.check_box : Icons.check_box_outline_blank,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            const Text('Selected sessions'),
          ],
        ),
      );
    }

    Widget sortDropdown() {
  final theme = Theme.of(context);

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Sort by',
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(width: 8),
      DropdownButtonHideUnderline(
        child: DropdownButton<SortOption>(
          value: _sort,
          onChanged: (v) => setState(() => _sort = v ?? _sort),
          items: const [
  DropdownMenuItem(value: SortOption.soonest, child: Text('Soonest')),
  DropdownMenuItem(value: SortOption.newest, child: Text('Newest added')),
  DropdownMenuItem(value: SortOption.relevant, child: Text('Most relevant')),
  DropdownMenuItem(value: SortOption.costLow, child: Text('Lowest cost')),
  DropdownMenuItem(value: SortOption.titleAZ, child: Text('Title A–Z')),
  DropdownMenuItem(value: SortOption.closest, child: Text('Closest')),
],
        ),
      ),
    ],
  );
}


    Widget filtersBtn() {
      return TextButton(
        onPressed: _openFiltersPopup, // <-- your popup method
        child: const Text('Advanced Filters'),
      );
    }

    // Search field (intentionally NOT full width anymore)
    Widget searchField() {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: TextField(
          controller: _searchCtl,
          onChanged: (s) => setState(() => _query = s),
          decoration: InputDecoration(
            hintText: 'Search events…',
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    if (isWide) {
      return Row(
  children: [
    Flexible(flex: 6, child: searchField()),
    const SizedBox(width: 18),

    // Move sort + filters right next to the search bar
    sortDropdown(),
    const SizedBox(width: 10),
    filtersBtn(),

    const Spacer(),

    // Move Favorites + Selected sessions to the far right
    Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [favChip(), selectedChip()],
    ),
  ],
);

    }

    // Narrow: 2 rows so it never overflows
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: searchField()),
            const SizedBox(width: 10),
            sortDropdown(),
            const SizedBox(width: 6),
            filtersBtn(),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 8, children: [favChip(), selectedChip()]),
      ],
    );
  },
),






          const SizedBox(height: 8),

                                        Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;

                // Helper to build one EventQuickViewCard
                Widget buildCard(int i) {
                  final e = filtered[i];

                  final hasIdx =
                      (e.profileIndex >= 0 && e.profileIndex < widget.profiles.length);
                  final Profile? pForColor = hasIdx
                      ? widget.profiles[e.profileIndex]
                      : (widget.profiles.isNotEmpty
                          ? widget.profiles.first
                          : null);
                  final Color color =
                      _profileColor(pForColor) ?? Theme.of(context).colorScheme.primary;

                  final fullFuture =
                      widget.loadById?.call(e.id) ?? Future<Event?>.value(e);

                  return FutureBuilder<Event?>(
                    future: fullFuture,
                    builder: (context, snap) {
                      // Loading placeholder
                      if (snap.connectionState == ConnectionState.waiting) {
                        return EventQuickViewCard(
                          title: e.title,
                          color: color,
                          shortDescription: e.shortDescription,
                          city: e.city,
                          startDate: e.date,
                          startTime: null,
                          ageMin: e.ageMin,
                          ageMax: e.ageMax,
                          weeks: null,
                          cost: e.cost,
                          imageSrc: _firstImageLink(e),
                          onView: () {},
                          onEdit: null,
                        );
                      }

                      // Error placeholder
                      if (snap.hasError) {
                        return EventQuickViewCard(
                          title: e.title,
                          color: color,
                          shortDescription: 'Unable to load details',
                          city: e.city,
                          startDate: e.date,
                          startTime: null,
                          ageMin: e.ageMin,
                          ageMax: e.ageMax,
                          weeks: null,
                          cost: e.cost,
                          imageSrc: _firstImageLink(e) ??
                              'assets/images/placeholder.jpg',
                          onView: () => widget.onOpenEvent(e),
                          onEdit: () async {},
                        );
                      }

                      final ev = snap.data ?? e;

                      // === Derive summary info from slots ===
                      DateTime? startDate = ev.date;
                      TimeOfDay? startTime;
                      int? weeks;
                      String? daysLabel;
                      int? ageMinCombined;
                      int? ageMaxCombined;
                      String? levelLabel;

                      try {
                        final slots = ev.slotIds.toList()
                          ..sort((a, b) => a.date.compareTo(b.date));
                        if (slots.isNotEmpty) {
                          startDate = slots.first.date;
                          startTime = minToTime(slots.first.startMinutes);

                          // Unique dates (Y-M-D)
                          final dates = slots
                              .map((s) => DateTime(
                                    s.date.year,
                                    s.date.month,
                                    s.date.day,
                                  ))
                              .toSet();

                          // Weeks from distinct dates
                          weeks = _numWeeksFromDates(dates);

                          // All weekdays across all sessions, like "Tue, Thu"
                          final weekdayList = dates
                              .map((d) => d.weekday)
                              .toSet()
                              .toList()
                            ..sort();
                          if (weekdayList.isNotEmpty) {
                            final dayNames = weekdayList
                                .map((w) => kWeekdayShort[w - 1])
                                .join(', ');
                            final city = (ev.city ?? '').trim();
                            daysLabel =
                                city.isNotEmpty ? '$dayNames • $city' : dayNames;
                          }

                          // Overall age range + levels across all slots
                          final levels = <String>{};
                          for (final s in slots) {
                            final mn = s.ageMin;
                            final mx = s.ageMax;
                            if (mn != null) {
                              ageMinCombined = (ageMinCombined == null)
                                  ? mn
                                  : (mn < ageMinCombined!
                                      ? mn
                                      : ageMinCombined!);
                            }
                            if (mx != null) {
                              ageMaxCombined = (ageMaxCombined == null)
                                  ? mx
                                  : (mx > ageMaxCombined!
                                      ? mx
                                      : ageMaxCombined!);
                            }
                            final lvl = s.level?.trim();
                            if (lvl != null && lvl.isNotEmpty) {
                              levels.add(lvl);
                            }
                          }
                          if (levels.isNotEmpty) {
                            final sorted = levels.toList()..sort();
                            levelLabel = sorted.join(' • ');
                          }
                        }
                      } catch (_) {}

                      // Fallbacks if no slots / missing values
                      ageMinCombined ??= ev.ageMin;
                      ageMaxCombined ??= ev.ageMax;

                      final isFav =
                          widget.favoriteEventIds?.contains(ev.id) ?? false;
                      final isSel =
                          widget.selectedEventIds?.contains(ev.id) ?? false;

                      return EventQuickViewCard(
                        title: ev.title,
                        color: color,
                        shortDescription: ev.shortDescription,
                        city: ev.city,
                        startDate: startDate,
                        startTime: startTime,
                        ageMin: ageMinCombined,
                        ageMax: ageMaxCombined,
                        weeks: weeks,
                        cost: ev.cost,
                        subtitle:
                            (daysLabel != null && daysLabel.isNotEmpty)
                                ? daysLabel
                                : null,
                        levelLabel: levelLabel,

                        // NEW: favorites / selected wiring
                        isFavorite: isFav,
                        isSelected: isSel,
                        onToggleFavorite: widget.onToggleFavorite == null
                            ? null
                            : () => widget.onToggleFavorite!(ev, !isFav),
                        onToggleSelected: widget.onToggleSelected == null
                            ? null
                            : () => widget.onToggleSelected!(ev, !isSel),

                        imageSrc: (ev.imagePath?.trim().isNotEmpty == true)
                            ? ev.imagePath
                            : (_firstImageLink(ev) ??
                                'assets/images/soccer_camp.jpg'),
                        onView: () => widget.onOpenEvent(ev),
                        onEdit: () async {
                          final result =
                              await Navigator.push<Map<String, dynamic>?>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventEntryFormPage(
                                profiles: widget.profiles,
                                existing: e,
                              ),
                            ),
                          );

                          // User backed out of the form
                          if (result == null) return;

                          // ========= DELETE from form =========
if (result['delete'] == true) {
  final deletedId = result['id'] as int?;
  if (deletedId != null) {
    final isar = await getIsar();

    await isar.writeTxn(() async {
      // Delete slots first, then the event
      final ev = await isar.events.get(deletedId);
      if (ev != null) {
        await ev.slotIds.load();
        for (final old in ev.slotIds) {
          if (old.id != null) {
            await isar.eventSlots.delete(old.id!);
          }
        }
      }
      await isar.events.delete(deletedId);
    });

        if (!mounted) return;

    setState(() {
      _events.removeWhere((x) => x.id == deletedId);
      filtered.removeWhere((x) => x.id == deletedId);
    });

    // ✅ Tell the parent (_KeepBusyHomePageState) so it can
    // remove this event from its master list and saved sessions.
    widget.onEventDeleted?.call(deletedId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );

  }
  return; // stop here, don’t run the update/save branch
}


                          // ========= UPDATE / SAVE logic =========
                          final updated = result['event'] as Event;
                          final newSlots =
                              (result['slots'] as List<EventSlot>? ??
                                  const []);

                          final isar = await getIsar();
                          await isar.writeTxn(() async {
                            final existing =
                                await isar.events.get(updated.id);
                            if (existing != null) {
                              await existing.slotIds.load();
                              for (final old in existing.slotIds) {
                                if (old.id != null) {
                                  await isar.eventSlots
                                      .delete(old.id!);
                                }
                              }
                            }
                            await isar.events.put(updated);
                            updated.slotIds.clear();
                            for (final s in newSlots) {
                              final sid =
                                  await isar.eventSlots.put(s);
                              final slot =
                                  await isar.eventSlots.get(sid);
                              if (slot != null) {
                                updated.slotIds.add(slot);
                              }
                            }
                            await updated.slotIds.save();
                            await isar.events.put(updated);
                          });

                          final fresh = await (widget.loadById
                                  ?.call(updated.id) ??
                              Future.value(updated));
                          if (!mounted || fresh == null) return;

                          setState(() {
                            final j = _events
                                .indexWhere((x) => x.id == fresh.id);
                            if (j >= 0) {
                              _events[j] = fresh;
                            } else {
                              _events.insert(0, fresh);
                            }
                            final k = filtered
                                .indexWhere((x) => x.id == fresh.id);
                            if (k >= 0) {
                              filtered[k] = fresh;
                            }
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Event updated')),
                          );
                        },
                      );
                    },
                  );
                }

                // ---------- Layout: list for most widths, 2-col grid for very wide ----------
                if (w < 1200) {
                  // PHONE + TABLET + small desktop: single-column list
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: buildCard(i),
                    ),
                  );
                }

                // Very wide: 2-column grid with tighter row height
                const cols = 2;
                const cardH = 190.0;

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 16,
                    mainAxisExtent: cardH,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => buildCard(i),
                );
              },
            ),
          ),
        ],
      ), // Column
    ),
  ); // SafeArea
}
  }


class EventQuickViewCard extends StatelessWidget {
  const EventQuickViewCard({
    super.key,
    required this.title,
    required this.color,
    this.shortDescription,
    this.city,
    this.startDate,
    this.startTime,
    this.ageMin,
    this.ageMax,
    this.weeks,
    this.cost,
    this.subtitle,
    this.levelLabel,
    this.onEdit,
    required this.onView,
    this.imageSrc,
    this.isFavorite = false,
    this.isSelected = false,
    this.onToggleFavorite,
    this.onToggleSelected,
  });


  final String title;
  final Color color;

  final String? shortDescription;
  final String? city;
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final int? ageMin;
  final int? ageMax;
  final int? weeks;
  final double? cost;

  final String? subtitle;
  final String? levelLabel;
  final VoidCallback? onEdit;
  final VoidCallback onView;
  final String? imageSrc;
  final bool isFavorite;
  final bool isSelected;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleSelected;


  ImageProvider _imageProvider(String? src) {
    const fallback = 'assets/placeholders/event.png';

    if (src == null || src.trim().isEmpty) {
      return const AssetImage(fallback);
    }
    if (src.startsWith('http')) {
      return NetworkImage(src);
    }
    if (src.startsWith('assets/')) {
      return AssetImage(src);
    }
    return FileImage(File(src));
  }

  String _weekday(DateTime d) => DateFormat('EEEE').format(d);



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodySmallMuted =
        theme.textTheme.bodySmall?.copyWith(color: Colors.black54);

    // build the top meta lines (same logic as before)
    String line1 = (subtitle ?? '').trim();
    if (line1.isEmpty) {
      final p1 = <String>[];
      if (startDate != null) p1.add(_weekday(startDate!)); // DAY only
      if ((city ?? '').isNotEmpty) p1.add(city!); // CITY
      line1 = p1.join(' • ');
    }

    final meta = <String>[];
    if (ageMin != null || ageMax != null) {
      final a = ageMin?.toString() ?? '';
      final b = ageMax?.toString() ?? '';
      meta.add('Ages: $a${(a.isNotEmpty && b.isNotEmpty) ? '–' : ''}$b');
    }
    if (levelLabel != null && levelLabel!.isNotEmpty) {
      meta.add(levelLabel!);
    }
    if (weeks != null && weeks! > 0) {
      meta.add('$weeks weeks');
    }
    if (cost != null) {
      meta.add('\$${cost!.toStringAsFixed(0)}');
    }
    final line2 = meta.join(' • ');

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Compact layout for phone widths
              final isCompact = constraints.maxWidth < 520;

              final imgH = isCompact ? 160.0 : 130.0;
              final imgW = isCompact ? constraints.maxWidth : 200.0;

              // --- IMAGE ---
              final imageWidget = ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: imgW,
                  height: imgH,
                  child: Image(
                    image: _imageProvider(imageSrc),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFFEFEFEF)),
                  ),
                ),
              );

              // --- TEXT ---
              final textColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  if (line1.isNotEmpty)
                    Text(
                      line1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodySmallMuted,
                    ),
                  if (line2.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bodySmallMuted,
                    ),
                  ],
                  if ((shortDescription ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      shortDescription!,
                      maxLines: isCompact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );

              // --- ACTIONS (fav, selected, buttons) ---
final actionsColumn = Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  mainAxisSize: MainAxisSize.min,
  children: [
    // Favorite heart
    IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: theme.colorScheme.primary,
        size: 22,
      ),
      tooltip: 'Save to favorites',
      onPressed: onToggleFavorite, // can be null; IconButton disables itself
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    ),

    const SizedBox(height: 12),

    // Selected checkbox (commented out "//" for testing)
  //IconButton(
      //icon: Icon(
        //isSelected ? Icons.check_box : Icons.check_box_outline_blank,
        //color: theme.colorScheme.primary,
        //size: 22,
      //),
      //tooltip: 'Mark as selected',
      //onPressed: onToggleSelected,
      //padding: EdgeInsets.zero,
      //constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    //),

    const SizedBox(height: 12),

    // EVENT DETAILS button
    TextButton(
      onPressed: onView,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('EVENT DETAILS'),
    ),

    if (onEdit != null) ...[
      const SizedBox(height: 2),
      TextButton(
        onPressed: onEdit,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('EDIT EVENT'),
      ),
    ],
  ],
);


              if (isCompact) {
                // PHONE / NARROW: stack vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    imageWidget,
                    const SizedBox(height: 10),
                    textColumn,
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // little left padding so it looks balanced
                        const SizedBox(width: 4),
                        actionsColumn,
                      ],
                    ),
                  ],
                );
              } else {
                // WIDE: original side-by-side layout
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imageWidget,
                    const SizedBox(width: 12),
                    Expanded(child: textColumn),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 140,
                      child: actionsColumn,
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
