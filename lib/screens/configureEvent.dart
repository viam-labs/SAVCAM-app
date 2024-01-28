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

class ConfigureEventScreen extends StatefulWidget {
  final Viam app;
  final Map eventConfig;
  final int eventIndex;
  final Map components;
  final Map services;
  final Function callback;

  const ConfigureEventScreen(
      {super.key, required this.callback, required this.app, required this.components, required this.services, required this.eventConfig, required this.eventIndex});

  @override
  State<ConfigureEventScreen> createState() {
    return _ConfigureEventScreenState();
  }
}

class _ConfigureEventScreenState extends State<ConfigureEventScreen> {
  bool _isLoaded = false;
  final _logicTypes = ["AND", "OR", "XOR", "NOR", "NAND", "XNOR"];
  String _logicType = "AND";
  List<bool> _modesState = [false, false];

  Timer? timer;

  void _setModeState(String mode) {
    setState(() {
      var modes = [];
      if (mode == 'home') {
        _modesState[0] = !_modesState[0];
        if (_modesState[0]) {
          modes.add('home');
        }
      } else {
        _modesState[1] = !_modesState[1];
        if (_modesState[1]) {
          modes.add('away');
        }
      }
      widget.eventConfig['modes'] = modes;
    });
  }

  @override
  void initState() {
    super.initState();
    _modesState[0] = widget.eventConfig['modes'].contains('home');
    _modesState[1] = widget.eventConfig['modes'].contains('away');
    _isLoaded = true;
  }

  @override
  void dispose() {
    widget.callback(widget.eventIndex, widget.eventConfig);
    super.dispose();
  }

  ruleCallback(int index, Map updatedRule, [delete=false]) {
    if (delete) {
      widget.eventConfig['rules'].removeAt(index);
    }
    else {
      widget.eventConfig['rules'][index] = updatedRule;
    }
    
    widget.callback(widget.eventIndex, widget.eventConfig);
  }

  notificationCallback(int index, Map updatedNotification, [delete=false]) {
    if (delete) {
      widget.eventConfig['notifications'].removeAt(index);
    }
    else {
      widget.eventConfig['notifications'][index] = updatedNotification;
    }
    
    widget.callback(widget.eventIndex, widget.eventConfig);
  }

  Widget? _getConfigureRule(int index, Map config) {
    return ConfigureRuleScreen(app: widget.app, components: widget.components, services: widget.services, ruleConfig: config, ruleIndex: index, callback: ruleCallback);
  }
  
  Widget? _getConfigureNotification(int index, Map config) {
    return ConfigureNotificationScreen(app: widget.app, notificationConfig: config, notificationIndex: index, callback: notificationCallback);
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title:
            const Text("Event Configuration", style: TextStyle(fontSize: 13)),
      ),
      iosContentPadding: true,
      body: _isLoaded
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 30),
              physics: const ScrollPhysics(),
              child: Column(children: <Widget>[
                GestureDetector(
                    child: Row(children: [
                      Expanded(
                          child: Align(
                              alignment: Alignment.topRight,
                              child: SizedBox(
                                  height: 24,
                                  child: Image.asset('web/icons/delete.png')))),
                      const SizedBox(width: 25, height: 25),
                    ]),
                    onTap: () async {
                      await widget.callback(widget.eventIndex, widget.eventConfig, true);
                      Navigator.pop(context);
                    }),
                TextFormField(
                  initialValue: widget.eventConfig['name'],
                  key: const Key('name'),
                  decoration: const InputDecoration(labelText: "Event Name"),
                  // The validator receives the text that the user has entered.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                  onChanged: (value) => widget.eventConfig['name'] = value,
                ),
                const SizedBox(height: 25),
                Row(children: [
                  const Text("Active Modes:"),
                  const SizedBox(width: 20, height: 35),
                  ToggleButtons(
                    direction: Axis.horizontal,
                    onPressed: (int index) {
                      _setModeState(index == 0 ? 'home' : 'away');
                    },
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    selectedBorderColor: Colors.blue[700],
                    selectedColor: Colors.white,
                    fillColor: Colors.blue[200],
                    color: Colors.blue[400],
                    constraints: const BoxConstraints(
                      minHeight: 20.0,
                      minWidth: 80.0,
                    ),
                    isSelected: _modesState,
                    children: const [Text('Home'), Text('Away')],
                  )
                ]),
                TextFormField(
                  initialValue:
                      widget.eventConfig['debounce_interval_secs'].toString(),
                  key: const Key('debounce_interval_secs'),
                  decoration: const InputDecoration(
                      labelText: "Debounce Interval (seconds)"),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Debounce interval is required';
                    }
                    return null;
                  },
                  onChanged: (value) => widget.eventConfig['debounce_interval_secs'] = int.parse(value),
                ),
                Row(children: [
                  const Text("Rule Logic Type:"),
                  const SizedBox(width: 40, height: 35),
                  DropdownButton<String>(
                      key: const Key('rule_logic_type'),
                      value: _logicType,
                      items: _logicTypes.map((String items) {
                        return DropdownMenuItem(
                          value: items,
                          child: Text(items),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _logicType = newValue!;
                        });
                        widget.eventConfig['rule_logic_type'] = newValue;
                      }),
                ]),
                const SizedBox(height: 15),
                const Row(children: [
                  Expanded(
                      child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                              child:
                                  Text("Rules:", textAlign: TextAlign.left))))
                ]),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: widget.eventConfig['rules'].length,
                  itemBuilder: (context, index) {
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(width: 5, height: 5),
                          GestureDetector(
                            child: const SizedBox(
                              height: 10,
                            ),
                            onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureRule(index, widget.eventConfig['rules'][index])!)),
                          ),
                          PlatformListTile(
                            title: Text(widget.eventConfig['rules'][index]['type'] +
                                        " " +
                                        (widget.eventConfig['rules'][index]['type'] == 'time'
                                ? ''
                                : " - " + widget.eventConfig['rules'][index]['class_regex'])),
                            trailing: Icon(context.platformIcons.rightChevron),
                            onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureRule(index, widget.eventConfig['rules'][index])!)),
                          ),
                          const Divider(height: 0, indent: 0, endIndent: 0)
                        ]);
                  },
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 15),
                const Row(children: [
                  Expanded(
                      child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                              child:
                                  Text("Notifications:", textAlign: TextAlign.left))))
                ]),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: widget.eventConfig['notifications'].length,
                  itemBuilder: (context, index) {
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(width: 5, height: 5),
                          GestureDetector(
                            child: const SizedBox(
                              height: 10,
                            ),
                            onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureNotification(index, widget.eventConfig['notifications'][index])!)),
                          ),
                          PlatformListTile(
                            title: Text(widget.eventConfig['notifications'][index]['type'] +
                                        " " +
                                        (widget.eventConfig['notifications'][index]['type'] == 'sms'
                                ?  " - " + widget.eventConfig['notifications'][index]['phone']
                                : (widget.eventConfig['notifications'][index]['type'] == 'webhook_get' ? " - " + widget.eventConfig['notifications'][index]['url'] : " - " + widget.eventConfig['notifications'][index]['address'])),
                                            overflow: TextOverflow.ellipsis,

                                ),
                            trailing: Icon(context.platformIcons.rightChevron),
                            onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureNotification(index, widget.eventConfig['notifications'][index])!)),
                          ),
                          const Divider(height: 0, indent: 0, endIndent: 0)
                        ]);
                  },
                  padding: EdgeInsets.zero,
                ),
              ]))
          : const Center(child: Text("Loading...")),
    );
  }
}
