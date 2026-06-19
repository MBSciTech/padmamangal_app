import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String?> pickImageBase64() async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 75,
  );
  if (image != null) {
    final bytes = await image.readAsBytes();
    final base64String = base64Encode(bytes);
    final mimeType = image.mimeType ?? 'image/jpeg';
    return 'data:$mimeType;base64,$base64String';
  }
  return null;
}
