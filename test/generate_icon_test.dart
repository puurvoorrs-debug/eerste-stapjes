import 'dart:io';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate clean png icons from svg paths', () async {
    // Read the SVG file
    final svgFile = File('assets/images/Eerste stapjes - Logo nieuw ronde icoon.svg');
    if (!svgFile.existsSync()) {
      print('Error: SVG file not found!');
      return;
    }
    var svgContent = svgFile.readAsStringSync();

    // Replace CSS styling with inline attributes since flutter_svg style elements are unhandled
    svgContent = svgContent.replaceAll('class="cls-1"', 'fill="#ffffff"');
    svgContent = svgContent.replaceAll('class="cls-2"', 'fill="#ec6437"');

    // Extract the inner content of the svg
    final int svgOpenEnd = svgContent.indexOf('>', svgContent.indexOf('<svg')) + 1;
    final int svgCloseStart = svgContent.lastIndexOf('</svg>');
    if (svgOpenEnd == 0 || svgCloseStart == -1) {
      print('Error parsing SVG contents!');
      return;
    }
    final String innerContent = svgContent.substring(svgOpenEnd, svgCloseStart).trim();

    // Remove the background circle and the orange border ring for the adaptive foreground image
    // The foreground should ONLY contain the footprints (which are already centered in the original SVG space)
    final String innerContentNoCircleOrRing = innerContent
        .replaceFirst(RegExp(r'<circle[^>]*/>'), '')
        .replaceFirst(RegExp(r'<path[^>]*d="M294\.4,32[^"]*"[^>]*/>'), '');

    // Centered and scaled versions (original viewport is 588.8 x 588.8)
    // 1. Static full icon scaled to 90% for a clean margin (retains background and border ring)
    final String fullIconSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 588.8 588.8">
  <g transform="translate(29.44, 29.44) scale(0.90)">
    $innerContent
  </g>
</svg>''';

    // 2. Adaptive foreground scaled to 65% to fit perfectly inside the Android safe zone (169px radius on 512px canvas)
    // Centering: (588.8 - 588.8 * 0.65) / 2 = 103.04
    final String footprintSvg = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 588.8 588.8">
  <g transform="translate(103.04, 103.04) scale(0.65)">
    $innerContentNoCircleOrRing
  </g>
</svg>''';

    // Output directory
    final outDir = Directory('assets/images');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    const int size = 512;

    // 1. Generate Foreground (Transparent Background with footprints only)
    final PictureInfo fgPicInfo = await vg.loadPicture(
      SvgStringLoader(footprintSvg),
      null,
    );
    final Image fgImage = await fgPicInfo.picture.toImage(size, size);
    final fgByteData = await fgImage.toByteData(format: ImageByteFormat.png);
    final fgBuffer = fgByteData!.buffer.asUint8List();
    await File('assets/images/Statische_logo_voor_app_icon_foreground.png')
        .writeAsBytes(fgBuffer);

    // 2. Generate Full Icon (White Background with Orange Foot & Border)
    final PictureInfo bgPicInfo = await vg.loadPicture(
      SvgStringLoader(fullIconSvg),
      null,
    );
    final Image bgImage = await bgPicInfo.picture.toImage(size, size);
    final bgByteData = await bgImage.toByteData(format: ImageByteFormat.png);
    final bgBuffer = bgByteData!.buffer.asUint8List();
    await File('assets/images/Statische_logo_voor_app_icon.png')
        .writeAsBytes(bgBuffer);

    print('Launcher icons generated successfully with inline styling, scaling, and centering!');
  });
}
