String? cacRetryHint(int attempts) => switch (attempts) {
      2 => 'Lay the card flat and fill the box with the whole back — the '
          'number reads best running straight across the frame.',
      >= 3 => 'Stand so your own shadow falls across the card and tilt it '
          'until the number stops shining.',
      _ => null,
    };
