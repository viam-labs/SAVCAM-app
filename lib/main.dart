import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:viam_sdk/protos/app/app.dart';
import 'package:viam_sdk/protos/component/generic.dart';
import 'package:viam_sdk/viam_sdk.dart';
import 'package:viam_sdk/src/utils.dart';
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
  final List<ResourceName> _cameraNames = [];
  final Map<String,ResourceName> _cameraNameStrings = {};
  final List<Map> _Triggered = [];
  late RobotClient _robot;
  late Viam _app;
  late Generic _eventManager;
  late RobotPart Part;
  late Map PartComponentMap = {};
  late Map PartServiceMap = {};
  List<bool> ModeState = [true, false];

  Timer? timer;

  void _setModeState(String mode, [bool save=false]) {
      if (mode == 'away') {
        ModeState = [false, true];
      } else {
        ModeState = [true, false];
      }
      PartComponentMap[dotenv.env['EVENT_MANAGER']]['attributes']['mode'] = mode;
      if(save) {
        _saveConfig();
      }
  }

  void _saveConfig() {
    var robotConfig = Part.robotConfig.toMap();
    List componentList = PartComponentMap.entries.map( (component) => component.value).toList();
    robotConfig['components'] = componentList;
    var setRobotConfig = robotConfig.toStruct();
    _app.appClient.updateRobotPart(dotenv.env['PART_ID']!, Part.name, setRobotConfig);
    Part.robotConfig = setRobotConfig;
  }

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
        final cam = Camera.fromRobot(_robot, dotenv.env['DIR_CAM']!);
        _Triggered.clear();
        for (Map triggered in value["triggered"]) {
            _getImage(triggered["id"], cam, triggered["id"]);
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
      Future<RobotPart> partFut;
      partFut = _app.appClient.getRobotPart(dotenv.env['PART_ID']!);
      partFut.then((part) async {
        Part = part;
        var components = part.robotConfig.fields['components']!.toPrimitive();
        var index = 0;
        components.forEach((component) {
          PartComponentMap[component['name']] = component;
          index = index + 1;
        });
        var services = part.robotConfig.fields['services']!.toPrimitive();
        index = 0;
        services.forEach((service) {
          PartServiceMap[service['name']] = service;
          index = index + 1;
        });
        _setModeState(PartComponentMap[dotenv.env['EVENT_MANAGER']]['attributes']['mode']);
      });
    });

    robotFut.then((value) async {
      _robot = value;
      final cameras = _robot.resourceNames.where((element)  {_cameraNameStrings[element.name] = element; return (element.subtype == Camera.subtype.resourceSubtype) && (element.name != dotenv.env['DIR_CAM']);});
      final defaultCamIcon = await rootBundle.load('web/icons/camera.png');
      for (ResourceName c in cameras) {
        _imageData[c.name] = defaultCamIcon;
        timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) => _getImage(c.name, Camera.fromRobot(_robot, c.name), null));
      }
    
      // default to "event-manager"
      final eventManagers = _robot.resourceNames.where((element) => (element.name == dotenv.env['EVENT_MANAGER']) || (element.name == "event-manager"));
      final eventManager = eventManagers.firstOrNull;
      if (eventManager != null) { 
        _eventManager =  Generic.fromRobot(_robot, eventManager.name);
        timer = Timer.periodic(const Duration(milliseconds: 500), (Timer t) => _getTriggered(_eventManager));
      }

      setState(() {
        _loggedIn = true;
        _loading = false;
        _cameraNames.addAll(cameras);
      });
    });
  }

  configuredEventsCallback(Map emAttributes) {
    PartComponentMap[dotenv.env['EVENT_MANAGER']]['attributes'] = emAttributes;
    _saveConfig();
  }

  Widget? _getConfiguredEvents() {
    return ConfiguredEventsScreen(callback: configuredEventsCallback, app: _app, components: PartComponentMap, services: PartServiceMap, emAttributes: PartComponentMap[dotenv.env['EVENT_MANAGER']]['attributes']);
  }

  Widget? _getStream(ResourceName rname, String title, [String dir=""]) {
    return StreamScreen(camera: Camera.fromRobot(_robot, rname.name), robot: _robot, resourceName: rname, title: title, dir: dir, eventManager: _eventManager);
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
                ToggleButtons(
                  direction: Axis.horizontal,
                onPressed: (int index) {
                  _setModeState(index == 0 ? 'home' : 'away', true);
                },
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                selectedBorderColor: Colors.blue[700],
                selectedColor: Colors.white,
                fillColor: Colors.blue[200],
                color: Colors.blue[400],
                constraints: const BoxConstraints(
                  minHeight: 40.0,
                  minWidth: 80.0,
                ),
                isSelected: ModeState,
                children: const [
                  Text('Home'),
                  Text('Away')
                ],
              ),
                GestureDetector(
                  child: const Row(children: [
                    SizedBox(width: 5, height: 5),
                    Text('Cameras', textAlign: TextAlign.start, style: TextStyle(fontSize:24, fontWeight: FontWeight.bold)),
                  ]
                  ),
                  onTap: () {
                    
                  }     
                ),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _cameraNames.length,
                  itemBuilder: (context, index) {
                    final resourceName = _cameraNames[index];
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
                    const Text('Alerts', textAlign: TextAlign.start, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    SizedBox(height: 24, child: Image.asset('web/icons/gear.png')),
                  ]
                  ),
                  onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfiguredEvents()!)),
                ),
                _Triggered.isNotEmpty ? ListView.builder(
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
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(_cameraNameStrings[dotenv.env['DIR_CAM']]!, "Alert Replay: ${triggered['event']} (${triggered["camera"]}) ${DateTime.fromMillisecondsSinceEpoch(int.parse(triggered['time'])*1000).toIso8601String()}", triggered['id'])!)),
                        ),
                        PlatformListTile(
                          title: Text(triggered['event'] + " (" + triggered["camera"] + ")"),
                          subtitle: Text(DateTime.fromMillisecondsSinceEpoch(int.parse(triggered['time'])*1000).toIso8601String()),
                          trailing: Icon(context.platformIcons.rightChevron),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(_cameraNameStrings[dotenv.env['DIR_CAM']]!, "Alert Replay: ${triggered['event']} (${triggered["camera"]}) ${DateTime.fromMillisecondsSinceEpoch(int.parse(triggered['time'])*1000).toIso8601String()}", triggered['id'])!)),
                        ),
                        const Divider(height: 0, indent: 0, endIndent: 0)
                    ]);
                  },
                  padding: EdgeInsets.zero,
                ) : const Text("No triggered events"),
              ] 
          )
        )
          : const Center(
              child: Text("Authenticating...")
            ),
    );
  }
}
