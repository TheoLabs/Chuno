import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// 약관 전문 조항(제목 + 본문) 한 단락.
class DocClause {
  final String heading;
  final String body;
  const DocClause(this.heading, this.body);
}

/// 약관 문서 데이터 (mock · Placeholder · 추후 법무 검토 반영).
class TermsDoc {
  final String title;
  final String version;
  final List<DocClause> clauses;
  const TermsDoc(this.title, this.version, this.clauses);
}

/// 문서 키별 mock 전문. 실 문서는 추후 CMS/서버 연동으로 교체.
const Map<String, TermsDoc> kTermsDocs = {
  'terms': TermsDoc('이용약관', 'v1.0 · 시행일 2026-00-00', [
    DocClause('제1조 (목적)',
        '본 약관은 추노(이하 "회사")가 제공하는 러닝 매칭·경주 서비스(이하 "서비스")의 이용 조건 및 절차, 회사와 이용자의 권리·의무·책임사항을 규정함을 목적으로 합니다. (Placeholder 문구 · 추후 법무 검토 반영)'),
    DocClause('제2조 (정의)',
        '"서비스"란 회사가 제공하는 실시간 러닝 매칭·추격전 기능 일체를 의미합니다. 세부 용어 정의는 추후 확정됩니다. (Placeholder)'),
    DocClause('제3조 (이용계약의 체결)',
        '이용계약은 이용자가 본 약관에 동의하고 회사가 이를 승낙함으로써 체결됩니다. (Placeholder)'),
    DocClause('제4조 (서비스의 제공 및 변경)',
        '회사는 운영상·기술상 필요에 따라 서비스 내용을 사전 고지 후 변경할 수 있습니다. (Placeholder)'),
  ]),
  'privacy': TermsDoc('개인정보 수집·이용 동의', 'v1.0 · 시행일 2026-00-00', [
    DocClause('1. 수집 항목',
        '닉네임, 러닝 기록(거리·페이스·순위), 소셜 로그인 식별자 등을 수집합니다. (Placeholder)'),
    DocClause('2. 수집·이용 목적',
        '경주 매칭, 랭킹 산정, 서비스 부정이용 방지 및 고객 문의 대응에 이용합니다. (Placeholder)'),
    DocClause('3. 보유 및 이용 기간',
        '회원 탈퇴 시 지체 없이 파기하며, 관계 법령에 따라 일정 기간 보관될 수 있습니다. (Placeholder)'),
    DocClause('4. 동의를 거부할 권리',
        '동의를 거부할 수 있으나, 필수 항목 미동의 시 서비스 이용이 제한될 수 있습니다. (Placeholder)'),
  ]),
  'location': TermsDoc('위치기반서비스 이용동의', 'v1.0 · 시행일 2026-00-00', [
    DocClause('1. 위치정보의 수집·이용 목적',
        '경주 중 이동 거리 측정, 실시간 순위 산정, 부정 출발·GPS 조작 탐지에 한해 이용합니다. (Placeholder)'),
    DocClause('2. 수집 방식',
        '경주 진행 중에만 기기 GPS를 통해 이동 거리를 계산하며, 정확한 좌표값은 서버로 전송하지 않습니다. (Placeholder)'),
    DocClause('3. 보유 기간',
        '경주 종료 및 결과 산정 후 위치 관련 원본 데이터는 즉시 파기합니다. (Placeholder)'),
    DocClause('4. 이용자의 권리',
        '본 동의는 위치정보의 보호 및 이용 등에 관한 법률에 따른 별도 동의이며, 기기의 OS 위치 권한 허용과는 구분됩니다. 언제든 동의를 철회할 수 있습니다. (Placeholder)'),
  ]),
};

/// 약관 전문 뷰어. "동의" 시 true, "닫기/뒤로" 시 false 를 pop 으로 반환한다.
class TermsDocScreen extends StatelessWidget {
  final String docKey;
  const TermsDocScreen({super.key, required this.docKey});

  @override
  Widget build(BuildContext context) {
    final doc = kTermsDocs[docKey] ?? kTermsDocs['terms']!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 앱바: 뒤로 / 제목 / 균형용 여백
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Text('←', style: TextStyle(fontSize: 20, color: AppColors.muted)),
                    ),
                  ),
                  Expanded(
                    child: Text(doc.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(doc.version, style: numStyle(size: 11, w: FontWeight.w500, color: AppColors.muted)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var k = 0; k < doc.clauses.length; k++) ...[
                      if (k > 0) const SizedBox(height: 18),
                      Text(doc.clauses[k].heading,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 6),
                      Text(doc.clauses[k].body,
                          style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton('닫기', variant: BtnVariant.ghost, onTap: () => Navigator.of(context).pop(false)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: AppButton('동의', onTap: () => Navigator.of(context).pop(true)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
