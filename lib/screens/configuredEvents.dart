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
  List emDeps;
  final Function callback;

  ConfiguredEventsScreen({super.key, required this.callback, required this.app, required this.components, required this.services, required this.emAttributes, required this.emDeps});

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

  configureEventCallback(int index, Map updatedEvent, List updatedDeps, [delete=false]) {
    if (delete) {
      if(index == -1) { return; }
      widget.emAttributes['events'].removeAt(index);
    }
    else {
      if(index == -1) {
        if (! widget.emAttributes.containsKey('events')) {
          widget.emAttributes['events'] = [];
        }
        widget.emAttributes['events'].add(updatedEvent);
        index = widget.emAttributes['events'].length - 1;
      } else {
        widget.emAttributes['events'][index] = updatedEvent;
      }
      // Add deps by merging lists.
      // Note that we do not currently handle removing deps if an event is deleted.
      widget.emDeps = {...updatedDeps, ...widget.emDeps}.toList();
    }
    widget.callback(widget.emAttributes, widget.emDeps);
    Future.delayed(Duration.zero, () => setState(() { }));
    return index;
  }

  Widget? _getConfigureEvent(int index, Map eventConfig) {
    return ConfigureEventScreen(callback: configureEventCallback, app: widget.app, components: widget.components, services: widget.services, eventConfig: eventConfig, eventIndex: index);
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
                onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureEvent(-1, <String,dynamic>{})!))),

                widget.emAttributes.containsKey('events') ?
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
                            onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureEvent(index, widget.emAttributes['events'][index])!)),
                          ),
                          PlatformListTile(
                            title: Text(widget.emAttributes['events'][index]['name']),
                            trailing: Icon(context.platformIcons.rightChevron),
                            onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureEvent(index, widget.emAttributes['events'][index])!)),
                          ),
                          const Divider(height: 0, indent: 0, endIndent: 0)
                      ]);
                    },
                    padding: EdgeInsets.zero,
                  ) 
                  :
                  const Text('No configured events')
              ] 
          )
        )
          : const Center(
              child: Text("Loading...")
            ),
    );
  }

  
}
