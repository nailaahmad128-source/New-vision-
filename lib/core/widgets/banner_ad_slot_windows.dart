import 'package:flutter/material.dart';

class BannerAdSlot extends StatelessWidget {
final String placement;
const BannerAdSlot({super.key, this.placement = 'home'});

@override
Widget build(BuildContext context) => const SizedBox.shrink();
}
