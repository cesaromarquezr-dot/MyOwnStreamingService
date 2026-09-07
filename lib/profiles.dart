import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_core.dart';

/// ============================================================
/// PROFILE SELECTION SCREEN
/// ============================================================
///
/// Shown after login.
///
/// The screen is responsible only for the profile-selection UI.
/// Actual profile state is owned by AppController.
///
/// When a profile is selected:
///   1. AppController.switchProfile(...) is called.
///   2. onProfileSelected is invoked.
///   3. main.dart can navigate to MainScreen without creating
///      a circular import between main.dart and profiles.dart.
class ProfileSelectionScreen extends StatefulWidget {
  final VoidCallback? onProfileSelected;

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
      duration: const Duration(
        milliseconds: 900,
      ),
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
      barrierColor: Colors.black.withValues(
        alpha: 0.72,
      ),
      builder: (_) => const CreateProfileSheet(),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _selectProfile(Profile profile) {
    final controller = AppController.instance;

    try {
      controller.switchProfile(profile.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

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

    if (!mounted) {
      return;
    }

    if (widget.onProfileSelected != null) {
      widget.onProfileSelected!();
      return;
    }

    Navigator.of(context).pop(profile);
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
                      maxWidth: 1000,
                    ),
                    child: Column(
                      children: [
                        const _ProfileLogo(),

                        const SizedBox(
                          height: 42,
                        ),

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

                        const SizedBox(
                          height: 10,
                        ),

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

                        const SizedBox(
                          height: 42,
                        ),

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

                        const SizedBox(
                          height: 50,
                        ),

                        Text(
                          '${profiles.length} '
                          '${profiles.length == 1 ? 'profile' : 'profiles'}',
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
  final TextEditingController _nameController =
      TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  IconData? _selectedAvatar;
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

      if (photo == null || !mounted) {
        return;
      }

      setState(() {
        _selectedPhoto = photo;
        _selectedAvatar = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

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

      if (photo == null || !mounted) {
        return;
      }

      setState(() {
        _selectedPhoto = photo;
        _selectedAvatar = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to choose photo: $error',
          ),
        ),
      );
    }
  }

  void _selectAvatar(IconData avatar) {
    setState(() {
      _selectedAvatar = avatar;
      _selectedPhoto = null;
    });
  }

  String? _avatarKeyForIcon(IconData? icon) {
    if (icon == null) {
      return null;
    }

    final index = _avatarIcons.indexOf(icon);

    if (index < 0) {
      return null;
    }

    return 'avatar:$index';
  }

  Future<void> _create() async {
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

    final controller = AppController.instance;

    setState(() {
      _saving = true;
    });

    try {
      String? avatarUrl;

      if (_selectedPhoto != null) {
        avatarUrl = _selectedPhoto!.path;
      } else if (_selectedAvatar != null) {
        avatarUrl = _avatarKeyForIcon(
          _selectedAvatar,
        );
      }

      final profile = controller.addProfile(
        name,
        avatarUrl: avatarUrl,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile "${profile.name}" created.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

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
      margin: const EdgeInsets.only(
        top: 50,
      ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              const Text(
                'Create Profile',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Text(
                'Add a profile for your household.',
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.55,
                  ),
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(
                    milliseconds: 220,
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _ProfilePreview(
                    key: ValueKey(
                      _selectedPhoto?.path ??
                          _selectedAvatar ??
                          'empty',
                    ),
                    photo: _selectedPhoto,
                    avatar: _selectedAvatar,
                  ),
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              TextField(
                controller: _nameController,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
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
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              const Text(
                'Profile picture',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(
                height: 13,
              ),

              Row(
                children: [
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Take photo',
                      onTap: _saving
                          ? null
                          : _takePhoto,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: _PictureButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Choose photo',
                      onTap: _saving
                          ? null
                          : _pickPhoto,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 24,
              ),

              const Text(
                'Or choose an avatar',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount: _avatarIcons.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (
                  context,
                  index,
                ) {
                  final icon = _avatarIcons[index];
                  final selected =
                      _selectedAvatar == icon;

                  return GestureDetector(
                    onTap: _saving
                        ? null
                        : () => _selectAvatar(icon),
                    child: AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 180,
                      ),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(
                                alpha: 0.06,
                              ),
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.white12,
                          width: selected ? 1.5 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.white
                                      .withValues(
                                    alpha: 0.08,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: AnimatedScale(
                        scale: selected ? 1.08 : 1,
                        duration: const Duration(
                          milliseconds: 180,
                        ),
                        child: Icon(
                          icon,
                          color: selected
                              ? Colors.black
                              : Colors.white70,
                          size: 25,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 28,
              ),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _saving ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        Colors.white24,
                    disabledForegroundColor:
                        Colors.white54,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: _saving
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            key: ValueKey('text'),
                            'CREATE PROFILE',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
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
/// PROFILE CARD
/// ============================================================

class _ProfileCard extends StatefulWidget {
  final Profile profile;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.onTap,
  });

  @override
  State<_ProfileCard> createState() =>
      _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.94
              : _hovered
                  ? 1.045
                  : 1,
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),
            width: 150,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: _hovered
                  ? Colors.white.withValues(
                      alpha: 0.045,
                    )
                  : Colors.transparent,
            ),
            child: Column(
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

                const SizedBox(
                  height: 13,
                ),

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
              ],
            ),
          ),
        ),
      ),
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTapCancel: () {
          setState(() {
            _pressed = false;
          });
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed
              ? 0.94
              : _hovered
                  ? 1.045
                  : 1,
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
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? Colors.white.withValues(
                            alpha: 0.075,
                          )
                        : Colors.white.withValues(
                            alpha: 0.055,
                          ),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: _hovered
                          ? Colors.white54
                          : Colors.white12,
                      width: 1.2,
                    ),
                  ),
                  child: AnimatedScale(
                    scale: _hovered ? 1.08 : 1,
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 48,
                      color: _hovered
                          ? Colors.white
                          : Colors.white54,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 13,
                ),

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
    final avatarValue =
        profile.avatarUrl?.trim() ?? '';

    if (avatarValue.startsWith('avatar:')) {
      final icon = _iconFromAvatarKey(
        avatarValue,
      );

      if (icon != null) {
        return _IconAvatar(
          icon: icon,
          size: size,
        );
      }
    }

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
    final letter = name.trim().isEmpty
        ? '?'
        : name.trim()[0].toUpperCase();

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
/// PROFILE PREVIEW
/// ============================================================

class _ProfilePreview extends StatelessWidget {
  final XFile? photo;
  final IconData? avatar;

  const _ProfilePreview({
    super.key,
    required this.photo,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(photo!.path),
          width: 130,
          height: 130,
          fit: BoxFit.cover,
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            return const _EmptyProfilePreview();
          },
        ),
      );
    }

    if (avatar != null) {
      return Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white12,
          ),
        ),
        child: Icon(
          avatar,
          size: 55,
          color: Colors.white,
        ),
      );
    }

    return const _EmptyProfilePreview();
  }
}

/// ============================================================
/// EMPTY PROFILE PREVIEW
/// ============================================================

class _EmptyProfilePreview extends StatelessWidget {
  const _EmptyProfilePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: const Icon(
        Icons.person_outline,
        size: 55,
        color: Colors.white38,
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white24,
        side: const BorderSide(
          color: Colors.white12,
        ),
        minimumSize:
            const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
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
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add),
      label: const Text(
        'CREATE PROFILE',
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
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
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.045,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white12,
            ),
          ),
          child: Icon(
            Icons.people_outline,
            size: 42,
            color: Colors.white.withValues(
              alpha: 0.25,
            ),
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        Text(
          'No profiles yet',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(
              alpha: 0.75,
            ),
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        Text(
          'Create your first profile to start watching.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(
              alpha: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// LOGO
/// ============================================================

class _ProfileLogo extends StatelessWidget {
  const _ProfileLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(
                  alpha: 0.08,
                ),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.play_arrow,
            color: Colors.black,
            size: 27,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        const Text(
          'MY STREAMING SERVICE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// BACKGROUND
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
            left: -140,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.025,
                ),
              ),
            ),
          ),

          Positioned(
            right: -200,
            bottom: -180,
            child: Container(
              width: 550,
              height: 550,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(
                  alpha: 0.02,
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(
                      alpha: 0.18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}