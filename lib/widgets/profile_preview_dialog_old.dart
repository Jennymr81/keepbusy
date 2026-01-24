import 'package:flutter/material.dart';
import '../models/profile.dart';

import '../utils/profile_label.dart';


/* =========================
 * LARGE PROFILE CARD VIEW (on click)
 * ========================= */
void openProfilePreviewDialog({
  required BuildContext context,
  required Profile profile,
  required Color color,
  required ImageProvider avatarProvider,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.25),
    builder: (_) => _ProfilePreviewDialog(
      profile: profile,
      color: color,
      avatarProvider: avatarProvider,
    ),
  );
}

class _ProfilePreviewDialog extends StatelessWidget {
  const _ProfilePreviewDialog({
    required this.profile,
    required this.color,
    required this.avatarProvider,
  });

  final Profile profile;
  final Color color;
  final ImageProvider avatarProvider;

  int? _ageFrom(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int years = now.year - dob.year;
    final hadBirthday = (now.month > dob.month) || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) years -= 1;
    return years;
  }

  String _birthdateText(DateTime? dob) {
    if (dob == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dob.month)}/${two(dob.day)}/${dob.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = profileLabel(profile).toUpperCase();
    final first = profile.firstName.trim();
    final last = profile.lastName.trim();
    final nick = (profile.nickname ?? '').trim();
    final dob = profile.birthdate;
    final age = _ageFrom(dob);
    final interests = profile.interests;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: LayoutBuilder(
        builder: (context, c) {
          final maxW = c.maxWidth < 520 ? c.maxWidth : 520.0;
          final maxH = c.maxHeight * 0.85;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.96),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                      ),

                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ),

                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                backgroundImage: avatarProvider,
                              ),
                              const SizedBox(height: 10),

                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),

                              const SizedBox(height: 6),
                              Text(
                                [
                                  if (first.isNotEmpty) first,
                                  if (last.isNotEmpty) last,
                                  if (age != null) '$age yrs',
                                ].join(' • ').trim().isEmpty
                                    ? '—'
                                    : [
                                        if (first.isNotEmpty) first,
                                        if (last.isNotEmpty) last,
                                        if (age != null) '$age yrs',
                                      ].join(' • '),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                              ),

                              const SizedBox(height: 10),
                              _ProfileInfoRow(label: 'Nickname', value: nick.isEmpty ? '—' : nick),
                              const SizedBox(height: 6),
                              _ProfileInfoRow(label: 'Birthdate', value: _birthdateText(dob)),

                              if (interests.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Interests',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: interests.map((interest) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: color.withValues(alpha: 0.30)),
                                      ),
                                      child: Text(
                                        interest,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: t.textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}


