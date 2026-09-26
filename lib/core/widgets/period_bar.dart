import 'package:flutter/material.dart';

/// Barra di navigazione di un periodo (settimana/mese) con "Oggi".
final class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.previousTooltip = 'Periodo precedente',
    this.nextTooltip = 'Periodo successivo',
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final String previousTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: previousTooltip,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: nextTooltip,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          TextButton(onPressed: onToday, child: const Text('Oggi')),
        ],
      ),
    );
  }
}
