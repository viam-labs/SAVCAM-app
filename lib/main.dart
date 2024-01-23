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
  final Map<String,ResourceName> _resourceNameStrings = {};
  final List<Map> _Triggered = [];
  late RobotClient _robot;
  late Viam _app;

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

    void _getImage(String name, Camera camera, String? dir) {
      final imageFut = (dir == null) ? camera.image() : camera.image( extra:{"dir": dir});
      imageFut.then((value) {
        try {
          final convertFut = convertImageToFlutterUi(value.image ?? img.Image.empty());
          convertFut.then((value) {
            final pngFut = value.toByteData(format: ui.ImageByteFormat.png);
            pngFut.then((value) => setState(() {
              _imageData[name] = value;
            }));
          });
        }
        catch (e) {
            print(e);
        }
      });
    }

    void _getTriggered(em) {
      final triggeredFut = em.doCommand({"get_triggered": {"number": 5}});
      triggeredFut.then((value) {
        _Triggered.clear();
        for (Map triggered in value["triggered"]) {
          final cam = Camera.fromRobot(_robot, dotenv.env['DIR_CAM']!);
          final commandFut = cam.doCommand({'set': {'dir': triggered["id"], 'index_reset': true, 'index_jog': -1}});
          commandFut.then((value) {
            _getImage(triggered["id"], Camera.fromRobot(_robot, dotenv.env['DIR_CAM']!), triggered["id"]);
          });
          _Triggered.add(triggered);
        }
      });
    }
    
    Future<Viam> appFut;
    Future<RobotClient> robotFut;

    if (dotenv.env['ROBOT_LOCATION'] != null && dotenv.env['API_KEY'] != null) {
      robotFut = RobotClient.atAddress(
        dotenv.env['ROBOT_LOCATION'] ?? '', // or whatever default value you want
        RobotClientOptions.withApiKey(
          dotenv.env['API_KEY_ID'] ?? '',
          dotenv.env['API_KEY'] ?? '',
        )..dialOptions.attemptMdns=false,
      );

      appFut = Viam.withApiKey(dotenv.env['API_KEY_ID']!, dotenv.env['API_KEY']!);
    } else {
      throw Exception('None of the required variables are defined in .env. Please see README.md for more information.');
    }

    appFut.then((value) async {
      _app = value;
    });

    robotFut.then((value) async {
      _robot = value;
      final cameras = _robot.resourceNames.where((element) => element.subtype == Camera.subtype.resourceSubtype);
      final defaultCamIcon = await rootBundle.load('web/icons/camera.png');
      for (ResourceName c in cameras) {
        _imageData[c.name] = defaultCamIcon;
        timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) => _getImage(c.name, Camera.fromRobot(_robot, c.name), null));
      }
    
      // default to "event-manager"
      final eventManagers = _robot.resourceNames.where((element) => (element.name == dotenv.env['EVENT-MANAGER']) || (element.name == "event-manager"));
      final eventManager = eventManagers.firstOrNull;
      if (eventManager != null) { 
        final em = Generic.fromRobot(_robot, eventManager.name);
        timer = Timer.periodic(const Duration(seconds: 2), (Timer t) => _getTriggered(em));
      }

      setState(() {
        _loggedIn = true;
        _loading = false;
        _resourceNames.addAll(cameras);
        _resourceNames.forEach((n) => _resourceNameStrings[n.name] = n);
      });
    });
  }

  Widget? _getConfiguredAlerts() {
    return ConfiguredAlertsScreen(app: _app, partId: dotenv.env['PART_ID'] ?? '');
  }

  Widget? _getStream(ResourceName rname, String title, [String dir=""]) {
    if (rname.subtype == Camera.subtype.resourceSubtype) {
      return StreamScreen(camera: Camera.fromRobot(_robot, rname.name), robot: _robot, resourceName: rname, title: title, dir: dir);
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
                const SizedBox(width: 5, height: 15),
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
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(resourceName, "${resourceName.name} live stream")!)),
                        ),
                        PlatformListTile(
                          title: Text(resourceName.name),
                          trailing: Icon(context.platformIcons.rightChevron),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(resourceName, "${resourceName.name} live stream")!)),
                        ),
                        const Divider(height: 0, indent: 0, endIndent: 0)
                    ]);
                  },
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 5, height: 25),
                GestureDetector(
                  child: Row(children: [
                    const SizedBox(width: 5, height: 5),
                    const Text('Triggered Alerts', textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    SizedBox(height: 20, child: Image.asset('web/icons/gear.png')),
                  ]
                  ),
                  onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfiguredAlerts()!)),
                ),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _Triggered.length,
                  itemBuilder: (context, index) {
                    final triggered = _Triggered[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 5, height: 5),
                        GestureDetector( 
                          child: SizedBox(
                            height: 80,
                            child: Image.memory(Uint8List.view(_imageData[triggered['id']]?.buffer ?? ByteData.sublistView(Uint8List(4)).buffer), width: 150, gaplessPlayback: true)
                          ),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(_resourceNameStrings[dotenv.env['DIR_CAM']]!, "Alert Replay: ${triggered['event']} (${triggered["camera"]}) ${DateTime.fromMillisecondsSinceEpoch(int.parse(triggered['time'])*1000).toIso8601String()}", triggered['id'])!)),
                        ),
                        PlatformListTile(
                          title: Text(triggered['event'] + " (" + triggered["camera"] + ")"),
                          subtitle: Text(DateTime.fromMillisecondsSinceEpoch(int.parse(triggered['time'])*1000).toIso8601String()),
                          trailing: Icon(context.platformIcons.rightChevron),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(_resourceNameStrings[dotenv.env['DIR_CAM']]!, "Alert Replay: ${triggered['event']} (${triggered["camera"]}) ${DateTime.fromMillisecondsSinceEpoch(int.parse(triggered['time'])*1000).toIso8601String()}", triggered['id'])!)),
                        ),
                        const Divider(height: 0, indent: 0, endIndent: 0)
                    ]);
                  },
                  padding: EdgeInsets.zero,
                ),
              ] 
          )
        )
          : const Center(
              child: Text("Authenticating...")
            ),
    );
  }
}
