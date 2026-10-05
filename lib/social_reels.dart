import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_core.dart';
import 'shop.dart';
import 'social_sharing.dart';

/// Vertical short-video surface for friend + community posts.
///
/// The existing social post API remains the source of truth. Reels are a
/// different presentation of those video posts rather than a second storage
/// system.
class SocialReelsScreen extends StatefulWidget {
  const SocialReelsScreen({
    super.key,
    required this.posts,
    this.onRefresh,
  });

  final List<Map<String, dynamic>> posts;
  final Future<void> Function()? onRefresh;

  @override
  State<SocialReelsScreen> createState() => _SocialReelsScreenState();
}

class _SocialReelsScreenState extends State<SocialReelsScreen> {
  late List<Map<String, dynamic>> _reels;
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _syncPosts();
  }

  @override
  void didUpdateWidget(covariant SocialReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPosts();
  }

  void _syncPosts() {
    final candidates = widget.posts
        .map(Map<String, dynamic>.from)
        .where((post) {
          final reference = _mediaReference(post);
          return reference['type']?.toString() == 'video' &&
              reference['videoUrl']?.toString().isNotEmpty == true;
        })
        .toList()
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
    _reels = candidates;
    if (_reels.isEmpty) {
      _index = 0;
    } else if (_index >= _reels.length) {
      _index = _reels.length - 1;
    }
  }

  Map<String, dynamic> _mediaReference(Map<String, dynamic> post) {
    final value = post['mediaReference'] ?? post['media_reference'];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reels.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: ListView(
          children: const [
            SizedBox(height: 90),
            Icon(Icons.play_circle_outline_rounded, size: 64),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No Shorts yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(height: 6),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Create a short linked to a movie, show, or song. Reviews and skits can use the same vertical-video format.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _reels.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (context, index) => _SocialReelPage(
          key: ValueKey(_reels[index]['id']?.toString() ?? index),
          post: _reels[index],
          active: index == _index,
        ),
      ),
    );
  }
}

class _SocialReelPage extends StatefulWidget {
  const _SocialReelPage({super.key, required this.post, required this.active});

  final Map<String, dynamic> post;
  final bool active;

  @override
  State<_SocialReelPage> createState() => _SocialReelPageState();
}

class _SocialReelPageState extends State<_SocialReelPage> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  bool _liked = false;
  int _reactionCount = 0;

  Map<String, dynamic> get _reference {
    final value = widget.post['mediaReference'] ?? widget.post['media_reference'];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Map<String, dynamic> get _author {
    final value = widget.post['author'];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  String get _displayName =>
      _author['display_name']?.toString() ??
      widget.post['author_profile_name']?.toString() ??
      _author['username']?.toString() ??
      'Friend';

  @override
  void initState() {
    super.initState();
    _liked = widget.post['myReaction']?.toString() == '❤️';
    _reactionCount = (widget.post['reactionCount'] as num?)?.toInt() ?? 0;
    _loadVideo();
  }

  @override
  void didUpdateWidget(covariant _SocialReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _setPlaying(widget.active);
    }
  }

  Future<void> _loadVideo() async {
    final url = _reference['videoUrl']?.toString();
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'This Short is no longer available.';
        });
      }
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.setVolume(1);
      if (mounted) {
        setState(() => _loading = false);
        if (widget.active) await controller.play();
      }
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to play this Short.';
        });
      }
    }
  }

  Future<void> _setPlaying(bool playing) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (playing) {
      await controller.play();
    } else {
      await controller.pause();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final profile = AppController.instance.currentProfile;
    final postId = widget.post['id']?.toString();
    if (profile == null || postId == null || postId.isEmpty) return;
    try {
      await AppController.instance.backendApi.reactToSocialPost(
        profileId: profile.id,
        postId: postId,
        reaction: _liked ? 'remove' : '❤️',
      );
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _reactionCount = (_reactionCount + (_liked ? 1 : -1)).clamp(0, 1 << 30);
      });
    } catch (error) {
      _notice(error.toString());
    }
  }

  Future<void> _comment() async {
    final profile = AppController.instance.currentProfile;
    final postId = widget.post['id']?.toString();
    if (profile == null || postId == null || postId.isEmpty) return;
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Comment on Short'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1000,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Add a comment…'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (comment == null || comment.isEmpty) return;
    try {
      await AppController.instance.backendApi.commentOnSocialPost(
        profileId: profile.id,
        postId: postId,
        body: comment,
      );
      if (mounted) {
        _notice('Comment posted.');
        setState(() {
          final count = (widget.post['commentCount'] as num?)?.toInt() ?? 0;
          widget.post['commentCount'] = count + 1;
        });
      }
    } catch (error) {
      _notice(error.toString());
    }
  }

  void _notice(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value.replaceFirst('Exception: ', ''))),
    );
  }

  void _openProduct() {
    final productId = _reference['productId']?.toString();
    if (productId == null || productId.isEmpty) return;
    final product = ShopCatalog.instance.productById(productId);
    if (product == null) {
      _notice('That product is no longer available.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopProductDetailsScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final reference = _reference;
    final contentMode = reference['contentMode']?.toString() ?? 'short';
    final linkedTitle = reference['relatedMediaTitle']?.toString();
    final linkedType = reference['relatedMediaType']?.toString();
    final productId = reference['productId']?.toString();
    final product = productId == null || productId.isEmpty
        ? null
        : ShopCatalog.instance.productById(productId);
    final hasProduct = product != null;
    final commentCount = (widget.post['commentCount'] as num?)?.toInt() ?? 0;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            GestureDetector(
              onTap: () => _setPlaying(!controller.value.isPlaying),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else if (reference['coverUrl']?.toString().isNotEmpty == true)
            Image.network(reference['coverUrl'].toString(), fit: BoxFit.cover)
          else
            const Center(child: CircularProgressIndicator()),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
                stops: [0.55, 1],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 88,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (linkedTitle != null && linkedTitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_prettyType(contentMode)} • ${linkedType ?? 'media'} • $linkedTitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                if ((widget.post['body']?.toString() ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.post['body'].toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.3),
                    ),
                  ),
                if (hasProduct)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _ReelProductCard(product: product, onTap: _openProduct),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 38,
            child: Column(
              children: [
                _ReelAction(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '$_reactionCount',
                  active: _liked,
                  onTap: _toggleLike,
                ),
                _ReelAction(
                  icon: Icons.mode_comment_outlined,
                  label: '$commentCount',
                  onTap: _comment,
                ),
                _ReelAction(
                  icon: Icons.send_outlined,
                  label: 'Share',
                  onTap: () => showSocialShareDialog(
                    context,
                    title: linkedTitle ?? 'Short',
                    message: widget.post['body']?.toString() ?? 'Shared Short',
                    mediaReference: reference,
                    sourcePostId: widget.post['id']?.toString(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .44),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    contentMode == 'short'
                        ? 'Reels'
                        : _prettyType(contentMode),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!),
                ),
              ),
            ),
          if (!_loading && controller != null && controller.value.isInitialized && !controller.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow_rounded, size: 34),
              ),
            ),
        ],
      ),
    );
  }

  String _prettyType(String value) => switch (value) {
        'review' => 'Video review',
        'skit' => 'Skit',
        _ => 'Short',
      };
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          IconButton.filledTonal(
            onPressed: onTap,
            icon: Icon(icon),
            color: active ? Colors.redAccent : null,
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _ReelProductCard extends StatelessWidget {
  const _ReelProductCard({required this.product, required this.onTap});

  final ShopProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.imageUrls.isEmpty
                    ? Container(
                        width: 44,
                        height: 44,
                        color: Colors.white10,
                        child: const Icon(Icons.shopping_bag_outlined, size: 20),
                      )
                    : Image.network(
                        product.imageUrls.first,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SHOP',
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${product.price.toStringAsFixed(2)} ${product.currency}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
