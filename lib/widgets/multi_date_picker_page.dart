import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// =============================================================
// MULTI-DATE PICKER PAGE
// (used by Event Entry to pick session dates)
// =============================================================
class MultiDatePickerPage extends StatefulWidget {
  const MultiDatePickerPage({super.key, required this.initial});
  final Set<DateTime> initial;

  @override
  State<MultiDatePickerPage> createState() => _MultiDatePickerPageState();
}

class _MultiDatePickerPageState extends State<MultiDatePickerPage> {
  late Set<DateTime> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial.map(_d).toSet();
  }

  // --- small helpers (local to this page) ---
  DateTime _d(DateTime d) => DateTime(d.year, d.month, d.day);
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
    final lastMonth = _addMonths(firstMonth, 13); // and 13 after
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
