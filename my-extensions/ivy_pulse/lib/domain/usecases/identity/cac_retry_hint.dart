String? cacRetryHint(int attempts, {bool bothSides = false}) =>
    switch (attempts) {
      2 when bothSides => 'Lay the card flat and fill the box with the photo '
          'side first. Keep the name straight across the frame, then flip '
          'the card when asked.',
      2 => 'Lay the card flat and fill the box with the whole back — the '
          'number reads best running straight across the frame.',
      >= 3 => 'Stand so your own shadow falls across the card and tilt it '
          'until the print stops shining.',
      _ => null,
    };
