import 'package:flutter/material.dart';

/// The body an overview card shows while its *first* load is in flight: a
/// card-sized centered spinner carrying the caller's [indicatorKey]. Meant to
/// sit inside the caller's own card shell — it draws no card of its own.
class CardLoading extends StatelessWidget {
  final Key indicatorKey;

  const CardLoading({super.key, required this.indicatorKey});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 48,
        width: 48,
        child: CircularProgressIndicator(key: indicatorKey),
      ),
    );
  }
}
