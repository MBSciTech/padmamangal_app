// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, avoid_print
import 'dart:html' as html;

void playAudioBase64(String base64Data) {
  try {
    final audio = html.AudioElement(base64Data);
    audio.play();
  } catch (e) {
    print('Error playing audio: $e');
  }
}
