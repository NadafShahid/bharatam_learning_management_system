import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../theme/app_theme.dart';

class PdfViewerScreen extends StatelessWidget {
  final String title;
  final String pdfUrl;
  final Map<String, String> headers;

  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.headers = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.titleMedium),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SfPdfViewer.network(
        pdfUrl,
        headers: headers.isNotEmpty ? headers : null,
        canShowScrollHead: false,
        canShowScrollStatus: false,
      ),
    );
  }
}
