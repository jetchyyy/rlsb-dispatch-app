import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';

/// In-app PDF viewer for locally generated PDF files.
class FilePdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const FilePdfViewerScreen({
    super.key,
    required this.filePath,
    this.title = 'E-Street Form PDF',
  });

  @override
  State<FilePdfViewerScreen> createState() => _FilePdfViewerScreenState();
}

class _FilePdfViewerScreenState extends State<FilePdfViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;

  Future<void> _openInBrowser() async {
    final uri = Uri.file(widget.filePath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sharePdf() async {
    await Share.shareXFiles([XFile(widget.filePath)], text: widget.title);
  }

  Future<void> _savePdf() async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }
      final fileName = 'EStreet_Form_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final destPath = '${downloadsDir.path}/$fileName';
      await File(widget.filePath).copy(destPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads/$fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePdf,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _savePdf,
            tooltip: 'Save to Downloads',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Open in External App',
          ),
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: File(widget.filePath).existsSync()
          ? PDFView(
              filePath: widget.filePath,
              autoSpacing: true,
              enableSwipe: true,
              pageSnap: true,
              swipeHorizontal: false,
              nightMode: false,
              onRender: (pages) {
                setState(() => _totalPages = pages ?? 0);
              },
              onPageChanged: (page, total) {
                setState(() => _currentPage = page ?? 0);
              },
              onError: (error) {
                debugPrint('PDF render error: $error');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error rendering PDF: $error'),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text('PDF file not found'),
                  const SizedBox(height: 8),
                  Text(
                    widget.filePath,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
