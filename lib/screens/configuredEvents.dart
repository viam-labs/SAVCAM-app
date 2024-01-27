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
import 'screens.dart';

class ConfiguredEventsScreen extends StatefulWidget {
  final Viam app;
  final Map components;
  final Map services;
  final Map emAttributes;
  const ConfiguredEventsScreen({super.key, required this.app, required this.components, required this.services, required this.emAttributes});

  @override
  State<ConfiguredEventsScreen> createState() {
    return _ConfiguredEventsScreenState();
  }
}

class _ConfiguredEventsScreenState extends State<ConfiguredEventsScreen> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _isLoaded = true;
  }
  
  @override
  void dispose(){
    super.dispose();
  }
  Widget? _getConfigureEvent(Map eventConfig) {
    return ConfigureEventScreen(app: widget.app, components: widget.components, services: widget.services, eventConfig: eventConfig);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: const Text("Event Configuration", style: TextStyle(fontSize: 13)),
      ),
      iosContentPadding: true,
      body: _isLoaded
          ? SingleChildScrollView(
              physics: const ScrollPhysics(),
              child: Column( children: <Widget>[
              const SizedBox(height: 25),
              GestureDetector(
                child: Row(children: [
                  Expanded(
                      child: Align(
                          alignment: Alignment.topRight,
                          child: SizedBox(
                              height: 32,
                              child: Image.asset('web/icons/plus.png')))),
                  const SizedBox(width: 25),
                ]),
                onTap: () async {
                  //await widget.eventManager.doCommand({'clear_triggered': {'id': widget.dir}});
                  Navigator.pop(context);
                }),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: widget.emAttributes['events'].length,
                  itemBuilder: (context, index) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 5, height: 5),
                        GestureDetector( 
                          child: const SizedBox(
                            height: 80,
                          ),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureEvent(widget.emAttributes['events'][index])!)),
                        ),
                        PlatformListTile(
                          title: Text(widget.emAttributes['events'][index]['name']),
                          trailing: Icon(context.platformIcons.rightChevron),
                          onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureEvent(widget.emAttributes['events'][index])!)),
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
