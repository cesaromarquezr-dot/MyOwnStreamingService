import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'config.dart';

/// Raised when a request body exceeds the configured byte ceiling.
/// Extends FormatException so existing route validation paths safely reject
/// oversized JSON bodies instead of allowing unbounded `.join()` allocations.
class RequestBodyTooLargeException extends FormatException {
  RequestBodyTooLargeException(this.maxBytes)
      : super('Request body exceeds the configured size limit.');

  final int maxBytes;
}

/// Reads a byte stream with a hard cap. This is independently testable and
/// also protects chunked transfer requests with no declared Content-Length.
Future<List<int>> readBoundedBytes(
  Stream<List<int>> source, {
  required int maxBytes,
}) async {
  if (maxBytes < 1) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'Must be positive.');
  }

  final builder = BytesBuilder(copy: false);
  var total = 0;
  await for (final chunk in source) {
    total += chunk.length;
    if (total > maxBytes) {
      throw RequestBodyTooLargeException(maxBytes);
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

/// Reads a request body with a byte cap for both fixed Content-Length and
/// chunked transfer. Routes should use this instead of unbounded `.join()`.
Future<String> readBoundedRequestBody(
  HttpRequest request, {
  int? maxBytes,
}) async {
  final limit = maxBytes ?? AppConfig.maxRequestBodyBytes;
  if (request.contentLength > limit) {
    request.response.persistentConnection = false;
    throw RequestBodyTooLargeException(limit);
  }

  try {
    final bytes = await readBoundedBytes(request, maxBytes: limit);
    return utf8.decode(bytes);
  } on RequestBodyTooLargeException {
    request.response.persistentConnection = false;
    rethrow;
  }
}
