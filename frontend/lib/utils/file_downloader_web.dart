// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../services/chat_service.dart';

void downloadOrOpenFile(ChatFile file) {
  try {
    final String dataUrl = file.data;
    final String base64Data = dataUrl.contains(',') ? dataUrl.split(',')[1] : dataUrl;
    final bytes = base64Decode(base64Data);
    
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute("download", file.name)
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    debugPrint('Error downloading file on web: $e');
  }
}
