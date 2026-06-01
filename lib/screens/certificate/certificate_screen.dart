import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/gradient_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public Screen
// ─────────────────────────────────────────────────────────────────────────────

class CertificateScreen extends StatefulWidget {
  final String courseName;
  final String userName;
  final DateTime? completedAt;

  const CertificateScreen({
    super.key,
    required this.courseName,
    required this.userName,
    this.completedAt,
  });

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final GlobalKey _certificateKey = GlobalKey();
  bool _isExporting = false;

  DateTime get _completionDate => widget.completedAt ?? DateTime.now();

  Future<void> _downloadCertificate() async {
    if (_isExporting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExporting = true);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final boundary = _certificateKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;

      final safeCourseName = widget.courseName
          .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final fileName = 'Bharatam_Certificate_$safeCourseName.png';
      final file = File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Certificate downloaded: ${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download certificate: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completionDate =
        DateFormat('MMMM dd, yyyy').format(_completionDate);
    final certificateId =
        'BT-${DateFormat('yyyyMMdd').format(_completionDate)}-${widget.userName.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Certificate', style: AppTextStyles.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    duration: const Duration(milliseconds: 700),
                    child: RepaintBoundary(
                      key: _certificateKey,
                      child: _BharatamCertificateTemplate(
                        courseName: widget.courseName,
                        userName: widget.userName,
                        completionDate: completionDate,
                        certificateId: certificateId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 420),
              slideOffset: const Offset(0, 20),
              child: GradientButton(
                text: _isExporting ? 'Downloading...' : 'Download Certificate',
                height: 52,
                borderRadius: AppRadius.pill,
                gradient: AppGradients.primary,
                icon: Icons.download_rounded,
                onPressed: _downloadCertificate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Certificate Template — mirrors the official Bharatam Limited HTML design
// ─────────────────────────────────────────────────────────────────────────────

class _BharatamCertificateTemplate extends StatelessWidget {
  final String courseName;
  final String userName;
  final String completionDate;
  final String certificateId;

  const _BharatamCertificateTemplate({
    required this.courseName,
    required this.userName,
    required this.completionDate,
    required this.certificateId,
  });

  // Design tokens (matching HTML)
  static const _navy = Color(0xFF1A3A5F);
  static const _gold = Color(0xFFB8860B);
  static const _paper = Color(0xFFFAF7EE);
  static const _textDark = Color(0xFF0C1A2B);
  static const _textMid = Color(0xFF444444);
  static const _textLight = Color(0xFF555555);

  @override
  Widget build(BuildContext context) {
    // Landscape A4 aspect ratio: 297 / 210 ≈ 1.414
    return AspectRatio(
      aspectRatio: 297 / 210,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 960),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Padding(
          // 24px padding == wrapper padding in HTML
          padding: const EdgeInsets.all(14),
          child: _OuterBorder(
            child: _InnerBorder(
              child: _CertificateBody(
                userName: userName,
                courseName: courseName,
                completionDate: completionDate,
                certificateId: certificateId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Outer navy double border ──────────────────────────────────────────────────
class _OuterBorder extends StatelessWidget {
  final Widget child;
  const _OuterBorder({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1A3A5F), width: 4),
      ),
      padding: const EdgeInsets.all(5),
      child: child,
    );
  }
}

// ── Inner gold border ─────────────────────────────────────────────────────────
class _InnerBorder extends StatelessWidget {
  final Widget child;
  const _InnerBorder({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB8860B), width: 1.5),
        gradient: const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFAF7EE)],
        ),
      ),
      child: Stack(
        children: [
          // Security watermark
          const Center(child: _WatermarkText()),
          // Corner ornaments
          const _CornerOrnaments(),
          // Main content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Faint "BHARATAM" watermark ────────────────────────────────────────────────
class _WatermarkText extends StatelessWidget {
  const _WatermarkText();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.025,
      child: Center(
        child: Text(
          'BHARATAM',
          style: GoogleFonts.poppins(
            fontSize: 72,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1A3A5F),
            letterSpacing: 12,
          ),
        ),
      ),
    );
  }
}

// ── Corner L-shaped ornaments (gold) ─────────────────────────────────────────
class _CornerOrnaments extends StatelessWidget {
  const _CornerOrnaments();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CornerPainter());
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const edge = 18.0;
    const len = 32.0;

    // Top-left
    canvas.drawLine(
        const Offset(edge, edge), Offset(edge + len, edge), paint);
    canvas.drawLine(
        const Offset(edge, edge), Offset(edge, edge + len), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - edge, edge), Offset(size.width - edge - len, edge), paint);
    canvas.drawLine(
        Offset(size.width - edge, edge), Offset(size.width - edge, edge + len), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(edge, size.height - edge), Offset(edge + len, size.height - edge), paint);
    canvas.drawLine(
        Offset(edge, size.height - edge), Offset(edge, size.height - edge - len), paint);
    // Bottom-right
    canvas.drawLine(
        Offset(size.width - edge, size.height - edge),
        Offset(size.width - edge - len, size.height - edge),
        paint);
    canvas.drawLine(
        Offset(size.width - edge, size.height - edge),
        Offset(size.width - edge, size.height - edge - len),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Main body content ─────────────────────────────────────────────────────────
class _CertificateBody extends StatelessWidget {
  final String userName;
  final String courseName;
  final String completionDate;
  final String certificateId;

  const _CertificateBody({
    required this.userName,
    required this.courseName,
    required this.completionDate,
    required this.certificateId,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        _Header(),
        const SizedBox(height: 8),
        // Gold gradient divider
        Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Color(0xFFB8860B), Colors.transparent],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // ── Title ───────────────────────────────────────────────────────────
        Text(
          'CERTIFICATE OF COMPLETION',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFB8860B),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is to officially certify and record that',
          style: GoogleFonts.lora(
            fontSize: 9,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF444444),
          ),
        ),
        const SizedBox(height: 8),
        // ── Recipient name ───────────────────────────────────────────────────
        _RecipientName(name: userName),
        const SizedBox(height: 8),
        // ── Accomplishment text ──────────────────────────────────────────────
        Text(
          'has successfully completed and fulfilled all evaluation standards for the\nprescribed professional curriculum in technical studies for:',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 8.5,
            color: const Color(0xFF333333),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          courseName.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A3A5F),
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        // ── Footer ───────────────────────────────────────────────────────────
        _Footer(
          certificateId: certificateId,
          completionDate: completionDate,
        ),
      ],
    );
  }
}

// ── Header: Logo + Title + sub-text ──────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chevron logo
        SizedBox(
          width: 68,
          height: 42,
          child: CustomPaint(painter: _ChevronLogoPainter()),
        ),
        const SizedBox(height: 6),
        Text(
          'Bharatam Limited',
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1A3A5F),
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Registered National Training Corporation  •  ISO 9001:2015 Certified',
          style: GoogleFonts.poppins(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: const Color(0xFF444444),
          ),
        ),
      ],
    );
  }
}

// ── Chevron logo (green + orange, matching the HTML SVG paths) ────────────────
class _ChevronLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Green chevron (left)
    final greenPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final greenPath = Path()
      ..moveTo(w * 0.10, h * 0.25)
      ..lineTo(w * 0.35, h * 0.50)
      ..lineTo(w * 0.10, h * 0.75)
      ..lineTo(w * 0.22, h * 0.50)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Orange chevron (right)
    final orangePaint = Paint()
      ..color = const Color(0xFFEF6C00)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final orangePath = Path()
      ..moveTo(w * 0.42, h * 0.08)
      ..lineTo(w * 0.82, h * 0.50)
      ..lineTo(w * 0.42, h * 0.92)
      ..lineTo(w * 0.58, h * 0.50)
      ..close();
    canvas.drawPath(orangePath, orangePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Recipient name with dashed underline ──────────────────────────────────────
class _RecipientName extends StatelessWidget {
  final String name;
  const _RecipientName({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            style: GoogleFonts.playfairDisplay(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C1A2B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Dashed gold underline — mimics border-bottom: 1px dashed #b8860b
        CustomPaint(
          size: const Size(200, 1),
          painter: _DashedLinePainter(color: const Color(0xFFB8860B)),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Footer row: meta | seal | signature ───────────────────────────────────────
class _Footer extends StatelessWidget {
  final String certificateId;
  final String completionDate;

  const _Footer({required this.certificateId, required this.completionDate});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left: meta data
        Expanded(
          child: _MetaData(
            certificateId: certificateId,
            completionDate: completionDate,
          ),
        ),
        // Centre: official seal
        const _OfficialSeal(),
        // Right: signature block
        const Expanded(child: _SignatureBlock()),
      ],
    );
  }
}

class _MetaData extends StatelessWidget {
  final String certificateId;
  final String completionDate;

  const _MetaData(
      {required this.certificateId, required this.completionDate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _metaRow('Certificate ID:', certificateId),
        const SizedBox(height: 3),
        _metaRow('Date of Issue:', completionDate),
        const SizedBox(height: 3),
        _metaRow('Status:', 'Verified Practitioner'),
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(fontSize: 7, color: const Color(0xFF555555)),
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A3A5F),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

// ── Circular official seal (rotated, matching HTML) ───────────────────────────
class _OfficialSeal extends StatelessWidget {
  const _OfficialSeal();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -8 * math.pi / 180, // -8deg
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFEFCF5).withValues(alpha: 0.85),
          border: Border.all(color: const Color(0xFFB8860B), width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '★ BHARATAM LTD ★',
              style: GoogleFonts.poppins(
                fontSize: 5.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFB8860B),
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 32,
              height: 20,
              child: CustomPaint(painter: _ChevronLogoPainter()),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFB8860B), width: 0.8),
                ),
              ),
              child: Text(
                'VERIFIED',
                style: GoogleFonts.poppins(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A3A5F),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Signature block (right side) ──────────────────────────────────────────────
class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Signature line
        Container(
          width: double.infinity,
          height: 1,
          color: const Color(0xFF444444),
        ),
        const SizedBox(height: 5),
        Text(
          'Dr. A. K. Sharma',
          style: GoogleFonts.cinzel(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A3A5F),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'ACADEMIC REGISTRAR',
          style: GoogleFonts.poppins(
            fontSize: 6,
            color: const Color(0xFF666666),
            letterSpacing: 0.8,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
