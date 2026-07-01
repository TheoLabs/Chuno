import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        title: const Text('포인트 스토어', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Panel(
            hud: true,
            child: Column(children: [
              const Muted('보유 포인트', size: 11),
              const SizedBox(height: 6),
              Text('1,240 P', style: numStyle(size: 32, color: AppColors.coral)),
            ]),
          ),
          const SizedBox(height: 14),
          Panel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('🛡️ 광고 제거', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Muted('한 달권 · 배너/전면 광고 제거', size: 11),
                  ],
                ),
                AppButton('500 P', expand: false, height: 40, fontSize: 13, onTap: () => comingSoon(context, '구매는 준비 중이에요')),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: 0.55,
            child: Panel(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('🎽 프로필 뱃지', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      SizedBox(height: 5),
                      Muted('MVP 이후 예정', size: 11),
                    ],
                  ),
                  Tag('준비중', bg: const Color(0xFF2B323A), fg: const Color(0xFF9AA3AD)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: const Muted('ⓘ 포인트 적립률·가격은 MVP 이후 밸런싱 예정.', size: 12),
          ),
        ],
      ),
    );
  }
}
