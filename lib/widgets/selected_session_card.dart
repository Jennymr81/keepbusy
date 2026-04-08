import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:keepbusy/models/profile.dart';

// ===============================
// SELECTED SESSION CARD
// (for Saved page – per-session selection)
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
  required this.sessionLocation,
  required this.profiles,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 480;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(.05)),
          ),
          child: isWide
    ? Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // IMAGE (LEFT)
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(16),
            ),
            child: SizedBox(
              width: 240,
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFF1F1F1)),
              ),
            ),
          ),

          // TEXT (RIGHT)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: _content(theme),
            ),
          ),
        ],
      )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // IMAGE (TOP)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
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

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: _content(theme),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _content(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // TITLE
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

        // DAY / DATE
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

        // META
        if (metaLabel.isNotEmpty)
          Text(
            metaLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.black87),
          ),

        // PROFILES
        if (forProfilesLabel.isNotEmpty)
          Text(
            forProfilesLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.black54),
          ),

        const SizedBox(height: 8),

        // ACTIONS
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
    );
  }
}