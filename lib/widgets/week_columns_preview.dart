import 'package:flutter/material.dart';

@immutable
class DayPip {
  const DayPip({required this.color, this.tooltip, this.title});
  final Color color;
  final String? tooltip;

  /// Optional: if you want to show an event name in the day card list.
  final String? title;
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
    this.showScrollArrow = true,
  });

  final DateTime focusDate;

  /// Key MUST be date-only (year, month, day). Values are small “pips” to show.
  final Map<DateTime, List<DayPip>> itemsByDay;

  final void Function(DateTime day)? onTapDay;
  final VoidCallback? onTapHeader;

  final String headerTitle;
  final bool showHeader;

  /// NEW: show a right chevron to scroll the week strip (mobile + small widths)
  final bool showScrollArrow;

  @override
  State<WeekColumnsPreview> createState() => _WeekColumnsPreviewState();
}

class _WeekColumnsPreviewState extends State<WeekColumnsPreview> {
  final ScrollController _ctl = ScrollController();
  bool _canScroll = false;

  static DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  static DateTime _startOfWeekMonday(DateTime d) {
    final day = _d(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static const _dow = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _mon = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  String _dateLabel(DateTime d) => '${_mon[d.month - 1]} ${d.day}';

  @override
  void initState() {
    super.initState();
    _ctl.addListener(_recalcCanScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcCanScroll());
  }

  @override
  void dispose() {
    _ctl.removeListener(_recalcCanScroll);
    _ctl.dispose();
    super.dispose();
  }

  void _recalcCanScroll() {
    if (!_ctl.hasClients) return;
    final can = _ctl.position.maxScrollExtent > 0.0;
    if (can != _canScroll) setState(() => _canScroll = can);
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final start = _startOfWeekMonday(widget.focusDate);
    final days = List.generate(7, (i) => _d(start.add(Duration(days: i))));

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 900;

        // Column width + card height tuned to avoid overflow on Windows + mobile.
        final double colW = isWide ? 150.0 : 125.0;
        final double cardH = isWide ? 170.0 : 168.0;

        final body = Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F0ED),
            borderRadius: BorderRadius.vertical(
              top: widget.showHeader ? Radius.zero : const Radius.circular(14),
              bottom: const Radius.circular(14),
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Horizontal week strip
              SingleChildScrollView(
                controller: _ctl,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(
                  right: (widget.showScrollArrow && !isWide) ? 56 : 0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in days)
                      _DayColumnCard(
                        width: colW,
                        height: cardH,
                        dowLabel: _dow[day.weekday - 1],
                        dateLabel: _dateLabel(day),
                        items: widget.itemsByDay[_d(day)] ?? const <DayPip>[],
                        onTap: widget.onTapDay == null
                            ? null
                            : () => widget.onTapDay!(day),
                      ),
                  ],
                ),
              ),

              // NEW: right arrow scroll
              if (widget.showScrollArrow && !isWide && _canScroll)
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _scrollBy(colW + 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        if (!widget.showHeader) return body;

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
            body,
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
    this.onTap,
  });

  final double width;
  final double height;
  final String dowLabel;
  final String dateLabel;
  final List<DayPip> items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // We will show up to 2 event titles, then "+N more" to prevent overflow.
    final titles = <DayPip>[
      for (final p in items)
        if ((p.title ?? '').trim().isNotEmpty) p,
    ];

    final showTitles = titles.take(2).toList();
    final remaining = titles.length - showTitles.length;

    final savedCount = items.length;

    final card = SizedBox(
      width: width,
      height: height, // ✅ forces equal height for ALL days (matches your "Sun" height)
      child: Container(
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),

            Text(
              savedCount == 0 ? 'No saved' : '$savedCount saved',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF7D7A78),
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            // ✅ Either show titles (2 max) + "+N more", OR just show pips.
            if (showTitles.isNotEmpty) ...[
              for (final pip in showTitles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 6,
                        decoration: BoxDecoration(
                          color: pip.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pip.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (remaining > 0)
                Text(
                  '+$remaining more',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF7D7A78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ] else if (savedCount > 0) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final pip in items.take(6))
                    Tooltip(
                      message: pip.tooltip ?? '',
                      child: Container(
                        width: 22,
                        height: 7,
                        decoration: BoxDecoration(
                          color: pip.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  if (savedCount > 6)
                    Text(
                      '+${savedCount - 6}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF7D7A78),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
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
