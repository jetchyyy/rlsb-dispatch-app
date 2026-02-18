import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';

/// In-app PDF viewer that downloads the server-generated PDF and renders it.
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  String? _error;
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'e_street_form_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(widget.pdfUrl, filePath);

      if (mounted) {
        setState(() {
          _localPath = filePath;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sharePdf() async {
    if (_localPath == null) return;
    await Share.shareXFiles([XFile(_localPath!)], text: 'E-Street Form PDF');
  }

  Future<void> _savePdf() async {
    if (_localPath == null) return;
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }
      final fileName = 'EStreet_Form_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final destPath = '${downloadsDir.path}/$fileName';
      await File(_localPath!).copy(destPath);

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
        title: const Text('E-Street Form PDF'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_localPath != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePdf,
              tooltip: 'Share',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _savePdf,
              tooltip: 'Save to Downloads',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
            tooltip: 'Open in Browser',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _totalPages > 1
          ? Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Page ${_currentPage + 1} of $_totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Downloading PDF…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _downloadPdf();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _openInBrowser,
                child: const Text('Open in Browser Instead'),
              ),
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) {
        setState(() => _totalPages = pages ?? 0);
      },
      onViewCreated: (_) {},
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        });
      },
      onError: (error) {
        setState(() => _error = error.toString());
      },
    );
  }
}
