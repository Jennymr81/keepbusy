import 'dart:io' show File;
import 'package:flutter/material.dart';



// ===============================
// SELECTED SESSION CARD
// (for Saved page – per-session selection)
// ===============================
class SelectedSessionCard extends StatelessWidget {
  const SelectedSessionCard({
    super.key,
    required this.eventTitle,
    required this.sessionLabel,      // e.g. "Session 1"
    required this.dayDateLabel,      // e.g. "Youth Center • Sat • Sep 13 – Oct 11"
    required this.timeLabel,         // e.g. "9:00 AM – 10:00 AM"
    required this.metaLabel,         // e.g. "Ages: 3–12 • 5 weeks • $101"
    required this.forProfilesLabel,  // e.g. "For: Mia"
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
    const fallback = 'assets/soccer_camp.jpg'; 

    if (src == null || src.trim().isEmpty) {
      return const AssetImage(fallback);
    }

    final s = src.trim();

    if (s.startsWith('http')) {
      // Network image (Firebase, CDN, etc.)
      return NetworkImage(s);
    }
    if (s.startsWith('assets/')) {
      // Bundled asset
      return AssetImage(s);
    }

    // Anything else: treat it as a local file path
    return FileImage(File(s));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ✅ Use the helper so file paths / assets / network all work
    final ImageProvider provider = _imageProvider(imageSrc);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7D9), // 🔶 whole card light yellow
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





