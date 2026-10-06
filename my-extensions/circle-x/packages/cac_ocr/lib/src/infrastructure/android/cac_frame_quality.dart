import 'dart:typed_data';

typedef CacFrameQuality = ({double sharpness, double glare});

CacFrameQuality measureCacFrame(Uint8List luma, int width, int height,
    {int step = 4}) {
  var edges = 0;
  var washedOut = 0;
  var samples = 0;
  final down = step * width;
  for (var y = step; y < height - step; y += step) {
    final rowEnd = y * width + width - step;
    for (var index = y * width + step; index < rowEnd; index += step) {
      final centre = luma[index];
      edges += (4 * centre -
              luma[index - step] -
              luma[index + step] -
              luma[index - down] -
              luma[index + down])
          .abs();
      if (centre >= 250) washedOut++;
      samples++;
    }
  }
  return samples == 0
      ? (sharpness: 0.0, glare: 0.0)
      : (sharpness: edges / samples, glare: washedOut / samples);
}
