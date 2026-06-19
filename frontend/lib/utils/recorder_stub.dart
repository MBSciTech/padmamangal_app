abstract class AudioRecorderPlatform {
  Future<void> start();
  Future<String?> stop(); // Returns Base64 Data URL
  bool get isRecording;
}

AudioRecorderPlatform getAudioRecorder() {
  throw UnimplementedError('Platform not supported');
}
