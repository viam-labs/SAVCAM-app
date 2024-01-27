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

void main() async {
  await dotenv.load();
}

class ConfigureRuleScreen extends StatefulWidget {
  final Viam app;
  final Map components;
  final Map services;
  final Map ruleConfig;
  const ConfigureRuleScreen(
      {super.key, required this.app, required this.components, required this.services, required this.ruleConfig});

  @override
  State<ConfigureRuleScreen> createState() {
    return _ConfigureRuleScreenState();
  }
}

class _ConfigureRuleScreenState extends State<ConfigureRuleScreen> {
  bool _isLoaded = false;
  final _ruleTypes = ["detection", "classification", "time"];
  String _ruleType = "detection";
  int _selectedConfidence = 50;
  List _cameras = [];
  List<bool> _camerasState = [];
  List _visions = [];
  List<bool> _visionsState = [];

  void _setCameraState(int index) {
    setState(() {
      _camerasState[index] = !_camerasState[index];    
    });
  }
  void _setVisionsState(int index) {
    setState(() {
      for (int i = 0; i < _visionsState.length; i++) {
        _visionsState[i] = (i == index) ? true : false;
      } 
    });
  }

  @override
  void initState() {
    super.initState();
    widget.components.forEach((key, value) {
      if ((value['type'] == 'camera') && (value['name'] != dotenv.env['DIR_CAM'])) {
        _cameras.add(key);
        if ((widget.ruleConfig['type'] != 'time') && (widget.ruleConfig['cameras'].indexOf(key) != -1)) {
          _camerasState.add(true);
        } else {
          _camerasState.add(false);
        }
      }
    });
    widget.services.forEach((key, value) {
      if (value['type'] == 'vision') {
        _visions.add(key);
        if ((widget.ruleConfig['type'] == 'detection' && widget.ruleConfig['detector'] == key) 
          || (widget.ruleConfig['type'] == 'classification' && widget.ruleConfig['classifier'] == key)) {
          _visionsState.add(true);
        } else {
          _visionsState.add(false);
        }
      }
    });

    if (widget.ruleConfig['type'] != 'time') {
      _selectedConfidence = (widget.ruleConfig['confidence_pct'] * 100).toInt();
    }

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
            const Text("Rule Configuration", style: TextStyle(fontSize: 13)),
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
                (widget.ruleConfig['type'] == 'time') ? 
                  Column( children: [
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: widget.ruleConfig['ranges'].length,
                      itemBuilder: (context, index) {
                        return Row( 
                          children: [
                          const Text("Start hour:"),
                          const SizedBox(width: 20, height: 35),
                          DropdownButton<int>(
                          value: widget.ruleConfig['ranges'][index]['start_hour'].toInt(),
                          items: List.generate(25, (index) => index).map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          );
                        }).toList(),
                        onChanged: (int? newValue) {
                        setState(() {
                          widget.ruleConfig['ranges'][index]['start_hour'] = newValue;
                            });
                          },
                        ), 
                        const Text("End hour:"),
                        const SizedBox(width: 20, height: 35),
                        DropdownButton<int>(
                        value: widget.ruleConfig['ranges'][index]['end_hour'].toInt(),
                        items: List.generate(25, (index) => index).map<DropdownMenuItem<int>>((int value) {
                          return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                      setState(() {
                        widget.ruleConfig['ranges'][index]['end_hour'] = newValue;
                          });
                        },
                        ),
                        const SizedBox(width: 10), 
                        if (index != 0) GestureDetector(
                          child:
                         SizedBox(
                                      height: 24,
                                      child: Image.asset('web/icons/minus24.png')),
                          onTap: () async {
                              setState(() {
                                widget.ruleConfig['ranges'].removeAt(index);
                              });
                          }),
                        ]
                      );
                      },
                      padding: EdgeInsets.zero,
                    ),
                    GestureDetector(
                    child:
                    Row(children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.bottomLeft,
                            child: SizedBox(
                                height: 32,
                                child: Image.asset('web/icons/plus.png')))),
                    const SizedBox(width: 25),
                    ]),
                    onTap: () async {
                          setState(() {
                          widget.ruleConfig['ranges'].add({'start_hour': 0, 'end_hour': 0});
                        });
                    }),
                  ])
                : 
                Column( children: [
                    Row(children: [
                      (widget.ruleConfig['type'] == 'detection') ? const Text("Detector:") : const Text("Classifier:"),
                      const SizedBox(width: 20, height: 35),
                      ToggleButtons(
                        direction: Axis.horizontal,
                        onPressed: (int index) {
                          _setVisionsState(index);
                        },
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        selectedBorderColor: Colors.blue[700],
                        selectedColor: Colors.white,
                        fillColor: Colors.blue[200],
                        color: Colors.blue[400],
                        constraints: const BoxConstraints(
                          minHeight: 25.0,
                          minWidth: 80.0,
                        ),
                        isSelected: _visionsState,
                        children: _visions.map((label) => Text(label)).toList(),
                      )
                    ]),
                    TextFormField(
                      initialValue: widget.ruleConfig['class_regex'],
                      key: const Key('class_regex'),
                      decoration: const InputDecoration(labelText: "Class match regex"),
                      // The validator receives the text that the user has entered.
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Class regex is required';
                        }
                        return null;
                      },
                    ),
                    Row( 
                      children: [
                      const Text("Confidence percent:"),
                      const SizedBox(width: 20, height: 35),
                      DropdownButton<int>(
                      value: _selectedConfidence,
                      items: List.generate(100, (index) => index + 1).map<DropdownMenuItem<int>>((int value) {
                        return DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                    setState(() {
                      _selectedConfidence = newValue!;
                        });
                      },
                    ), 
                    ]
                  ),
                  Row(children: [
                  const Text("Cameras:"),
                  const SizedBox(width: 20, height: 35),
                  ToggleButtons(
                    direction: Axis.horizontal,
                    onPressed: (int index) {
                      _setCameraState(index);
                    },
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    selectedBorderColor: Colors.blue[700],
                    selectedColor: Colors.white,
                    fillColor: Colors.blue[200],
                    color: Colors.blue[400],
                    constraints: const BoxConstraints(
                      minHeight: 25.0,
                      minWidth: 80.0,
                    ),
                    isSelected: _camerasState,
                    children: _cameras.map((label) => Text(label)).toList(),
                  )
                ])
                ]),
              ]))
          : const Center(child: Text("Loading...")),
    );
  }
}
