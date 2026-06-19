// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'recorder_stub.dart';

class WebAudioRecorder implements AudioRecorderPlatform {
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _chunks = [];
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start() async {
    if (_isRecording) return;
    _chunks.clear();

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('MediaDevices API not supported on this browser.');
      }
      final stream = await mediaDevices.getUserMedia({'audio': true});
      _mediaRecorder = html.MediaRecorder(stream);
      
      _mediaRecorder!.on['dataavailable'].listen((html.Event e) {
        final dynamic event = e;
        if (event.data != null) {
          _chunks.add(event.data);
        }
      });

      _mediaRecorder!.start();
      _isRecording = true;
    } catch (e) {
      throw Exception('Could not access microphone: $e');
    }
  }

  @override
  Future<String?> stop() async {
    if (!_isRecording || _mediaRecorder == null) return null;

    final completer = Completer<String?>();
    
    _mediaRecorder!.on['stop'].listen((_) {
      if (_chunks.isEmpty) {
        completer.complete(null);
        return;
      }
      
      final blob = html.Blob(_chunks, 'audio/webm');
      final reader = html.FileReader();
      reader.readAsDataUrl(blob);
      reader.onLoadEnd.listen((e) {
        completer.complete(reader.result as String?);
      });
      
      // Stop stream tracks to turn off mic light
      _mediaRecorder!.stream?.getTracks().forEach((track) => track.stop());
      _mediaRecorder = null;
      _isRecording = false;
    });

    _mediaRecorder!.stop();
    return completer.future;
  }
}

AudioRecorderPlatform getAudioRecorder() => WebAudioRecorder();
