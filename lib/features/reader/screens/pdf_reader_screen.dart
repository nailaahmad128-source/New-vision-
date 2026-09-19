import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/document_item.dart';

class PdfReaderScreen extends StatefulWidget {
  final DocumentItem doc;
  const PdfReaderScreen({super.key, required this.doc});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  late final PdfViewerController _controller;
  bool _chromeVisible = true;
  int _currentPage = 1;
  int _pageCount = 0;
  bool _jumpedToLastPage = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  void _toggleChrome() => setState(() => _chromeVisible = !_chromeVisible);

  @override
  Widget build(BuildContext context) {
    final data = context.read<AppDataController>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _chromeVisible
          ? AppBar(
              title: Text(
                widget.doc.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: () => Share.shareXFiles([XFile(widget.doc.filePath)]),
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleChrome,
        child: Stack(
          children: [
            SfPdfViewer.file(
              File(widget.doc.filePath),
              controller: _controller,
              canShowScrollHead: _chromeVisible,
              canShowScrollStatus: _chromeVisible,
              enableTextSelection: true,
              pageLayoutMode: PdfPageLayoutMode.continuous,
              scrollDirection: PdfScrollDirection.vertical,
              onDocumentLoaded: (details) {
                if (!mounted) return;
                setState(() => _pageCount = details.document.pages.count);
                final saved = data.readerLastPage(widget.doc.id);
                if (saved != null && saved > 1 && saved <= _pageCount && !_jumpedToLastPage) {
                  _jumpedToLastPage = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _controller.jumpToPage(saved);
                  });
                }
              },
              onPageChanged: (details) {
                setState(() => _currentPage = details.newPageNumber);
                data.setReaderLastPage(widget.doc.id, details.newPageNumber);
              },
            ),
            if (_chromeVisible && _pageCount > 0)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                        onPressed: _currentPage > 1 ? () => _controller.previousPage() : null,
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentPage.toDouble().clamp(1, _pageCount.toDouble()),
                          min: 1,
                          max: _pageCount.toDouble(),
                          divisions: _pageCount > 1 ? _pageCount - 1 : 1,
                          label: '$_currentPage / $_pageCount',
                          onChanged: (v) => _controller.jumpToPage(v.round()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        onPressed: _currentPage < _pageCount ? () => _controller.nextPage() : null,
                      ),
                      Text('$_currentPage/$_pageCount',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
