import 'dart:async';

import 'package:flutter/material.dart';

import 'app_core.dart';
import 'privacy_preferences.dart';
import 'backend_api.dart';

/// Shows the *other* profiles on the signed-in account, with live presence and
/// profile-to-profile messaging. The currently selected profile is deliberately
/// excluded from this strip.
class AccountProfileActivityStrip extends StatefulWidget {
  const AccountProfileActivityStrip({
    super.key,
    this.onMessageProfile,
  });

  final ValueChanged<String>? onMessageProfile;

  @override
  State<AccountProfileActivityStrip> createState() =>
      _AccountProfileActivityStripState();
}

class _AccountProfileActivityStripState
    extends State<AccountProfileActivityStrip> {
  Timer? _refreshTimer;
  bool _requestInFlight = false;
  List<Map<String, dynamic>> _presenceProfiles = const <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> _recentActivity =
      <String, List<Map<String, dynamic>>>{};
  final Set<String> _activityLoading = <String>{};

  @override
  void initState() {
    super.initState();
    AppController.instance.addListener(_onAccountChanged);
    unawaited(_loadPresence());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_loadPresence()),
    );
  }

  void _onAccountChanged() {
    if (mounted) {
      setState(() {});
      unawaited(_loadPresence());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    AppController.instance.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _loadPresence() async {
    if (_requestInFlight) return;
    final controller = AppController.instance;
    final current = controller.currentProfile;
    final account = controller.currentAccount;
    if (current == null || account == null) {
      if (mounted) {
        setState(() => _presenceProfiles = const <Map<String, dynamic>>[]);
      }
      return;
    }

    _requestInFlight = true;
    try {
      if (!controller.backendApi.isAuthenticated) {
        _presenceProfiles = account.profiles
            .where((profile) => profile.id != current.id)
            .map((profile) => <String, dynamic>{
                  'profileId': profile.id,
                  'name': profile.name,
                  'avatarUrl': profile.avatarUrl,
                })
            .toList();
      } else {
        final response = await controller.backendApi.getSocialAccountProfiles(
          profileId: current.id,
        );
        _presenceProfiles = (response['profiles'] as List? ?? const <dynamic>[])
            .whereType<Map>()
            .map((profile) {
              final normalized = Map<String, dynamic>.from(profile);
              normalized['name'] ??= normalized['displayName'] ??
                  normalized['display_name'] ??
                  normalized['profileName'] ??
                  normalized['profile_name'];
              normalized['avatarUrl'] ??= normalized['avatar_url'];
              normalized['profileId'] ??= normalized['profile_id'];
              return normalized;
            })
            .where((profile) =>
                (profile['profileId'] ?? profile['external_profile_id'] ?? '')
                    .toString() !=
                current.id)
            .toList();
      }
    } catch (_) {
      // Presence is an enhancement; never hide local account profiles if the
      // social service is temporarily offline.
      _presenceProfiles = account.profiles
          .where((profile) => profile.id != current.id)
          .map((profile) => <String, dynamic>{
                'profileId': profile.id,
                'name': profile.name,
                'avatarUrl': profile.avatarUrl,
              })
          .toList();
    } finally {
      _requestInFlight = false;
      if (mounted) setState(() {});
      unawaited(_loadOtherProfilesRecentActivity());
    }
  }

  Future<void> _loadOtherProfilesRecentActivity() async {
    final controller = AppController.instance;
    final currentId = controller.currentProfile?.id;
    if (!controller.backendApi.isAuthenticated) return;
    final profiles = _presenceProfiles.where((profile) {
      final id = (profile['profileId'] ?? profile['external_profile_id'] ?? '')
          .toString();
      return id.isNotEmpty && id != currentId;
    }).toList();
    await Future.wait(profiles.map((profile) async {
      final id = (profile['profileId'] ?? profile['external_profile_id'] ?? '')
          .toString();
      if (id.isEmpty || _activityLoading.contains(id)) return;
      _activityLoading.add(id);
      try {
        // Respect each profile's activity-sharing preference before requesting
        // its history. The backend must also enforce same-account membership
        // and the profile's sharing policy; client checks are not authorization.
        final privacy = await PrivacyPreferencesStore.load(profileId: id);
        if (!privacy.sharePresence || !privacy.shareActivity) {
          _recentActivity[id] = const <Map<String, dynamic>>[];
          return;
        }
        final items = await controller.backendApi
            .getMediaActivity(profileId: id, limit: 5);
        _recentActivity[id] = items;
      } catch (_) {
        _recentActivity.putIfAbsent(id, () => const <Map<String, dynamic>>[]);
      } finally {
        _activityLoading.remove(id);
      }
    }));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentId = AppController.instance.currentProfile?.id;
    final others = _presenceProfiles.where((profile) {
      final id = (profile['profileId'] ?? profile['external_profile_id'] ?? '')
          .toString();
      return id.isNotEmpty && id != currentId;
    }).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF12151A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other profiles on this account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 152,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: others.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _profileCard(others[index]),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Recently watched & listened to by other profiles',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...others.map(_profileRecentActivitySection),
          ],
        ),
      ),
    );
  }

  String _profileDisplayName(Map<String, dynamic> profile) {
    final id = (profile['profileId'] ??
        profile['profile_id'] ??
        profile['external_profile_id'] ??
        '');
    final fromResponse = (profile['displayName'] ??
            profile['display_name'] ??
            profile['profileName'] ??
            profile['profile_name'] ??
            profile['name'] ??
            '')
        .toString()
        .trim();
    if (fromResponse.isNotEmpty &&
        !RegExp(r'^user\s*\d+$', caseSensitive: false).hasMatch(fromResponse)) {
      return fromResponse;
    }
    // Social API responses can omit the display name. Resolve the profile ID
    // against this account's profile objects before using a generic fallback.
    final accountProfiles =
        AppController.instance.currentAccount?.profiles ?? const [];
    for (final candidate in accountProfiles) {
      if (candidate.id == id.toString()) {
        final accountName = candidate.name.trim();
        if (accountName.isNotEmpty) return accountName;
      }
    }
    return fromResponse.isNotEmpty ? fromResponse : 'Profile';
  }

  Widget _profileRecentActivitySection(Map<String, dynamic> profile) {
    final id = (profile['profileId'] ?? profile['external_profile_id'] ?? '')
        .toString();
    final name = _profileDisplayName(profile);
    final items = _recentActivity[id] ?? const <Map<String, dynamic>>[];
    final loading = _activityLoading.contains(id);
    if (items.isEmpty && !loading) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_rounded, size: 17, color: Colors.white70),
            const SizedBox(width: 7),
            Expanded(
                child: Text('$name recently watched / listened to',
                    style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          if (loading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else
            ...items.take(5).map(_activityTile),
          const Divider(height: 14, color: Colors.white12),
        ],
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> item) {
    final action = (item['action'] ?? '').toString().toLowerCase();
    final type = (item['contentType'] ?? item['content_type'] ?? 'media')
        .toString()
        .toLowerCase();
    final title = (item['title'] ??
            item['contentTitle'] ??
            item['content_title'] ??
            item['name'] ??
            item['contentId'] ??
            item['content_id'] ??
            'Untitled')
        .toString();
    final isMusic = type.contains('song') ||
        type.contains('track') ||
        type.contains('music') ||
        type.contains('album');
    final isEpisode = type.contains('episode') ||
        type.contains('tv') ||
        type.contains('show');
    final subtitle = isMusic
        ? 'Listened to${(item['artist'] ?? item['artistName'] ?? item['artist_name']) == null ? '' : ' · ${item['artist'] ?? item['artistName'] ?? item['artist_name']}'}'
        : isEpisode
            ? _episodeSubtitle(item)
            : action.contains('watch') || type.contains('movie')
                ? 'Movie · Recently watched'
                : '${type.isEmpty ? 'Media' : type[0].toUpperCase() + type.substring(1)} · Recent activity';
    final timestamp = DateTime.tryParse(
        (item['occurredAt'] ?? item['occurred_at'] ?? '').toString());
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 2, right: 2),
      leading: Icon(isMusic ? Icons.music_note_rounded : Icons.movie_outlined,
          color: isMusic ? Colors.purpleAccent : Colors.white70),
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
      trailing: timestamp == null
          ? null
          : Text(
              MaterialLocalizations.of(context)
                  .formatShortDate(timestamp.toLocal()),
              style: const TextStyle(color: Colors.white54, fontSize: 10)),
    );
  }

  String _episodeSubtitle(Map<String, dynamic> item) {
    final season =
        item['seasonNumber'] ?? item['season_number'] ?? item['season'];
    final episode =
        item['episodeNumber'] ?? item['episode_number'] ?? item['episode'];
    final show = item['showTitle'] ?? item['show_title'];
    final parts = <String>[];
    if (show != null && show.toString().trim().isNotEmpty) {
      parts.add(show.toString());
    }
    if (season != null && episode != null) {
      parts.add('Season $season · Episode $episode');
    } else {
      parts.add('TV episode · Recently watched');
    }
    return parts.join(' · ');
  }

  Widget _profileCard(Map<String, dynamic> profile) {
    final id = (profile['profileId'] ?? profile['external_profile_id'] ?? '')
        .toString();
    final name = _profileDisplayName(profile);
    final avatarUrl =
        (profile['avatarUrl'] ?? profile['avatar_url'])?.toString();
    final activity = (profile['activityText'] ?? profile['activity_text'])
        ?.toString()
        .trim();
    final active = _isActive(profile);
    final lastSeenText = active ? 'User is active' : _inactivePhrase(profile);
    final imageUri = Uri.tryParse(avatarUrl ?? '');
    final hasNetworkAvatar = imageUri != null &&
        (imageUri.scheme == 'https' || imageUri.scheme == 'http') &&
        imageUri.host.isNotEmpty;

    return SizedBox(
      width: 198,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? Colors.greenAccent.withValues(alpha: .75)
                : Colors.white.withValues(alpha: .08),
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: .12),
                    blurRadius: 13,
                    spreadRadius: 1,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: lastSeenText,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: active
                      ? Border.all(color: Colors.greenAccent, width: 1.5)
                      : Border.all(color: Colors.white24),
                  boxShadow: active
                      ? <BoxShadow>[
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: .85),
                            blurRadius: 13,
                            spreadRadius: 2,
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: CircleAvatar(
                  radius: 23,
                  backgroundColor: const Color(0xFF292D34),
                  backgroundImage:
                      hasNetworkAvatar ? NetworkImage(avatarUrl!) : null,
                  child: hasNetworkAvatar
                      ? null
                      : Text(
                          name.trim().isEmpty
                              ? '?'
                              : name.trim()[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Tooltip(
                    message: lastSeenText,
                    child: Text(
                      active ? 'User is active' : lastSeenText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? Colors.greenAccent : Colors.white54,
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: Text(
                      activity != null && activity.isNotEmpty
                          ? activity
                          : (active
                              ? 'Using MyOwnStreamingService'
                              : 'No current activity'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11, height: 1.2),
                    ),
                  ),
                  if (widget.onMessageProfile != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: id.isEmpty
                            ? null
                            : () => widget.onMessageProfile!(id),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 14),
                              SizedBox(width: 4),
                              Text('Message',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
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

  bool _isActive(Map<String, dynamic> profile) {
    final status =
        (profile['presenceStatus'] ?? profile['availability'] ?? 'away')
            .toString()
            .toLowerCase();
    if (status == 'away' || status == 'offline' || status == 'invisible') {
      return false;
    }
    final lastSeen = DateTime.tryParse(
      (profile['lastSeenAt'] ?? profile['last_seen_at'] ?? '').toString(),
    );
    if (lastSeen == null) return false;
    final age = DateTime.now().toUtc().difference(lastSeen.toUtc());
    return !age.isNegative && age <= const Duration(minutes: 5);
  }

  String _inactivePhrase(Map<String, dynamic> profile) {
    final lastSeen = DateTime.tryParse(
      (profile['lastSeenAt'] ?? profile['last_seen_at'] ?? '').toString(),
    );
    if (lastSeen == null) return 'User activity unavailable';
    final elapsed = DateTime.now().toUtc().difference(lastSeen.toUtc());
    if (elapsed.isNegative) return 'User activity time is unavailable';
    return 'User was active (${_elapsedParts(lastSeen.toUtc(), DateTime.now().toUtc())}) ago';
  }

  String _elapsedParts(DateTime start, DateTime end) {
    var cursor = DateTime.utc(
      start.year,
      start.month,
      start.day,
      start.hour,
      start.minute,
      start.second,
    );
    final target = DateTime.utc(
        end.year, end.month, end.day, end.hour, end.minute, end.second);
    if (!target.isAfter(cursor)) return 'less than 1 second';

    int years = target.year - cursor.year;
    var next = _addYearsClamped(cursor, years);
    if (next.isAfter(target)) {
      years--;
      next = _addYearsClamped(cursor, years);
    }
    cursor = next;

    int months = (target.year - cursor.year) * 12 + target.month - cursor.month;
    next = _addMonthsClamped(cursor, months);
    if (next.isAfter(target)) {
      months--;
      next = _addMonthsClamped(cursor, months);
    }
    cursor = next;

    final remaining = target.difference(cursor);
    final weeks = remaining.inDays ~/ 7;
    cursor = cursor.add(Duration(days: weeks * 7));
    final days = target.difference(cursor).inDays;
    cursor = cursor.add(Duration(days: days));
    final hours = target.difference(cursor).inHours;
    cursor = cursor.add(Duration(hours: hours));
    final minutes = target.difference(cursor).inMinutes;
    cursor = cursor.add(Duration(minutes: minutes));
    final seconds = target.difference(cursor).inSeconds;

    final parts = <String>[];
    void add(int value, String unit) {
      if (value > 0) parts.add('$value $unit${value == 1 ? '' : 's'}');
    }

    add(years, 'year');
    add(months, 'month');
    add(weeks, 'week');
    add(days, 'day');
    add(hours, 'hour');
    add(minutes, 'minute');
    add(seconds, 'second');
    return parts.isEmpty ? 'less than 1 second' : parts.join(', ');
  }

  DateTime _addYearsClamped(DateTime date, int years) {
    final year = date.year + years;
    final day =
        date.day.clamp(1, DateTime.utc(year, date.month + 1, 0).day).toInt();
    return DateTime.utc(
        year, date.month, day, date.hour, date.minute, date.second);
  }

  DateTime _addMonthsClamped(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final day = date.day.clamp(1, DateTime.utc(year, month + 1, 0).day).toInt();
    return DateTime.utc(year, month, day, date.hour, date.minute, date.second);
  }
}
