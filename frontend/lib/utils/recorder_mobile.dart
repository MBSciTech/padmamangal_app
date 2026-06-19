import 'recorder_stub.dart';

class MobileAudioRecorder implements AudioRecorderPlatform {
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> start() async {
    _isRecording = true;
  }

  @override
  Future<String?> stop() async {
    _isRecording = false;
    return null;
  }
}

AudioRecorderPlatform getAudioRecorder() => MobileAudioRecorder();
