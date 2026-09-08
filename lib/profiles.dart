import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_core.dart';

/// ============================================================
/// PROFILE SELECTION SCREEN
/// ============================================================

class ProfileSelectionScreen extends StatefulWidget {
  final void Function(BuildContext context)? onProfileSelected;

  const ProfileSelectionScreen({
    super.key,
    this.onProfileSelected,
  });

  @override
  State<ProfileSelectionScreen> createState() =>
      _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState
    extends State<ProfileSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => const CreateProfileSheet(),
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _editProfile(Profile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => EditProfileSheet(profile: profile),
    );

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _showStatistics(Profile profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => ProfileStatisticsSheet(profile: profile),
    );
  }

  void _selectProfile(Profile profile) {
    final controller = AppController.instance;

    try {
      controller.switchProfile(profile.id);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    final profileContext = context;

    if (widget.onProfileSelected != null) {
      widget.onProfileSelected!(profileContext);
      return;
    }

    Navigator.of(profileContext).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppController.instance;
    final account = controller.currentAccount;
    final profiles = account?.profiles ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: Stack(
        children: [
          const _ProfileBackground(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 48,
                ),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final animation = CurvedAnimation(
                      parent: _animationController,
                      curve: Curves.easeOutCubic,
                    );

                    return Opacity(
                      opacity: animation.value,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          30 * (1 - animation.value),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Column(
                      children: [
                        const _ProfileLogo(),

                        const SizedBox(height: 42),

                        const Text(
                          "Who's watching?",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'Choose a profile to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),

                        const SizedBox(height: 42),

                        if (profiles.isEmpty)
                          const _NoProfiles()
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 30,
                            runSpacing: 34,
                            children: [
                              ...profiles.map(
                                (profile) => _ProfileCard(
                                  profile: profile,
                                  onTap: () {
                                    _selectProfile(profile);
                                  },
                                  onEdit: () {
                                    _editProfile(profile);
                                  },
                                  onStatistics: () {
                                    _showStatistics(profile);
                                  },
                                ),
                              ),
                              if (profiles.length < 7)
                                _CreateProfileCard(
                                  onTap: _createProfile,
                                ),
                            ],
                          ),

                        if (profiles.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 26,
                            ),
                            child: _CreateProfileButton(
                              onTap: _createProfile,
                            ),
                          ),

                        const SizedBox(height: 50),

                        Text(
                          '${profiles.length} '
                          '${profiles.length == 1 ? 'profile' : 'profiles'}'
                          ' • Maximum 7',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE CARD
/// ============================================================

class _ProfileCard extends StatefulWidget {
  final Profile profile;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStatistics;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
    required this.onEdit,
    required this.onStatistics,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _showProfileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(
            22,
            12,
            22,
            28,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF151515),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                const SizedBox(height: 22),

                _ProfileMenuButton(
                  icon: Icons.play_circle_outline,
                  title: 'Use this profile',
                  subtitle:
                      'Start watching as ${widget.profile.name}',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onTap();
                  },
                ),

                const SizedBox(height: 10),

                _ProfileMenuButton(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  subtitle:
                      'Change name or profile picture',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit();
                  },
                ),

                const SizedBox(height: 10),

                _ProfileMenuButton(
                  icon: Icons.bar_chart_rounded,
                  title: 'See Statistics',
                  subtitle:
                      'View this profile\'s watching activity',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onStatistics();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
        },
        onTapCancel: () {
          setState(() => _pressed = false);
        },
        onTap: widget.onTap,
        onLongPress: _showProfileMenu,
        child: AnimatedScale(
          scale: _pressed
              ? 0.94
              : _hovered
                  ? 1.045
                  : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      padding: EdgeInsets.all(
                        _hovered ? 2 : 0,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(20),
                        border: Border.all(
                          color: _hovered
                              ? Colors.white38
                              : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: _ProfileAvatar(
                        profile: widget.profile,
                        size: 142,
                      ),
                    ),

                    Positioned(
                      right: -5,
                      top: -5,
                      child: AnimatedOpacity(
                        opacity: _hovered ? 1 : 0,
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        child: Material(
                          color: Colors.black.withValues(
                            alpha: 0.85,
                          ),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder:
                                const CircleBorder(),
                            onTap: _showProfileMenu,
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(
                                Icons.more_horiz,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                Text(
                  widget.profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _hovered
                        ? Colors.white
                        : Colors.white70,
                  ),
                ),

                const SizedBox(height: 7),

                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Colors.white54,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// PROFILE AVATAR
/// ============================================================

class _ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;

  const _ProfileAvatar({
    required this.profile,
    required this.size,
  });

  IconData? _iconFromAvatarKey(String value) {
    if (!value.startsWith('avatar:')) {
      return null;
    }

    final index = int.tryParse(
      value.substring('avatar:'.length),
    );

    const icons = [
      Icons.person,
      Icons.face,
      Icons.star,
      Icons.favorite,
      Icons.pets,
      Icons.sports_esports,
      Icons.music_note,
      Icons.movie,
      Icons.auto_awesome,
      Icons.rocket_launch,
      Icons.emoji_emotions,
      Icons.public,
    ];

    if (index == null ||
        index < 0 ||
        index >= icons.length) {
      return null;
    }

    return icons[index];
  }

  @override
  Widget build(BuildContext context) {
    final avatarValue = profile.avatarUrl?.trim() ?? '';

    // Built-in avatar icon.
    if (avatarValue.startsWith('avatar:')) {
      final icon = _iconFromAvatarKey(avatarValue);

      if (icon != null) {
        return _IconAvatar(
          icon: icon,
          size: size,
        );
      }
    }

    // Local image.
    if (avatarValue.isNotEmpty) {
      final file = File(avatarValue);

      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return _FallbackAvatar(
                size: size,
                name: profile.name,
              );
            },
          ),
        );
      }

      // Network image.
      if (avatarValue.startsWith('http://') ||
          avatarValue.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.network(
            avatarValue,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return _FallbackAvatar(
                size: size,
                name: profile.name,
              );
            },
          ),
        );
      }
    }

    // Default avatar.
    return _FallbackAvatar(
      size: size,
      name: profile.name,
    );
  }
}

/// ============================================================
/// ICON AVATAR
/// ============================================================

class _IconAvatar extends StatelessWidget {
  final IconData icon;
  final double size;

  const _IconAvatar({
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF343434),
            Color(0xFF151515),
          ],
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.38,
        color: Colors.white,
      ),
    );
  }
}

/// ============================================================
/// FALLBACK AVATAR
/// ============================================================

class _FallbackAvatar extends StatelessWidget {
  final double size;
  final String name;

  const _FallbackAvatar({
    required this.size,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();

    final letter = trimmedName.isEmpty
        ? '?'
        : trimmedName[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF343434),
            Color(0xFF151515),
          ],
        ),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// ============================================================
/// EDIT PROFILE SHEET
/// ============================================================

class EditProfileSheet extends StatefulWidget {
  final Profile profile;

  const EditProfileSheet({
    super.key,
    required this.profile,
  });

  @override
  State<EditProfileSheet> createState() =>
      _EditProfileSheetState();
}

class _EditProfileSheetState
    extends State<EditProfileSheet> {
  late final TextEditingController _nameController;

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedPhoto;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.profile.name,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to take photo: $error',
          ),
        ),
      );
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to choose photo: $error',
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a profile name.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final controller = AppController.instance;

      // Profile update will be connected to the actual
      // AppController implementation once its profile
      // update API is available.

      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile "$name" updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 50),
      padding: EdgeInsets.fromLTRB(
        26,
        18,
        26,
        26 + bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Update your profile information.',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: _EditableProfileAvatar(
                  profile: widget.profile,
                  selectedPhoto: _selectedPhoto,
                ),
              ),

              const SizedBox(height: 25),

              TextField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization:
                    TextCapitalization.words,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'Profile name',
                  labelStyle: const TextStyle(
                    color: Colors.white60,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Change profile picture',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 13),

              Row(
                children: [
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take photo',
                      onTap:
                          _saving ? null : _takePhoto,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _PictureButton(
                      icon:
                          Icons.photo_library_outlined,
                      label: 'Choose photo',
                      onTap:
                          _saving ? null : _pickPhoto,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// EDITABLE PROFILE AVATAR
/// ============================================================

class _EditableProfileAvatar extends StatelessWidget {
  final Profile profile;
  final XFile? selectedPhoto;

  const _EditableProfileAvatar({
    required this.profile,
    required this.selectedPhoto,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(
          File(selectedPhoto!.path),
          width: 130,
          height: 130,
          fit: BoxFit.cover,
        ),
      );
    }

    return _ProfileAvatar(
      profile: profile,
      size: 130,
    );
  }
}

/// ============================================================
/// PROFILE STATISTICS
/// ============================================================

class ProfileStatisticsSheet extends StatelessWidget {
  final Profile profile;

  const ProfileStatisticsSheet({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.fromLTRB(
        24,
        18,
        24,
        30,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              Row(
                children: [
                  _ProfileAvatar(
                    profile: profile,
                    size: 70,
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistics',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight:
                                FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const Row(
                children: [
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.movie_outlined,
                      title: 'Movies',
                      value: '—',
                    ),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.tv_outlined,
                      title: 'Shows',
                      value: '—',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              const Row(
                children: [
                  Expanded(
                    child: _StatisticCard(
                      icon: Icons.schedule_outlined,
                      title: 'Watch time',
                      value: '—',
                    ),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: _StatisticCard(
                      icon:
                          Icons.check_circle_outline,
                      title: 'Completed',
                      value: '—',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.045,
                  ),
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.white70,
                          size: 20,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Your watching profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Detailed viewing statistics, '
                      'favorite genres, watch history, '
                      'and yearly Wrapped data will '
                      'appear here.',
                      style: TextStyle(
                        height: 1.5,
                        color: Colors.white.withValues(
                          alpha: 0.48,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// STATISTIC CARD
/// ============================================================

class _StatisticCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.045,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white54,
            size: 21,
          ),

          const SizedBox(height: 14),

          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE MENU BUTTON
/// ============================================================

class _ProfileMenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.045,
      ),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color:Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// PICTURE BUTTON
/// ============================================================

class _PictureButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PictureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(
        alpha: 0.045,
      ),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 10,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.white70,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// CREATE PROFILE SHEET
/// ============================================================

class CreateProfileSheet extends StatefulWidget {
  const CreateProfileSheet({
    super.key,
  });

  @override
  State<CreateProfileSheet> createState() =>
      _CreateProfileSheetState();
}

class _CreateProfileSheetState
    extends State<CreateProfileSheet> {
  late final TextEditingController _nameController;

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedPhoto;

  bool _saving = false;

  final List<IconData> _avatarIcons = const [
    Icons.person,
    Icons.face,
    Icons.star,
    Icons.favorite,
    Icons.pets,
    Icons.sports_esports,
    Icons.music_note,
    Icons.movie,
    Icons.auto_awesome,
    Icons.rocket_launch,
    Icons.emoji_emotions,
    Icons.public,
  ];

  int _selectedAvatarIndex = 0;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to take photo: $error',
          ),
        ),
      );
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (photo == null || !mounted) return;

      setState(() {
        _selectedPhoto = photo;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to choose photo: $error',
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a profile name.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final controller = AppController.instance;

      final avatarUrl = _selectedPhoto != null
          ? _selectedPhoto!.path
          : 'avatar:$_selectedAvatarIndex';

      controller.addProfile(
        name,
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile "$name" created.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 50),
      padding: EdgeInsets.fromLTRB(
        26,
        18,
        26,
        26 + bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Create Profile',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Create a profile for your library.',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: _CreateProfileAvatarPreview(
                  selectedPhoto: _selectedPhoto,
                  icon: _avatarIcons[
                      _selectedAvatarIndex],
                ),
              ),

              const SizedBox(height: 25),

              TextField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization:
                    TextCapitalization.words,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'Profile name',
                  labelStyle: const TextStyle(
                    color: Colors.white60,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(
                    alpha: 0.06,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Choose an avatar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 14),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(
                  _avatarIcons.length,
                  (index) {
                    final selected =
                        _selectedPhoto == null &&
                            _selectedAvatarIndex ==
                                index;

                    return GestureDetector(
                      onTap: _saving
                          ? null
                          : () {
                              setState(() {
                                _selectedPhoto =
                                    null;
                                _selectedAvatarIndex =
                                    index;
                              });
                            },
                      child: AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 160,
                        ),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(14),
                          gradient:
                              const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF343434),
                              Color(0xFF151515),
                            ],
                          ),
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : Colors.white12,
                            width:
                                selected ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          _avatarIcons[index],
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take photo',
                      onTap:
                          _saving ? null : _takePhoto,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _PictureButton(
                      icon:
                          Icons.photo_library_outlined,
                      label: 'Choose photo',
                      onTap:
                          _saving ? null : _pickPhoto,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'CREATE PROFILE',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// CREATE PROFILE AVATAR PREVIEW
/// ============================================================

class _CreateProfileAvatarPreview
    extends StatelessWidget {
  final XFile? selectedPhoto;
  final IconData icon;

  const _CreateProfileAvatarPreview({
    required this.selectedPhoto,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedPhoto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(
          File(selectedPhoto!.path),
          width: 130,
          height: 130,
          fit: BoxFit.cover,
        ),
      );
    }

    return _IconAvatar(
      icon: icon,
      size: 130,
    );
  }
}

/// ============================================================
/// CREATE PROFILE CARD
/// ============================================================

class _CreateProfileCard extends StatefulWidget {
  final VoidCallback onTap;

  const _CreateProfileCard({
    required this.onTap,
  });

  @override
  State<_CreateProfileCard> createState() =>
      _CreateProfileCardState();
}

class _CreateProfileCardState
    extends State<_CreateProfileCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.045 : 1,
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(18),
                    color: Colors.white.withValues(
                      alpha: 0.035,
                    ),
                    border: Border.all(
                      color: _hovered
                          ? Colors.white38
                          : Colors.white12,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 42,
                    color: _hovered
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),

                const SizedBox(height: 13),

                Text(
                  'Add Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _hovered
                        ? Colors.white
                        : Colors.white70,
                  ),
                ),

                const SizedBox(height: 7),

                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  child: const Text(
                    'Create new',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// CREATE PROFILE BUTTON
/// ============================================================

class _CreateProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateProfileButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add),
        label: const Text(
          'CREATE PROFILE',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(
            horizontal: 22,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// NO PROFILES
/// ============================================================

class _NoProfiles extends StatelessWidget {
  const _NoProfiles();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 500,
      ),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.035,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(
                alpha: 0.05,
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 32,
              color: Colors.white54,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'No profiles yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Create your first profile to start '
            'using your personal streaming library.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Colors.white.withValues(
                alpha: 0.48,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PROFILE LOGO
/// ============================================================

class _ProfileLogo extends StatelessWidget {
  const _ProfileLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF343434),
                Color(0xFF151515),
              ],
            ),
            border: Border.all(
              color: Colors.white12,
            ),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 38,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 15),

        const Text(
          'MY STREAMING SERVICE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// PROFILE BACKGROUND
/// ============================================================

class _ProfileBackground extends StatelessWidget {
  const _ProfileBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -150,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.018,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -220,
            right: -180,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.014,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}