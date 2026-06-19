import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class PickedFilePayload {
  final String data;
  final String name;
  final String type;

  PickedFilePayload({
    required this.data,
    required this.name,
    required this.type,
  });
}

Future<PickedFilePayload?> pickFileAttachment() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: true,
  );

  if (result != null && result.files.isNotEmpty) {
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final base64String = base64Encode(bytes);
    
    String mimeType = 'application/octet-stream';
    if (file.extension != null) {
      final ext = file.extension!.toLowerCase();
      if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
      else if (ext == 'png') mimeType = 'image/png';
      else if (ext == 'pdf') mimeType = 'application/pdf';
      else if (ext == 'mp4') mimeType = 'video/mp4';
      else if (ext == 'mp3' || ext == 'm4a') mimeType = 'audio/mpeg';
    }

    String type = 'file';
    if (mimeType.startsWith('image/')) type = 'image';
    else if (mimeType.startsWith('video/')) type = 'video';
    else if (mimeType.startsWith('audio/')) type = 'voice';

    return PickedFilePayload(
      data: 'data:$mimeType;base64,$base64String',
      name: file.name,
      type: type,
    );
  }
  return null;
}
