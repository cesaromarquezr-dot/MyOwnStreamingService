import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Simple trailer model used by TrailerScreen.
///
/// This is kept here because the current app_core.dart does not
/// contain a Trailer model.
class Trailer {
  final String youtubeVideoId;
  final String title;

  const Trailer({
    required this.youtubeVideoId,
    required this.title,
  });
}

/// Opens a trailer on YouTube.
Future<void> openTrailer(
  BuildContext context,
  Trailer trailer,
) async {
  final videoId = trailer.youtubeVideoId.trim();

  if (videoId.isEmpty) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'This trailer does not have a YouTube video ID.',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return;
  }

  final Uri youtubeUri = Uri.https(
    'www.youtube.com',
    '/watch',
    <String, String>{
      'v': videoId,
    },
  );

  try {
    final launched = await launchUrl(
      youtubeUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(18),
          backgroundColor: const Color(0xFF202020),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unable to open the trailer.',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),
        backgroundColor: const Color(0xFF202020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: const Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unable to open the trailer.',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TrailerScreen extends StatefulWidget {
  final Trailer trailer;

  const TrailerScreen({
    super.key,
    required this.trailer,
  });

  @override
  State<TrailerScreen> createState() => _TrailerScreenState();
}

class _TrailerScreenState extends State<TrailerScreen> {
  bool openingTrailer = false;

  Future<void> launchTrailer() async {
    if (openingTrailer) return;

    setState(() {
      openingTrailer = true;
    });

    await openTrailer(
      context,
      widget.trailer,
    );

    if (!mounted) return;

    setState(() {
      openingTrailer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compactLayout = size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // Ambient background.
          Positioned(
            top: -220,
            left: -160,
            child: _buildGlow(
              size: compactLayout ? 420 : 620,
            ),
          ),

          Positioned(
            bottom: -250,
            right: -180,
            child: _buildGlow(
              size: compactLayout ? 450 : 680,
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TrailerBackgroundPainter(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      compactLayout ? 18 : 32,
                      compactLayout ? 15 : 25,
                      compactLayout ? 18 : 32,
                      compactLayout ? 30 : 45,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1050,
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: 1,
                          ),
                          duration: const Duration(
                            milliseconds: 700,
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (
                            context,
                            animation,
                            child,
                          ) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                30 * (1 - animation),
                              ),
                              child: Opacity(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _buildContent(
                            context,
                            compactLayout,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow({
    required double size,
  }) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.065),
              Colors.white.withValues(alpha: 0.022),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        4,
      ),
      child: Row(
        children: [
          _buildGlassButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () {
              Navigator.of(context).maybePop();
            },
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Text(
              'TRAILER',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
          ),

          _buildGlassButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open trailer',
            onPressed: openingTrailer
                ? null
                : launchTrailer,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 15,
            sigmaY: 15,
          ),
          child: Material(
            color: Colors.white.withValues(alpha: 0.055),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 45,
                height: 45,
                child: Icon(
                  icon,
                  color: Colors.white.withValues(
                    alpha: onPressed == null ? 0.25 : 0.82,
                  ),
                  size: 21,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool compactLayout,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTrailerPreview(compactLayout),

        const SizedBox(height: 25),

        Text(
          widget.trailer.title,
          textAlign: compactLayout
              ? TextAlign.center
              : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: compactLayout ? 27 : 35,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
            height: 1.12,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: compactLayout
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'OFFICIAL TRAILER',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),

        const SizedBox(height: 25),

        _buildTrailerInfo(),

        const SizedBox(height: 25),

        _buildWatchButton(),

        const SizedBox(height: 18),

        Text(
          'The trailer will open on YouTube.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.32),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailerPreview(
    bool compactLayout,
  ) {
    final aspectRatio = compactLayout ? 16 / 10 : 16 / 8;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          compactLayout ? 20 : 26,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Cinematic background.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF191919),
                    Color(0xFF090909),
                  ],
                ),
              ),
            ),

            // Soft center glow.
            Center(
              child: Container(
                width: compactLayout ? 180 : 260,
                height: compactLayout ? 180 : 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0.025),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Decorative film-strip lines.
            Positioned.fill(
              child: CustomPaint(
                painter: _FilmPatternPainter(),
              ),
            ),

            // Gradient overlay.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.30),
                    ],
                  ),
                ),
              ),
            ),

            // Play button.
            Center(
              child: _buildPlayButton(),
            ),

            // Bottom metadata.
            Positioned(
              left: 20,
              right: 20,
              bottom: 17,
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WATCH TRAILER',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: 0.62,
                      ),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: openingTrailer ? null : launchTrailer,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: openingTrailer
                ? const Padding(
                    key: ValueKey('loading'),
                    padding: EdgeInsets.all(27),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.black,
                    ),
                  )
                : const Icon(
                    key: ValueKey('play'),
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 39,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailerInfo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 18,
          sigmaY: 18,
        ),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.075),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.ondemand_video_rounded,
                  color: Colors.white.withValues(alpha: 0.70),
                  size: 21,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YouTube trailer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Video ID: ${widget.trailer.youtubeVideoId}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.38,
                        ),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.open_in_new_rounded,
                color: Colors.white.withValues(alpha: 0.32),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatchButton() {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: openingTrailer ? null : launchTrailer,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor:
              Colors.white.withValues(alpha: 0.15),
          disabledForegroundColor:
              Colors.white.withValues(alpha: 0.50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (
            child,
            animation,
          ) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: openingTrailer
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.black,
                  ),
                )
              : const Row(
                  key: ValueKey('watch'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 23,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'WATCH TRAILER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TrailerBackgroundPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.014)
      ..strokeWidth = 1;

    const spacing = 60.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}

class _FilmPatternPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = Rect.fromCenter(
      center: Offset(
        size.width / 2,
        size.height / 2,
      ),
      width: size.width * 0.78,
      height: size.height * 0.70,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(20),
      ),
      paint,
    );

    const holeSize = 8.0;
    const holeSpacing = 25.0;

    for (
      double x = 20;
      x < size.width - 20;
      x += holeSpacing
    ) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              x,
              14,
            ),
            width: holeSize,
            height: holeSize,
          ),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              x,
              size.height - 14,
            ),
            width: holeSize,
            height: holeSize,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}