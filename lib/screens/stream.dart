import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image/image.dart' as img;
import 'package:viam_sdk/viam_sdk.dart';

class StreamScreen extends StatefulWidget {
  final Camera camera;
  final RobotClient robot;
  final ResourceName resourceName;
  final String title;
  final String dir;
  final Generic eventManager;

  const StreamScreen({super.key, required this.camera, required this.robot, required this.resourceName, required this.title, this.dir="", required this.eventManager});

  @override
  State<StreamScreen> createState() {
    return _StreamScreenState();
  }
}

class _StreamScreenState extends State<StreamScreen> {
  ByteData? imageBytes;
  Timer? timer;
  bool _isLoaded = false;

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

  void _getImage(String name, Camera camera, String? dir) {
    final imageFut = (dir == null) ? camera.image() : camera.image( extra:{"dir": dir});
    imageFut.then((value) {
      try {
        final convertFut = convertImageToFlutterUi(value.image ?? img.Image.empty());
        convertFut.then((value) {
          final pngFut = value.toByteData(format: ui.ImageByteFormat.png);
          pngFut.then((value) => setState(() {
            imageBytes = value;
          }));
        });
      }
      catch (e) {
          print(e);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Future<ByteData> camIconFut;
    camIconFut = rootBundle.load('web/icons/camera.png');
    camIconFut.then((value) async {
      imageBytes = value;
      timer = Timer.periodic(const Duration(milliseconds: 50), (Timer t) => _getImage(widget.resourceName.name, widget.camera, widget.dir));
      setState(() {
        _isLoaded = true;
      });
    });
  }

  @override
  void dispose(){
    timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 13)),
      ),
      iosContentPadding: true,
      body: _isLoaded ? Center(
        child: ListView(
          children: [
            GestureDetector(
                child: Row(children: [
                  if (widget.dir != "") ...[
                    Expanded( child: Align( alignment: Alignment.topRight, child: SizedBox(height: 24, child: Image.asset('web/icons/delete.png')))),
                    const SizedBox(width: 45, height: 25),
                  ]
                  ] ), 
              onTap: () async {
                await widget.eventManager.doCommand({'clear_triggered': {'id': widget.dir}});
                Navigator.pop(context);
              }    
            ), 
            SizedBox(
              height: 400,
              child: Image.memory(Uint8List.view(imageBytes?.buffer ?? ByteData(4).buffer), width: 400, gaplessPlayback: true)
            ), 
          ],
        ),
      ) : const Center(
              child: Text("Loading...")
            ),
    );
  }

  
}
