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
                      child: BharatamCertificateTemplate(
                        courseName: widget.courseName,
                        userName: widget.userName,
                        completionDate: completionDate,
                        certificateId: certificateId,
                        isPortrait: true,
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

class BharatamCertificateTemplate extends StatelessWidget {
  final String courseName;
  final String userName;
  final String completionDate;
  final String certificateId;
  final bool isPortrait;

  const BharatamCertificateTemplate({
    super.key,
    required this.courseName,
    required this.userName,
    required this.completionDate,
    required this.certificateId,
    this.isPortrait = false,
  });

  @override
  Widget build(BuildContext context) {
    final double canvasWidth = isPortrait ? 800 : 1131;
    final double canvasHeight = isPortrait ? 1131 : 800;

    return AspectRatio(
      aspectRatio: isPortrait ? (210 / 297) : (297 / 210),
      child: Container(
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
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: _OuterBorder(
              child: _InnerBorder(
                child: _CertificateBody(
                  userName: userName,
                  courseName: courseName,
                  completionDate: completionDate,
                  certificateId: certificateId,
                  isPortrait: isPortrait,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OuterBorder extends StatelessWidget {
  final Widget child;
  const _OuterBorder({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Color(0xFFE0E0E0),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF0D2C54), width: 4),
          color: const Color(0xFFFAF7F0),
        ),
        child: child,
      ),
    );
  }
}

class _InnerBorder extends StatelessWidget {
  final Widget child;
  const _InnerBorder({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC5A059), width: 2),
        gradient: const RadialGradient(
          colors: [Color(0x80FFFFFF), Color(0x66F2EEE3)],
          radius: 1.5,
        ),
      ),
      child: Stack(
        children: [
          const Center(child: _WatermarkImage()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _WatermarkImage extends StatelessWidget {
  const _WatermarkImage();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.04,
      child: Center(
        child: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/2/20/Simple_Map_of_India.svg',
          width: 500,
          height: 500,
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        ),
      ),
    );
  }
}

class _CertificateBody extends StatelessWidget {
  final String userName;
  final String courseName;
  final String completionDate;
  final String certificateId;
  final bool isPortrait;

  const _CertificateBody({
    required this.userName,
    required this.courseName,
    required this.completionDate,
    required this.certificateId,
    this.isPortrait = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Header(),
        SizedBox(height: isPortrait ? 40 : 30),
        Text(
          'CERTIFICATE OF COMPLETION',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: isPortrait ? 34 : 38,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFC5A059),
            letterSpacing: 4,
            shadows: [
              const Shadow(
                color: Color(0x1A000000),
                offset: Offset(0.5, 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text(
          'This is to officially certify and record that',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF444444),
          ),
        ),
        SizedBox(height: isPortrait ? 25 : 20),
        _RecipientName(name: userName),
        SizedBox(height: isPortrait ? 30 : 25),
        Text(
          'has successfully completed and fulfilled all evaluation standards for the\nprescribed professional curriculum in technical studies for:',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            color: const Color(0xFF555555),
            height: 1.8,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 15),
        Text(
          courseName.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D2C54),
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        _Footer(
          certificateId: certificateId,
          completionDate: completionDate,
          isPortrait: isPortrait,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CustomPaint(painter: _ChevronPainter(color: const Color(0xFF137547), isLeft: true)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 36,
              child: CustomPaint(painter: _ChevronPainter(color: const Color(0xFFF26419), isLeft: false)),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          'BHARATAM LIMITED',
          style: GoogleFonts.montserrat(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D2C54),
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'REGISTERED NATIONAL TRAINING CORPORATION • ISO 9001:2015 CERTIFIED',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: const Color(0xFF555555),
          ),
        ),
      ],
    );
  }
}

class _ChevronPainter extends CustomPainter {
  final Color color;
  final bool isLeft;
  const _ChevronPainter({required this.color, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    if (isLeft) {
      path.lineTo(size.width * 0.3, size.height / 2);
    } else {
      path.lineTo(size.width * 0.25, size.height / 2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

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
               fontSize: 42,
               fontWeight: FontWeight.w700,
               color: const Color(0xFF0D2C54),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CustomPaint(
          size: const Size(400, 2),
          painter: _DashedLinePainter(color: const Color(0xFFC5A059)),
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
      ..strokeWidth = 2;
    const dashWidth = 8.0;
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

class _Footer extends StatelessWidget {
  final String certificateId;
  final String completionDate;
  final bool isPortrait;

  const _Footer({required this.certificateId, required this.completionDate, this.isPortrait = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(child: _SignatureBlock()),
          const _OfficialSeal(),
          Expanded(
            child: _MetaData(
              certificateId: certificateId,
              completionDate: completionDate,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -5 * math.pi / 180,
          child: Text(
            'Sign',
            style: GoogleFonts.monsieurLaDoulaise(
              fontSize: 44,
              color: const Color(0xFF333333),
              height: 1,
            ),
          ),
        ),
        Container(
          width: 160,
          height: 1,
          color: const Color(0xFFA3A3A3),
        ),
        const SizedBox(height: 8),
        Text(
          'AUTHORIZED SIGNATORY',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF666666),
            letterSpacing: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OfficialSeal extends StatelessWidget {
  const _OfficialSeal();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: const Color(0xFF0D2C54), width: 3),
        boxShadow: const [
           BoxShadow(color: Color(0xFFFAF7F0), spreadRadius: -4, blurRadius: 0),
           BoxShadow(color: Color(0xFFC5A059), spreadRadius: -6, blurRadius: 0),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'BHARATAM\nLIMITED',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D2C54),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.6,
                    child: SizedBox(
                      width: 12,
                      height: 14,
                      child: CustomPaint(painter: _ChevronPainter(color: const Color(0xFFC5A059), isLeft: false)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 16,
                    height: 18,
                    child: CustomPaint(painter: _ChevronPainter(color: const Color(0xFFC5A059), isLeft: false)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'OFFICIAL SEAL',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D2C54),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
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
        RichText(
          text: TextSpan(
            style: GoogleFonts.montserrat(fontSize: 11, color: const Color(0xFF444444), height: 1.8),
            children: [
              const TextSpan(
                text: 'Certificate ID: ',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222222)),
              ),
              TextSpan(text: certificateId),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Date of Issue: ',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF222222),
              ),
            ),
            Container(
              width: 80,
              height: 14,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF888888))),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  completionDate,
                  style: GoogleFonts.montserrat(fontSize: 10, color: const Color(0xFF444444)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
