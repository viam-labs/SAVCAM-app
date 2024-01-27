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

class ConfigureNotificationScreen extends StatefulWidget {
  final Viam app;
  final Map notificationConfig;
  const ConfigureNotificationScreen(
      {super.key, required this.app, required this.notificationConfig});

  @override
  State<ConfigureNotificationScreen> createState() {
    return _ConfigureNotificationScreenState();
  }
}

class _ConfigureNotificationScreenState extends State<ConfigureNotificationScreen> {
  bool _isLoaded = false;
  final _logicTypes = ["AND", "OR", "XOR", "NOR", "NAND", "XNOR"];
  String _logicType = "AND";
  List<bool> _modesState = [false, false];

  Timer? timer;

  void _setModeState(String mode) {
    print(mode);
    if (mode == 'home') {
      _modesState[0] = !_modesState[0];
    } else {
      _modesState[1] = !_modesState[1];
    }
    print(_modesState);
  }

  @override
  void initState() {
    super.initState();
    _modesState[0] = widget.notificationConfig['modes'].contains('home');
    _modesState[1] = widget.notificationConfig['modes'].contains('away');
    _isLoaded = true;
  }

  @override
  void dispose() {
    super.dispose();
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
                      //await widget.eventManager.doCommand({'clear_triggered': {'id': widget.dir}});
                      Navigator.pop(context);
                    }),
                TextFormField(
                  initialValue: widget.notificationConfig['name'],
                  key: const Key('name'),
                  decoration: const InputDecoration(labelText: "Event Name"),
                  // The validator receives the text that the user has entered.
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
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
                      widget.notificationConfig['debounce_interval_secs'].toString(),
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
                  itemCount: widget.notificationConfig['rules'].length,
                  itemBuilder: (context, index) {
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(width: 5, height: 5),
                          GestureDetector(
                            child: const SizedBox(
                              height: 10,
                            ),
                            //onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureRule(widget.notificationConfig['rules'][index])!)),
                          ),
                          PlatformListTile(
                            title: Text(widget.notificationConfig['rules'][index]['type'] +
                                        " " +
                                        (widget.notificationConfig['rules'][index]['type'] == 'time'
                                ? ''
                                : " - " + widget.notificationConfig['rules'][index]['class_regex'])),
                            trailing: Icon(context.platformIcons.rightChevron),
                            //onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureRule(widget.notificationConfig['rules'][index])!)),
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
                  itemCount: widget.notificationConfig['notifications'].length,
                  itemBuilder: (context, index) {
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(width: 5, height: 5),
                          GestureDetector(
                            child: const SizedBox(
                              height: 10,
                            ),
                            //onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureNotification(widget.notificationConfig['notifications'][index])!)),
                          ),
                          PlatformListTile(
                            title: Text(widget.notificationConfig['notifications'][index]['type'] +
                                        " " +
                                        (widget.notificationConfig['notifications'][index]['type'] == 'sms'
                                ?  " - " + widget.notificationConfig['notifications'][index]['phone']
                                : (widget.notificationConfig['notifications'][index]['type'] == 'webhook_get' ? " - " + widget.notificationConfig['notifications'][index]['url'] : " - " + widget.notificationConfig['notifications'][index]['address'])),
                                            overflow: TextOverflow.ellipsis,

                                ),
                            trailing: Icon(context.platformIcons.rightChevron),
                            //onTap: () => Navigator.push(context, platformPageRoute(context: context, builder: (context) => _getConfigureNotification(widget.notificationConfig['notifications'][index])!)),
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
