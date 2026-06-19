// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<String?> pickImageBase64() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
  uploadInput.click();
  
  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((e) {
        final dataUrl = reader.result as String;
        
        // Use HTML Image & Canvas to compress/resize on the fly
        final img = html.ImageElement();
        img.src = dataUrl;
        img.onLoad.listen((_) {
          final canvas = html.CanvasElement();
          int width = img.width ?? 0;
          int height = img.height ?? 0;
          
          // Limit to max 512x512
          const maxDim = 512;
          if (width > maxDim || height > maxDim) {
            if (width > height) {
              height = (height * maxDim / width).round();
              width = maxDim;
            } else {
              width = (width * maxDim / height).round();
              height = maxDim;
            }
          }
          
          canvas.width = width;
          canvas.height = height;
          
          final ctx = canvas.context2D;
          ctx.drawImageScaled(img, 0, 0, width, height);
          
          // Export as optimized JPEG at 75% quality
          final compressedDataUrl = canvas.toDataUrl('image/jpeg', 0.75);
          completer.complete(compressedDataUrl);
        });
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
