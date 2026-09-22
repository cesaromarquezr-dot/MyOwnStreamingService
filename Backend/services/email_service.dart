// FILE: Backend/services/email_service.dart.
//
// Purpose: Implements the email service portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.
//
// Security:
// - SMTP credentials are read from environment variables.
// - Passwords, invitation tokens, MFA codes, and other secrets are never
//   written to application logs.
// - Email failures return false rather than exposing SMTP/server details.
// - Email delivery is best-effort; account/security state is persisted by
//   the calling service independently of notification delivery.

import 'dart:io';

import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

/// Sends transactional notifications through the configured SMTP server.
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

  /// Creates an email service from the server environment.
  ///
  /// Environment variables:
  /// - STREAM_EMAIL_HOST
  /// - STREAM_EMAIL_PORT
  /// - STREAM_EMAIL_USERNAME
  /// - STREAM_EMAIL_PASSWORD
  /// - STREAM_EMAIL_FROM
  /// - STREAM_EMAIL_SSL
  factory EmailService.fromEnvironment() {
    final configuredPort =
        int.tryParse(Platform.environment['STREAM_EMAIL_PORT'] ?? '');

    return EmailService(
      host: Platform.environment['STREAM_EMAIL_HOST']?.trim() ?? '',
      port: configuredPort != null && configuredPort > 0
          ? configuredPort
          : 465,
      username:
          Platform.environment['STREAM_EMAIL_USERNAME']?.trim() ?? '',
      password: Platform.environment['STREAM_EMAIL_PASSWORD'] ?? '',
      from: Platform.environment['STREAM_EMAIL_FROM']?.trim() ?? '',
      useSsl:
          (Platform.environment['STREAM_EMAIL_SSL'] ?? 'true')
                  .trim()
                  .toLowerCase() !=
              'false',
    );
  }

  /// Whether the minimum SMTP configuration is present.
  bool get configured =>
      host.isNotEmpty &&
      port > 0 &&
      port <= 65535 &&
      username.isNotEmpty &&
      password.isNotEmpty &&
      _isValidEmail(from);

  /// Sends a plain-text email.
  ///
  /// Returns true only when the SMTP client reports a successful send.
  /// Delivery is intentionally best-effort and failures do not expose SMTP
  /// credentials, message contents, or server details to callers.
  Future<bool> send({
    required String to,
    required String subject,
    required String body,
  }) async {
    final recipient = to.trim();
    final normalizedSubject = subject.trim();

    if (!configured ||
        !_isValidEmail(recipient) ||
        normalizedSubject.isEmpty ||
        body.trim().isEmpty) {
      _logUnavailable();
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
      ..recipients.add(recipient)
      ..subject = normalizedSubject
      ..text = body;

    try {
      await mailer.send(message, server);
      return true;
    } catch (_) {
      // Do not log the exception because SMTP libraries may include server
      // details or other sensitive transport information.
      stdout.writeln('[EmailService] Email send failed.');
      return false;
    }
  }

  /// Sends the account welcome message.
  Future<void> welcome(String email, String username) async {
    await send(
      to: email,
      subject: 'Welcome to your own personal streaming service',
      body:
          'Welcome to your own personal streaming service, $username!\n\n'
          'Your account is ready. You can create profiles, build your library, '
          'watch together, and access your media remotely.',
    );
  }

  /// Sends an invitation for an existing streaming account membership.
  Future<void> memberInvitation(
    String email,
    String accountName,
    String token,
    DateTime expiresAt,
  ) async {
    await send(
      to: email,
      subject: 'You have been invited to a streaming account',
      body:
          'You were invited to join $accountName.\n\n'
          'Invitation token: $token\n'
          'This invitation expires: ${expiresAt.toLocal()}\n\n'
          'Accept the invitation in the streaming service to create or '
          'connect your login.',
    );
  }

  /// Sends a short-lived MFA verification code.
  ///
  /// The plaintext code is never logged by this service.
  Future<void> mfaCode(String email, String code) async {
    await send(
      to: email,
      subject: 'Your streaming service MFA code',
      body:
          'Your verification code is $code. It expires in 10 minutes.\n\n'
          'If you did not request this code, secure your account immediately.',
    );
  }

  /// Sends a notification when a new device is paired.
  Future<void> newDevice(String email, String deviceName) async {
    await send(
      to: email,
      subject: 'New paired device',
      body:
          'A new device was paired with your personal streaming service.\n\n'
          'Device: $deviceName\n'
          'If you did not do this, review your active sessions and change '
          'your password.',
    );
  }

  /// Sends a suspicious-login notification.
  Future<void> suspicious(
    String email,
    String location,
    String timeZoneTime,
  ) async {
    await send(
      to: email,
      subject: 'Suspicious login detected',
      body:
          'Suspicious login detected at $location, at $timeZoneTime.\n\n'
          'If this was not you, sign out all sessions and secure your account.',
    );
  }

  /// Sends a notification when media is added to the library.
  Future<void> mediaAdded(
    String email,
    String profileName,
    String title, {
    String? details,
  }) async {
    final extraDetails =
        details == null || details.trim().isEmpty
            ? ''
            : '\n\n${details.trim()}';

    await send(
      to: email,
      subject: '$profileName added $title',
      body:
          '$profileName added $title to your personal streaming library.'
          '$extraDetails',
    );
  }

  /// Sends the platform-owner notification for a paid physical storage
  /// request.
  Future<void> storageRequest(
    String email,
    String username,
    String accountId,
    String serverName,
    int terabytes,
    double feeUsd,
  ) async {
    if (terabytes <= 0 || feeUsd < 0) {
      return;
    }

    await send(
      to: email,
      subject: 'Additional storage request received',
      body:
          '$username from $accountId using $serverName is requesting '
          '$terabytes TB of additional storage.\n\n'
          'Requested fee: \$${feeUsd.toStringAsFixed(2)} USD.\n'
          'Please review the request, receive payment, acquire the physical '
          'storage, install it, and mark the request complete.',
    );
  }

  /// Sends the user the acceptance message while storage is being acquired.
  Future<void> storageAccepted(String email, int terabytes) async {
    if (terabytes <= 0) {
      return;
    }

    await send(
      to: email,
      subject: 'Additional storage request accepted',
      body:
          'We accepted your request for $terabytes TB of additional storage.\n\n'
          'Please be patient while we obtain and install the additional '
          'storage on your server.',
    );
  }

  /// Sends the user confirmation after physical storage has been installed.
  Future<void> storageInstalled(String email, int terabytes) async {
    if (terabytes <= 0) {
      return;
    }

    await send(
      to: email,
      subject: 'Additional storage added to your server',
      body:
          'Dear user,\n\n'
          'We added $terabytes TB of additional storage to your server.\n'
          'Your storage capacity has been updated.',
    );
  }

  /// Sends a short-lived one-time access code.
  ///
  /// The code is intentionally included only in the email body and is never
  /// logged by this service.
  Future<void> oneTimeCode(String email, String code) async {
    await send(
      to: email,
      subject: 'Your one-time streaming service access code',
      body:
          'Your one-time access code is: $code\n\n'
          'This code expires soon. Never share it with anyone.',
    );
  }

  void _logUnavailable() {
    // Deliberately do not include recipient, subject, body, MFA codes,
    // invitation tokens, or other potentially sensitive information.
    stdout.writeln('[EmailService] Email service is not configured or '
        'the requested message is invalid.');
  }

  bool _isValidEmail(String value) {
    if (value.length > 254) {
      return false;
    }

    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
      caseSensitive: false,
    ).hasMatch(value);
  }
}
