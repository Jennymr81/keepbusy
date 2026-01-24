// lib/pages/event_entry_form_page.dart

import 'dart:io' show File;
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;
import 'package:table_calendar/table_calendar.dart';

import '../models/event_models.dart';        // Event, EventSlot, Id, etc.
import 'package:keepbusy/models/profile.dart';
import '../data/db.dart';                    // getIsar()
import '../widgets/image_helpers.dart';      // eventImageProvider, etc.
import 'package:isar/isar.dart';

import '../utils/input_formatters.dart';
import '../widgets/aligned_image_preview.dart';
import '../constants/app_constants.dart';



// ==============================
// Event Form-specific helpers
// ==============================

// Local weekday labels for this page
String _weekdayShort(int w) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];


// Valid 2-letter US state / territory postal abbreviations
const Set<String> kvalidStates = {
  'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA',
  'ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK',
  'OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY','DC','PR'
};

// Whether Google Places is wired (you had this as a stub in main.dart)
const bool kPlacesEnabled = false;

// Basic date/time helpers
DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);
int? timeToMin(TimeOfDay? t) => t == null ? null : t.hour * 60 + t.minute;
TimeOfDay? minToTime(int? m) =>
    m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);

// Short weekday names used in the form (Mon, Tue, etc.)
const List<String> kWeekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
];

// Month labels + helpers for range text like "Jan 3 – Feb 7"
const List<String> _month = [
  '',
  'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
];

String _md(DateTime d) => '${_month[d.month]} ${d.day}';

String _rangeLabel(DateTime? a, DateTime? b) {
  if (a == null || b == null) return '—';
  final sameMonth = a.month == b.month && a.year == b.year;
  return sameMonth
      ? '${_month[a.month]} ${a.day} – ${b.day}'
      : '${_month[a.month]} ${a.day} – ${_month[b.month]} ${b.day}';
}

// ======================================
// Multi-date picker page (used by sessions)
// ======================================
class _MultiDatePickerPage extends StatefulWidget {
  const _MultiDatePickerPage({required this.initial});
  final Set<DateTime> initial;

  @override
  State<_MultiDatePickerPage> createState() => _MultiDatePickerPageState();
}

class _MultiDatePickerPageState extends State<_MultiDatePickerPage> {
  late Set<DateTime> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.map(_d).toSet();
  }

  // --- small helpers ---
  DateTime _mStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _addMonths(DateTime d, int n) => DateTime(d.year, d.month + n, 1);
  int _monthDiff(DateTime a, DateTime b) =>
      (b.year - a.year) * 12 + (b.month - a.month);

  String _mLabel(DateTime m) => DateFormat('MMMM yyyy').format(m);
  bool _isSelected(DateTime day) => _selected.contains(_d(day));

  void _toggle(DateTime day) {
    final key = _d(day);
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Widget _monthCalendar(DateTime month) {
    final firstDay = _mStart(month);
    final lastDay = _addMonths(month, 1).subtract(const Duration(days: 1));
    return TableCalendar(
      firstDay: firstDay,
      lastDay: lastDay,
      focusedDay: month,
      headerVisible: false,
      availableGestures: AvailableGestures.none,
      pageAnimationEnabled: false,
      sixWeekMonthsEnforced: true,
      daysOfWeekVisible: true,
      selectedDayPredicate: _isSelected,
      onDaySelected: (d, _) => _toggle(d),
      onDisabledDayTapped: (d) => _toggle(d),
      calendarStyle: CalendarStyle(
        isTodayHighlighted: true,
        tablePadding: const EdgeInsets.symmetric(horizontal: 6),
        cellMargin: const EdgeInsets.all(2),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        todayDecoration: const BoxDecoration(shape: BoxShape.circle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = _selected.isNotEmpty ? _selected.first : DateTime.now();
    final firstMonth = _addMonths(_mStart(base), -1); // one before
    final lastMonth = _addMonths(firstMonth, 13);     // and 13 after
    final total = _monthDiff(firstMonth, lastMonth) + 1;

    final title = _selected.isEmpty
        ? 'Select session dates'
        : (() {
            final list = _selected.toList()..sort();
            return '${DateFormat('MMM d').format(list.first)} – '
                   '${DateFormat('MMM d').format(list.last)}';
          })();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Save'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: total,
            itemBuilder: (_, i) {
              final month = _addMonths(firstMonth, i);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                    child: Text(
                      _mLabel(month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _monthCalendar(month),
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
// Event Entry Form (Create/Edit canonical)
// ==============================
class EventEntryFormPage extends StatefulWidget {
  const EventEntryFormPage({super.key, required this.profiles, this.existing});
  final List<Profile> profiles;
  final Event? existing;

  @override
  State<EventEntryFormPage> createState() => _EventEntryFormPageState();
}

// Simple local session model used by the form
class _Session {
  DateTime? startDate;
  DateTime? endDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  Set<DateTime> selectedDates = {};
  Set<int> weekdays = {};
  int? weeks;

  int? ageMin;
  int? ageMax;
  double? cost;

  String? level;
  String? locationName;

  void setDates(Set<DateTime> dates) {
    DateTime d0(DateTime d) => DateTime(d.year, d.month, d.day);
    selectedDates = dates.map(d0).toSet();

    if (selectedDates.isEmpty) {
      startDate = null;
      endDate   = null;
      weekdays  = {};
      weeks     = null;
      return;
    }

    startDate = selectedDates.reduce((a, b) => a.isBefore(b) ? a : b);
    endDate   = selectedDates.reduce((a, b) => a.isAfter(b)  ? a : b);
    weekdays  = selectedDates.map((d) => d.weekday).toSet();

    final total = selectedDates.length;
    final dpw   = weekdays.isEmpty ? 1 : weekdays.length;
    weeks = ((total + dpw - 1) ~/ dpw);
  }
}

class _EventEntryFormPageState extends State<EventEntryFormPage> {
  // if editing, store the id
  Id? _editingId;

  DateTime? _existingCreatedAt;

  final _formKey = GlobalKey<FormState>();


  // fields
  final _title = TextEditingController();
  final _desc  = TextEditingController();

  final _location = TextEditingController();
  final _address  = TextEditingController();
  final _city     = TextEditingController();
  final _state    = TextEditingController();
  final _zip      = TextEditingController();

  double? _pickedLat;
double? _pickedLng;

  int? _ageMin;
  int? _ageMax;
  final _cost = TextEditingController();
  final _fee  = TextEditingController();
  final _feeNote = TextEditingController();

  final _linkCtrls = <TextEditingController>[TextEditingController()];

  // Interests
  final Set<String> _pickedInterests = {};
  final List<String> _customInterests = <String>[];
  final TextEditingController _customInterestCtrl = TextEditingController();
  static const int _maxCustom = 3;

  int get _totalSelected => _pickedInterests.length + _customInterests.length;
  int get _remaining     => 5 - _totalSelected;

  static const int _maxLinks = 3;

  // Image fields
  final TextEditingController _imageCtl = TextEditingController(); // image URL
  String? _pickedImagePath;                                        // local file path
  final ImagePicker _picker = ImagePicker();
  double _imgAlignY = 0.0; // -1..1

  // sessions
  static const _maxSessions = 10;
  int _visibleCount = 1;
  final List<_Session> sessions =
      List.generate(_maxSessions, (_) => _Session());

  // NEW: per-session favorite + selected profiles (UI prototype only)
  final List<bool> _sessionFavoriteFlags =
      List<bool>.filled(_maxSessions, false);

  /// For each session index, which profile indexes (into widget.profiles)
  /// this session is "selected" for.
  final List<Set<int>> _sessionSelectedProfileIndexes =
      List.generate(_maxSessions, (_) => <int>{});

  // we’ll assign everything to profile 0 (first) for now
  int get _selectedProfileIndex => 0;

  // ------------ helpers ------------

  bool _isValidUrl(String s) {
    try {
      final uri = Uri.parse(s.trim());
      if (!uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
        return false;
      }
      if (uri.host.isEmpty) return false;
      if (s.contains(' ')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  // Build a small keyword set from event/org fields
  Set<String> _orgKeywords() {
    final src = [
      _title.text,
      _location.text,
      _address.text,
      _city.text,
      _state.text,
      _zip.text,
    ].join(' ');
    final words = src
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3)
        .take(20);
    return words.toSet();
  }

  // Heuristic “is this link about this org?”
  bool _looksRelated(String url) {
    final kw = _orgKeywords();
    if (kw.isEmpty) return true;
    final u = url.toLowerCase();
    final hostPath = () {
      try {
        final uri = Uri.parse(u);
        return '${uri.host}${uri.path}';
      } catch (_) {
        return u;
      }
    }();
    return kw.any((k) => hostPath.contains(k));
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _addCustomInterest() {
    final raw = _customInterestCtrl.text.trim();
    if (raw.isEmpty) return;

    if (raw.length > 20) {
      _showErr('Custom interests must be 20 characters or fewer.');
      return;
    }

    final low = raw.toLowerCase();
    final dupPreset  = _pickedInterests.any((e) => e.toLowerCase() == low);
    final dupCustom  = _customInterests.any((e) => e.toLowerCase() == low);
    if (dupPreset || dupCustom) {
      _showErr('That interest is already selected.');
      return;
    }

    if (_customInterests.length >= _maxCustom) {
      _showErr('You can add up to 3 custom interests.');
      return;
    }
    if (_remaining <= 0) {
      _showErr('You’ve reached the maximum of 5 interests. '
          'Deselect one to add another.');
      return;
    }

    setState(() {
      _customInterests.add(raw);
      _customInterestCtrl.clear();
    });
  }

  void _removeCustomInterest(String v) {
    setState(() => _customInterests.remove(v));
  }

  void _rebuildSessionsFromSlots(List<EventSlot> slots) {
    sessions.clear();
    _visibleCount = 0;

    if (slots.isEmpty) {
      setState(() {});
      return;
    }

    final Map<int, List<EventSlot>> bySession = {};
    final Map<String, List<EventSlot>> byTimeFallback = {};
    bool hasAnyIndex = false;

    String timeKey(EventSlot s) {
      final sm = s.startMinutes ?? -1;
      final em = s.endMinutes ?? -1;
      return 't$sm-$em';
    }

    for (final s in slots) {
      final idx = s.sessionIndex;
      if (idx != null && idx >= 0) {
        hasAnyIndex = true;
        bySession.putIfAbsent(idx, () => []).add(s);
      } else {
        final key = timeKey(s);
        byTimeFallback.putIfAbsent(key, () => []).add(s);
      }
    }

    Iterable<List<EventSlot>> groups;
    if (hasAnyIndex) {
      final keys = bySession.keys.toList()..sort();
      groups = keys.map((k) {
        final list = bySession[k]!..sort((a, b) => a.date.compareTo(b.date));
        return list;
      });
    } else {
      groups = byTimeFallback.values;
      for (final list in groups) {
        list.sort((a, b) => a.date.compareTo(b.date));
      }
    }

    for (final list in groups) {
      if (list.isEmpty) continue;

      final first = list.first;
      final sm = first.startMinutes;
      final em = first.endMinutes;

      final ses = _Session()
        ..startTime = minToTime(sm)
        ..endTime   = minToTime(em)
        ..ageMin    = first.ageMin
        ..ageMax    = first.ageMax
        ..cost      = first.cost
        ..level     = first.level
        ..locationName = first.locationName;

      ses.setDates(
        list
            .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
            .toSet(),
      );

      sessions.add(ses);
    }

    _visibleCount = sessions.length;
    setState(() {});
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: .12),
          ),
        ),
      );

  ImageProvider<Object> _imageProviderFromInputs() {
    // Prefer a locally picked image (for live preview)
    if (_pickedImagePath != null) {
      final f = File(_pickedImagePath!);
      if (f.existsSync()) return FileImage(f);
    }

    // Otherwise, if the text field has an http(s) URL, use that
    final url = _imageCtl.text.trim();
    if (url.startsWith('http')) return NetworkImage(url);

    // Fallback to your placeholder asset
    return const AssetImage('assets/keepbusy_logo.png');
  }

  Future<Set<DateTime>?> _pickDates(Set<DateTime> initial) async {
    DateTime _ymd(DateTime d) => DateTime(d.year, d.month, d.day);

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return showModalBottomSheet<Set<DateTime>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        Set<DateTime> selected = {...initial.map(_ymd)};
        DateTime focused = monthStart;

        return StatefulBuilder(
          builder: (ctx, setSB) => SafeArea(
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Pick dates',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Expanded(
                    child: TableCalendar(
                      firstDay:
                          monthStart.subtract(const Duration(days: 365)),
                      lastDay: monthStart.add(const Duration(days: 365)),
                      focusedDay: focused,
                      selectedDayPredicate: (d) =>
                          selected.contains(_ymd(d)),
                      onDaySelected: (selectedDay, newFocusedDay) {
                        final key = _ymd(selectedDay);
                        setSB(() {
                          if (selected.contains(key)) {
                            selected.remove(key);
                          } else {
                            selected.add(key);
                          }
                          focused = newFocusedDay;
                        });
                      },
                      onPageChanged: (newFocusedDay) {
                        setSB(() => focused = newFocusedDay);
                      },
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, selected),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // pick profiles for a specific session (UI-only prototype)
  Future<void> _pickProfilesForSession(int sessionIndex) async {
    if (widget.profiles.isEmpty) {
      _showErr('Add at least one profile first.');
      return;
    }

    final current =
        Set<int>.from(_sessionSelectedProfileIndexes[sessionIndex]);

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
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select profiles for this session',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        itemCount: widget.profiles.length,
                        itemBuilder: (ctx, i) {
                          final checked = temp.contains(i);
                          final label = 'Profile ${i + 1}';

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

    if (result == null) return;

    setState(() {
      _sessionSelectedProfileIndexes[sessionIndex]
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _showLimitDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limit reached'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<TimeOfDay?> _pickTime(
    TimeOfDay initial, {
    String? helpText,
  }) =>
      showTimePicker(
        context: context,
        initialTime: initial,
        initialEntryMode: TimePickerEntryMode.input,
        helpText: helpText,
      );

  // Pick dates for a specific session (uses _MultiDatePickerPage)
  Future<void> _pickDatesForSession(int index) async {
    final s = sessions[index];

    final picked = await Navigator.push<Set<DateTime>?>(
      context,
      MaterialPageRoute(
        builder: (_) => _MultiDatePickerPage(initial: s.selectedDates),
      ),
    );

    if (!mounted || picked == null) return;

    setState(() {
      s.setDates(picked);
    });
  }

  // Pick start/end time for a specific session
  Future<void> _pickTimesForSession(int index) async {
    final s = sessions[index];

    final start = await _pickTime(
      s.startTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Select start time',
    );
    if (start == null) return;

    final end = await _pickTime(
      s.endTime ??
          TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
      helpText: 'Select end time',
    );
    if (end == null) return;

    final sm = timeToMin(start)!;
    final em = timeToMin(end)!;
    if (em <= sm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() {
      s.startTime = start;
      s.endTime = end;
    });
  }

  // ---- save ----
  void _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Strict checks for links
    for (final c in _linkCtrls) {
      final s = c.text.trim();
      if (s.isEmpty) continue;
      if (!_isValidUrl(s)) {
        await _showLimitDialog('Please fix or remove invalid links.');
        return;
      }
      if (!_looksRelated(s)) {
        await _showLimitDialog(
          'One or more links don’t appear related to this event/org.\n'
          'Please provide an official website, registration page, or social profile that matches your org/address.',
        );
        return;
      }
    }

    // Build slots from sessions
    final List<EventSlot> slots = [];

    if (sessions.isEmpty) {
      _showErr('Add at least one session');
      return;
    }

    final int count = min(_visibleCount, sessions.length);

    for (int i = 0; i < count; i++) {
      final s = sessions[i];

      if (s.selectedDates.isEmpty ||
          s.startTime == null ||
          s.endTime == null) {
        continue;
      }

      final int sm = timeToMin(s.startTime!)!;
      final int em = timeToMin(s.endTime!)!;

      final dates = s.selectedDates.toList()..sort();
      for (final d in dates) {
        slots.add(
          EventSlot()
            ..date         = d
            ..startMinutes = sm
            ..endMinutes   = em
            ..sessionIndex = i
            ..ageMin       = s.ageMin
            ..ageMax       = s.ageMax
            ..cost         = s.cost
            ..level        = s.level
            ..locationName = s.locationName,
        );
      }
    }

    if (slots.isEmpty) {
      _showErr('Pick dates and times for at least one session');
      return;
    }

    slots.sort((a, b) => a.date.compareTo(b.date));

    int? eventAgeMin;
    int? eventAgeMax;
    double? eventCostMin;

    for (final s in slots) {
      final mn = s.ageMin;
      final mx = s.ageMax;
      final c  = s.cost;

      if (mn != null) {
        eventAgeMin =
            (eventAgeMin == null) ? mn : (mn < eventAgeMin! ? mn : eventAgeMin!);
      }
      if (mx != null) {
        eventAgeMax =
            (eventAgeMax == null) ? mx : (mx > eventAgeMax! ? mx : eventAgeMax!);
      }
      if (c != null) {
        eventCostMin =
            (eventCostMin == null) ? c : (c < eventCostMin! ? c : eventCostMin!);
      }
    }

    final e = Event()
      ..title            = _title.text.trim()
      ..description      = _desc.text.trim()
      ..shortDescription = _desc.text.trim()
      ..locationName     = _location.text.trim()
      ..address          = _address.text.trim()
      ..city             = _city.text.trim()
      ..state            = _state.text.trim().toUpperCase()
      ..zip              = _zip.text.trim()
      ..ageMin           = eventAgeMin
      ..ageMax           = eventAgeMax
      ..createdAt = _existingCreatedAt ?? DateTime.now()
      ..locationLat      = _pickedLat
..locationLng      = _pickedLng
      ..cost             = (() {
            final fromHeader = double.tryParse(_cost.text.trim());
            if (fromHeader != null) return fromHeader;
            return eventCostMin;
          })()
      ..fee              = double.tryParse(_fee.text.trim())
      ..feeNote          = _feeNote.text.trim()
      ..interests        = <String>[
        ..._pickedInterests,
        ..._customInterests,
      ]
      ..links            = _linkCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList()
      ..imagePath        = (() {
        final p = _pickedImagePath ?? _imageCtl.text.trim();
        return p.isNotEmpty ? p : null;
      })()
      ..profileIndex     = _selectedProfileIndex
      ..date             = _d(slots.first.date);

    if (_editingId != null) e.id = _editingId!;

    Navigator.pop(context, {'event': e, 'slots': slots});
  }

  Future<void> _confirmDelete() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete event?'),
        content: const Text(
          'This will permanently remove the event and its sessions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      Navigator.pop(context, {'delete': true, 'id': _editingId});
    }
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _existingCreatedAt = e.createdAt;
      _editingId = e.id;
      _title.text  = e.title;
      _desc.text = (e.shortDescription?.trim().isNotEmpty == true)
          ? e.shortDescription!.trim()
          : (e.description ?? '');
      _location.text = e.locationName ?? '';
      _address.text  = e.address ?? '';
      _state.text    = e.state ?? '';
      _city.text = e.city ?? '';
      _zip.text      = e.zip ?? '';
      _ageMin = e.ageMin;
      _ageMax = e.ageMax;
      _pickedLat = e.locationLat;
_pickedLng = e.locationLng;
      if (e.cost != null) _cost.text = e.cost!.toStringAsFixed(2);
      if (e.fee  != null) _fee.text  = e.fee!.toStringAsFixed(2);
      _feeNote.text = e.feeNote ?? '';
      _pickedInterests
        ..clear()
        ..addAll(e.interests);
      _imageCtl.text = e.imagePath ?? '';
      _pickedImagePath =
          (e.imagePath != null && !e.imagePath!.startsWith('http'))
              ? e.imagePath
              : null;

      final existingSlots = e.slotIds.toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      _rebuildSessionsFromSlots(existingSlots);

      _linkCtrls
        ..clear()
        ..addAll(
          (e.links.isEmpty ? [''] : e.links)
              .map((s) => TextEditingController(text: s)),
        );
    } else {
      sessions.clear();
      sessions.add(_Session());
      _visibleCount = sessions.length;

      _linkCtrls
        ..clear()
        ..add(TextEditingController(text: ''));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _location.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _cost.dispose();
    _fee.dispose();
    _feeNote.dispose();
    _customInterestCtrl.dispose();
    for (final c in _linkCtrls) {
      c.dispose();
    }
    _imageCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 520;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Entry'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Form(
              key: _formKey,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'EVENT ENTRY FORM (COORDINATOR VIEW)',
                      style: t.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  TextFormField(
                    controller: _title,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    maxLengthEnforcement:
                        MaxLengthEnforcement.enforced,
                    maxLines: 1,
                    decoration:
                        _dec('Title').copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),

                  // ======= EVENT IMAGE =======
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: .12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event image',
                          style: t.textTheme.titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(10),
                            child: GestureDetector(
                              onVerticalDragUpdate: (d) {
                                setState(() {
                                  _imgAlignY = (_imgAlignY +
                                          d.delta.dy / 120)
                                      .clamp(-1.0, 1.0);
                                });
                              },
                              child: AlignedImagePreview(
                                provider:
                                    _imageProviderFromInputs(),
                                alignY: _imgAlignY,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Crop Y',
                              style: TextStyle(fontSize: 12),
                            ),
                            Expanded(
                              child: Slider(
                                value: _imgAlignY,
                                min: -1,
                                max: 1,
                                onChanged: (v) => setState(
                                    () => _imgAlignY = v),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(
                                  () => _imgAlignY = 0),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _imageCtl,
                          decoration: _dec(
                                  'Image URL (optional)')
                              .copyWith(
                            helperText:
                                'Paste an http(s) image URL or pick from gallery',
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                final x =
                                    await _picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 2048,
                                  maxHeight: 2048,
                                  imageQuality: 85,
                                );
                                if (x == null) return;
                                setState(() =>
                                    _pickedImagePath = x.path);
                              },
                              icon: const Icon(
                                  Icons.photo_library_outlined),
                              label: const Text('Pick image'),
                            ),
                            const SizedBox(width: 12),
                            if (_pickedImagePath != null ||
                                _imageCtl.text
                                    .trim()
                                    .isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _pickedImagePath = null;
                                    _imageCtl.clear();
                                  });
                                },
                                icon: const Icon(Icons.close),
                                label: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _desc,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    maxLength: 500,
                    maxLengthEnforcement:
                        MaxLengthEnforcement.enforced,
                    minLines: isNarrow ? 5 : 4,
                    maxLines: isNarrow ? 10 : 8,
                    decoration: _dec(
                      'Description (up to 500 characters)',
                    ).copyWith(counterText: ''),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) {
                        return 'Please enter a description';
                      }
                      if (s.length > 500) {
                        return 'Max 500 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Location
                  TextFormField(
                    controller: _location,
                    textInputAction: TextInputAction.next,
                    maxLength: 100,
                    maxLengthEnforcement:
                        MaxLengthEnforcement.enforced,
                    maxLines: 1,
                    decoration: _dec(
                      'Location (venue / park / facility)',
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 10),

                  // Fee row
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextFormField(
                          controller: _fee,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [CurrencyFormatter()],
                          decoration: const InputDecoration(
                            labelText: 'Fee (instructor)',
                            prefixText: '\$',
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: TextFormField(
                          controller: _feeNote,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.text,
                          maxLength: 100,
                          maxLengthEnforcement:
                              MaxLengthEnforcement.enforced,
                          decoration:
                              _dec('Fee note (optional)').copyWith(
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // =====================
                  // Sessions
                  // =====================
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16.0,
                      bottom: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sessions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'up to $_maxSessions (1 required)',
                        ),
                      ],
                    ),
                  ),

                  if (sessions.isNotEmpty)
                    Column(
                      children: List.generate(
                        (_visibleCount <= sessions.length)
                            ? _visibleCount
                            : sessions.length,
                        (i) {
                          final s = sessions[i];
                          final selectedIndexes =
                              _sessionSelectedProfileIndexes[i];

                          final selectedLabel =
                              selectedIndexes.isEmpty
                                  ? 'None yet'
                                  : selectedIndexes
                                      .map(
                                          (pi) => 'Profile ${pi + 1}')
                                      .join(', ');

                          String range() =>
                              _rangeLabel(s.startDate, s.endDate);

                          String times() =>
                              (s.startTime == null ||
                                      s.endTime == null)
                                  ? 'Start & End Time'
                                  : '${s.startTime!.format(context)} – '
                                      '${s.endTime!.format(context)}';

                          final String daysText =
                              s.weekdays.isEmpty
                                  ? '—'
                                  : (() {
                                      final list = s.weekdays
                                          .toList()
                                        ..sort();
                                      return list
                                          .map(_weekdayShort)
                                          .join(', ');
                                    })();

                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: 12,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F0ED),
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.black
                                    .withOpacity(.12),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // LEFT COLUMN
                                SizedBox(
                                  width: 220,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration:
                                                BoxDecoration(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          999),
                                              color: Theme.of(
                                                      context)
                                                  .colorScheme
                                                  .secondaryContainer,
                                            ),
                                            child: Text(
                                              'Session ${i + 1}',
                                              style: Theme.of(
                                                      context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight
                                                            .w700,
                                                  ),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (_visibleCount > 1)
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _visibleCount--;
                                                });
                                              },
                                              icon: const Icon(Icons
                                                  .remove_circle_outline),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Text(
                                            'Days: ',
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(daysText),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text(
                                            'Number of weeks:',
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${s.weeks ?? 0}',
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          const Text(
                                            'Selected for:',
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              selectedLabel,
                                              maxLines: 2,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text(
                                            'Level:',
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<String>(
                                            value: s.level,
                                            hint: const Text(
                                              'Select',
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                s.level = value;
                                              });
                                            },
                                            items: const [
                                              DropdownMenuItem(
                                                value:
                                                    'Beginner',
                                                child: Text(
                                                    'Beginner'),
                                              ),
                                              DropdownMenuItem(
                                                value:
                                                    'Intermediate',
                                                child: Text(
                                                    'Intermediate'),
                                              ),
                                              DropdownMenuItem(
                                                value:
                                                    'Advanced',
                                                child: Text(
                                                    'Advanced'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text(
                                            'Age:',
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<int>(
                                            value: s.ageMin,
                                            hint: const Text('Min'),
                                            onChanged: (value) {
                                              setState(() {
                                                s.ageMin = value;
                                              });
                                            },
                                            items:
                                                List.generate(
                                              101,
                                              (n) =>
                                                  DropdownMenuItem(
                                                value: n,
                                                child: Text(
                                                  '$n',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text('–'),
                                          const SizedBox(width: 4),
                                          DropdownButton<int>(
                                            value: s.ageMax,
                                            hint: const Text('Max'),
                                            onChanged: (value) {
                                              setState(() {
                                                s.ageMax = value;
                                              });
                                            },
                                            items:
                                                List.generate(
                                              101,
                                              (n) =>
                                                  DropdownMenuItem(
                                                value: n,
                                                child: Text(
                                                  '$n',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Text(
                                            'Cost:',
                                            style: TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 90,
                                            child:
                                                TextFormField(
                                              key: ValueKey(
                                                  'session_cost_$i'),
                                              initialValue: s.cost
                                                      ?.toStringAsFixed(
                                                          0) ??
                                                  '',
                                              keyboardType:
                                                  const TextInputType
                                                      .numberWithOptions(
                                                decimal: true,
                                              ),
                                              onChanged: (v) {
                                                final parsed =
                                                    double.tryParse(
                                                  v.trim(),
                                                );
                                                setState(
                                                  () =>
                                                      s.cost =
                                                          parsed,
                                                );
                                              },
                                              decoration:
                                                  const InputDecoration(
                                                prefixText: '\$',
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        key: ValueKey(
                                          'session_location_$i',
                                        ),
                                        initialValue:
                                            s.locationName ?? '',
                                        onChanged: (v) =>
                                            setState(() =>
                                                s.locationName =
                                                    v.trim()),
                                        decoration:
                                            const InputDecoration(
                                          labelText:
                                              'Location (optional)',
                                          isDense: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // RIGHT COLUMN - date/time tiles
                                Expanded(
                                  child: Column(
                                    children: [
                                      _pill(
                                        label: 'Start & End Date',
                                        value: range(),
                                        icon: Icons.event,
                                        onTap: () =>
                                            _pickDatesForSession(
                                          i,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _pill(
                                        label: 'Start & End Time',
                                        value: times(),
                                        icon: Icons.access_time,
                                        onTap: () =>
                                            _pickTimesForSession(
                                          i,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                  if (sessions.length < _maxSessions)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          sessions.add(_Session());
                          _visibleCount = sessions.length;
                        }),
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add session (${_maxSessions - sessions.length} left)',
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Interests
                  Row(
                    children: [
                      Text(
                        'Interests (up to 5)',
                        style: t.textTheme.titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_remaining left',
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in const [
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
                      ])
                        FilterChip(
                          label: Text(label),
                          selected:
                              _pickedInterests.contains(label),
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                if (_remaining <= 0) {
                                  _showLimitDialog(
                                    'You’ve reached the maximum of 5 interests. '
                                    'Deselect one to add another.',
                                  );
                                  return;
                                }
                                _pickedInterests.add(label);
                              } else {
                                _pickedInterests.remove(label);
                              }
                            });
                          },
                        ),
                      for (final s in _customInterests)
                        InputChip(
                          label: Text(s),
                          selected: true,
                          onDeleted: () =>
                              _removeCustomInterest(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Custom interests (up to 3 • 20 chars each)',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customInterestCtrl,
                          maxLength: 20,
                          maxLengthEnforcement:
                              MaxLengthEnforcement.enforced,
                          decoration: const InputDecoration(
                            hintText:
                                'Type a custom interest (e.g., “Pickleball”)',
                            counterText: '',
                          ),
                          onFieldSubmitted: (_) =>
                              _addCustomInterest(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _addCustomInterest,
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Address
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _address,
                          decoration: _dec('Street Address'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          decoration: _dec('City'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          controller: _state,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z]'),
                            ),
                            LengthLimitingTextInputFormatter(2),
                            UpperCaseTextFormatter(),
                          ],
                          decoration: _dec('State'),
                          validator: (v) {
                            final s =
                                (v ?? '').trim().toUpperCase();
                            if (s.isEmpty) return 'Required';
                            if (!kvalidStates.contains(s)) {
                              return 'Use 2-letter code';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: TextFormField(
                          controller: _zip,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: _dec('ZIP'),
                          validator: (v) {
                            final z = (v ?? '').trim();
                            if (z.isEmpty) return 'Required';
                            if (z.length != 5) return '5 digits';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Links
                  Row(
                    children: [
                      Text(
                        'Links',
                        style: t.textTheme.titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        '(${_linkCtrls.length}/$_maxLinks)',
                        style: t.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          if (_linkCtrls.length >= _maxLinks) {
                            await _showLimitDialog(
                              'You can add up to $_maxLinks links.',
                            );
                            return;
                          }
                          setState(() => _linkCtrls.add(
                                TextEditingController(),
                              ));
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add link'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: List.generate(
                      _linkCtrls.length,
                      (i) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _linkCtrls[i],
                                  decoration:
                                      _dec('https://…'),
                                  keyboardType:
                                      TextInputType.url,
                                  autovalidateMode:
                                      AutovalidateMode
                                          .onUserInteraction,
                                  validator: (v) {
                                    final s =
                                        (v ?? '').trim();
                                    if (s.isEmpty) {
                                      return null;
                                    }
                                    if (!_isValidUrl(s)) {
                                      return 'Enter a valid http(s) URL';
                                    }
                                    if (!_looksRelated(s)) {
                                      return 'Link doesn’t look related to this org/address';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => setState(() {
                                  final c =
                                      _linkCtrls.removeAt(i);
                                  c.dispose();
                                }),
                                icon: const Icon(Icons.close),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Save Event & Sessions',
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_editingId != null)
                    Center(
                      child: TextButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete event'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black.withValues(alpha: .12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.black54,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
}
