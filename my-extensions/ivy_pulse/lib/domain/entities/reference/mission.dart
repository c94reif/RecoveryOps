/// A dispatch profile — how long the vehicle is expected to be out.
class Mission {
  final String type;
  final int days;
  final String description;

  const Mission({
    required this.type,
    required this.days,
    required this.description,
  });
}
