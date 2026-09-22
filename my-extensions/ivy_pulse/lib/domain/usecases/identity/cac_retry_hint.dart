/// What to tell an operator after a scan has missed more than once.
///
/// The first miss gets nothing — the refusal itself already says what to
/// fix, and a hint on top of it is noise. The advice escalates from there,
/// framing first and light second, because that is the order the fixes are
/// cheap in and the order they actually fail in.
String? cacRetryHint(int attempts) => switch (attempts) {
      // The back of the card is landscape and the DoD ID number is one short
      // line of small print on it. A card held at an angle or half out of the
      // box puts that line on too few pixels, skewed, and OCR reads a 3 for
      // an 8. Flat and filling the box, the number runs straight across the
      // frame at a size that reads on the first frame.
      2 => 'Lay the card flat and fill the box with the whole back — the '
          'number reads best running straight across the frame.',
      // Glare is the failure that survives good framing: the card's
      // holographic overlay throws a highlight straight over the digits, and
      // a phone held over a card at arm's length is the worst angle for it.
      // Standing so the operator's own body shades the card kills the
      // highlight without needing anything they do not already have.
      >= 3 => 'Stand so your own shadow falls across the card and tilt it '
          'until the number stops shining.',
      _ => null,
    };
