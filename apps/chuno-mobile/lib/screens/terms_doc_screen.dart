import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/error/app_exception.dart';
import '../features/legal/legal_models.dart';
import '../features/legal/legal_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// 약관 전문 뷰어. list 로 받은 [document](id·title·version)를 받아
/// 단건 `GET /legal-documents/:id`(retrieve)로 전문(content)·시행일을 로드한다.
/// "동의" 시 true, "닫기/뒤로" 시 false 를 pop 으로 반환한다.
class TermsDocScreen extends ConsumerStatefulWidget {
  final LegalDocument document;
  const TermsDocScreen({super.key, required this.document});

  @override
  ConsumerState<TermsDocScreen> createState() => _TermsDocScreenState();
}

class _TermsDocScreenState extends ConsumerState<TermsDocScreen> {
  /// 전문 로드 결과(content·expectedActivateOn 포함). null=미로딩.
  LegalDocument? _full;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await ref
          .read(legalDocumentRepositoryProvider)
          .retrieve(widget.document.id);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _full = doc;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppException ? e.message : '문서를 불러오지 못했어요.';
      });
    }
  }

  /// version 라인. 시행일(expectedActivateOn)이 있으면 함께 표시한다.
  String get _versionLine {
    final version = _full?.version.isNotEmpty == true ? _full!.version : widget.document.version;
    final activate = _formatDate(_full?.expectedActivateOn);
    return activate == null ? version : '$version · 시행일 $activate';
  }

  static String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _full?.title.isNotEmpty == true ? _full!.title : widget.document.title;
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
                    child: Text(title,
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
                child: Text(_versionLine, style: numStyle(size: 11, w: FontWeight.w500, color: AppColors.muted)),
              ),
            ),
            Expanded(child: _body()),
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

  Widget _body() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.coral),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Muted(_error!, size: 13, height: 1.6),
            const SizedBox(height: 16),
            AppButton('다시 시도', variant: BtnVariant.ghost, expand: false, onTap: _load),
          ],
        ),
      );
    }
    final content = _full?.content ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          content,
          style: const TextStyle(fontSize: 12.5, height: 1.8, color: AppColors.muted),
        ),
      ),
    );
  }
}
