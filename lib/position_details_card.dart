import 'package:flutter/material.dart';
import 'models.dart';

const _ink = Color(0xFF10283F), _sea = Color(0xFF007F78);

class PositionDetailsCard extends StatelessWidget {
  const PositionDetailsCard({
    super.key,
    required this.position,
    required this.name,
  });
  final Position position;
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _sea.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.directions_car_filled_rounded, color: _sea),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stamp(position.time),
                style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
              ),
              if (position.address.trim().isNotEmpty)
                Text(
                  position.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
              if (!position.valid)
                const Text(
                  'Invalid GPS fix',
                  style: TextStyle(color: Colors.deepOrange, fontSize: 11),
                ),
              if (position.overspeed)
                const Text(
                  'Speed alert',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            Text(
              position.kmh.toStringAsFixed(0),
              style: const TextStyle(
                color: _ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'km/h',
              style: TextStyle(color: Colors.blueGrey, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}
