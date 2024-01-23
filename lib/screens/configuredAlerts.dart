import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:image/image.dart' as img;
import 'package:viam_sdk/src/gen/app/v1/app.pb.dart';
import 'package:viam_sdk/viam_sdk.dart';

class ConfiguredAlertsScreen extends StatefulWidget {
  final Viam app;
  final String partId;
  const ConfiguredAlertsScreen({super.key, required this.app, required this.partId});

  @override
  State<ConfiguredAlertsScreen> createState() {
    return _ConfiguredAlertsScreenState();
  }
}

class _ConfiguredAlertsScreenState extends State<ConfiguredAlertsScreen> {
  bool _isLoaded = false;
  final List<ResourceName> _alertNames = [];
  late Object _partConfig;

  @override
  void initState() {
    super.initState();
    final partFut = getPart();
    partFut.then((part) async {
      print(part.robotConfig.toString());
      _isLoaded = true;
    });
  }

  Future<RobotPart> getPart() async {
    final part = await widget.app.appClient.getRobotPart(widget.partId);
    return part;
  }

  @override
  void dispose(){
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text("Configured Alerts", style: TextStyle(fontSize: 13)),
      ),
      iosContentPadding: true,
      body: _isLoaded
          ? SingleChildScrollView(
              physics: const ScrollPhysics(),
              child: Column( children: <Widget>[
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _alertNames.length,
                  itemBuilder: (context, index) {
                    final resourceName = _alertNames[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 5, height: 5),
                        GestureDetector( 
                          child: const SizedBox(
                            height: 80,
                          ),
                          //onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(resourceName, "${resourceName.name} live stream")!)),
                        ),
                        PlatformListTile(
                          title: Text(resourceName.name),
                          trailing: Icon(context.platformIcons.rightChevron),
                          //onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getStream(resourceName, "${resourceName.name} live stream")!)),
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
              child: Text("Loading...")
            ),
    );
  }

  
}
