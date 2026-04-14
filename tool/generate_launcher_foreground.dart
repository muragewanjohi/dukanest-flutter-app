import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const inputPath = 'assets/images/dukanest_logo.png';
  const outputPath = 'assets/images/dukanest_logo_foreground.png';
  const canvasSize = 1024;
  const logoScale = 0.68;

  final sourceBytes = File(inputPath).readAsBytesSync();
  final sourceImage = img.decodeImage(sourceBytes);
  if (sourceImage == null) {
    stderr.writeln('Could not decode image at $inputPath');
    exitCode = 1;
    return;
  }

  final paddedCanvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(paddedCanvas, color: img.ColorRgba8(0, 0, 0, 0));

  final targetLongestSide = (canvasSize * logoScale).round();
  final resized = sourceImage.width >= sourceImage.height
      ? img.copyResize(sourceImage, width: targetLongestSide)
      : img.copyResize(sourceImage, height: targetLongestSide);

  final x = ((canvasSize - resized.width) / 2).round();
  final y = ((canvasSize - resized.height) / 2).round();
  img.compositeImage(paddedCanvas, resized, dstX: x, dstY: y);

  File(outputPath).writeAsBytesSync(img.encodePng(paddedCanvas));
  stdout.writeln('Generated padded icon foreground: $outputPath');
}
