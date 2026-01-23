// lib/pages/calendar_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:keepbusy/models/profile.dart';

import '../data/db.dart';
import '../models/event_models.dart';
import '../models/profile_color_ext.dart';
import '../widgets/image_helpers.dart';
import 'event_details_page.dart';

import 'package:keepbusy/utils/profile_label.dart';





/* ==============================
 * Calendar
 * ============================== */
class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.profiles,
    required this.events,
    required this.onOpenProfile,
    required this.onAddEvent,
    required this.sessionSelections,
  });

  final List<Profile> profiles;
  final List<Event> events;

  final void Function(Profile profile) onOpenProfile;
  final VoidCallback onAddEvent;

  // eventId -> (sessionIndex -> set of profile indexes)
  final Map<Id, Map<int, Set<int>>> sessionSelections;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}



enum _ViewMode { month, week, day }

class _CalItem {
  _CalItem({
    required this.event,
    required this.slot,
    required this.sessionIndex,
    required this.profileIndexes,
  });

  final Event event;
  final EventSlot slot;
  final int sessionIndex;
  final Set<int> profileIndexes;
}


class _CalendarPageState extends State<CalendarPage> {
  DateTime _shown = DateTime(DateTime.now().year, DateTime.now().month, 1);
  _ViewMode _view = _ViewMode.month;

  final Set<int> _selectedProfiles = <int>{};
  bool _viewAll = true;

  int _daysInMonth(DateTime d) {
    final next = (d.month == 12) ? DateTime(d.year + 1, 1, 1) : DateTime(d.year, d.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

TimeOfDay? _minutesToTimeOfDay(int? m) {
  if (m == null) return null;
  final h = m ~/ 60;
  final min = m % 60;
  return TimeOfDay(hour: h, minute: min);
}



  // clicking a day opens a “Quick View” card //
Future<void> _openDayQuickView(DateTime day) async {
  final items = _viewAll
      ? _itemsForDay(day)
      : _itemsForDay(day).where((it) => it.profileIndexes.contains(_profileIndex)).toList();

  if (items.isEmpty) return;



  // group by event+sessionIndex so multiple slots in same session/day don’t spam
  final map = <String, _CalItem>{};
  for (final it in items) {
    map['${it.event.id}-${it.sessionIndex}-${_dayKey(it.slot.date).millisecondsSinceEpoch}'] = it;
  }
  final list = map.values.toList()
    ..sort((a, b) => a.slot.startMinutes == null || b.slot.startMinutes == null
        ? 0
        : a.slot.startMinutes!.compareTo(b.slot.startMinutes!));

  if (!mounted) return;

  await showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (ctx) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(day),
              style: Theme.of(ctx)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final it = list[i];

                  // Names for profiles that selected this session
                  final safeNames = it.profileIndexes
                      .where((pi) => pi >= 0 && pi < widget.profiles.length)
                      .map((pi) => profileLabel(widget.profiles[pi]))
                      .toList()
                    ..sort();

                  // Choose a profile to pass into EventDetailsPage
                  final chosenProfileIndex = (!_viewAll)
                      ? _profileIndex
                      : (it.profileIndexes.isNotEmpty
                          ? it.profileIndexes.first
                          : 0);

                  final prof = (chosenProfileIndex >= 0 &&
                          chosenProfileIndex < widget.profiles.length)
                      ? widget.profiles[chosenProfileIndex]
                      : widget.profiles.first;

                  // Time label
                  final start =
                      _minutesToTimeOfDay(it.slot.startMinutes)?.format(ctx) ??
                          '';
                  final end =
                      _minutesToTimeOfDay(it.slot.endMinutes)?.format(ctx) ?? '';
                  final safeTime =
                      [start, end].where((x) => x.isNotEmpty).join(' – ');

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6D9), // Saved-card vibe
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: .08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.event.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),

                        Text(
                          [
                            if (safeTime.isNotEmpty) safeTime,
                            'Session ${it.sessionIndex + 1}',
                            if (safeNames.isNotEmpty)
                              'For: ${safeNames.join(", ")}',
                          ].join(' • '),
                          style: Theme.of(ctx)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black54),
                        ),

                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(); // close sheet
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EventDetailsPage(
                                    event: it.event,
                                    profile: prof,
                                    profiles: widget.profiles,
                                    sessionSelections:
                                        widget.sessionSelections[it.event.id] ??
                                            const {},
                                  ),
                                ),
                              );
                            },
                            child: const Text('View event'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  },
);

}

 // ---------- NEW: selections-driven calendar items ----------

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

// calendar selection state
DateTime _focusedDay = DateTime.now();
DateTime? _selectedDay;

// which profile we’re viewing (0 = first)
int _profileIndex = 0;

// day -> list of items for that day
final Map<DateTime, List<_CalItem>> _itemsByDay = {};

bool _loadingIndex = false;

Future<void> _rebuildIndex() async {
  if (_loadingIndex) return;
  _loadingIndex = true;

  try {
    final isar = await getIsar();

    final Map<DateTime, List<_CalItem>> next = {};

    for (final stub in widget.events) {
      final eventId = stub.id;

      // Only include events that have selections
      final selBySession = widget.sessionSelections[eventId];
      if (selBySession == null || selBySession.isEmpty) continue;

      // Load full event with slots
      final ev = await isar.events.get(eventId);
      if (ev == null) continue;

      await ev.slotIds.load();

      for (final slot in ev.slotIds) {
        final idx = slot.sessionIndex ?? 0;

        // only include selected sessions
 final selectedProfiles = selBySession[idx];
if (selectedProfiles == null || selectedProfiles.isEmpty) continue;

// ✅ keep only profile indexes that still exist in widget.profiles
final safeProfiles = selectedProfiles
    .where((pi) => pi >= 0 && pi < widget.profiles.length)
    .toSet();
if (safeProfiles.isEmpty) continue;

final day = _dayKey(slot.date);
(next[day] ??= <_CalItem>[]).add(
  _CalItem(
    event: ev,
    slot: slot,
    sessionIndex: idx,
    profileIndexes: safeProfiles, // ✅ HERE
  ),
);

      }
    }

    if (!mounted) return;
    setState(() {
      _itemsByDay
        ..clear()
        ..addAll(next);

      _selectedDay ??= _dayKey(DateTime.now());
    });
  } finally {
    _loadingIndex = false;
  }
}

// For TableCalendar markers
List<_CalItem> _itemsForDay(DateTime day) => _itemsByDay[_dayKey(day)] ?? const [];

// For the profile list under the calendar 
List<_CalItem> _visibleItemsForSelectedDay() {
  final day = _selectedDay;
  if (day == null) return const [];
  final items = _itemsForDay(day);

  // ✅ If view all, do NOT filter to one profile
  if (_viewAll) return items;

  // ✅ Otherwise show only items selected for the chosen profile
  return items.where((it) => it.profileIndexes.contains(_profileIndex)).toList();
}


// --- Compatibility helpers still used by the UI ---

// TableCalendar's eventLoader or older UI calls this name
List<dynamic> _filteredEvents(DateTime day) => _itemsForDay(day);

// Top nav / view mode buttons still call these
// Top nav / view mode buttons still call these
void _toMonth() => setState(() => _view = _ViewMode.month);

void _toWeek() => setState(() {
  _view = _ViewMode.week;

  // Keep selection consistent when switching views
  _selectedDay ??= _dayKey(_focusedDay);
  _focusedDay = _selectedDay!;
});

void _toDay() => setState(() => _view = _ViewMode.day);

// "Today" button handler (if your UI has one)
void _today() {
  final now = DateTime.now();
  setState(() {
    _focusedDay = now;
    _selectedDay = _dayKey(now);
    _shown = DateTime(now.year, now.month, 1);
  });
}

DateTime _startOfWeek(DateTime d) {
  final key = _dayKey(d);
  return key.subtract(Duration(days: key.weekday - DateTime.monday));
}

List<DateTime> _daysOfWeek(DateTime anchor) {
  final start = _startOfWeek(anchor);
  return List.generate(7, (i) => start.add(Duration(days: i)));
}


@override
void initState() {
  super.initState();
  _rebuildIndex();
}


  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;

    Widget header() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Text('MY EVENTS', style: t.textTheme.titleLarge?.copyWith(color: Colors.white)),
        const Spacer(),
        TextButton.icon(onPressed: widget.onAddEvent, icon: const Icon(Icons.add), label: const Text('Add'), style: TextButton.styleFrom(foregroundColor: Colors.white)),
        const SizedBox(width: 8),
        const Icon(Icons.calendar_month, color: Colors.white),
      ]),
    );

    Widget monthBar() {
      final title = DateFormat('MMMM yyyy').format(_shown);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => setState(() => _shown = DateTime(_shown.year, _shown.month - 1, 1))),
          Expanded(child: Center(child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)))),
          IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => setState(() => _shown = DateTime(_shown.year, _shown.month + 1, 1))),
        ]),
      );
    }

    Widget weekHeader() {
      const wds = ['MON','TUES','WEDS','THURS','FRI','SAT','SUN'];
      return Row(children: List.generate(7, (i) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .12)))),
          child: Center(child: Text(wds[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ),
      )));
    }

    Widget dayCell({required bool inMonth, required DateTime? date}) {
final dayItems =
    (inMonth && date != null) ? _itemsForDay(date) : const <_CalItem>[];

// ✅ View All = show everything for that day
// ✅ Single profile = only items for selected profile
final visibleItems = _viewAll
    ? dayItems
    : dayItems.where((it) => it.profileIndexes.contains(_profileIndex)).toList();

  // Optional: make dots bigger when a profile is selected
  final dotW = _viewAll ? 18.0 : 26.0;
  final dotH = _viewAll ? 6.0  : 8.0;

  return InkWell(
    onTap: (inMonth && date != null)
    ? () {
        final d = _dayKey(date);
        setState(() {
          _focusedDay = d;
          _selectedDay = d;
        });
        _openDayQuickView(d);
      }
    : null,

    child: Container(
      decoration: BoxDecoration(
        color: inMonth ? Colors.white : Colors.white.withValues(alpha: .5),
        border: Border.all(color: Colors.black.withValues(alpha: .07)),
      ),
      padding: const EdgeInsets.all(6),
      child: Stack(children: [
        Positioned(
          right: 0,
          top: 0,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              (inMonth && date != null) ? '${date.day}' : '',
              style: TextStyle(
                fontSize: 12,
                color: inMonth ? Colors.black87 : Colors.black38,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        if (inMonth && visibleItems.isNotEmpty)
  Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Builder(
      builder: (_) {
        // VIEW ALL: show one marker per profile that has anything saved this day
        if (_viewAll) {
          final set = <int>{};
          for (final it in visibleItems) {
            set.addAll(it.profileIndexes);
          }
          final indexes = set.toList()..sort();

          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: indexes.map((pi) {
              final safeIndex = (pi >= 0 && pi < widget.profiles.length) ? pi : 0;
              final c = widget.profiles[safeIndex].color;

              return Container(
                width: dotW,
                height: dotH,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.withValues(alpha: .6)),
                ),
              );
            }).toList(),
          );
        }

        // SINGLE PROFILE: show markers only for the selected profile
        final c = widget.profiles[_profileIndex].color;

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(
            visibleItems.length.clamp(1, 3),
            (_) => Container(
              width: dotW * 1.6,   // slightly bigger when a profile is selected
              height: dotH * 1.3,
              decoration: BoxDecoration(
                color: c.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.withValues(alpha: .75), width: 1.2),
              ),
            ),
          ),
        );
      },
    ),
  ),

      ]),
    ),
  );
}


    Widget monthGrid() {
      final firstWeekday = DateTime(_shown.year, _shown.month, 1).weekday; // 1..7
      final leading = (firstWeekday + 6) % 7; // 0..6
      final days = _daysInMonth(_shown);
      final total = ((leading + days) <= 35) ? 35 : 42;
      return Column(children: [
        weekHeader(),
        GridView.builder(
  shrinkWrap: true,                       // <-- let it size to content
  physics: const NeverScrollableScrollPhysics(),
  padding: EdgeInsets.zero,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 7,
  ),
  itemCount: total,
  itemBuilder: (_, i) {
    final dayNum = i - leading + 1;
    final inMonth = dayNum >= 1 && dayNum <= days;
    final date = inMonth ? DateTime(_shown.year, _shown.month, dayNum) : null;
    return dayCell(inMonth: inMonth, date: date);
            },
          ),
      ]);
    }



DateTime _startOfWeek(DateTime d) {
  // Monday-based week start
  final key = _dayKey(d);
  final delta = (key.weekday + 6) % 7; // Mon=0 ... Sun=6
  return key.subtract(Duration(days: delta));
}

Widget weekView() {
  // Monday-based start of week
  DateTime startOfWeek(DateTime d) {
    final day = _dayKey(d);
    final shift = day.weekday - DateTime.monday; // 0..6
    return day.subtract(Duration(days: shift));
  }

  final base = _selectedDay ?? _dayKey(_focusedDay);
  final start = startOfWeek(base);
  final days = List.generate(7, (i) => _dayKey(start.add(Duration(days: i))));

  // Make the single week row "tall"
  final h = MediaQuery.of(context).size.height;
  final gridHeight = (h * 0.62).clamp(360.0, 620.0);

  return SizedBox(
    height: gridHeight,
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,           // ✅ 7 vertical columns
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.25,      // ✅ taller blocks (smaller = taller)
      ),
      itemCount: 7,
      itemBuilder: (_, i) {
        final day = days[i];
        final dayItems = _itemsForDay(day);

        // Apply profile filter (if not viewAll)
        final visibleItems = _viewAll
            ? dayItems
            : dayItems.where((it) => it.profileIndexes.contains(_profileIndex)).toList();

        // Dots sizing
        final dotW = _viewAll ? 18.0 : 26.0;
        final dotH = _viewAll ? 6.0  : 8.0;

        // Build dots:
        // - View all: one dot per profile that has saved sessions that day
        // - Single profile: show up to 6 dots for that profile
        List<Widget> buildDots() {
          if (visibleItems.isEmpty) return const [];

          if (_viewAll) {
            final set = <int>{};
            for (final it in visibleItems) {
              set.addAll(it.profileIndexes);
            }
            final indexes = set.toList()..sort();

            return indexes.map((pi) {
              final safeIndex = (pi >= 0 && pi < widget.profiles.length) ? pi : 0;
              final c = widget.profiles[safeIndex].color;

              return Container(
                width: dotW,
                height: dotH,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: .28),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.withValues(alpha: .6)),
                ),
              );
            }).toList();
          }

          // single profile view color
          final safeIndex = (_profileIndex >= 0 && _profileIndex < widget.profiles.length) ? _profileIndex : 0;
          final c = widget.profiles[safeIndex].color;

          final count = visibleItems.length > 6 ? 6 : visibleItems.length;
          return List.generate(count, (_) {
            return Container(
              width: dotW,
              height: dotH,
              decoration: BoxDecoration(
                color: c.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: c.withValues(alpha: .6)),
              ),
            );
          });
        }

        final dots = buildDots();

        return InkWell(
          onTap: () {
            setState(() {
              _focusedDay = day;
              _selectedDay = day;
            });
            _openDayQuickView(day);
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: .08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Text(
                  DateFormat('EEE').format(day).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d').format(day),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 6),

                Text(
                  visibleItems.isEmpty ? 'No saved' : '${visibleItems.length} saved',
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),

                const SizedBox(height: 8),

                if (dots.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: dots,
                  ),

                const Spacer(),
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(Icons.chevron_right, size: 16, color: Colors.black45),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}



    Widget dayList() {
  final day = _selectedDay ?? _dayKey(_focusedDay ?? _shown);

  // Selected-items for that day
  final itemsForDay = _itemsForDay(day);

  // Apply profile filter
  final list = _viewAll
      ? itemsForDay
      : itemsForDay.where((it) => it.profileIndexes.contains(_profileIndex)).toList();

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .12))),
      ),
      child: Center(
        child: Text(
          DateFormat('EEEE, MMM d, yyyy').format(day),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ),

    if (list.isEmpty)
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No saved sessions', style: t.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
      )
    else
      ...list.map((it) {
        // Which profile to show as "For:"
        final profile = _viewAll
            ? widget.profiles[(it.profileIndexes.isNotEmpty ? it.profileIndexes.first : 0)]
            : widget.profiles[_profileIndex];

        final c = profile.color;

        return ListTile(
          dense: true,
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: c.withValues(alpha: .28),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: c.withValues(alpha: .6)),
            ),
          ),
          title: Text(it.event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('For: ${profileLabel(profile)} • Session ${it.sessionIndex + 1}'),
          onTap: () {
            final eventId = it.event.id;

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsPage(
                  event: it.event,
                  profile: profile,
                  profiles: widget.profiles,
                  // ✅ this is what makes the checkbox show selected
                  sessionSelections: widget.sessionSelections[eventId] ?? const {},
                  onUpdateSessionSelections: (map) {
                    // calendar page can’t mutate home state;
                    // selections updates should happen from details page back in home/saved flow.
                    // For now: do nothing here OR wire a callback later.
                  },
                ),
              ),
            );
          },
        );
      }),
  ]);
}


    Widget leftCard() => Container(
      decoration: BoxDecoration(color: const Color(0xFFF4EBE6), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: .08))),
      child: Column(children: [
        monthBar(),
        if (_view == _ViewMode.month) monthGrid(),
        if (_view == _ViewMode.week) weekView(),
        if (_view == _ViewMode.day) dayList(),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _viewChip('DAY', selected: _view == _ViewMode.day, onTap: _toDay),
    _viewChip('WEEK', selected: _view == _ViewMode.week, onTap: _toWeek),   
    _viewChip('MONTH', selected: _view == _ViewMode.month, onTap: _toMonth),
  ],
),

        ),
      ]),
    );

   Widget miniProfile(int index) {
  final p = widget.profiles[index];

  // ✅ selected state = "this profile is active" (when not viewAll)
  final selected = !_viewAll && _profileIndex == index;
  final bcolor = selected ? p.color : Colors.black.withValues(alpha: .15);

  // avatar
  final avatarSrc = (p.asset != null && p.asset!.isNotEmpty)
      ? p.asset!
      : 'assets/placeholders/event.jpg';
  final avatarProvider = profileImageProvider(avatarSrc);

  return InkWell(
    onTap: () => setState(() {
      _viewAll = false;
      _profileIndex = index;          // ✅ THIS is the key change
      _selectedProfiles               // ✅ keep this too (so older code stays safe)
        ..clear()
        ..add(index);
    }),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bcolor, width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: avatarProvider,
            backgroundColor: Colors.white,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              profileLabel(p).toUpperCase(), // ✅ 3A: consistent label
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}



    Widget sidebar() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
FilterChip(
  label: const Text('View all'),
  selected: _viewAll,
  showCheckmark: false,
  onSelected: (v) => setState(() {
    _viewAll = true;
    _selectedProfiles.clear();
  }),
),
      ]),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 2 * 54 + 10),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisExtent: 54, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: widget.profiles.length,
          itemBuilder: (_, i) => miniProfile(i),
        ),
      ),
      const SizedBox(height: 12),
      Text('Tap a profile to filter events.\nTap “View all” to show all events.', style: t.textTheme.bodySmall?.copyWith(color: Colors.black.withValues(alpha: .6))),
    ]);

        return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(),
            const SizedBox(height: 10),

            // NEW: make the calendar + sidebar scrollable and
            // allow them to shrink inside the available height.
            Expanded(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final wide = c.maxWidth >= 980;

                    if (wide) {
                      // Desktop / wide layout: calendar on left, sidebar on right
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: leftCard()),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: sidebar()),
                        ],
                      );
                    }

                    // Narrow layout: stack calendar and sidebar vertically
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftCard(),
                        const SizedBox(height: 16),
                        sidebar(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewChip(String label, {required bool selected, required VoidCallback onTap}) =>
      Padding(padding: const EdgeInsets.only(left: 8),
        child: FilterChip(selected: selected, showCheckmark: false, label: Text(label, style: const TextStyle(fontSize: 12)), onSelected: (_) => onTap()));
}