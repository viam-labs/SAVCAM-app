import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image/image.dart' as img;
import 'package:viam_sdk/viam_sdk.dart';
import 'package:viam_sdk/widgets.dart';

class StreamScreen extends StatefulWidget {
  final Camera camera;
  final RobotClient robot;
  final ResourceName resourceName;
  const StreamScreen({super.key, required this.camera, required this.robot, required this.resourceName});

  @override
  State<StreamScreen> createState() {
    return _StreamScreenState();
  }
}

class _StreamScreenState extends State<StreamScreen> {
  // Single frame
  ByteData? imageBytes;
  bool _imgLoaded = false;

  void _getImage() {
    setState(() {
      _imgLoaded = false;
    });
    final imageFut = widget.camera.image();
    imageFut.then((value) {
      final convertFut = convertImageToFlutterUi(value.image ?? img.Image.empty());
      convertFut.then((value) {
        final pngFut = value.toByteData(format: ui.ImageByteFormat.png);
        pngFut.then((value) => setState(() {
              imageBytes = value;
              _imgLoaded = true;
            }));
      });
    });
  }

  Future<ui.Image> convertImageToFlutterUi(img.Image image) async {
    if (image.format != img.Format.uint8 || image.numChannels != 4) {
      final cmd = img.Command()
        ..image(image)
        ..convert(format: img.Format.uint8, numChannels: 4);
      final rgba8 = await cmd.getImageThread();
      if (rgba8 != null) {
        image = rgba8;
      }
    }

    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(image.toUint8List());

    final ui.ImageDescriptor id =
        ui.ImageDescriptor.raw(buffer, height: image.height, width: image.width, pixelFormat: ui.PixelFormat.rgba8888);

    final ui.Codec codec = await id.instantiateCodec(targetHeight: image.height, targetWidth: image.width);

    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image uiImage = fi.image;

    return uiImage;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.resourceName.name.toUpperCase()),
      ),
      iosContentPadding: true,
      body: Center(
        child: ListView(
          children: [
            ViamCameraStreamView(camera: widget.camera, streamClient: widget.robot.getStream(widget.resourceName.name)),
      
          ],
        ),
      ),
    );
  }
}
