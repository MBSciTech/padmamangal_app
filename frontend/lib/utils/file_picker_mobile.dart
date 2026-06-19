import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'file_picker_stub.dart';

Future<PickedFilePayload?> pickFileAttachment() async {
  final ImagePicker picker = ImagePicker();
  final XFile? media = await picker.pickMedia(
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 75,
  );
  if (media != null) {
    final bytes = await media.readAsBytes();
    final base64String = base64Encode(bytes);
    final mimeType = media.mimeType ?? 'image/jpeg';
    String type = 'file';
    if (mimeType.startsWith('image/')) {
      type = 'image';
    } else if (mimeType.startsWith('video/')) {
      type = 'video';
    }
    return PickedFilePayload(
      data: 'data:$mimeType;base64,$base64String',
      name: media.name,
      type: type,
    );
  }
  return null;
}
