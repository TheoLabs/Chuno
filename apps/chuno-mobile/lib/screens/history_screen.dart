import 'package:flutter/material.dart';
import '../data/mock.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: Text('기록')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            children: [
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(children: [
                  _stat('128', '누적 km', AppColors.coral),
                  _divider(),
                  _stat('32', '경기', AppColors.text),
                  _divider(),
                  _stat('58%', '승률', AppColors.done),
                ]),
              ),
              const SizedBox(height: 14),
              for (final h in Mock.history) ...[
                Panel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Muted(h.sub, size: 11),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Tag(h.place, bg: h.placeColor.withValues(alpha: .18), fg: h.placeColor),
                          const SizedBox(height: 4),
                          Text(h.score, style: numStyle(size: 11, color: AppColors.muted, w: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: numStyle(size: 22, color: color)),
          const SizedBox(height: 3),
          Muted(label, size: 11),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 34, color: AppColors.line);
}
