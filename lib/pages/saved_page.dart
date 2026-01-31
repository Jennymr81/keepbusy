// lib/pages/saved_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/event_models.dart';
import '../models/profile.dart';

import '../widgets/selected_session_card.dart';

// ==============================
// Saved Page-specific helpers
// ==============================

/// Local copy of the minutes→TimeOfDay helper so this file is self-contained.
TimeOfDay? minToTime(int? m) =>
    m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);



// ===============================
// SAVED PAGE – SHOW SELECTED SESSIONS ONLY
// ===============================
class SavedPage extends StatefulWidget {
  const SavedPage({
    super.key,
    required this.profiles,
    required this.events,
    required this.sessionSelectionsByEvent,
    required this.onOpenEvent,
    this.onUnselectSession,
  });

  final List<Profile> profiles;
  final List<Event> events;

  /// eventId -> (sessionIndex -> set of profile indexes into [profiles])
  final Map<Id, Map<int, Set<int>>> sessionSelectionsByEvent;

  final void Function(Event e) onOpenEvent;

  /// Called when the user unselects a session from a yellow card
  final void Function(Id eventId, int sessionIndex)? onUnselectSession;

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  /// -1 = All profiles; otherwise index into widget.profiles
  int _selectedProfileIndex = -1;

  // Pick the best image URL/path for this event (same logic as before)
  String? _firstImageLink(Event ev) {
    try {
      final p = ev.imagePath;
      if (p != null && p.trim().isNotEmpty) return p.trim();
    } catch (_) {}

    try {
      for (final u in ev.links) {
        final l = u.toLowerCase();
        if (l.startsWith('assets/')) return u;

        final hasExt = l.endsWith('.jpg') ||
            l.endsWith('.jpeg') ||
            l.endsWith('.png') ||
            l.endsWith('.webp') ||
            l.endsWith('.gif');
        if (l.startsWith('http') && hasExt) return u;

        final isStorageNoExt = l.startsWith('http') &&
            (l.contains('firebasestorage.googleapis.com') ||
                l.contains('supabase') ||
                l.contains('cloudfront') ||
                l.contains('cdn') ||
                l.contains('alt=media'));
        if (isStorageNoExt) return u;
      }
    } catch (_) {}

    return null;
  }

  String _profileLabel(int index) {
    if (index < 0 || index >= widget.profiles.length) {
      return 'Profile ${index + 1}';
    }
    final p = widget.profiles[index];

    final nick = (p.nickname ?? '').trim();
    if (nick.isNotEmpty) return nick;

    final first = (p.firstName ?? '').trim();
    final last = (p.lastName ?? '').trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;

    return 'Profile ${index + 1}';
  }

  // Helpers that mirror the EventDetails page logic
  String _daysLabel(List<EventSlot> list) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final w = list.map((e) => e.date.weekday).toSet().toList()..sort();
    return w.map((x) => names[x - 1]).join(', ');
  }

  String _timeLabel(BuildContext context, List<EventSlot> list) {
    final first = list.first;
    final start = minToTime(first.startMinutes)?.format(context) ?? '';
    final end = minToTime(first.endMinutes)?.format(context) ?? '';
    return [start, end].where((x) => x.isNotEmpty).join(' – ');
  }

  int _computeWeeks(List<EventSlot> list) {
    final uniqueDays = list.map((e) => e.date.weekday).toSet().length;
    if (uniqueDays == 0) return 0;
    return (list.length / uniqueDays).round();
  }

  String _agesLabel(List<EventSlot> list) {
    int? minAge;
    int? maxAge;
    for (final s in list) {
      final a1 = s.ageMin;
      final a2 = s.ageMax;
      if (a1 != null) {
        minAge = (minAge == null || a1 < minAge!) ? a1 : minAge;
      }
      if (a2 != null) {
        maxAge = (maxAge == null || a2 > maxAge!) ? a2 : maxAge;
      }
    }
    if (minAge == null && maxAge == null) return '';
    if (minAge != null && maxAge != null) return '$minAge–$maxAge';
    return (minAge ?? maxAge).toString();
  }

  String _costLabel(List<EventSlot> list) {
    double? c;
    for (final s in list) {
      c ??= s.cost;
    }
    if (c == null) return '';
    return '\$${c!.toStringAsFixed(0)}';
  }

  String _levelLabel(List<EventSlot> list) {
    // Look at all slots in the session and collect non-empty levels
    final levels = <String>{};

    for (final s in list) {
      final l = (s.level ?? '').trim();
      if (l.isNotEmpty) {
        levels.add(l);
      }
    }

    if (levels.isEmpty) return '';
    if (levels.length == 1) return levels.first;
    return levels.join(', ');
  }

  String _md(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    // Build a flat list of “selected session” view models
    final List<_SavedSessionView> selectedSessions = [];

    for (final ev in widget.events) {
      final id = ev.id;
      if (id == null) continue;

      final selectionsForEvent = widget.sessionSelectionsByEvent[id];
      if (selectionsForEvent == null || selectionsForEvent.isEmpty) continue;

      // IMPORTANT:
      // sessionIndex is derived in HomePage as the index in a stable ordering by slotId.
      // SavedPage must use the SAME ordering, otherwise sessionIndex will point to the wrong slot.
      final slots = ev.slotIds.toList()..sort((a, b) => a.id.compareTo(b.id));
      if (slots.isEmpty) continue;


      final imageSrc = (ev.imagePath?.trim().isNotEmpty == true)
          ? ev.imagePath!.trim()
          : (_firstImageLink(ev) ?? 'assets/images/soccer_camp.jpg');

      for (final entry in selectionsForEvent.entries) {
        final sessionIndex = entry.key;
        final profileIdxs = entry.value;
        if (profileIdxs.isEmpty) continue;

        if (sessionIndex < 0 || sessionIndex >= slots.length) continue;


        // FILTER by selected profile (if any)
        if (_selectedProfileIndex >= 0 &&
            !profileIdxs.contains(_selectedProfileIndex)) {
          continue;
        }

        // Slots for this session index
        final sessionSlots = slots
            .where((s) => (s.sessionIndex ?? 0) == sessionIndex)
            .toList();
        if (sessionSlots.isEmpty) continue;

        final first = sessionSlots.first.date;
        final last = sessionSlots.last.date;

        final days = _daysLabel(sessionSlots);
        final time = _timeLabel(context, sessionSlots);
        final weeks = _computeWeeks(sessionSlots);
        final ages = _agesLabel(sessionSlots);
        final cost = _costLabel(sessionSlots);
        final level = _levelLabel(sessionSlots);

        // Location + dates in one line
        final loc = (ev.locationName ?? '').trim();
        final dayDate = [
          if (loc.isNotEmpty) loc,
          '$days • ${_md(first)} – ${_md(last)}',
        ].join(' • ');

        final metaParts = <String>[];
        if (ages.isNotEmpty) metaParts.add('Ages: $ages');
        if (level.isNotEmpty) metaParts.add(level);
        if (weeks > 0) metaParts.add('$weeks weeks');
        if (cost.isNotEmpty) metaParts.add(cost);
        final meta = metaParts.join(' • ');

        final forLabel =
            'For: ' + profileIdxs.map(_profileLabel).join(', ');

        selectedSessions.add(
          _SavedSessionView(
            event: ev,
            eventId: id,
            sessionIndex: sessionIndex,
            eventTitle: ev.title,
            sessionLabel: 'Session ${sessionIndex + 1}',
            dayDateLabel: dayDate,
            timeLabel: time,
            metaLabel: meta,
            forProfilesLabel: forLabel,
            imageSrc: imageSrc,
            profileIndexes: Set<int>.from(profileIdxs),
          ),
        );
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top header – “SAVED EVENTS” bar
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'SAVED EVENTS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 12),

            // PROFILE FILTER ROW – ALWAYS SHOW ALL PROFILES
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ProfileFilterChip(
                    label: 'All profiles',
                    selected: _selectedProfileIndex == -1,
                    onTap: () {
                      setState(() {
                        _selectedProfileIndex = -1;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  for (int i = 0; i < widget.profiles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ProfileFilterChip(
                        label: _profileLabel(i),
                        selected: _selectedProfileIndex == i,
                        onTap: () {
                          setState(() {
                            _selectedProfileIndex = i;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Yellow selected-session cards
            Expanded(
              child: selectedSessions.isEmpty
                  ? Center(
                      child: Text(
                        _selectedProfileIndex == -1
                            ? 'No selected sessions yet.\n\nOpen an event and assign a session to a profile to see it here.'
                            : 'No selected sessions for ${_profileLabel(_selectedProfileIndex)} yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;

                        int cols;
                        if (w >= 1200) {
                          cols = 4;
                        } else if (w >= 900) {
                          cols = 3;
                        } else if (w >= 600) {
                          cols = 2;
                        } else {
                          cols = 1;
                        }

                        return GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 3 / 4,
                          ),
                          itemCount: selectedSessions.length,
                          itemBuilder: (context, i) {
                            final m = selectedSessions[i];
                            return SelectedSessionCard(
                              eventTitle: m.eventTitle,
                              sessionLabel: m.sessionLabel,
                              dayDateLabel: m.dayDateLabel,
                              timeLabel: m.timeLabel,
                              metaLabel: m.metaLabel,
                              forProfilesLabel: m.forProfilesLabel,
                              imageSrc: m.imageSrc,
                              onOpenEvent: () =>
                                  widget.onOpenEvent(m.event),
                              onEditEvent: null,
                              onUnselect: widget.onUnselectSession == null
                                  ? null
                                  : () => widget.onUnselectSession!(
                                      m.eventId, m.sessionIndex),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple “chip” used in the profile filter row
class _ProfileFilterChip extends StatelessWidget {
  const _ProfileFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.secondaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? cs.primary : Colors.black26,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: cs.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple view-model used inside SavedPage
class _SavedSessionView {
  _SavedSessionView({
    required this.event,
    required this.eventId,
    required this.sessionIndex,
    required this.profileIndexes,
    required this.eventTitle,
    required this.sessionLabel,
    required this.dayDateLabel,
    required this.timeLabel,
    required this.metaLabel,
    required this.forProfilesLabel,
    required this.imageSrc,
  });

  final Event event;
  final Id eventId;
  final int sessionIndex;
  final Set<int> profileIndexes;

  final String eventTitle;
  final String sessionLabel;
  final String dayDateLabel;
  final String timeLabel;
  final String metaLabel;
  final String forProfilesLabel;
  final String imageSrc;
}

// ===============================
// SELECTED SESSION CARD WIDGET
// ===============================
class SelectedSessionCard extends StatelessWidget {
  const SelectedSessionCard({
    super.key,
    required this.eventTitle,
    required this.sessionLabel,
    required this.dayDateLabel,
    required this.timeLabel,
    required this.metaLabel,
    required this.forProfilesLabel,
    required this.imageSrc,
    this.onOpenEvent,
    this.onEditEvent,
    this.onUnselect,
  });

  final String eventTitle;
  final String sessionLabel;
  final String dayDateLabel;
  final String timeLabel;
  final String metaLabel;
  final String forProfilesLabel;
  final String imageSrc;

  final VoidCallback? onOpenEvent;
  final VoidCallback? onEditEvent;
  final VoidCallback? onUnselect;

  ImageProvider _imageProvider(String? src) {
    const fallback = 'assets/images/soccer_camp.jpg';

    if (src == null || src.trim().isEmpty) {
      return const AssetImage(fallback);
    }

    final s = src.trim();

    if (s.startsWith('http')) {
      return NetworkImage(s);
    }
    if (s.startsWith('assets/')) {
      return AssetImage(s);
    }
    return FileImage(File(s));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = _imageProvider(imageSrc);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // IMAGE ACROSS TOP
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFF1F1F1)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // EVENT TITLE
          Text(
            eventTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),

          // SESSION LABEL
          if (sessionLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              sessionLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],

          // LOCATION / DAY / DATES
          if (dayDateLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dayDateLabel,
              style: theme.textTheme.bodySmall,
            ),
          ],

          // TIME
          if (timeLabel.isNotEmpty)
            Text(
              timeLabel,
              style: theme.textTheme.bodySmall,
            ),

          const SizedBox(height: 4),

          // META: Ages / level / weeks / cost
          if (metaLabel.isNotEmpty)
            Text(
              metaLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.black87),
            ),

          // FOR: nickname(s)
          if (forProfilesLabel.isNotEmpty)
            Text(
              forProfilesLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Colors.black54),
            ),

          const SizedBox(height: 8),

          // ACTIONS ROW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onUnselect != null)
                IconButton(
                  icon: const Icon(Icons.check_box, size: 20),
                  color: theme.colorScheme.primary,
                  tooltip: 'Unselect this session',
                  onPressed: onUnselect,
                )
              else
                const SizedBox(width: 20),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: onOpenEvent,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('VIEW EVENT'),
                  ),
                  if (onEditEvent != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onEditEvent,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('EDIT EVENT'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
