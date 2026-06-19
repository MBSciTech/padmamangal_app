// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildFullVideoPlayer(String data) {
  final viewId = 'video-preview-${data.hashCode}';
  
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
    return html.VideoElement()
      ..src = data
      ..autoplay = true
      ..controls = true
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
  });

  return Container(
    constraints: const BoxConstraints(maxHeight: 500, maxWidth: 800),
    child: HtmlElementView(viewType: viewId),
  );
}
