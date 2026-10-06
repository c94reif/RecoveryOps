enum CacScanSide { front, back }

enum CacSides {
  frontAndBack,
  backOnly;

  CacScanSide get firstSide =>
      this == backOnly ? CacScanSide.back : CacScanSide.front;
}
