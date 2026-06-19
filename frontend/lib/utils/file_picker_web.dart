// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'file_picker_stub.dart';

Future<PickedFilePayload?> pickFileAttachment() async {
  final completer = Completer<PickedFilePayload?>();
  final uploadInput = html.FileUploadInputElement()..accept = '*/*';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) {
        final dataUrl = reader.result as String;
        
        final mime = file.type.toLowerCase();
        String type = 'file';
        if (mime.startsWith('image/')) {
          type = 'image';
        } else if (mime.startsWith('video/')) {
          type = 'video';
        } else if (mime.startsWith('audio/')) {
          type = 'voice';
        }

        completer.complete(PickedFilePayload(
          data: dataUrl,
          name: file.name,
          type: type,
        ));
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
