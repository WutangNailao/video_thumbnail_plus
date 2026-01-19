import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List? _thumbnailData;
  String? _thumbnailPath;
  bool _isLoading = false;
  String? _error;

  // Sample video URL for testing
  final String _sampleVideoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  Future<void> _generateThumbnailData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await VideoThumbnailPlus.thumbnailData(
        video: _sampleVideoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        maxHeight: 300,
        timeMs: 1000,
        quality: 75,
      );

      setState(() {
        _thumbnailData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateThumbnailFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final path = await VideoThumbnailPlus.thumbnailFile(
        video: _sampleVideoUrl,
        imageFormat: ImageFormat.PNG,
        maxWidth: 300,
        maxHeight: 300,
        timeMs: 2000,
        quality: 100,
      );

      setState(() {
        _thumbnailPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Video Thumbnail Plus Demo'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sample Video URL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _sampleVideoUrl,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateThumbnailData,
                child: const Text('Generate Thumbnail Data'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _generateThumbnailFile,
                child: const Text('Generate Thumbnail File'),
              ),
              const SizedBox(height: 24),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade100,
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_thumbnailData != null) ...[
                const Text(
                  'Thumbnail from Data:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Image.memory(
                  _thumbnailData!,
                  fit: BoxFit.contain,
                ),
              ],
              if (_thumbnailPath != null) ...[
                const SizedBox(height: 16),
                const Text(
                  'Thumbnail File Path:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _thumbnailPath!,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
