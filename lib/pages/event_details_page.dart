// lib/pages/event_details_page.dart

import 'dart:async';                         // StreamSubscription
import 'package:flutter/foundation.dart'
    show kIsWeb;                             // kIsWeb
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';             // Id, Isar (if referenced)

import '../data/db.dart';                    // getIsar()
import '../models/event_models.dart';        // Event, EventSlot, etc.
import 'package:keepbusy/models/profile.dart';

import '../widgets/image_helpers.dart';      // eventImageProvider(...)
import '../utils/notify.dart';               // showSnack(...)
import 'saved_page.dart';                    // SelectedSessionCard

import 'event_entry_form_page.dart';

// ==============================
// Event Details-specific helpers
// ==============================

// --- small local helpers used only by EventDetailsPage ---

TimeOfDay? minToTime(int? m) =>
    m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);

String _md(DateTime d) {
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}


// ==============================
// Event Details
// ==============================
class EventDetailsPage extends StatefulWidget {
  const EventDetailsPage({
    super.key,
    required this.event,
    required this.profile,
    required this.profiles,
    this.sessionSelections = const {},
    required this.slotSelections,
    this.onUpdateSessionSelections,
  });

  final Event event;
  final Profile? profile; // nullable
  final List<Profile> profiles;

/// slotId -> set of profile indexes (derived, UI-only)
final Map<Id, Set<int>> sessionSelections;

/// slotId -> set of profile indexes (SOURCE OF TRUTH)
final Map<Id, Set<int>> slotSelections;

/// Notify parent after slot-level updates
final void Function(Map<int, Set<int>>)? onUpdateSessionSelections;



  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  late Event _event;


  /// slotId -> set(profileIndex)  (NEW source of truth)
  Map<Id, Set<int>> _slotSelectedProfileIndexes = {};



@override
void initState() {
  super.initState();
  _event = widget.event;
debugPrint('🔥 EVENT DETAILS INIT — callback is null? ${widget.onUpdateSessionSelections == null}');
  // ✅ Slot-level source of truth (hydrate immediately)
  _slotSelectedProfileIndexes = {
    for (final entry in widget.slotSelections.entries)
      entry.key: Set<int>.from(entry.value),
  };

  // ✅ Session-level cache for immediate UI (checkboxes, labels, popup initial state)
  // Build from slots so it reflects ALL profiles already selected across slots.

}



  /// Pretty label for a profile index (nickname > full name > fallback).
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

    /// Canonical identifier for a profile *within this page*.
  /// 
  /// IMPORTANT:
  /// - Today: returns the profile index
  /// - Future: can return profile.id or userId without changing UI logic
  int _profileKey(int index) => index;


  Future<Event> _upsertEventWithSlots(Event e, List<EventSlot> slots) async {
    final isar = await getIsar();
    await isar.writeTxn(() async {
      // keep the same id when editing
      if (_event.id != null) e.id = _event.id!;

      // remove old slots
      await _event.slotIds.load();
      for (final old in _event.slotIds) {
        if (old.id != null) {
          await isar.eventSlots.delete(old.id!);
        }
      }
      await _event.slotIds.reset();

      // upsert event first (so links can attach)
      await isar.events.put(e);
      e.slotIds.clear();

      // insert new slots and link them
      for (final s in slots) {
        final sid = await isar.eventSlots.put(s);
        final slot = await isar.eventSlots.get(sid);
        if (slot != null) e.slotIds.add(slot);
      }
      await e.slotIds.save();

      // persist event again with links set
      await isar.events.put(e);
    });
    return e;
  }

  Future<void> _editEvent() async {
    // Load current links/slots before opening the form (no transaction)
    await _event.slotIds.load();

    // Open the entry form in EDIT mode (no DB work here)
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => EventEntryFormPage(
          profiles: widget.profiles,
          existing: _event,
        ),
      ),
    );

    if (result == null) return;

    // 0) HANDLE DELETE FIRST — no save work at all
    if (result['delete'] == true) {
      final isar = await getIsar();
      await isar.writeTxn(() async {
        await _event.slotIds.load();
        for (final old in _event.slotIds) {
          if (old.id != null) {
            await isar.eventSlots.delete(old.id!);
          }
        }
        await _event.slotIds.reset();

        if (_event.id != null) {
          await isar.events.delete(_event.id!);
        }
      });

      if (!mounted) return;
      Navigator.pop(context, {'deleted': true, 'id': _event.id});
      return; // IMPORTANT: stop here
    }

    // 1) SAVE / UPDATE PATH
    final updated = result['event'] as Event;
    final newSlots =
        (result['slots'] as List<EventSlot>? ?? const <EventSlot>[]);

    final isar = await getIsar();
    await isar.writeTxn(() async {
      // keep same id when editing
      if (_event.id != null) updated.id = _event.id!;

      // remove old slots
      await _event.slotIds.load();
      for (final old in _event.slotIds) {
        if (old.id != null) {
          await isar.eventSlots.delete(old.id!);
        }
      }
      await _event.slotIds.reset();

      // upsert event first (so links can attach)
      await isar.events.put(updated);
      updated.slotIds.clear();

      // write new slots and attach
      for (final s in newSlots) {
        final sid = await isar.eventSlots.put(s);
        final slot = await isar.eventSlots.get(sid);
        if (slot != null) updated.slotIds.add(slot);
      }
      await updated.slotIds.save();

      // persist event again with links set
      await isar.events.put(updated);

      // update local copy for this details page
      _event = updated;
    });

    if (!mounted) return;
    setState(() {}); // refresh UI

    // 2) Also mirror scalar fields into existing _event (your original logic)
    _event
      ..date = updated.date
      ..profileIndex = updated.profileIndex
      ..title = updated.title
      ..locationName = updated.locationName
      ..address = updated.address
      ..city = updated.city
      ..state = updated.state
      ..zip = updated.zip
      ..cost = updated.cost
      ..fee = updated.fee
      ..feeNote = updated.feeNote
      ..ageMin = updated.ageMin
      ..ageMax = updated.ageMax
      ..shortDescription = updated.shortDescription
      ..description = updated.description
      ..interests = updated.interests
      ..links = updated.links
      ..imagePath = updated.imagePath;

    // 3) Reload a fresh copy with links and update the page state
    final fresh = await isar.events.get(_event.id);
    if (fresh != null) await fresh.slotIds.load();

    if (!mounted || fresh == null) return;
    setState(() => _event = fresh);

    showSnack('Event updated');
  }

  String levelLabel(List<EventSlot> list) {
    final l = list.first.level;
    return l ?? '';
  }

  // Build "Selected sessions" cards for this event,

  Widget _buildSelectedSessionCards(
    BuildContext context,
    List<EventSlot> slots,
  ) {
    final theme = Theme.of(context);

    // ----- group slots into sessions (same as SESSIONS table) -----
    final Map<int, List<EventSlot>> bySession = {};
    for (final s in slots) {
      final key = s.sessionIndex ?? 0;
      (bySession[key] ??= <EventSlot>[]).add(s);
    }

    final keys = bySession.keys.toList()
      ..sort((a, b) {
        final la = bySession[a]!..sort((x, y) => x.date.compareTo(y.date));
        final lb = bySession[b]!..sort((x, y) => x.date.compareTo(y.date));
        return la.first.date.compareTo(lb.first.date);
      });

    // ----- helpers to format labels -----
    String daysLabel(List<EventSlot> list) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final w = list.map((e) => e.date.weekday).toSet().toList()..sort();
      return w.map((x) => names[x - 1]).join(', ');
    }

    String timeLabel(List<EventSlot> list) {
      final first = list.first;
      final start =
          minToTime(first.startMinutes)?.format(context) ?? '';
      final end =
          minToTime(first.endMinutes)?.format(context) ?? '';
      return [start, end].where((x) => x.isNotEmpty).join(' – ');
    }

    int computeWeeks(List<EventSlot> list) {
      final uniqueDays = list.map((e) => e.date.weekday).toSet().length;
      if (uniqueDays == 0) return 0;
      return (list.length / uniqueDays).round();
    }

    String agesLabel(List<EventSlot> list) {
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

    String costLabel(List<EventSlot> list) {
      double? c;
      for (final s in list) {
        c ??= s.cost;
      }
      if (c == null) return '';
      return '\$${c!.toStringAsFixed(0)}';
    }

    // Figure out which image to show for this event
    final imageSrc = (_event.imagePath?.trim().isNotEmpty == true)
        ? _event.imagePath!.trim()
        : 'assets/soccer_camp.jpg';

    // ----- build one SelectedSessionCard per *selected* session -----
    final List<Widget> cards = [];

    for (int displayIndex = 0; displayIndex < keys.length; displayIndex++) {
      final key = keys[displayIndex];
      final list =
          bySession[key]!..sort((a, b) => a.date.compareTo(b.date));
      final first = list.first.date;
      final last = list.last.date;

// ✅ Session selection = UNION of slot selections (source of truth)
final selected = <int>{};
for (final s in list) {
  final sid = s.id;
  if (sid == 0) continue;
  selected.addAll(_slotSelectedProfileIndexes[sid] ?? const <int>{});
}

final forLabel = selected.isEmpty
    ? ''
    : 'For: ' + selected.map(_profileLabel).join(', ');

      final days = daysLabel(list);
      final time = timeLabel(list);
      final weeks = computeWeeks(list);
      final ages = agesLabel(list);
      final cost = costLabel(list);
      final level = levelLabel(list);


      // Build a compact meta line: "Ages: 5–16 • Advanced • 4 weeks • $50"
      final metaParts = <String>[];
      if (ages.isNotEmpty) metaParts.add('Ages: $ages');
      if (level.isNotEmpty) metaParts.add(level);
      if (weeks > 0) metaParts.add('$weeks weeks');
      if (cost.isNotEmpty) metaParts.add(cost);
      final metaLabel = metaParts.join(' • ');

      cards.add(
        SelectedSessionCard(
          eventTitle: _event.title,
          sessionLabel: 'Session ${displayIndex + 1}',
          dayDateLabel: '$days • ${_md(first)} – ${_md(last)}',
          timeLabel: time,
          metaLabel: metaLabel,
          forProfilesLabel: forLabel,
          imageSrc: imageSrc,
          onOpenEvent: () {
            // already on this event; no-op for now
          },
          onEditEvent: _editEvent,
onUnselect: () {
  setState(() {
    final sessionSlots = bySession[key] ?? const <EventSlot>[];

    for (final s in sessionSlots) {
      final sid = s.id;
      if (sid != 0) {
        _slotSelectedProfileIndexes.remove(sid);
      }
    }
  });

  if (widget.onUpdateSessionSelections != null) {
    widget.onUpdateSessionSelections!(
      Map<int, Set<int>>.from(_slotSelectedProfileIndexes),
    );
  }
},
        ),
      );
    }

    if (cards.isEmpty) {
      // No sessions selected => don't show anything
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Selected sessions',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...cards,
      ],
    );
  }

 Future<void> _pickProfilesForSession(
  int sessionKey,
  List<EventSlot> sessionSlots,
) async {
  if (widget.profiles.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add at least one profile first.')),
    );
    return;
  }

  // ✅ Slot IDs for this session
  final slotIds = sessionSlots
      .map((s) => s.id)
      .where((id) => id != 0)
      .toList();

  // ✅ Current selection = UNION across all slots in this session
  final current = <int>{};
  for (final sid in slotIds) {
    current.addAll(_slotSelectedProfileIndexes[sid] ?? const <int>{});
  }

  final result = await showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      Set<int> temp = Set<int>.from(current);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: StatefulBuilder(
            builder: (ctx, setSB) {
              final theme = Theme.of(ctx);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select profiles for this session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 260,
                    child: ListView.builder(
                      itemCount: widget.profiles.length,
                      itemBuilder: (ctx, i) {
                        final checked = temp.contains(i);
                        final p = widget.profiles[i];

                        final nickname = (p.nickname ?? '').trim();
                        final fullName =
                            '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
                        final label = nickname.isNotEmpty
                            ? nickname
                            : (fullName.isNotEmpty
                                ? fullName
                                : 'Profile ${i + 1}');

                        return CheckboxListTile(
                          value: checked,
                          title: Text(label),
                          onChanged: (val) {
                            setSB(() {
                              if (val == true) {
                                temp.add(i);
                              } else {
                                temp.remove(i);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, temp),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );

  debugPrint('🔥 BOTTOM SHEET RESULT: $result');

  if (result == null) return;

// ✅ Write the same selected set to EACH slot in this session
// ✅ Then rebuild the FULL session map from slot selections (source of truth)
setState(() {
  final mapped = result.map(_profileKey).toSet();

  for (final sid in slotIds) {
    _slotSelectedProfileIndexes[sid] = Set<int>.from(mapped);
  }

});

debugPrint('🔥 EVENT DETAILS SENDING UP: $_slotSelectedProfileIndexes');

if (widget.onUpdateSessionSelections != null) {
  widget.onUpdateSessionSelections!(
    Map<int, Set<int>>.from(_slotSelectedProfileIndexes),
  );
}
}


  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final slots = _event.slotIds.toList();

    String joinNonEmpty(List<String?> xs) =>
        xs.where((s) => (s ?? '').isNotEmpty).join(' • ');
    final addressLine = joinNonEmpty([
      _event.address,
      [_event.city, _event.state]
          .where((s) => (s ?? '').isNotEmpty)
          .join(', '),
      _event.zip,
    ]);

    // Aggregate ages + cost across all sessions
    int? minAge = _event.ageMin;
    int? maxAge = _event.ageMax;
    double? minCost = _event.cost;
    double? maxCost = _event.cost;

    for (final s in slots) {
      final aMin = s.ageMin;
      final aMax = s.ageMax;
      final c = s.cost;

      if (aMin != null) {
        minAge = (minAge == null) ? aMin : (aMin < minAge! ? aMin : minAge);
      }
      if (aMax != null) {
        maxAge = (maxAge == null) ? aMax : (aMax > maxAge! ? aMax : maxAge);
      }

      if (c != null) {
        minCost = (minCost == null) ? c : (c < minCost! ? c : minCost);
        maxCost = (maxCost == null) ? c : (c > maxCost! ? c : maxCost);
      }
    }

    // Combined age line, e.g. "Ages: 7–11"
    final String? agesLine = (minAge != null || maxAge != null)
        ? 'Ages: ${minAge ?? ''}'
            '${(minAge != null && maxAge != null) ? '-' : ''}'
            '${maxAge ?? ''}'
        : null;

    // Combined cost line, e.g. "$25–$200" or just "$145"
    String? costLine;
    if (minCost != null && maxCost != null) {
      if (minCost == maxCost) {
        costLine = '\$${minCost.toStringAsFixed(0)}';
      } else {
        costLine =
            '\$${minCost.toStringAsFixed(0)}–\$${maxCost.toStringAsFixed(0)}';
      }
    } else if (minCost != null) {
      costLine = '\$${minCost.toStringAsFixed(0)}';
    } else {
      costLine = null;
    }

    final String? feeLine =
        _event.fee != null ? '\$${_event.fee!.toStringAsFixed(0)}' : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        actions: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.favorite_border)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.check_box_outlined)),
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.calendar_today_outlined)),
          TextButton.icon(
            onPressed: _editEvent,
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'EVENT PAGE (USER VIEW)',
                    style: t.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: eventImageProvider(_event),
                    fit: BoxFit.cover,
                    height: 200,
                    width: double.infinity,
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: _event.title.toUpperCase(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((_event.locationName ?? '').isNotEmpty)
                        _kvRow('Location', _event.locationName!),
                      if (addressLine.isNotEmpty)
                        _kvRow('Address', addressLine),
                      if (agesLine != null)
                        _kvRow('Age Group', agesLine),
                      if (costLine != null) _kvRow('Cost', costLine),
                      if (feeLine != null) _kvRow('Fee', feeLine),
                      if ((_event.shortDescription ?? '').isNotEmpty)
                        _kvRow('Summary', _event.shortDescription!),
                    ],
                  ),
                ),

                // SESSIONS (grouped by sessionIndex, with age + cost)
                if (slots.isNotEmpty)
                  _SectionCard(
                    title: 'SESSIONS',
                    child: Builder(
                      builder: (context) {
                        final textTheme = Theme.of(context).textTheme;
                        final headerStyle =
                            textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        );
                        final cellStyle = textTheme.bodyMedium;

                        // ----- group slots into sessions (by sessionIndex) -----
                        final Map<int, List<EventSlot>> bySession = {};
                        for (final s in slots) {
                          final key = s.sessionIndex ?? 0;
                          (bySession[key] ??= <EventSlot>[]).add(s);
                        }

                        final keys = bySession.keys.toList()
                          ..sort((a, b) {
                            final la = bySession[a]!
                              ..sort((x, y) =>
                                  x.date.compareTo(y.date));
                            final lb = bySession[b]!
                              ..sort((x, y) =>
                                  x.date.compareTo(y.date));
                            return la.first.date.compareTo(lb.first.date);
                          });

                        // make sure we have a selection set for each sessionIndex
                        // Keep session UI map in sync with slot source-of-truth.
// (Don't seed empty sets here — it can mask updates.)

                        // ---------- helpers for labels ----------
                        String daysLabel(List<EventSlot> list) {
                          const names = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun'
                          ];
                          final w = list
                              .map((e) => e.date.weekday)
                              .toSet()
                              .toList()
                            ..sort();
                          return w
                              .map((x) => names[x - 1])
                              .join(', ');
                        }

                        String timeLabel(List<EventSlot> list) {
                          final first = list.first;
                          final start =
                              minToTime(first.startMinutes)
                                      ?.format(context) ??
                                  '';
                          final end =
                              minToTime(first.endMinutes)
                                      ?.format(context) ??
                                  '';
                          return [start, end]
                              .where((x) => x.isNotEmpty)
                              .join(' – ');
                        }

                        int computeWeeks(List<EventSlot> list) {
                          final uniqueDays = list
                              .map((e) => e.date.weekday)
                              .toSet()
                              .length;
                          if (uniqueDays == 0) return 0;
                          return (list.length / uniqueDays).round();
                        }

                        String agesLabel(List<EventSlot> list) {
                          int? minAge;
                          int? maxAge;
                          for (final s in list) {
                            final a1 = s.ageMin;
                            final a2 = s.ageMax;
                            if (a1 != null) {
                              minAge =
                                  (minAge == null || a1 < minAge!)
                                      ? a1
                                      : minAge;
                            }
                            if (a2 != null) {
                              maxAge =
                                  (maxAge == null || a2 > maxAge!)
                                      ? a2
                                      : maxAge;
                            }
                          }
                          if (minAge == null && maxAge == null) return '';
                          if (minAge != null && maxAge != null) {
                            return '$minAge–$maxAge';
                          }
                          return (minAge ?? maxAge).toString();
                        }

                        String costLabel(List<EventSlot> list) {
                          double? c;
                          for (final s in list) {
                            c ??= s.cost;
                          }
                          if (c == null) return '';
                          return '\$${c!.toStringAsFixed(0)}';
                        }

                        String levelLabelLocal(List<EventSlot> list) {
                          final l = list.first.level;
                          return l ?? '';
                        }

                        // cells for the wide (table) layout
                        Widget headerCell(String text, {int flex = 2}) =>
                            Expanded(
                                flex: flex,
                                child: Text(text, style: headerStyle));
                        Widget bodyCell(String text, {int flex = 2}) =>
                            Expanded(
                                flex: flex,
                                child: Text(text, style: cellStyle));

                        // ---------- responsive switch ----------
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final bool compact =
                                constraints.maxWidth < 700;

                            // ====== NARROW: stacked cards (phone) ======
                            if (compact) {
                              final items = <Widget>[];

                              for (int displayIndex = 0;
                                  displayIndex < keys.length;
                                  displayIndex++) {
                                final key = keys[displayIndex];
                                final list = bySession[key]!
                                  ..sort((a, b) =>
                                      a.date.compareTo(b.date));
                                final first = list.first.date;
                                final last = list.last.date;

                                final days = daysLabel(list);
                                final time = timeLabel(list);
                                final weeks = computeWeeks(list);
                                final ages = agesLabel(list);
                                final cost = costLabel(list);
                                final level = levelLabelLocal(list);

                                final selected = <int>{};
for (final s in bySession[key] ?? const <EventSlot>[]) {
  final sid = s.id;
  if (sid != 0) {
    selected.addAll(
      _slotSelectedProfileIndexes[sid] ?? const <int>{},
    );
  }
}

final selectedLabel = selected.isEmpty
    ? ''
    : 'For: ' +
        selected.map(_profileLabel).join(', ');

                                items.add(
                                  Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.black
                                            .withOpacity(.08),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.event,
                                                size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Session ${displayIndex + 1}',
                                              style: headerStyle,
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Icon(
                                                selected.isNotEmpty
                                                    ? Icons.check_box
                                                    : Icons
                                                        .check_box_outline_blank,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              tooltip:
                                                  'Select profiles for this session',
                                              onPressed: () => _pickProfilesForSession(key, bySession[key] ?? const <EventSlot>[]),
                                            ),
                                          ],
                                        ),
                                        if (selectedLabel.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                                    left: 24,
                                                    bottom: 4),
                                            child: Text(
                                              selectedLabel,
                                              style: textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          '$days • ${_md(first)} – ${_md(last)}',
                                          style: cellStyle,
                                        ),
                                        if (time.isNotEmpty)
                                          Text(time, style: cellStyle),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            if (weeks > 0)
                                              Text('Weeks: $weeks',
                                                  style: cellStyle),
                                            if (level.isNotEmpty)
                                              Text('Level: $level',
                                                  style: cellStyle),
                                            if (ages.isNotEmpty)
                                              Text('Age: $ages',
                                                  style: cellStyle),
                                            if (cost.isNotEmpty)
                                              Text('Cost: $cost',
                                                  style: cellStyle),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: items,
                              );
                            }

                            // ====== WIDE: table layout (tablet / desktop) ======
                            final rows = <Widget>[];

                            // header row
                            rows.add(
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 140,
                                    child: Text(
                                      'Session',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  headerCell('Day'),
                                  headerCell('Dates', flex: 3),
                                  headerCell('Time', flex: 3),
                                  headerCell('Weeks', flex: 1),
                                  headerCell('Level'),
                                  headerCell('Age'),
                                  headerCell('Cost'),
                                ],
                              ),
                            );
                            rows.add(const SizedBox(height: 8));

                            // data rows
                            for (int displayIndex = 0;
                                displayIndex < keys.length;
                                displayIndex++) {
                              final key = keys[displayIndex];
                              final list = bySession[key]!
                                ..sort((a, b) =>
                                    a.date.compareTo(b.date));
                              final first = list.first.date;
                              final last = list.last.date;

                              final days = daysLabel(list);
                              final time = timeLabel(list);
                              final weeks = computeWeeks(list);
                              final ages = agesLabel(list);
                              final cost = costLabel(list);
                              final level = levelLabelLocal(list);

                              final selected = <int>{};
for (final s in bySession[key] ?? const <EventSlot>[]) {
  final sid = s.id;
  if (sid != 0) {
    selected.addAll(
      _slotSelectedProfileIndexes[sid] ?? const <int>{},
    );
  }
}

final selectedLabel = selected.isEmpty
    ? ''
    : 'For: ' +
        selected.map(_profileLabel).join(', ');

                              rows.add(
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(
                                              bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 140,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                    Icons.event,
                                                    size: 18),
                                                const SizedBox(
                                                    width: 6),
                                                Text(
                                                  'Session ${displayIndex + 1}',
                                                  style: headerStyle,
                                                ),
                                                const SizedBox(
                                                    width: 4),
                                                IconButton(
                                                  padding:
                                                      EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  icon: Icon(
                                                    selected.isNotEmpty
                                                        ? Icons
                                                            .check_box
                                                        : Icons
                                                            .check_box_outline_blank,
                                                    size: 18,
                                                    color: Theme.of(
                                                            context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                                  tooltip:
                                                      'Select profiles for this session',
                                                  onPressed: () => _pickProfilesForSession(key, bySession[key] ?? const <EventSlot>[]),
                                                ),
                                              ],
                                            ),
                                          ),
                                          bodyCell(days),
                                          bodyCell(
                                              '${_md(first)} – ${_md(last)}',
                                              flex: 3),
                                          bodyCell(time, flex: 3),
                                          bodyCell(
                                              weeks > 0
                                                  ? '$weeks'
                                                  : '',
                                              flex: 1),
                                          bodyCell(level),
                                          bodyCell(ages),
                                          bodyCell(cost),
                                        ],
                                      ),
                                    ),
                                    if (selectedLabel.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                left: 24, bottom: 6),
                                        child: Text(
                                          selectedLabel,
                                          style: textTheme.bodySmall
                                              ?.copyWith(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: rows,
                            );
                          },
                        );
                      },
                    ),
                  ),

                // (optional) Selected sessions section using the same state

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kvRow(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                k,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(child: Text(v)),
          ],
        ),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EBE6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
