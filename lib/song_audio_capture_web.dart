import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'song_audio_sample.dart';

web.MediaStream? _stream;
web.MediaRecorder? _mediaRecorder;

final List<web.Blob> _chunks = <web.Blob>[];

Future<void> start() async {
  // Release any previous recording before starting a new one.
  await dispose();

  if (!web.window.isSecureContext) {
    throw StateError(
      'Microphone access requires a secure HTTPS connection or localhost.',
    );
  }

  // Request microphone access.
  final stream = await web.window.navigator.mediaDevices
      .getUserMedia(
        web.MediaStreamConstraints(audio: true.toJS),
      )
      .toDart;

  _stream = stream;

  try {
    String? requestedMimeType;

    if (web.MediaRecorder.isTypeSupported(
      'audio/webm;codecs=opus',
    )) {
      requestedMimeType = 'audio/webm;codecs=opus';
    } else if (web.MediaRecorder.isTypeSupported('audio/webm')) {
      requestedMimeType = 'audio/webm';
    }

    // Create the recorder using the best supported format.
    final web.MediaRecorder recorder;

    if (requestedMimeType == null) {
      recorder = web.MediaRecorder(stream);
    } else {
      recorder = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(
          mimeType: requestedMimeType,
        ),
      );
    }

    _mediaRecorder = recorder;
    _chunks.clear();

    // Receive recorded audio chunks.
    recorder.ondataavailable = ((web.Event event) {
      final blobEvent = event as web.BlobEvent;
      final chunk = blobEvent.data;

      if (chunk.size > 0) {
        _chunks.add(chunk);
      }
    }).toJS;

    // Begin recording, requesting data every 250 milliseconds.
    recorder.start(250);
  } catch (_) {
    await dispose();
    rethrow;
  }
}

Future<SongAudioSample> stop() async {
  final recorder = _mediaRecorder;

  if (recorder == null) {
    throw StateError('Microphone recording was not started.');
  }

  final stopped = Completer<void>();

  // Listen for the browser's recording completion event.
  recorder.onstop = ((web.Event event) {
    if (!stopped.isCompleted) {
      stopped.complete();
    }
  }).toJS;

  try {
    if (recorder.state == 'inactive') {
      stopped.complete();
    } else {
      recorder.stop();
    }

    // Wait for the final audio data to be delivered.
    await stopped.future.timeout(
      const Duration(seconds: 5),
    );

    // Determine the actual recording format.
    String mimeType = recorder.mimeType;

    if (mimeType.isEmpty) {
      for (final chunk in _chunks) {
        if (chunk.type.isNotEmpty) {
          mimeType = chunk.type;
          break;
        }
      }
    }

    if (mimeType.isEmpty) {
      mimeType = 'audio/webm';
    }

    // Combine all recorded chunks into one byte array.
    final builder = BytesBuilder(copy: false);

    for (final chunk in _chunks) {
      if (chunk.size == 0) {
        continue;
      }

      final buffer = await chunk.arrayBuffer().toDart;

      builder.add(
        Uint8List.view(buffer.toDart),
      );
    }

    final bytes = builder.takeBytes();

    if (bytes.isEmpty) {
      throw StateError(
        'The microphone did not capture any audio.',
      );
    }

    return SongAudioSample(
      bytes: bytes,
      mimeType: mimeType,
    );
  } finally {
    await dispose();
  }
}

Future<void> dispose() async {
  final recorder = _mediaRecorder;

  if (recorder != null) {
    try {
      if (recorder.state != 'inactive') {
        recorder.stop();
      }
    } catch (_) {
      // Ignore errors when stopping an already stopped recorder.
    }

    // Remove browser event handlers.
    recorder.ondataavailable = null;
    recorder.onstop = null;
  }

  // Release microphone tracks.
  final stream = _stream;

  if (stream != null) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  _stream = null;
  _mediaRecorder = null;

  _chunks.clear();
}
