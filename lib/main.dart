import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:viam_sdk/protos/component/generic.dart';
import 'package:viam_sdk/viam_sdk.dart';
import 'package:viam_sdk/widgets.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

import 'screens/screens.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final materialTheme = ThemeData(
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: Color(0xff127EFB),
      ),
      primarySwatch: Colors.green,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(const EdgeInsets.all(16.0)),
          foregroundColor: MaterialStateProperty.all(const Color(0xFF3DDC84)),
        ),
      ),
    );

    return Theme(
      data: materialTheme,
      child: PlatformProvider(
        settings: PlatformSettingsData(
          iosUsesMaterialWidgets: true,
          iosUseZeroPaddingForAppbarPlatformIcon: true,
        ),
        builder: (context) => PlatformApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
          ],
          title: 'SAVCAM',
          home: const MyHomePage(
            title: 'SAVCAM',
          ),
          material: (_, __) => MaterialAppData(
            theme: materialTheme,
          ),
          cupertino: (_, __) => CupertinoAppData(
            theme: const CupertinoThemeData(
              brightness: Brightness.light,
              primaryColor: Color(0xff127EFB),
            ),
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _loggedIn = false;
  bool _loading = false;
  final Map<String,ByteData?> _imageData = {};
  final List<ResourceName> _resourceNames = [];
  late RobotClient _robot;
  Timer? timer;

  // automatically login with credentials from .env
  @override
  void initState() {
      super.initState();
      _login();
  }

  void _login() {
    if (_loading) {
      return;
    }
    if (_loggedIn) {
      return;
    }

    setState(() {
      _loading = true;
    });

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

    void _getImage(name, camera) {
      final imageFut = camera.image();
      imageFut.then((value) {
        try {
          final convertFut = convertImageToFlutterUi(value.image ?? img.Image.empty());
          convertFut.then((value) {
            final pngFut = value.toByteData(format: ui.ImageByteFormat.png);
            pngFut.then((value) => setState(() {
              _imageData[name] = value;
              print("Got image");
            }));
          });
        }
        catch (e) {
            print(e);
        }
      });
    }
    
    Future<RobotClient> robotFut;

    if (dotenv.env['ROBOT_LOCATION'] != null && dotenv.env['LOCATION_SECRET'] != null) {
      robotFut = RobotClient.atAddress(
        dotenv.env['ROBOT_LOCATION'] ?? '',
        RobotClientOptions.withLocationSecret(dotenv.env['LOCATION_SECRET'] ?? ''),
      );
    } else if (dotenv.env['API_KEY_ID'] != null && dotenv.env['API_KEY'] != null) {
      robotFut = RobotClient.atAddress(
        dotenv.env['ROBOT_LOCATION'] ?? '', // or whatever default value you want
        RobotClientOptions.withApiKey(
          dotenv.env['API_KEY_ID'] ?? '',
          dotenv.env['API_KEY'] ?? '',
        )..dialOptions.attemptMdns=false,
      );
    } else {
      throw Exception('None of the required variables are defined in .env. Please see README.md for more information.');
    }

    robotFut.then((value) async {
      _robot = value;
      final cameras = _robot.resourceNames.where((element) => element.subtype == Camera.subtype.resourceSubtype);
      final defaultCamIcon = await rootBundle.load('web/icons/camera.png');
      for (ResourceName c in cameras) {
        _imageData[c.name] = defaultCamIcon;
        timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getImage(c.name, Camera.fromRobot(_robot, c.name)));
      }
    
      // default to "event-manager"
      final eventManagers = _robot.resourceNames.where((element) => (element.name == dotenv.env['EVENT-MANAGER']) || (element.name == "event-manager"));
      final eventManager = eventManagers.firstOrNull;
      if (eventManager != null) { 
        final em = Generic.fromRobot(_robot, eventManager.name);
        final alertFut = em.doCommand({"get_triggered": {"number": 5}});
        alertFut.then((value) {
          print(value);
        });
      }

      setState(() {
        _loggedIn = true;
        _loading = false;
        _resourceNames.addAll(cameras);
      });
    });
  }

  StreamClient _getStream(ResourceName name) {
    return _robot.getStream(name.name);
  }

  Widget? _getScreen(ResourceName rname) {
    if (rname.subtype == Camera.subtype.resourceSubtype) {
      return StreamScreen(camera: Camera.fromRobot(_robot, rname.name), robot: _robot, resourceName: rname);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.title),
      ),
      iosContentPadding: true,
      body: _loggedIn
          ? SingleChildScrollView(
              physics: const ScrollPhysics(),
              child: Column( children: <Widget>[
                GestureDetector(
                  child: Row(children: [
                    const SizedBox(width: 5, height: 5),
                    const Text('Cameras', textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    SizedBox(height: 20, child: Image.asset('web/icons/gear.png'))
                  ]
                  ),
                  onTap: () {
                    
                  }     
                ),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _resourceNames.length,
                  itemBuilder: (context, index) {
                    final resourceName = _resourceNames[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 5, height: 5),
                        GestureDetector( 
                          child: SizedBox(
                            height: 80,
                            child: Image.memory(Uint8List.view(_imageData[resourceName.name]!.buffer), width: 150, gaplessPlayback: true)
                          ),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getScreen(resourceName)!)),
                        ),
                        PlatformListTile(
                          title: Text(resourceName.name),
                          trailing: Icon(context.platformIcons.rightChevron),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getScreen(resourceName)!)),
                        ),
                        const Divider(height: 0, indent: 0, endIndent: 0)
                    ]);
                  },
                  padding: EdgeInsets.zero,
            )] ))
          : const Center(
              child: Text("Authenticating...")
            ),
    );
  }
}
