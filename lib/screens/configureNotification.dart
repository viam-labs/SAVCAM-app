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
  final int notificationIndex;
  final Function callback;

  const ConfigureNotificationScreen(
      {super.key, required this.app, required this.notificationConfig, required this.notificationIndex, required this.callback});

  @override
  State<ConfigureNotificationScreen> createState() {
    return _ConfigureNotificationScreenState();
  }
}

class _ConfigureNotificationScreenState extends State<ConfigureNotificationScreen> {
  bool _isLoaded = false;
  final _notificationTypes = ["email", "sms", "webhook_get"];

  @override
  void initState() {
    super.initState();

    if (widget.notificationIndex == -1) {
      // default to sms
      _initType('sms');
    }
    _isLoaded = true;
  }

  _initType(type) {
    setState(() {
      widget.notificationConfig['type'] = type;
    });
  }

  @override
  void dispose() {
    widget.callback(widget.notificationIndex, widget.notificationConfig, []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title:
            const Text("Notification Configuration", style: TextStyle(fontSize: 13)),
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
                      await widget.callback(widget.notificationIndex, widget.notificationConfig, [], true);
                      Navigator.pop(context);
                }),
                if (widget.notificationIndex == -1) // new rule
                  DropdownButton<String>(
                    key: const Key('type'),
                    value: widget.notificationConfig['type'],
                    items: ['sms', 'email', 'webhook_get'].map((String items) {
                      return DropdownMenuItem(
                        value: items,
                        child: Text(items),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _initType(newValue);
                      });
                    }),
                if (widget.notificationConfig['type'] == 'sms')
                  Column( children: [
                    TextFormField(
                      initialValue: widget.notificationConfig['phone'],
                      key: const Key('phone'),
                      decoration: const InputDecoration(labelText: "Phone number"),
                      // The validator receives the text that the user has entered.
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone is required';
                        }
                        return null;
                      },
                      onChanged: (value) => widget.notificationConfig['phone'] = value,
                    ),
                    Row( 
                        children: [
                        const Text("Carrier:"),
                        const SizedBox(width: 20, height: 35),
                        DropdownButton<String>(
                          value: widget.notificationConfig['carrier'],
                          items: ["att", "verizon", "sprint", "tmobile", "boost", "metropcs"].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            widget.notificationConfig['carrier'] = newValue;
                          });
                        },
                        )
                      ])
                  ])
                else if (widget.notificationConfig['type'] == 'webhook_get')
                  Column( children: [
                    TextFormField(
                      initialValue: widget.notificationConfig['url'],
                      key: const Key('url'),
                      decoration: const InputDecoration(labelText: "URL"),
                      // The validator receives the text that the user has entered.
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'URL is required';
                        }
                        return null;
                      },
                      onChanged: (value) => widget.notificationConfig['url'] = value,
                    ),
                  ])
                  else if (widget.notificationConfig['type'] == 'email')
                    Column( children: [
                      TextFormField(
                        initialValue: widget.notificationConfig['address'],
                        key: const Key('address'),
                        decoration: const InputDecoration(labelText: "Email address"),
                        // The validator receives the text that the user has entered.
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email Address is required';
                          }
                          return null;
                        },
                        onChanged:(value) => widget.notificationConfig['address'] = value,
                      ),
                    ])
              ]))
          : const Center(child: Text("Loading...")),
    );
  }
}
