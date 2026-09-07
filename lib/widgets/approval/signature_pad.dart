import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../seed/seed_button.dart';

/// 결재 서명 그리기 패드. 투명 배경 PNG(base64 data URL)로 내보낸다.
class SignaturePadController {
  _SignaturePadState? _state;

  bool get isEmpty => _state?._strokes.isEmpty ?? true;

  void clear() => _state?._clear();

  /// PNG data URL (data:image/png;base64,...) — 비어 있으면 null
  Future<String?> exportPngDataUrl() async => _state?._exportPngDataUrl();
}

class SignaturePad extends StatefulWidget {
  final SignaturePadController controller;
  final double height;
  final ValueChanged<bool>? onChanged; // isEmpty 변화 알림

  const SignaturePad({
    super.key,
    required this.controller,
    this.height = 180,
    this.onChanged,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final GlobalKey _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void dispose() {
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
    super.dispose();
  }

  void _clear() {
    setState(() => _strokes.clear());
    widget.onChanged?.call(true);
  }

  Future<String?> _exportPngDataUrl() async {
    if (_strokes.isEmpty) return null;
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final base64Str = base64Encode(byteData.buffer.asUint8List());
      return 'data:image/png;base64,$base64Str';
    } catch (e) {
      debugPrint('서명 내보내기 실패: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: AppSemanticColors.borderDefault),
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.xl),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: RawGestureDetector(
                gestures: {
                  _SignaturePanRecognizer:
                      GestureRecognizerFactoryWithHandlers<_SignaturePanRecognizer>(
                    () => _SignaturePanRecognizer(),
                    (recognizer) {
                      recognizer
                        ..onStart = (details) {
                          setState(() => _strokes.add([details.localPosition]));
                          widget.onChanged?.call(false);
                        }
                        ..onUpdate = (details) {
                          if (_strokes.isEmpty) return;
                          setState(() => _strokes.last.add(details.localPosition));
                        };
                    },
                  ),
                },
                child: CustomPaint(
                  // 투명 배경 유지 (배경색을 칠하지 않음)
                  painter: _SignaturePainter(_strokes),
                  child: _strokes.isEmpty
                      ? Center(
                          child: Text(
                            '여기에 서명을 그려주세요',
                            style: TextStyle(
                              color: AppSemanticColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        SeedButton(
          label: '지우기',
          variant: SeedButtonVariant.neutralWeak,
          size: SeedButtonSize.xsmall,
          onPressed: _clear,
        ),
      ],
    );
  }
}

/// 서명 칸 안에서 시작한 손가락은 **무조건 서명이다.**
///
/// 기본 GestureDetector의 팬 인식기는 제스처 경쟁(아레나)에 참가만 하고 이길 때까지
/// 기다린다. 그래서 서명 칸이 무엇 안에 들어 있느냐에 따라 획이 통째로 사라졌다:
///
/// - 세로 스크롤 화면(내 서명 관리) 안에서는 **세로 획**을 스크롤이 가져갔다.
/// - 결재·회의록 서명 시트(모달 바텀시트)에서도 **세로 획**을 시트 내리기가 가져갔다.
/// - iOS에서 화면 왼쪽 끝부터 그은 **가로 획**은 '밀어서 뒤로가기'가 가져갔다.
///   ("앱에서 서명 작성 시 가로 획 작성이 안됨" 제보가 이것이다.)
///
/// 손가락이 서명 칸 위에 내려온 순간 아레나를 즉시 가져가 다른 제스처가 끼어들지
/// 못하게 한다. 대신 서명 칸 위에서 시작한 드래그로는 화면을 스크롤할 수 없는데,
/// 그림판에서는 그게 맞는 동작이다(칸 밖에서 시작하면 그대로 스크롤된다).
class _SignaturePanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawCircle(stroke.first, 1.25, paint..style = PaintingStyle.fill);
          paint.style = PaintingStyle.stroke;
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
