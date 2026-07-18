/// Per-food-group portion counts (staple, meat, fruit, vegetable), mirroring
/// the backend's `Portions` shape.
class Portions {
  final double staple;
  final double meat;
  final double fruit;
  final double veg;

  const Portions({
    required this.staple,
    required this.meat,
    required this.fruit,
    required this.veg,
  });

  factory Portions.fromJson(Map<String, dynamic> json) {
    return Portions(
      staple: (json['staple'] as num).toDouble(),
      meat: (json['meat'] as num).toDouble(),
      fruit: (json['fruit'] as num).toDouble(),
      veg: (json['veg'] as num).toDouble(),
    );
  }
}
