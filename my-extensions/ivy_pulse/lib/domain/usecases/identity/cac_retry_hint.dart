/// Aiming advice that only earns its place after the operator has already
/// missed, keyed to how many scans in a row have come back without a Soldier.
///
/// Pure, and in the domain rather than inside a build method, because the two
/// things it says are the only non-obvious facts about photographing a CAC and
/// they have to stay testable without a camera or a widget.
///
/// Nothing on the first miss on purpose. The rejection carries its own
/// instruction — wipe the card, move closer, turn it over — and stacking a
/// second piece of advice on top of it while the operator is still lining the
/// card up is how a Soldier in the rain stops reading the panel at all.
///
/// [attempts] counts scans since the last verified read, so the escalation is
/// about *this* card and *this* light, not about the day.
String? cacRetryHint(int attempts) => switch (attempts) {
      // The PDF417's bars run the long way up a portrait card, so a card held
      // upright puts a tall thin symbol in a frame that is wide — most of the
      // sensor is spent on card stock and sky. Turned sideways the symbol
      // fills the frame and every module lands on roughly twice as many
      // pixels, which is the whole difference between a miss and a read. It
      // costs nothing to decode: the detector sweeps all four rotations
      // whatever the operator does.
      2 => 'Turn the card sideways so the barcode runs across the frame — it '
          'reads at about twice the size that way.',
      // Glare is the failure that survives good framing, and a phone held over
      // a card at arm's length is the worst possible angle for it. Standing so
      // the operator's own body shades the card kills the specular highlight
      // without needing anything they do not already have.
      >= 3 => 'Lay the card flat, stand so your own shadow falls across it, '
          'and shoot straight down.',
      _ => null,
    };
