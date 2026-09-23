// Image utility functions

import 'package:image/image.dart' as img;

extension ImageExtensions on img.Image {
  /// Get pixel as list of [r, g, b, a]
  List<int> getPixel(int x, int y) {
    final p = this.getPixelSafe(x, y);
    return [p.r, p.g, p.b, p.a];
  }
}

extension ListExtensions<T> on List<T> {
  /// Reshape a flat list into a nested list structure
  List<dynamic> reshape(List<int> shape) {
    if (shape.length == 1) return this;
    
    final stride = shape.sublist(1).fold(1, (a, b) => a * b);
    final result = <dynamic>[];
    
    for (int i = 0; i < shape[0]; i++) {
      final start = i * stride;
      final end = start + stride;
      final sublist = this.sublist(start, end);
      if (shape.length > 2) {
        result.add(sublist.reshape(shape.sublist(1)));
      } else {
        result.add(sublist);
      }
    }
    
    return result;
  }
}