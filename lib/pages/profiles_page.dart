// lib/pages/profiles_page.dart

import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:keepbusy/models/profile.dart';
import 'package:keepbusy/repositories/local/profiles_repository_isar.dart';

import '../models/profile_color_ext.dart';
import '../widgets/image_helpers.dart';

import 'package:keepbusy/utils/profile_label.dart';


import '../widgets/profile_preview_dialog_kb.dart' show openProfilePreviewDialog;



/* =========================
 * PROFILES GRID
 * ========================= */
class ProfilesPage extends StatelessWidget {
  const ProfilesPage({
    super.key,
    required this.profiles,
    required this.onUpdate,
    required this.onAdd,
    required this.onDelete,
  });

  final List<Profile> profiles;
  final Future<void> Function(int index, Profile updated) onUpdate;
  final Future<void> Function(Profile newProfile) onAdd;
  final Future<void> Function(Profile p) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = profiles; // alias for readability

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Profiles',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF2F8A82),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cols = w >= 1200 ? 5 : w >= 980 ? 4 : w >= 720 ? 3 : 2;

                  return GridView.builder(
  clipBehavior: Clip.none,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    crossAxisSpacing: 20,
    mainAxisSpacing: 24,
    childAspectRatio: 0.86,
  ),
  itemCount: items.length + 1,
  itemBuilder: (context, i) {
   
                      // =========================
                      // EXISTING PROFILE TILE
                      // =========================
                      if (i < profiles.length) {
                        final p = profiles[i];
                        final color = p.color;

                        // ✅ CONSISTENT label everywhere:
                        // nickname (if present) else firstName else "PROFILE"
                        final displayName = profileLabel(p).toUpperCase();

                        // For the small “First name • age” line, use real first name
                        final first = p.firstName.trim();
                        final hasFirst = first.isNotEmpty;

                        // ✅ Interests used by chips
                        final interests = p.interests;

                        // ✅ Avatar: use shared helper so assets/file/web are handled consistently
                        final avatarProvider = profileImageProvider(
                          (p.asset != null && p.asset!.trim().isNotEmpty)
                              ? p.asset!.trim()
                              : 'assets/keepbusy_logo.png',
                        );

                        final tightTextBtn = TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                        );

                        int? age;
                        if (p.birthdate != null) {
                          final now = DateTime.now();
                          age = now.year - p.birthdate!.year;
                          if (now.month < p.birthdate!.month ||
                              (now.month == p.birthdate!.month && now.day < p.birthdate!.day)) {
                            age--;
                          }
                        }

return _HoverableProfileCard(
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Color stripe
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),

        // Main content
        Expanded(
          child: Padding(
  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // ✅ Clickable area (everything above the buttons)
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
onTap: () => openProfilePreviewDialog(
  context: context,
  profile: p,
  color: color,
  avatarProvider: avatarProvider,
),


          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarProvider,
                ),
                const SizedBox(height: 8),

                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),

                if (hasFirst || age != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (hasFirst) first,
                      if (age != null) '$age yrs',
                    ].join(' • '),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                ],

                if (interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: interests.take(5).map((interest) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: color.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          interest,
                          style: theme.textTheme.labelSmall?.copyWith(
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
      ),

      // ✅ Buttons stay NOT clickable for the card
      TextButton(
        style: tightTextBtn,
        onPressed: () async {
          final profileToEdit = profiles[i];

          final result = await Navigator.of(context).push<Profile?>(
            MaterialPageRoute(
              builder: (_) => EditProfilePage(
                profile: profileToEdit,
                onSave: (updated) => Navigator.pop<Profile?>(context, updated),
              ),
            ),
          );

          if (result == null) {
            await onDelete(profileToEdit);
            return;
          }

          await onUpdate(i, result);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved')),
          );
        },
        child: const Text('Edit profile'),
      ),

      TextButton(
        style: tightTextBtn,
        onPressed: () {},
        child: const Text('View calendar'),
      ),
    ],
  ),
),

        ),
      ],
    ),
  ),
);




                      }

                      // =========================
                      // NEW PROFILE TILE
                      // =========================
                      return _HoverableProfileCard(
  child: InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () async {
      final blank = Profile()
        ..firstName = ''
        ..lastName = ''
        ..nickname = null
        ..birthdate = null
        ..colorValue = const Color(0xFF2F8A82).value
        ..asset = null
        ..interests = <String>[];

      final result = await Navigator.push<Profile?>(
        context,
        MaterialPageRoute(
          builder: (_) => EditProfilePage(
  profile: blank,
  isNew: true, // ✅ add this
  onSave: (updated) => Navigator.pop<Profile?>(context, updated),
),
        ),
      );


                         if (result != null) {
        await onAdd(result);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved')),
        );
      }
    },
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        // ✅ NO _hover here (hover is handled by _HoverableProfileCard)
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
      ),

  child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              child: Icon(Icons.add, size: 40, color: Color(0xFF2F8A82)),
            ),
            SizedBox(height: 10),
            Text('New profile', style: TextStyle(color: Colors.black54)),
      ],
    ),
  ),
),
  )
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _HoverableProfileCard extends StatefulWidget {
  const _HoverableProfileCard({required this.child});
  final Widget child;

  @override
  State<_HoverableProfileCard> createState() => _HoverableProfileCardState();
}

class _HoverableProfileCardState extends State<_HoverableProfileCard> {
  bool _hover = false; // ✅ this is what your error is missing

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
  blurRadius: _hover ? 20 : 8,      // tighter = less side haze
  spreadRadius: _hover ? 0 : -1,    // ✅ reduces side shadow a lot
  offset: Offset(0, _hover ? 10 : 6), // keeps bottom drop
  color: Colors.black.withOpacity(_hover ? 0.18 : 0.07),
),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.white.withValues(alpha: 0.94),
            border: Border.all(
              color: Colors.black.withOpacity(_hover ? 0.08 : 0.05),
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}



/* =========================
 * EDIT PROFILE PAGE
 * ========================= */
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.profile,
    this.onSave,
    this.isNew = false, 
  });

  final Profile profile;
  final void Function(Profile updated)? onSave;
   final bool isNew;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // controllers
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _nickCtrl;
  late final TextEditingController _birthCtrl;

  // Date selection state
  int selectedMonth = DateTime.now().month;
  int selectedDay = DateTime.now().day;
  int selectedYear = DateTime.now().year;

  // editable state
  late DateTime? _birthdate;
  late Color _color;
  late Set<String> _interests;
  String? _assetPath;

  // color swatches (24 total — 8 color families × 3 tones each)
  static const List<Color> _swatches = [
    // === LIGHT COLORS ===
    Color(0xFFB2EFE6),
    Color(0xFFB8DBFF),
    Color(0xFFFAC7E3),
    Color.fromARGB(255, 255, 169, 216),
    Color(0xFFE2D4FF),
    Color(0xFFFFF5C4),
    Color.fromARGB(255, 253, 210, 181),
    Color.fromARGB(255, 252, 161, 151),
    Color.fromARGB(255, 237, 237, 237),

    // === MEDIUM COLORS ===
    Color.fromARGB(255, 96, 243, 214),
    Color.fromARGB(255, 116, 178, 250),
    Color.fromARGB(255, 250, 119, 180),
    Color.fromARGB(255, 250, 115, 216),
    Color.fromARGB(255, 169, 123, 253),
    Color.fromARGB(255, 255, 224, 111),
    Color.fromARGB(255, 255, 178, 123),
    Color.fromARGB(255, 250, 114, 114),
    Color(0xFF9E9E9E),

    // === DEEP COLORS ===
    Color.fromARGB(255, 0, 255, 229),
    Color.fromARGB(255, 1, 136, 255),
    Color.fromARGB(255, 255, 0, 128),
    Color.fromARGB(255, 94, 2, 255),
    Color.fromARGB(255, 253, 190, 1),
    Color.fromARGB(255, 255, 86, 2),
    Color.fromARGB(255, 255, 2, 2),
    Color.fromARGB(255, 47, 47, 47),
  ];

  static const List<String> _interestChoices = [
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
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _firstCtrl = TextEditingController(text: p.firstName);
    _lastCtrl = TextEditingController(text: p.lastName);
    _nickCtrl = TextEditingController(text: p.nickname ?? '');
    _birthdate = p.birthdate;
    _assetPath = p.asset;
    _birthCtrl = TextEditingController(
      text: p.birthdate != null ? DateFormat('MM/dd/yyyy').format(p.birthdate!) : '',
    );
    _color = p.color;
    _interests = {...p.interests};
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _nickCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  int? get _age {
    if (_birthdate == null) return null;
    final now = DateTime.now();
    int years = now.year - _birthdate!.year;
    final hadBirthday = (now.month > _birthdate!.month) ||
        (now.month == _birthdate!.month && now.day >= _birthdate!.day);
    if (!hadBirthday) years -= 1;
    return years;
  }

  String get _displayName {
    final nick = _nickCtrl.text.trim();
    if (nick.isNotEmpty) return nick.toUpperCase();
    final first = _firstCtrl.text.trim();
    return first.isEmpty ? 'PROFILE' : first.toUpperCase();
  }

  Future<void> _showBirthdateError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invalid birthdate'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final initial = _birthdate ?? DateTime(now.year - 10, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Select birthdate',
      fieldHintText: 'MM/DD/YYYY',
      errorFormatText: 'Use MM/DD/YYYY',
      errorInvalidText: 'Birthdate out of range',
    );

    if (picked == null) return;

    setState(() {
      _birthdate = picked;
      _birthCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
    });
  }

  DateTime? _parseBirthdate(String? s) {
    if (s == null) return null;
    final raw = s.trim();
    final m = RegExp(r'^\s*(\d{1,2})\s*/\s*(\d{1,2})\s*/\s*(\d{4})\s*$').firstMatch(raw);
    if (m == null) return null;

    final month = int.parse(m.group(1)!);
    final day = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);

    final now = DateTime.now();
    if (year < 1900) return null;
    try {
      final dt = DateTime(year, month, day);
      if (dt.year != year || dt.month != month || dt.day != day) return null;
      if (dt.isAfter(DateTime(now.year, now.month, now.day))) return null;
      return dt;
    } catch (_) {
      return null;
    }
  }

  String? _validateBirthdate(String? s) {
    if ((s ?? '').trim().isEmpty) return 'Enter a birthdate (MM/DD/YYYY).';
    return _parseBirthdate(s) == null ? 'Enter a valid date (MM/DD/YYYY) not in the future.' : null;
  }

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  void _openColorPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose profile color', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _swatches.map((c) {
                  final isSelected = c == _color;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _color = c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.black26,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 3,
                            offset: Offset(0, 1),
                            color: Colors.black12,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  static const kDefaultAvatarAsset = 'assets/default_avatar.png';

  ImageProvider _avatarProvider(String? src) {
    final s = (src ?? '').trim();
    if (s.isEmpty) return const AssetImage(kDefaultAvatarAsset);
    if (s.startsWith('http')) return NetworkImage(s);
    if (s.startsWith('assets/')) return AssetImage(s);
    return FileImage(File(s));
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();

    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update profile picture', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),

                // OPTION 1: library
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF2F8A82)),
                  title: const Text('Choose from photo library'),
                  onTap: () async {
                    Navigator.pop(context);

                    try {
                      if (isMobile && defaultTargetPlatform == TargetPlatform.iOS) {
                        final status = await Permission.photos.request();
                        if (!status.isGranted) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Permission denied. Enable photo access in Settings.'),
                            ),
                          );
                          return;
                        }
                      }

                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 85,
                      );
                      if (picked != null && mounted) {
                        setState(() => _assetPath = picked.path);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open gallery: $e')),
                      );
                    }
                  },
                ),

                // OPTION 2: camera
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2F8A82)),
                  title: const Text('Take a new photo'),
                  onTap: () async {
                    Navigator.pop(context);

                    if (!isMobile) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Camera not supported on this platform.'),
                        ),
                      );
                      return;
                    }

                    final status = await Permission.camera.request();
                    if (!status.isGranted) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Camera access denied. Enable it in Settings.'),
                        ),
                      );
                      return;
                    }

                    try {
                      final picked = await picker.pickImage(
                        source: ImageSource.camera,
                        imageQuality: 85,
                      );
                      if (picked != null && mounted) {
                        setState(() => _assetPath = picked.path);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not open camera: $e')),
                      );
                    }
                  },
                ),

                const Divider(height: 20),

                // OPTION 3: KeepBusy avatars
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Color(0xFF2F8A82)),
                  title: const Text('Select from KeepBusy avatars'),
                  onTap: () async {
                    Navigator.pop(context);
                    const assets = [
                      'assets/face1.jpg',
                      'assets/face2.jpg',
                      'assets/face3.jpg',
                      'assets/face4.jpg',
                      'assets/face5.jpg',
                    ];

                    final chosen = await showModalBottomSheet<String>(
                      context: context,
                      showDragHandle: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select an avatar', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: assets.map((path) {
                                  return GestureDetector(
                                    onTap: () => Navigator.pop(context, path),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundImage: AssetImage(path),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    );

                    if (chosen != null && chosen.isNotEmpty && mounted) {
                      setState(() => _assetPath = chosen);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _save() {
    if (_firstCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name is required')),
      );
      return;
    }

    final parsedDob = _parseBirthdate(_birthCtrl.text);
    if (_birthCtrl.text.trim().isNotEmpty && parsedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid birthdate (MM/DD/YYYY).')),
      );
      return;
    }

    final updated = Profile()
      ..id = widget.profile.id
      ..firstName = _firstCtrl.text.trim()
      ..lastName = _lastCtrl.text.trim()
      ..nickname = _nickCtrl.text.trim().isEmpty ? null : _nickCtrl.text.trim()
      ..birthdate = parsedDob
      ..colorValue = _color.value
      ..asset = _assetPath
      ..interests = List<String>.from(_interests);

    Navigator.pop<Profile?>(context, updated);
  }

  void _showBirthdatePicker() {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    const int kMinYear = 1900;

    DateTime? parsed;
    final s = _birthCtrl.text.trim();
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(s)) {
      try {
        parsed = DateFormat('MM/dd/yyyy').parseStrict(s);
      } catch (_) {}
    }
    final init = parsed ?? _birthdate ?? DateTime(now.year - 10, 6, 15);

    final safeInit = DateTime(init.year.clamp(kMinYear, now.year), init.month, init.day);
    final minDate = DateTime(kMinYear, 1, 1);
    final maxDate = DateTime(now.year, now.month, now.day);

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Center(
        child: Container(
          width: 400,
          height: 400,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const Text('Select birthdate', style: TextStyle(fontWeight: FontWeight.w600)),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: safeInit,
                  minimumDate: minDate,
                  maximumDate: maxDate,
                  onDateTimeChanged: (d) {
                    setState(() {
                      _birthdate = d;
                      _birthCtrl.text = DateFormat('MM/dd/yyyy').format(d);
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dob = _parseBirthdate(_birthCtrl.text);
    final ageText = (dob == null) ? '--' : _ageFrom(dob).toString();

    InputDecoration dec(String label, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      );
    }

    final avatarProvider = profileImageProvider(
      _assetPath?.isNotEmpty == true
          ? _assetPath!
          : (widget.profile.asset?.isNotEmpty == true ? widget.profile.asset! : 'assets/keepbusy_logo.png'),
    );

    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _color,
                  border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
                ),
              ),
              Expanded(
                child: Text(
                  _displayName,
                  style: t.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _updateProfilePicture,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Update picture'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.white,
                    backgroundImage: avatarProvider,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (_firstCtrl.text.trim().isNotEmpty || _age != null)
            Text(
              [
                if (_firstCtrl.text.trim().isNotEmpty) _firstCtrl.text.trim(),
                if (_age != null) '${_age} yrs',
              ].join(' • '),
              style: t.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
            ),

          const SizedBox(height: 8),

          if (_interests.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _interests
                  .take(5)
                  .map(
                    (interest) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        interest,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _firstCtrl,
                onChanged: (_) => setState(() {}),
                decoration: dec('First Name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lastCtrl,
                onChanged: (_) => setState(() {}),
                decoration: dec('Last Name'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _birthCtrl,
                decoration: dec(
                  'Birthdate (MM / DD / YYYY)',
                  suffix: IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickBirthdate,
                    tooltip: 'Pick from calendar',
                  ),
                ),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateBirthdate,
                onChanged: (s) {
                  final dt = _parseBirthdate(s);
                  setState(() {
                    _birthdate = dt;
                  });
                },
                onEditingComplete: () => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: InputDecorator(
                decoration: dec('Age'),
                child: Text(
                  ageText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nickCtrl,
          onChanged: (_) => setState(() {}),
          decoration: dec('Profile Nickname'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Profile color', style: t.textTheme.bodyLarge),
            const SizedBox(width: 12),
            InkWell(
              onTap: _openColorPicker,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Interests',
              style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            const Text(
              '(Select up to 5)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _interestChoices.map((label) {
            final selected = _interests.contains(label);
            return FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    if (_interests.length >= 5) {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: const Text('Limit Reached'),
                          content: const Text(
                            'You can select up to 5 interests only.',
                            style: TextStyle(fontSize: 15),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK', style: TextStyle(color: Color(0xFF2F8A82))),
                            ),
                          ],
                        ),
                      );
                    } else {
                      _interests.add(label);
                    }
                  } else {
                    _interests.remove(label);
                  }
                });
              },
              selectedColor: const Color(0xFF2F8A82).withOpacity(.16),
              checkmarkColor: const Color(0xFF2F8A82),
              labelStyle: TextStyle(
                color: selected ? const Color(0xFF2F8A82) : Colors.black87,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: selected ? const Color(0xFF2F8A82) : Colors.black12,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            );
          }).toList(),
        ),
        const SizedBox(height: 100),
        Center(
          child: TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Profile'),
                  content: const Text(
                    'Are you sure you want to delete this profile? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                Navigator.pop<Profile?>(context, null);
              }
            },
            child: const Text(
              'Delete Profile',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
      ],
    );

    return WillPopScope(
  onWillPop: () async {
    Navigator.pop<Profile?>(context, widget.isNew ? null : widget.profile);
    return false; // we handled it
  },
  child: Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          Navigator.pop<Profile?>(context, widget.isNew ? null : widget.profile);
        },
      ),

        title: const Text('Edit profile'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1500;
              final content = Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: leftColumn),
                          const SizedBox(width: 28),
                          const Expanded(flex: 2, child: SizedBox()),
                        ],
                      )
                    : ListView(children: [leftColumn]),
              );
              return Container(
                color: const Color(0xFFF4EBE6),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: content,
                  ),
                ),
              );
            },
          ),
        ),
      ),
  ),
    );
  }
}


