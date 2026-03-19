import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus.dart';
import 'package:video_thumbnail_plus/video_thumbnail_plus_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelVideoThumbnailPlus platform = MethodChannelVideoThumbnailPlus();
  const MethodChannel channel =
      MethodChannel('world.nailao.flutter.plugin/video_thumbnail_plus');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'file') {
          return '/path/to/thumbnail.png';
        } else if (methodCall.method == 'data') {
          return Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('thumbnailFile returns file path', () async {
    final result = await platform.thumbnailFile(
      video: 'test.mp4',
      imageFormat: ImageFormat.PNG,
    );
    expect(result, '/path/to/thumbnail.png');
  });

  test('thumbnailData returns bytes', () async {
    final result = await platform.thumbnailData(
      video: 'test.mp4',
      imageFormat: ImageFormat.PNG,
    );
    expect(result, isNotNull);
    expect(result!.length, 4);
  });
}
