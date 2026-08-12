import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// ← شاشة قصّ الصورة (بدون مكتبات إضافية — يعمل بجميع الأجهزة)
/// إطار ثابت حسب النسبة (مربع/بانر) مع تحريك + تقريب/تبعيد، ويقصّ الإطار تماماً
/// تُرجع البايتات المقصوصة أو null عند الإلغاء
Future<Uint8List?> cropImage(
  BuildContext context,
  Uint8List bytes, {
  double aspect = 1,
  String title = 'قصّ الصورة ✂️',
}) async {
  return await Navigator.push<Uint8List>(
    context,
    MaterialPageRoute(
      builder: (_) =>
          CropScreen(bytes: bytes, aspectRatio: aspect, title: title),
    ),
  );
}

/// قماش قصّ المرسوم يدوياً: الصورة داخل الإطار + تعتيم الخارج + شبكة الأثلاث
class _CropPainter extends CustomPainter {
  final ui.Image img;
  final Rect frame;
  final double scale;
  final Offset draw;
  final double outK;
  final void Function(Rect src, int outW, int outH) onRegion;
  _CropPainter({
    required this.img,
    required this.frame,
    required this.scale,
    required this.draw,
    required this.outK,
    required this.onRegion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      ((frame.left - draw.dx) / scale).clamp(0, img.width.toDouble()),
      ((frame.top - draw.dy) / scale).clamp(0, img.height.toDouble()),
      (frame.width / scale).clamp(1, img.width.toDouble()),
      (frame.height / scale).clamp(1, img.height.toDouble()),
    );
    onRegion(src, (frame.width * outK).round(), (frame.height * outK).round());

    // الصورة نفسها — مقصوصة على الإطار
    canvas.save();
    canvas.clipRect(frame);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(draw.dx, draw.dy, img.width * scale, img.height * scale),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.restore();

    // تعتيم خارج الإطار
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(10)));
    canvas.drawPath(scrim, Paint()..color = Colors.black.withOpacity(0.62));

    // حدّ الإطار
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(10));
    canvas.drawRRect(rrect, border);

    // شبكة الأثلاث
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withOpacity(0.35);
    for (final t in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(frame.left + frame.width * t, frame.top),
        Offset(frame.left + frame.width * t, frame.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(frame.left, frame.top + frame.height * t),
        Offset(frame.right, frame.top + frame.height * t),
        grid,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.img != img ||
      old.frame != frame ||
      old.scale != scale ||
      old.draw != draw;
}

class CropScreen extends StatefulWidget {
  final Uint8List bytes;
  final double aspectRatio; // نسبة العرض للطول (1 = مربع، 16/9 = بانر)
  final String title;
  const CropScreen({
    super.key,
    required this.bytes,
    this.aspectRatio = 1,
    this.title = 'قصّ الصورة ✂️',
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _img;
  bool _loaded = false;
  double _scale = 1; // تكبير البداية = يغطر الإطار بالكامل
  Offset _pan = Offset.zero;
  double _startScale = 1;
  double _outK = 2; // دقة الحفظ (أضعاف مقاس الإطار)
  Rect _lastSrc = Rect.zero;
  Size _lastOut = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final comp = await ui.instantiateImageCodec(widget.bytes);
      final frame = await comp.getNextFrame();
      setState(() {
        _img = frame.image;
        _loaded = true;
      });
    } catch (_) {}
  }

  /// إطار القصّ: نسبة ثابتة، موسّط بحدود الشاشة
  Rect _frame(Size view) {
    final pad = 18.0;
    var w = view.width - pad * 2;
    var h = w / widget.aspectRatio;
    if (h > view.height - pad * 2) {
      h = view.height - pad * 2;
      w = h * widget.aspectRatio;
    }
    return Rect.fromCenter(
      center: Offset(view.width / 2, view.height / 2),
      width: w,
      height: h,
    );
  }

  Future<Uint8List?> _save() async {
    final img = _img!;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImageRect(
      img,
      _lastSrc,
      Rect.fromLTWH(0, 0, _lastOut.width, _lastOut.height),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = rec.endRecording();
    final bi = await picture.toImage(
      _lastOut.width.toInt(),
      _lastOut.height.toInt(),
    );
    final by = await bi.toByteData(format: ui.ImageByteFormat.png);
    return by?.buffer.asUint8List();
  }

  void _clampPan(Size view) {
    final img = _img!;
    final frame = _frame(view);
    final base = math.max(frame.width / img.width, frame.height / img.height);
    final s = base * _scale;
    final dw = img.width * s, dh = img.height * s;
    final maxX = math.max(0.0, (dw - frame.width) / 2),
        maxY = math.max(0.0, (dh - frame.height) / 2);
    _pan = Offset(_pan.dx.clamp(-maxX, maxX), _pan.dy.clamp(-maxY, maxY));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          if (!_loaded)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            LayoutBuilder(
              builder: (_, cons) {
                final view = Size(cons.maxWidth, cons.maxHeight);
                final img = _img!;
                final frame = _frame(view);
                final base = math.max(
                  frame.width / img.width,
                  frame.height / img.height,
                );
                final s = base * _scale;
                final dx = frame.center.dx - (img.width * s) / 2 + _pan.dx;
                final dy = frame.center.dy - (img.height * s) / 2 + _pan.dy;
                return Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onScaleStart: (d) {
                          _startScale = _scale;
                        },
                        onScaleUpdate: (d) {
                          setState(() {
                            _scale = (_startScale * d.scale).clamp(1.0, 5.0);
                            _pan += Offset(
                              d.focalPointDelta.dx,
                              d.focalPointDelta.dy,
                            );
                          });
                        },
                        onScaleEnd: (_) => setState(() => _clampPan(view)),
                        onDoubleTap: () => setState(() {
                          _scale = _scale > 1.4 ? 1 : 2.5;
                          _clampPan(view);
                        }),
                        child: CustomPaint(
                          size: view,
                          painter: _CropPainter(
                            img: img,
                            frame: frame,
                            scale: s,
                            draw: Offset(dx, dy),
                            outK: _outK,
                            onRegion: (src, ow, oh) {
                              _lastSrc = src;
                              _lastOut = Size(ow.toDouble(), oh.toDouble());
                            },
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                              ),
                              onPressed: () => setState(() {
                                _scale = 1;
                                _pan = Offset.zero;
                              }),
                              child: const Text('إعادة'),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: () => setState(() {
                                _scale = (_scale * 0.78).clamp(1.0, 5.0);
                                _clampPan(view);
                              }),
                              icon: const Icon(
                                Icons.zoom_out_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'تصغير',
                            ),
                            IconButton.outlined(
                              onPressed: () => setState(() {
                                _scale = (_scale * 1.28).clamp(1.0, 5.0);
                                _clampPan(view);
                              }),
                              icon: const Icon(
                                Icons.zoom_in_rounded,
                                color: Colors.white,
                              ),
                              tooltip: 'تقريب',
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () async {
                                final out = await _save();
                                if (out != null && mounted)
                                  Navigator.pop(context, out);
                              },
                              child: const Text('قصّ ✓'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
