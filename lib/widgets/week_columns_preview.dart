import 'package:flutter/material.dart';

@immutable
class DayPip {
  const DayPip({required this.color, this.title, this.tooltip});
  final Color color;
  final String? title;    // ✅ optional label shown under pips
  final String? tooltip;  // ✅ optional tooltip
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
    this.showScrollArrow = true, // ✅ NEW
    this.dayCardHeight = 170,    // ✅ NEW (keeps all columns same height)
  });

  final DateTime focusDate;

  /// Key MUST be date-only (year, month, day). Values are small “pips” to show.
  final Map<DateTime, List<DayPip>> itemsByDay;

  final void Function(DateTime day)? onTapDay;
  final VoidCallback? onTapHeader;

  final String headerTitle;
  final bool showHeader;

  final bool showScrollArrow; // ✅ NEW
  final double dayCardHeight; // ✅ NEW

  @override
  State<WeekColumnsPreview> createState() => _WeekColumnsPreviewState();

  static DateTime dOnly(DateTime x) => DateTime(x.year, x.month, x.day);

  static DateTime startOfWeekMonday(DateTime d) {
    final day = dOnly(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}

class _WeekColumnsPreviewState extends State<WeekColumnsPreview> {
  final _ctl = ScrollController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
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

  static const _dow = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _mon = [
    'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  String _dateLabel(DateTime d) => '${_mon[d.month - 1]} ${d.day}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = WeekColumnsPreview.startOfWeekMonday(widget.focusDate);
    final days = List.generate(7, (i) => WeekColumnsPreview.dOnly(start.add(Duration(days: i))));

    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 900;
        final colW = isWide ? 150.0 : 135.0; // slightly wider for titles

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader) ...[
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
            ],

            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F0ED),
                borderRadius: BorderRadius.vertical(
                  top: widget.showHeader ? Radius.zero : const Radius.circular(14),
                  bottom: const Radius.circular(14),
                ),
              ),
              child: SizedBox(
                height: widget.dayCardHeight, // ✅ forces same height across all days
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _ctl,
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      padding: EdgeInsets.only(right: widget.showScrollArrow ? 52 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final day = days[i];
                        return _DayColumnCard(
                          width: colW,
                          height: widget.dayCardHeight,
                          dowLabel: _dow[day.weekday - 1],
                          dateLabel: _dateLabel(day),
                          items: widget.itemsByDay[day] ?? const <DayPip>[],
                          onTap: widget.onTapDay == null ? null : () => widget.onTapDay!(day),
                        );
                      },
                    ),

                    if (widget.showScrollArrow)
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
                              onPressed: () => _scrollBy(colW + 20),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
    final savedCount = items.length;

    // show at most 2 titled lines (fits without overflow)
    final titled = items.where((x) => (x.title ?? '').trim().isNotEmpty).toList();
    final shownTitles = titled.take(2).toList();
    final remaining = (titled.length - shownTitles.length);

    final card = Container(
      width: width,
      height: height,
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
          const SizedBox(height: 8),

          Text(
            savedCount == 0 ? 'No saved' : '$savedCount saved',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF7D7A78),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          if (savedCount > 0)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final pip in items.take(4))
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
                if (savedCount > 4)
                  Text(
                    '+${savedCount - 4}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF7D7A78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 10),

          // Titles area (flexes but never overflows)
          if (shownTitles.isNotEmpty) ...[
            for (final pip in shownTitles)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 7,
                      decoration: BoxDecoration(
                        color: pip.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7D7A78),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }
}
