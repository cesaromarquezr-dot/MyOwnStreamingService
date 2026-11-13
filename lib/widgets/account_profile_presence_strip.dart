import 'package:flutter/material.dart';

import '../presence/account_profile_presence_service.dart';

/// Compact green-ring profile indicators shared by Kiosk and Theater.
class AccountProfilePresenceStrip extends StatelessWidget {
  const AccountProfilePresenceStrip({
    super.key,
    this.theaterStyle = false,
    this.dayMode = false,
  });

  final bool theaterStyle;
  final bool dayMode;

  String _label(AccountProfilePresence profile) {
    final type = profile.activityType ?? '';
    final detail = profile.activityText?.trim() ?? '';
    if (type == 'watching') {
      final room = detail.isEmpty ? 'Theater' : detail;
      return '$room (${profile.name}) is watching';
    }
    if (type == 'listening') return '${profile.name} is in Listening Lounge';
    if (type == 'browsing') {
      if (theaterStyle && detail.toLowerCase().contains('theater')) {
        return '${profile.name} is in the Theater';
      }
      return '${profile.name} is active';
    }
    return '${profile.name} is active';
  }

  @override
  Widget build(BuildContext context) {
    final foreground = dayMode ? const Color(0xFF172334) : Colors.white;
    final panel = dayMode ? Colors.white : const Color(0xFF171D28);
    return AnimatedBuilder(
      animation: AccountProfilePresenceService.instance,
      builder: (context, _) {
        final active = AccountProfilePresenceService.instance.activeProfiles;
        if (active.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF32D978).withValues(alpha: .45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Color(0xFF35E879)),
                  const SizedBox(width: 7),
                  Text(
                    theaterStyle
                        ? 'ACCOUNT ACTIVITY · PRIVATE ROOMS'
                        : 'ACCOUNT PROFILES ACTIVE',
                    style: TextStyle(
                      color: foreground.withValues(alpha: .66),
                      fontSize: 9,
                      letterSpacing: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  for (final profile in active)
                    _PresenceProfilePill(
                      profile: profile,
                      label: _label(profile),
                      foreground: foreground,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresenceProfilePill extends StatelessWidget {
  const _PresenceProfilePill({
    required this.profile,
    required this.label,
    required this.foreground,
  });

  final AccountProfilePresence profile;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl?.trim() ?? '';
    final validRemote =
        avatar.startsWith('https://') || avatar.startsWith('http://');
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: const Color(0xFF35E879).withValues(alpha: .38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF35E879), width: 2),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x6635E879), blurRadius: 9, spreadRadius: 1),
              ],
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF293445),
              backgroundImage: validRemote ? NetworkImage(avatar) : null,
              child: validRemote
                  ? null
                  : Text(
                      profile.name.isEmpty
                          ? '?'
                          : profile.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900),
                    ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
                color: foreground, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
