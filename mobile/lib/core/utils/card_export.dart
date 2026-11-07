import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Renders the [RepaintBoundary] behind [card] to a PNG and either shares it
/// or saves it to the gallery. Shared by every "Bagikan ke Story" card.
///
/// Throws when the card isn't on screen or the image can't be written; callers
/// show their own error toast.
Future<void> exportCardImage(
  GlobalKey card, {
  bool save = false,
  String name = 'klubby_story',
}) async {
  await WidgetsBinding.instance.endOfFrame;
  final boundary =
      card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) throw StateError('Card unavailable');
  final img = await boundary.toImage(pixelRatio: 4);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (data == null) throw StateError('Image unavailable');
  final bytes = data.buffer.asUint8List();
  if (save) {
    await Gal.putImageBytes(
      bytes,
      name: '${name}_${DateTime.now().millisecondsSinceEpoch}',
    );
  } else {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: '$name.png'),
        ],
      ),
    );
  }
}
