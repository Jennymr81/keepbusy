// lib/pages/saved_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../models/event_models.dart';
import '../models/profile.dart';

import '../widgets/selected_session_card.dart';
import 'package:intl/intl.dart';
import '../widgets/profile_preview_dialog_kb.dart';

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
    this.onBrowseEvents,
    this.isAdmin = false,
  });

  final List<Profile> profiles;
  final List<Event> events;

  final Map<Id, Map<int, Set<Id>>> sessionSelectionsByEvent;

  final void Function(Event e) onOpenEvent;

  final void Function(Id eventId, int sessionIndex)? onUnselectSession;

  final VoidCallback? onBrowseEvents;

  final bool isAdmin; // ✅ ADD THIS

  @override
  State<SavedPage> createState() => _SavedPageState();
}

enum _SortOption {
  date,
  title,
  recent,
}

class _SavedPageState extends State<SavedPage> {
  /// -1 = All profiles; otherwise index into widget.profiles
  int _selectedProfileIndex = -1;
  _SortOption _currentSort = _SortOption.date;
  bool _showAllProfiles = false;

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

  String _profileLabel(Id profileId) {
  try {
    final p = widget.profiles.firstWhere((x) => x.id == profileId);

    final nick = (p.nickname ?? '').trim();
    if (nick.isNotEmpty) return nick;

    final first = (p.firstName ?? '').trim();
    final last = (p.lastName ?? '').trim();
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;

    return 'Profile ${p.id}';
  } catch (_) {
    return 'Profile $profileId';
  }
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

    final List<_SavedSessionView> savedSessions = [];

for (final ev in widget.events) {
  final id = ev.id;
  if (id == null) continue;

  final selectionsForEvent = widget.sessionSelectionsByEvent[id];
  if (selectionsForEvent == null || selectionsForEvent.isEmpty) continue;

  final slots = ev.slotIds.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  if (slots.isEmpty) continue;

  final imageSrc = (ev.imagePath?.trim().isNotEmpty == true)
      ? ev.imagePath!.trim()
      : (_firstImageLink(ev) ?? 'assets/soccer_camp.jpg');

  for (final entry in selectionsForEvent.entries) {
    final sessionIndex = entry.key;
    final profileIdxs = entry.value;
    if (profileIdxs.isEmpty) continue;

    if (_selectedProfileIndex >= 0) {
  final selectedProfileId =
      widget.profiles[_selectedProfileIndex].id;

  if (!profileIdxs.contains(selectedProfileId)) {
    continue;
  }
}

    final sessionSlots = slots
        .where((s) => (s.sessionIndex ?? 0) == sessionIndex)
        .toList();
    if (sessionSlots.isEmpty) continue;

sessionSlots.sort((a, b) => a.date.compareTo(b.date));

    final first = sessionSlots.first.date;
    final last = sessionSlots.last.date;
    final days = _daysLabel(sessionSlots);
    final time = _timeLabel(context, sessionSlots);
    final weeks = _computeWeeks(sessionSlots);
    final ages = _agesLabel(sessionSlots);
    final cost = _costLabel(sessionSlots);
    final level = _levelLabel(sessionSlots);
  

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

final sessionLocation = slots
    .where((s) => s.sessionIndex == sessionIndex)
    .map((s) => s.locationName ?? '')
    .firstWhere((loc) => loc.isNotEmpty, orElse: () => '');

    final sessionView = _SavedSessionView(
  event: ev,
  eventId: id,
  sessionIndex: sessionIndex,
  firstDate: first,
  lastDate: last,
  eventTitle: ev.title,
  sessionLabel: 'Session ${sessionIndex + 1}',
  dayDateLabel: dayDate,
  timeLabel: time,
  metaLabel: meta,
  forProfilesLabel: forLabel,
  imageSrc: imageSrc,
  sessionLocation: sessionLocation,

  profileIds: Set<Id>.from(profileIdxs),
);

    savedSessions.add(sessionView);
  }
}

savedSessions.sort((a, b) {
  switch (_currentSort) {
    case _SortOption.date:
      return a.firstDate.compareTo(b.firstDate);

    case _SortOption.title:
      return a.eventTitle.toLowerCase().compareTo(
            b.eventTitle.toLowerCase(),
          );

    case _SortOption.recent:
      return b.firstDate.compareTo(a.firstDate);
  }
});

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
LayoutBuilder(
  builder: (context, constraints) {
    final isNarrow = constraints.maxWidth < 1000;

    if (isNarrow) {
  final visibleEntries = _showAllProfiles
      ? widget.profiles.asMap().entries
      : widget.profiles.asMap().entries.take(5);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
                _ProfileFilterChip(
                  label: 'All',
                  selected: _selectedProfileIndex == -1,
                  onTap: () {
                    setState(() {
                      _selectedProfileIndex = -1;
                    });
                  },
                ),
                const SizedBox(width: 8),

                for (final entry in visibleEntries) ...[
                  Builder(
                    builder: (context) {
                      final i = entry.key;
final p = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _ProfileFilterChip(
                          label: _profileLabel(p.id),
                          profile: p,
                          selected: _selectedProfileIndex == i,
                          onTap: () {
                            setState(() {
                              _selectedProfileIndex = i;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),

              const SizedBox(height: 8),

            if (widget.profiles.length > 6)
  Padding(
    padding: const EdgeInsets.only(top: 6),
    child: GestureDetector(
      onTap: () {
        setState(() {
          _showAllProfiles = !_showAllProfiles;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _showAllProfiles ? 'Show less' : 'Show more',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _showAllProfiles
                ? Icons.expand_less
                : Icons.expand_more,
            size: 18,
          ),
        ],
      ),
    ),
  ),

          const SizedBox(height: 12),

          ToggleButtons(
            isSelected: [
              _currentSort == _SortOption.date,
              _currentSort == _SortOption.title,
            ],
            onPressed: (index) {
              setState(() {
                _currentSort =
                    index == 0 ? _SortOption.date : _SortOption.title;
              });
            },
            borderRadius: BorderRadius.circular(10),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Date'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Title'),
              ),
            ],
          ),
          const SizedBox(width: 12),

        ],
      );
    }

    // WIDE layout (desktop)
    return SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: ConstrainedBox(
    constraints: BoxConstraints(
      minWidth: constraints.maxWidth,
    ),
    child: Row(
        children: [
          _ProfileFilterChip(
            label: 'All',
            selected: _selectedProfileIndex == -1,
            onTap: () {
              setState(() {
                _selectedProfileIndex = -1;
              });
            },
          ),
          const SizedBox(width: 8),

          for (int i = 0; i < widget.profiles.length; i++) ...[
            Builder(
              builder: (context) {
                final p = widget.profiles[i];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ProfileFilterChip(
                    label: _profileLabel(p.id),
                    profile: p,
                    selected: _selectedProfileIndex == i,
                    onTap: () {
                      setState(() {
                        _selectedProfileIndex = i;
                      });
                    },
                  ),
                );
              },
            ),
          ],

          const SizedBox(width: 16),

          ToggleButtons(
            isSelected: [
              _currentSort == _SortOption.date,
              _currentSort == _SortOption.title,
            ],
            onPressed: (index) {
              setState(() {
                _currentSort =
                    index == 0 ? _SortOption.date : _SortOption.title;
              });
            },
            borderRadius: BorderRadius.circular(10),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Date'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Title'),
              ),
            ],
          ),
        ],
      ),
  ),
    );
  },
),

const SizedBox(height: 12),

const SizedBox(height: 12),

            // selected-session cards
            Expanded(
  child: savedSessions.isEmpty
      ? Center(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 44,
        ),
        decoration: BoxDecoration(
  color: Theme.of(context)
      .colorScheme
      .surfaceVariant
      .withOpacity(.20),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(
    color: Theme.of(context)
        .colorScheme
        .outlineVariant
        .withOpacity(.4),
  ),
),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
  Icons.bookmark_border,
  size: 60,
  color: Theme.of(context)
      .colorScheme
      .primary
      .withOpacity(.65),
),
            const SizedBox(height: 20),

            // 🔹 Title
            Text(
              _selectedProfileIndex == -1
                  ? 'No saved sessions yet'
                  : 'No saved sessions for ${_profileLabel(widget.profiles[_selectedProfileIndex].id)}',
              textAlign: TextAlign.center,
             style: Theme.of(context)
    .textTheme
    .headlineSmall
    ?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: .2,
    ),
            ),

            const SizedBox(height: 14),

            // 🔹 Helper text (softer + clearer)
            Text(
              'Browse events and save sessions to quickly access them here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
            ),

            const SizedBox(height: 32),

            // 🔹 CTA
            ElevatedButton(
              onPressed: () {
                if (widget.onBrowseEvents != null) {
                  widget.onBrowseEvents!();
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: const Text('Browse Events'),
            ),
          ],
        ),
      ),
    ),
  ),
)
      : ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final now = DateTime.now();

final activeSessions = <_SavedSessionView>[];
final pastSessions = <_SavedSessionView>[];

for (final m in savedSessions) {
  if (m.lastDate.isBefore(now)) {
    pastSessions.add(m);
  } else {
    activeSessions.add(m);
  }
}
               const minCardWidth = 540.0;
final canUseTwoCols =
    constraints.maxWidth >= (minCardWidth * 2 + 24);

if (!canUseTwoCols) {
  return Column(
    children: [
      ...activeSessions.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SelectedSessionCard(
            eventTitle: m.eventTitle,
            sessionLabel: m.sessionLabel,
            dayDateLabel: m.dayDateLabel,
            timeLabel: m.timeLabel,
            metaLabel: m.metaLabel,
            forProfilesLabel: m.forProfilesLabel,
            imageSrc: m.imageSrc,
            sessionLocation: m.sessionLocation,
            profiles: widget.profiles
    .where((p) => m.profileIds.contains(p.id))
    .toList(),
    firstDate: m.firstDate,
    lastDate: m.lastDate,
            onOpenEvent: () => widget.onOpenEvent(m.event),
            onEditEvent: null,
            onUnselect: widget.onUnselectSession == null
                ? null
                : () => widget.onUnselectSession!(
                      m.eventId,
                      m.sessionIndex,
                    ),
          ),
        );
      }),

  

      if (pastSessions.isNotEmpty) ...[
        const SizedBox(height: 32),
        ExpansionTile(
          title: Text(
            'Past Sessions (${pastSessions.length})',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            for (final m in pastSessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SelectedSessionCard(
                  eventTitle: m.eventTitle,
                  sessionLabel: m.sessionLabel,
                  dayDateLabel: m.dayDateLabel,
                  timeLabel: m.timeLabel,
                  metaLabel: m.metaLabel,
                  forProfilesLabel: m.forProfilesLabel,
                  imageSrc: m.imageSrc,
                  sessionLocation: m.sessionLocation,
                  profiles: widget.profiles
    .where((p) => m.profileIds.contains(p.id))
    .toList(),
    
    firstDate: m.firstDate,
    lastDate: m.lastDate,
                  onOpenEvent: () => widget.onOpenEvent(m.event),
                  onEditEvent: null,
                  onUnselect: widget.onUnselectSession == null
                      ? null
                      : () => widget.onUnselectSession!(
                            m.eventId,
                            m.sessionIndex,
                          ),
                ),
              ),
          ],
        ),
      ],
    ],
  );
}

return Column(
  children: [
    for (int i = 0; i < activeSessions.length; i += 2)
  Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectedSessionCard(
            eventTitle: activeSessions[i].eventTitle,
            sessionLabel: activeSessions[i].sessionLabel,
            dayDateLabel: activeSessions[i].dayDateLabel,
            timeLabel: activeSessions[i].timeLabel,
            metaLabel: activeSessions[i].metaLabel,
            forProfilesLabel: activeSessions[i].forProfilesLabel,
            imageSrc: activeSessions[i].imageSrc,
            sessionLocation: activeSessions[i].sessionLocation,
            profiles: widget.profiles
                .where((p) => activeSessions[i].profileIds.contains(p.id))
                .toList(),
            firstDate: activeSessions[i].firstDate,
            lastDate: activeSessions[i].lastDate,
            onOpenEvent: () =>
                widget.onOpenEvent(activeSessions[i].event),
            onEditEvent: null,
            onUnselect: widget.onUnselectSession == null
                ? null
                : () => widget.onUnselectSession!(
                      activeSessions[i].eventId,
                      activeSessions[i].sessionIndex,
                    ),
          ),
        ),
        const SizedBox(width: 24),
        if (i + 1 < activeSessions.length)
          Expanded(
            child: SelectedSessionCard(
              eventTitle: activeSessions[i + 1].eventTitle,
              sessionLabel: activeSessions[i + 1].sessionLabel,
              dayDateLabel: activeSessions[i + 1].dayDateLabel,
              timeLabel: activeSessions[i + 1].timeLabel,
              metaLabel: activeSessions[i + 1].metaLabel,
              forProfilesLabel: activeSessions[i + 1].forProfilesLabel,
              imageSrc: activeSessions[i + 1].imageSrc,
              sessionLocation: activeSessions[i + 1].sessionLocation,
              profiles: widget.profiles
                  .where((p) => activeSessions[i + 1].profileIds.contains(p.id))
                  .toList(),
              firstDate: activeSessions[i + 1].firstDate,
              lastDate: activeSessions[i + 1].lastDate,   
              onOpenEvent: () => widget
                  .onOpenEvent(activeSessions[i + 1].event),
              onEditEvent: null,
              onUnselect:
                  widget.onUnselectSession == null
                      ? null
                      : () => widget.onUnselectSession!(
                            activeSessions[i + 1].eventId,
                            activeSessions[i + 1].sessionIndex,
                          ),
            ),
          )
        else
          const Spacer(),
      ],
    ),
  ),

    if (pastSessions.isNotEmpty) ...[
      const SizedBox(height: 32),
      ExpansionTile(
        title: Text(
          'Past Sessions (${pastSessions.length})',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        children: [
          for (final m in pastSessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectedSessionCard(
                eventTitle: m.eventTitle,
                sessionLabel: m.sessionLabel,
                dayDateLabel: m.dayDateLabel,
                timeLabel: m.timeLabel,
                metaLabel: m.metaLabel,
                forProfilesLabel: m.forProfilesLabel,
                imageSrc: m.imageSrc,
                sessionLocation: m.sessionLocation,
                profiles: widget.profiles
                    .where((p) => m.profileIds.contains(p.id))
                    .toList(),
                firstDate: m.firstDate,
                lastDate: m.lastDate,
                onOpenEvent: () => widget.onOpenEvent(m.event),
                onEditEvent: null,
                onUnselect: widget.onUnselectSession == null
                    ? null
                    : () => widget.onUnselectSession!(
                          m.eventId,
                          m.sessionIndex,
                        ),
              ),
            ),
        ],
      ),
    ],
  ],
);
              },
            ),
          ],
        ),
),
          ],
        ),
      ),
    );
  }
}


// Simple “chip” used in the profile filter row
class _ProfileFilterChip extends StatefulWidget {
  const _ProfileFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.profile,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Profile? profile;

  @override
  State<_ProfileFilterChip> createState() => _ProfileFilterChipState();
}

class _ProfileFilterChipState extends State<_ProfileFilterChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    ImageProvider? avatar;

    if (widget.profile?.asset != null &&
        widget.profile!.asset!.isNotEmpty) {
      final path = widget.profile!.asset!;

      if (path.startsWith('http')) {
        avatar = NetworkImage(path);
      } else if (path.startsWith('assets/')) {
        avatar = AssetImage(path);
      } else {
        avatar = FileImage(File(path));
      }
    }

    // 🎨 Background color logic
    Color bgColor;
    if (widget.selected) {
      bgColor = cs.secondaryContainer;
    } else if (_hovering) {
      bgColor = cs.secondaryContainer.withOpacity(0.4); // 👈 light teal
    } else {
      bgColor = Colors.white;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? cs.primary
                  : Colors.black26,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.profile != null) ...[
                CircleAvatar(
                  radius: 11,
                  backgroundImage: avatar,
                  child: avatar == null
                      ? const Icon(Icons.person, size: 12)
                      : null,
                ),
                const SizedBox(width: 8),
              ],

              if (widget.selected) ...[
                Icon(Icons.check, size: 16, color: cs.primary),
                const SizedBox(width: 4),
              ],

              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple view-model used inside SavedPage
class _SavedSessionView {
  final Event event;
  final Id eventId;
  final int sessionIndex;

  final DateTime firstDate;
  final DateTime lastDate;

  final String eventTitle;
  final String sessionLabel;
  final String dayDateLabel;
  final String timeLabel;
  final String metaLabel;
  final String forProfilesLabel;
  final String imageSrc;
  final String sessionLocation;

  final Set<Id> profileIds;

  _SavedSessionView({
    required this.event,
    required this.eventId,
    required this.sessionIndex,
    required this.firstDate,
    required this.lastDate,
    required this.eventTitle,
    required this.sessionLabel,
    required this.dayDateLabel,
    required this.timeLabel,
    required this.metaLabel,
    required this.forProfilesLabel,
    required this.imageSrc,
    required this.sessionLocation,
    required this.profileIds,
  });
}

// ===============================
// SELECTED SESSION CARD WIDGET
// ===============================
class SelectedSessionCard extends StatefulWidget {
  const SelectedSessionCard({
    super.key,
    required this.eventTitle,
    required this.sessionLabel,
    required this.dayDateLabel,
    required this.timeLabel,
    required this.metaLabel,
    required this.forProfilesLabel,
    required this.imageSrc,
    required this.sessionLocation,
    required this.profiles,
    required this.firstDate,
    required this.lastDate,
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
  final String sessionLocation;
  final List<Profile> profiles;
  final DateTime firstDate;
  final DateTime lastDate;

  final VoidCallback? onOpenEvent;
  final VoidCallback? onEditEvent;
  final VoidCallback? onUnselect;

  @override
  State<SelectedSessionCard> createState() =>
      _SelectedSessionCardState();
}

class _SelectedSessionCardState extends State<SelectedSessionCard> {
  bool _showAllProfiles = false;
  int? _hoveredAvatarIndex;


String _sessionStatus() {
  final now = DateTime.now();

  if (now.isAfter(widget.firstDate) &&
      now.isBefore(widget.lastDate)) {
    return 'In Session';
  } else if (widget.firstDate.difference(now).inDays <= 7 &&
      widget.firstDate.isAfter(now)) {
    return 'Starting Soon';
  }

  return '';
}

  ImageProvider _imageProvider(String? src) {
    const fallback = 'assets/soccer_camp.jpg';

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
  final provider = _imageProvider(widget.imageSrc);

  return LayoutBuilder(
    builder: (context, constraints) {
      final useHorizontal = constraints.maxWidth >= 600;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: _HoverCard(
          child: Stack(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: widget.onOpenEvent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withOpacity(.05),
                    ),
                  ),
                  child: useHorizontal
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    const BorderRadius.horizontal(
                                  left: Radius.circular(18),
                                ),
                                child: SizedBox(
                                  width: 260,
                                  child: Image(
                                    image: provider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(
                                          20, 18, 20, 18),
                                  child: _buildContent(theme),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius:
                                  const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Image(
                                  image: provider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(
                                      16, 14, 16, 16),
                              child: _buildContent(theme),
                            ),
                          ],
                        ),
                ),
              ),

              // 🔹 STATUS BADGE (TOP RIGHT)
              if (_sessionStatus().isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _sessionStatus() == 'In Session'
                          ? Colors.green.withOpacity(0.9)
                          : Colors.orange.withOpacity(0.9),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      _sessionStatus(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}


Widget _buildContent(ThemeData theme) {

  // 🔹 Extract location + cleaned date text
  String location = '';
  String cleanedDayDate = widget.dayDateLabel;
  // 🔹 Split meta into structured parts
String ageText = '';
String levelText = '';
String durationCostText = '';
// 🔹 Compute session status
String sessionStatus = '';

final now = DateTime.now();

if (now.isAfter(widget.firstDate) &&
    now.isBefore(widget.lastDate)) {
  sessionStatus = 'In Session';
} else if (widget.firstDate.difference(now).inDays <= 7 &&
    widget.firstDate.isAfter(now)) {
  sessionStatus = 'Starting Soon';
}

if (widget.metaLabel.contains('•')) {
  final parts = widget.metaLabel.split('•').map((e) => e.trim()).toList();

  if (parts.isNotEmpty) ageText = parts[0];
  if (parts.length > 1) levelText = parts[1];
  if (parts.length > 2) {
    durationCostText = parts.sublist(2).join(' • ');
  }
}

if (widget.dayDateLabel.contains('•')) {
  final parts = widget.dayDateLabel.split('•').map((e) => e.trim()).toList();

  if (parts.length > 1) {
    location = widget.sessionLocation.isNotEmpty ? widget.sessionLocation : parts.first;
    cleanedDayDate = parts.sublist(1).join(' • ');
  }
}

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // 🔹 HEADER (Search-style)
      // 🔹 TITLE (always on top)
Text(
  widget.eventTitle,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: theme.textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w800,
  ),
),

const SizedBox(height: 6),


// 🔹 RESPONSIVE META SECTION
// 🔹 META SECTION (stable layout)
// 🔹 META SECTION (responsive-safe)
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    // LEFT SIDE
    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.metaLabel.isNotEmpty)
        Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    if (ageText.isNotEmpty)
      Text(
        ageText,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: Colors.black54),
      ),

    if (levelText.isNotEmpty)
      Text(
        levelText,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: Colors.black54),
      ),

    if (durationCostText.isNotEmpty) ...[
      const SizedBox(height: 2),
      Text(
        durationCostText,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: Colors.black54),
      ),
    ],
  ],
),
    ],
  ),
),


    // RIGHT SIDE (anchored)
    Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (cleanedDayDate.isNotEmpty)
          Text(
            cleanedDayDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.black54),
          ),

        if (widget.timeLabel.isNotEmpty)
          Text(
            widget.timeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.black54),
          ),

        if (location.isNotEmpty)
          Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.black54),
          ),
      ],
    ),
  ],
),

      const SizedBox(height: 12),

      // 🔹 SESSION CHIP (keep your feature)
      if (widget.sessionLabel.isNotEmpty) ...[
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.sessionLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],

      // 🔹 PROFILES + CHECKBOX
Row(
  children: [
    // ✅ Checkbox (moved here)
    if (widget.onUnselect != null)
      IconButton(
        icon: const Icon(Icons.check_box, size: 20),
        color: theme.colorScheme.primary,
        onPressed: widget.onUnselect,
      ),

    // ✅ Avatars placeholder (next step we populate)
    if (widget.forProfilesLabel.isNotEmpty)
      Expanded(
        child: Row(
          children: [
           Builder(
  builder: (context) {
    final display = _showAllProfiles
    ? widget.profiles
    : widget.profiles.take(3).toList();

final extraCount = widget.profiles.length - 3;

    return Row(
      children: [
        AnimatedContainer(
  duration: const Duration(milliseconds: 220),
  curve: Curves.easeInOut,
  height: 24,
  width: (display.length * 16) + 24,
  child: Stack(
            children: [
              for (int i = 0; i < display.length; i++)
                Positioned(
  left: i * 16,
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) {
      setState(() {
        _hoveredAvatarIndex = i;
      });
    },
    onExit: (_) {
      setState(() {
        _hoveredAvatarIndex = null;
      });
    },
    child: AnimatedScale(
      scale: _hoveredAvatarIndex == i ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _hoveredAvatarIndex == i
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Tooltip(
          message: (display[i].nickname != null &&
                  display[i].nickname!.isNotEmpty)
              ? display[i].nickname!
              : display[i].firstName,
          child: GestureDetector(
            onTap: () {
              openProfilePreviewDialog(
                context: context,
                profile: display[i],
                color: Color(display[i].colorValue),
                avatarProvider: (display[i].asset != null &&
                        display[i].asset!.isNotEmpty)
                    ? (display[i].asset!.startsWith('http')
                        ? NetworkImage(display[i].asset!)
                        : FileImage(File(display[i].asset!))
                            as ImageProvider)
                    : const AssetImage('assets/soccer_camp.jpg'),
              );
            },
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (display[i].asset != null &&
                        display[i].asset!.isNotEmpty)
                    ? (display[i].asset!.startsWith('http')
                        ? NetworkImage(display[i].asset!)
                        : FileImage(File(display[i].asset!))
                            as ImageProvider)
                    : null,
                child: (display[i].asset == null ||
                        display[i].asset!.isEmpty)
                    ? Text(
                        display[i].firstName.isNotEmpty
                            ? display[i]
                                .firstName[0]
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 10),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
),
            ],
          ),
        ),

        if (extraCount > 0) ...[
  const SizedBox(width: 6),
  if (!_showAllProfiles && extraCount > 0) ...[
  const SizedBox(width: 6),
  GestureDetector(
    onTap: () {
      setState(() {
        _showAllProfiles = true;
      });
    },
    child: Text(
      '+$extraCount',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  ),
],

if (_showAllProfiles && widget.profiles.length > 3) ...[
  const SizedBox(width: 6),
  GestureDetector(
    onTap: () {
      setState(() {
        _showAllProfiles = false;
      });
    },
    child: Text(
      '–',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  ),
],
],
      ],
    );
  },
),
          ],
        ),
      ),
  ],
),

const SizedBox(height: 12),

// 🔹 ACTIONS (checkbox removed from here)
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: widget.onOpenEvent,
          child: const Text('View Event Details'),
        ),
        if (widget.onEditEvent != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onEditEvent,
            child: const Text('EDIT'),
          ),
        ],
      ],
    ),
  ],
),

        ],
  );
}
}
class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child});

  final Widget child;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
    child: AnimatedContainer(
  duration: const Duration(milliseconds: 180),
  curve: Curves.easeOut,
  child: ClipRect(
    child: Stack(
      children: [
  // Actual card
  widget.child,

  // Hover overlay (on top)
  Positioned.fill(
  child: IgnorePointer(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16), // match card radius
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovering
            ? Colors.grey.withOpacity(0.12)
            : Colors.transparent,
      ),
    ),
  ),
),
],
    ),
  ),
),
    );
  }
}

