import 'dart:typed_data';

import 'package:crehooni/core/theme.dart';
import 'package:crehooni/ui/identify/photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _orangePng() {
  final image = img.Image(width: 80, height: 60);
  img.fill(image, color: img.ColorRgb8(214, 122, 48));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  testWidgets('a picked photo fills the drop target instead of collapsing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PhotoDropTarget(
            imageBytes: _orangePng(),
            title: '참고로 쓸 사진',
            hint: '모프가 잘 보이게 찍힌 컷',
            minHeight: 180,
            onTap: () {},
            onClear: () {},
          ),
        ),
      ),
    );

    final preview = tester.getSize(find.byType(Image));
    expect(preview.height, 180);
    expect(preview.width, greaterThan(0));
    expect(find.byType(Image), findsOne);
  });
}
