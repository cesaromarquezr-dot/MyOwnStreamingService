// FILE: `Backend/services/email_service.dart`.
// Purpose: Implements the email service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:io';

import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

class EmailService {
  final String host;
  final int port;
  final String username;
  final String password;
  final String from;
  final bool useSsl;

  const EmailService({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.from,
    this.useSsl = true,
  });

  factory EmailService.fromEnvironment() => EmailService(
        host: Platform.environment['STREAM_EMAIL_HOST'] ?? '',
        port: int.tryParse(
              Platform.environment['STREAM_EMAIL_PORT'] ?? '465',
            ) ??
            465,
        username: Platform.environment['STREAM_EMAIL_USERNAME'] ?? '',
        password: Platform.environment['STREAM_EMAIL_PASSWORD'] ?? '',
        from: Platform.environment['STREAM_EMAIL_FROM'] ?? '',
        useSsl:
            (Platform.environment['STREAM_EMAIL_SSL'] ?? 'true').toLowerCase() !=
                'false',
      );

  bool get configured =>
      host.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty &&
      from.isNotEmpty;

  /// Performs `send` for this feature. Update this documentation when its contract changes.
  Future<bool> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    if (!configured || to.trim().isEmpty) {
      stdout.writeln(
        '[EmailService] Not configured; would send "$subject" to $to\n$body',
      );
      return false;
    }

    final server = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: useSsl,
    );

    final message = mailer.Message()
      ..from = mailer.Address(from)
      ..recipients.add(to.trim())
      ..subject = subject
      ..text = body;

    try {
      await mailer.send(message, server);
      return true;
    } catch (e) {
      stdout.writeln('[EmailService] Send failed: $e');
      return false;
    }
  }

  /// Performs `welcome` for this feature. Update this documentation when its contract changes.
  Future<void> welcome(String email, String username) => send(
        to: email,
        subject: 'Welcome to your own personal streaming service',
        body:
            'Welcome to your own personal streaming service, $username!\n\n'
            'Your account is ready. You can create profiles, build your library, '
            'watch together, and access your media remotely.',
      );

  /// Performs `newDevice` for this feature. Update this documentation when its contract changes.
  Future<void> newDevice(String email, String deviceName) => send(
        to: email,
        subject: 'New paired device',
        body:
            'A new device was paired with your personal streaming service.\n\n'
            'Device: $deviceName\n'
            'If you did not do this, review your active sessions and change your password.',
      );

  /// Performs `suspicious` for this feature. Update this documentation when its contract changes.
  Future<void> suspicious(
    String email,
    String location,
    String timeZoneTime,
  ) =>
      send(
        to: email,
        subject: 'Suspicious login detected',
        body:
            'Suspicious login detected at $location, at $timeZoneTime.\n\n'
            'If this was not you, sign out all sessions and secure your account.',
      );

  /// Performs `mediaAdded` for this feature. Update this documentation when its contract changes.
  Future<void> mediaAdded(
    String email,
    String profileName,
    String title, {
    String? details,
  }) =>
      send(
        to: email,
        subject: '$profileName added $title',
        body:
            '$profileName added $title to your personal streaming library.'
            '${details == null || details.isEmpty ? '' : '\n\n$details'}',
      );

  /// Performs `storageRequest` for this feature. Update this documentation when its contract changes.
  Future<void> storageRequest(String email, String username) => send(
        to: email,
        subject: 'Storage expansion request received',
        body:
            '$username requested more server storage for the personal streaming service.\n\n'
            'The platform owner can review and approve the request.',
      );

  /// Performs `storageApproved` for this feature. Update this documentation when its contract changes.
  Future<void> storageApproved(
    String email,
    int additionalTerabytes,
  ) =>
      send(
        to: email,
        subject: 'Your request for more storage was successfully approved',
        body:
            'Your request for more storage is successfully approved. '
            'You have $additionalTerabytes TB of more storage.',
      );

  /// Performs `oneTimeCode` for this feature. Update this documentation when its contract changes.
  Future<void> oneTimeCode(String email, String code) => send(
        to: email,
        subject: 'Your one-time access code is: $code',
        body:
            'Your one-time access code is: $code\n\n'
            'This code expires soon. Never share it with anyone.',
      );
}
