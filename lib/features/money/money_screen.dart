import 'package:flutter/material.dart';

import '../../shell/root_shell.dart';
import '../../theme/tokens.dart';
import '../../ui/grain.dart';

/// Shell for the Money hub. The full hub (Expense and Deposit, accounts,
/// budgets, goals) is the next build; this screen shows where it will live.
class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.colors.isDark;
    final bg = dark ? MoneyColors.navy : MoneyColors.ice;
    final ink = dark ? MoneyColors.ice : MoneyColors.navy;
    final muted = dark ? MoneyColors.airy : MoneyColors.teal;
    final card = dark ? MoneyColors.deepNavy : Colors.white;
    const coming = [
      ('Expense and Deposit', 'Two taps to log money out or in'),
      ('Global deposit', 'All your savings combined in one number'),
      ('Budgets and safe to spend', 'Know what is left for today'),
      ('Goals', 'Emergency fund, laptop, trips'),
      ('Spending chart', 'Day by day against your budget'),
    ];
    return ColoredBox(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
            children: [
              Text('Money', style: AppText.sans(34, weight: FontWeight.w700, color: ink, letterSpacing: -0.9)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: SizedBox(
                  height: 190,
                  child: GrainArt(
                    base: MoneyColors.navy,
                    spots: const [
                      Spot(MoneyColors.airy, Alignment(1, -1), 1.0),
                      Spot(MoneyColors.steel, Alignment(-1, 1), 1.0),
                      Spot(Color(0x59F2EFE7), Alignment(0.4, 0.4), 0.5),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('GLOBAL DEPOSIT', style: AppText.label(11, color: MoneyColors.sky)),
                        const SizedBox(height: 12),
                        Text('৳0', style: AppText.dot(46, color: MoneyColors.ice)),
                        const SizedBox(height: 6),
                        Text('All savings combined', style: AppText.sans(13, color: MoneyColors.sky)),
                        const Spacer(),
                        Text('ARRIVES IN THE NEXT BUILD', style: AppText.label(10.5, color: MoneyColors.airy)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Coming to Money', style: AppText.sans(13, weight: FontWeight.w600, color: muted)),
              const SizedBox(height: 10),
              for (final item in coming)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(Radii.m)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.$1, style: AppText.sans(15, weight: FontWeight.w600, color: ink)),
                    const SizedBox(height: 2),
                    Text(item.$2, style: AppText.sans(13, color: muted)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
