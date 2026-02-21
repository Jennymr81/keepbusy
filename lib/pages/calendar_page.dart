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

import '../utils/profile_label.dart';




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
    required this.slotSelections, 
  });

  final List<Profile> profiles;
  final List<Event> events;

  final void Function(Profile profile) onOpenProfile;
  final VoidCallback onAddEvent;

  final Map<Id, Map<int, Set<int>>> sessionSelections;
  final Map<int, Set<int>> slotSelections;

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

  // calendar selection state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // which profile we’re viewing (0 = first)
  int _profileIndex = 0;

  // day -> list of items for that day
  final Map<DateTime, List<_CalItem>> _itemsByDay = {};



  bool _loadingIndex = false;
// Hover mini-preview state
OverlayEntry? _hoverPreview;
bool _isHoveringBubble = false;
bool _isHoveringPreview = false;
Timer? _hoverHideTimer;


  int _daysInMonth(DateTime d) {
    final next =
        (d.month == 12) ? DateTime(d.year + 1, 1, 1) : DateTime(d.year, d.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  TimeOfDay? _minutesToTimeOfDay(int? m) {
    if (m == null) return null;
    final h = m ~/ 60;
    final min = m % 60;
    return TimeOfDay(hour: h, minute: min);
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  // For TableCalendar markers / day lookups
  List<_CalItem> _itemsForDay(DateTime day) => _itemsByDay[_dayKey(day)] ?? const [];

  // For older UI that may still call this name
  List<dynamic> _filteredEvents(DateTime day) => _itemsForDay(day);

  void _toMonth() => setState(() => _view = _ViewMode.month);

  void _toWeek() => setState(() {
        _view = _ViewMode.week;
        _selectedDay ??= _dayKey(_focusedDay);
        _focusedDay = _selectedDay!;
      });

  void _toDay() => setState(() => _view = _ViewMode.day);

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

  // ---------------------------
  // Build index from selections
  // ---------------------------
  Future<void> _rebuildIndex() async {
  if (_loadingIndex) return;
  _loadingIndex = true;

  try {
    final isar = await getIsar();
    final Map<DateTime, List<_CalItem>> next = {};

   for (final stub in widget.events) {
  final Id? eventId = stub.id;
  if (eventId == null) continue;

  final ev = await isar.events.get(eventId);
  if (ev == null) continue;

  await ev.slotIds.load();

  for (final slot in ev.slotIds) {
    final slotId = slot.id;
    if (slotId == 0) continue;

    // ✅ SOURCE OF TRUTH
    final selectedProfiles =
        widget.slotSelections[slotId] ?? const <int>{};
    if (selectedProfiles.isEmpty) continue;

    final safeProfiles = selectedProfiles
        .where((pi) => pi >= 0 && pi < widget.profiles.length)
        .toSet();
    if (safeProfiles.isEmpty) continue;

    final day = _dayKey(slot.date);

    (next[day] ??= <_CalItem>[]).add(
      _CalItem(
        event: ev,
        slot: slot,
        sessionIndex: slot.sessionIndex ?? 0,
        profileIndexes: safeProfiles,
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






// Mini preview for a single calendar item (hover)
void _showMiniPreview(BuildContext context, _CalItem it, LayerLink link) {
  _hideMiniPreview(immediate: true);

  final start = _minutesToTimeOfDay(it.slot.startMinutes);
  final end = _minutesToTimeOfDay(it.slot.endMinutes);

  final timeLine = (start != null)
      ? '${start.format(context)}${end != null ? ' – ${end.format(context)}' : ''}'
      : 'Time TBD';

  final screen = MediaQuery.of(context).size;
  final maxWidth = screen.width < 420 ? screen.width - 32 : 320.0;

  _hoverPreview = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: Stack(
        children: [
          CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            offset: const Offset(0, 44),
            child: MouseRegion(
              onEnter: (_) {
                _isHoveringPreview = true;
                _hoverHideTimer?.cancel();
              },
              onExit: (_) {
                _isHoveringPreview = false;
                _hideMiniPreview(); // delayed hide
              },
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                elevation: 0,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeLine,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            _hideMiniPreview(immediate: true);
                            _openDayQuickView(_dayKey(it.slot.date));
                          },
                          child: const Text('View event'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Overlay.of(context).insert(_hoverPreview!);
}


void _hideMiniPreview({bool immediate = false}) {
  _hoverHideTimer?.cancel();

  // If hovering either bubble or preview, do nothing.
  if (!immediate && (_isHoveringBubble || _isHoveringPreview)) return;

  if (immediate) {
    _hoverPreview?.remove();
    _hoverPreview = null;
    return;
  }

  // Small delay prevents flicker while moving mouse bubble -> preview
  _hoverHideTimer = Timer(const Duration(milliseconds: 120), () {
    if (_isHoveringBubble || _isHoveringPreview) return;
    _hoverPreview?.remove();
    _hoverPreview = null;
  });
}




 // clicking a day opens a “Quick View” card
Future<void> _openDayQuickView(DateTime day) async {
  final items = _viewAll
      ? _itemsForDay(day)
      : _itemsForDay(day)
          .where((it) => it.profileIndexes.contains(_profileIndex))
          .toList();

  if (items.isEmpty) return;

  // group by event+sessionIndex so multiple slots in same session/day don’t spam
  final map = <String, _CalItem>{};
  for (final it in items) {
    map[
        '${it.event.id}-${it.sessionIndex}-${_dayKey(it.slot.date).millisecondsSinceEpoch}'] = it;
  }

  final uniqueItems = map.values.toList();

  if (!mounted) return;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: uniqueItems.length,
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemBuilder: (_, i) {
          final it = uniqueItems[i];

          final start = _minutesToTimeOfDay(it.slot.startMinutes);
          final end = _minutesToTimeOfDay(it.slot.endMinutes);

          final timeLine = (start != null)
              ? '${start.format(context)}${end != null ? ' – ${end.format(context)}' : ''}'
              : 'Time TBD';

          final safeIndex = (it.profileIndexes.isNotEmpty &&
                  it.profileIndexes.first >= 0 &&
                  it.profileIndexes.first < widget.profiles.length)
              ? it.profileIndexes.first
              : 0;

          final c = widget.profiles[safeIndex].color;

          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 10,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            title: Text(
              it.event.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              timeLine,
              style: const TextStyle(color: Colors.black54),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.of(context).push(
                MaterialPageRoute(
  builder: (_) => EventDetailsPage(
  event: it.event,
  profile: widget.profiles[safeIndex],
  profiles: widget.profiles,

  // derived (for UI)
  sessionSelections:
      widget.sessionSelections[it.event.id] ?? const <int, Set<int>>{},

  // source of truth map (slotId -> profiles)
  slotSelections: widget.slotSelections,
),

)

              );
            },
          );
        },
      ),
    ),
  );
}


  @override
  void initState() {
    super.initState();
    _rebuildIndex();
  }

  @override
  void didUpdateWidget(covariant CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.events, widget.events) ||
        !identical(oldWidget.sessionSelections, widget.sessionSelections) ||
        oldWidget.profiles.length != widget.profiles.length) {
      _rebuildIndex();
    }

    if (_profileIndex >= widget.profiles.length) {
      setState(() {
        _profileIndex = 0;
        _viewAll = true;
        _selectedProfiles.clear();
      });
    }
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
            TextButton.icon(
              onPressed: widget.onAddEvent,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Today',
              onPressed: _today,
              icon: const Icon(Icons.today, color: Colors.white),
            ),
          ]),
        );

    Widget monthBar() {
      final title = DateFormat('MMMM yyyy').format(_shown);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => setState(() => _shown = DateTime(_shown.year, _shown.month - 1, 1)),
          ),
          Expanded(
            child: Center(
              child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => setState(() => _shown = DateTime(_shown.year, _shown.month + 1, 1)),
          ),
        ]),
      );
    }

    Widget weekHeader() {
      const wds = ['MON', 'TUES', 'WEDS', 'THURS', 'FRI', 'SAT', 'SUN'];
      return Row(
        children: List.generate(
          7,
          (i) => Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: .12))),
              ),
              child: Center(
                child: Text(wds[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      );
    }

    Widget dayCell({required bool inMonth, required DateTime? date}) {
      final dayItems = (inMonth && date != null) ? _itemsForDay(date) : const <_CalItem>[];

      final visibleItems = _viewAll
          ? dayItems
          : dayItems.where((it) => it.profileIndexes.contains(_profileIndex)).toList();

      final dotW = _viewAll ? 18.0 : 26.0;
      final dotH = _viewAll ? 6.0 : 8.0;

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
  // Show up to 2 mini cards per day cell to avoid overflow
  final shown = visibleItems.take(1).toList();
final extraCount = visibleItems.length - shown.length;

 return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    ...shown.map((it) {
      final layerLink = LayerLink();


      final safeIndex =
          (it.profileIndexes.isNotEmpty &&
                  it.profileIndexes.first >= 0 &&
                  it.profileIndexes.first < widget.profiles.length)
              ? it.profileIndexes.first
              : 0;

      final c = widget.profiles[safeIndex].color;

      final start = _minutesToTimeOfDay(it.slot.startMinutes);
      final timeLabel = start == null ? '' : start.format(context);

     return Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: CompositedTransformTarget(
    link: layerLink,
    child: MouseRegion(
      onEnter: (_) => _showMiniPreview(context, it, layerLink),
      onExit: (_) => _hideMiniPreview(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // 📱 Mobile
        onLongPress: () {
          _openDayQuickView(_dayKey(it.slot.date));
        },

        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 42,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: c.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: c.withValues(alpha: .6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  it.event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);





    }),

    // ✅ ADDITION (this is the "+X more")
    if (extraCount > 0)
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          '+$extraCount more',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
  ],
);



},



              ),
              ),
          ]),
        ),
      );
    }

    Widget monthGrid() {
      final firstWeekday = DateTime(_shown.year, _shown.month, 1).weekday;
      final leading = (firstWeekday + 6) % 7;
      final days = _daysInMonth(_shown);
      final total = ((leading + days) <= 35) ? 35 : 42;

      return Column(children: [
        weekHeader(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
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

    Widget weekView() {
      final base = _selectedDay ?? _dayKey(_focusedDay);
      final days = _daysOfWeek(base).map(_dayKey).toList();

      final h = MediaQuery.of(context).size.height;
      final gridHeight = (h * 0.62).clamp(360.0, 620.0);

      return SizedBox(
        height: gridHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.18,
          ),
          itemCount: 7,
          itemBuilder: (_, i) {
            final day = days[i];
            final dayItems = _itemsForDay(day);
            final visibleItems = _viewAll
                ? dayItems
                : dayItems.where((it) => it.profileIndexes.contains(_profileIndex)).toList();

            final dotW = _viewAll ? 18.0 : 26.0;
            final dotH = _viewAll ? 6.0 : 8.0;

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

              final safeIndex =
                  (_profileIndex >= 0 && _profileIndex < widget.profiles.length) ? _profileIndex : 0;
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
                    Text(DateFormat('EEE').format(day).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(DateFormat('MMM d').format(day),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      visibleItems.isEmpty ? 'No saved' : '${visibleItems.length} saved',
                      style: const TextStyle(color: Colors.black54, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    if (dots.isNotEmpty)
                      Wrap(spacing: 4, runSpacing: 4, children: dots),
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
      final day = _selectedDay ?? _dayKey(_focusedDay);
      final itemsForDay = _itemsForDay(day);

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

      // derived (UI only)
      sessionSelections:
          widget.sessionSelections[it.event.id] ?? const <int, Set<int>>{},

      // source of truth (slotId -> profiles)
      slotSelections: widget.slotSelections,
    ),
  ),
);

              },
            );
          }),
      ]);
    }

    Widget leftCard() => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4EBE6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: .08)),
          ),
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
      final selected = !_viewAll && _profileIndex == index;
      final bcolor = selected ? p.color : Colors.black.withValues(alpha: .15);

      final avatarSrc = (p.asset != null && p.asset!.isNotEmpty) ? p.asset! : 'assets/keepbusy_logo.png';
      final avatarProvider = profileImageProvider(avatarSrc);

      return InkWell(
        onTap: () => setState(() {
          _viewAll = false;
          _profileIndex = index;
          _selectedProfiles
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
                  profileLabel(p).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 54,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: widget.profiles.length,
              itemBuilder: (_, i) => miniProfile(i),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap a profile to filter events.\nTap “View all” to show all events.',
            style: t.textTheme.bodySmall?.copyWith(color: Colors.black.withValues(alpha: .6)),
          ),
        ]);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header(),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final wide = c.maxWidth >= 980;

                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: leftCard()),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: sidebar()),
                        ],
                      );
                    }

                    return LayoutBuilder(
  builder: (context, c) {
    final isWide = c.maxWidth >= 900; // desktop / tablet breakpoint

    // WIDE: profiles on top, calendar gets full vertical space
    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sidebar(),               // profiles FIRST
          const SizedBox(height: 16),
          leftCard(),              // calendar gets full height
        ],
      );
    }

    // NARROW (mobile): keep existing behavior
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leftCard(),
        const SizedBox(height: 16),
        sidebar(),
      ],
    );
  },
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

  Widget _viewChip(String label, {required bool selected, required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: FilterChip(
          selected: selected,
          showCheckmark: false,
          label: Text(label, style: const TextStyle(fontSize: 12)),
          onSelected: (_) => onTap(),
        ),
      );
}