import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _globalKey = GlobalKey<ScaffoldState>();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  late BluetoothConnection _bluetoothConnection;
  bool bluetoothPermission = false;
  late BluetoothState _bluetoothState;
  int connectionStatus = 0;
  bool loading = true;
  bool actionsVisible = false;

  @override
  void initState() {
    _checkPermission();
    super.initState();
  }

  Future _checkPermission() async {
    var bluetooth = Permission.bluetooth;
    var bluetoothScan = Permission.bluetoothScan;
    var bluetoothConnect = Permission.bluetoothConnect;

    Map<Permission, PermissionStatus> statuses =
        await [bluetooth, bluetoothScan, bluetoothConnect].request();

    if (statuses[bluetooth] == PermissionStatus.granted &&
        statuses[bluetoothScan] == PermissionStatus.granted &&
        statuses[bluetoothConnect] == PermissionStatus.granted) {
      setState(() {
        bluetoothPermission = true;
      });
      _getBluetoothState();
      return;
    }

    if (await bluetooth.shouldShowRequestRationale ||
        await bluetoothScan.shouldShowRequestRationale ||
        await bluetoothConnect.shouldShowRequestRationale) {
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("Permission Required"),
              content: const Text(
                  "Bluetooth Permission Is Required For App To Connect To The Robot"),
              actions: [
                TextButton(
                    onPressed: () async {
                      _checkPermission();
                      if (!mounted) return;
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Grant",
                      style: TextStyle(color: Colors.green),
                    )),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      "Deny",
                      style: TextStyle(color: Colors.red),
                    ))
              ],
            );
          });
      return;
    }
  }

  Future _getBluetoothState() async {
    var state = await _bluetooth.state;
    setState(() {
      _bluetoothState = state;
      loading = false;
    });
  }

  Future _toggleBluetooth() async {
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await _bluetooth.requestEnable();
    } else {
      await _bluetooth.requestDisable();
    }
    await _getBluetoothState();
  }

  Future _initConnect() async {
    setState(() {
      connectionStatus = 1;
    });

    _bluetooth.startDiscovery().listen((event) async {
      log("Device ->>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${event.device.name}");
      var device = event.device;
      var name = event.device.name;
      if (name != null && name == "HC-05") {
        log("Connecting ->>>>>>>>>>>>>>>>>>>>>>>>>>>>> ${device.address}");
        await _bluetooth.cancelDiscovery();
        BluetoothConnection.toAddress(device.address)
            .then((bluetoothConnection) async {
          setState(() {
            _bluetoothConnection = bluetoothConnection;
            connectionStatus = bluetoothConnection.isConnected ? 2 : 0;
          });
        });
      }
    });
  }

  void showRobotActions() {
    var mediaQuery = MediaQuery.of(context);
    _globalKey.currentState?.showBottomSheet(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height - mediaQuery.padding.top - 80,
        ),
        enableDrag: true,
        backgroundColor: const Color.fromRGBO(255, 255, 255, 0.5), (context) {
      return WillPopScope(
        onWillPop: () async {
          setState(() {
            actionsVisible = false;
          });
          return true;
        },
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2),
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () async {
                      _bluetoothConnection.output
                          .add(utf8.encoder.convert(("$index\r\n")));
                      _bluetoothConnection.output.allSent;
                    },
                    child: Card(
                      elevation: 0,
                      color: Colors.transparent,
                      child: Center(
                        child: Text("$index"),
                      ),
                    ),
                  );
                }),
          ),
        ),
      );
    });
    setState(() {
      actionsVisible = true;
    });
  }

  void navBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          backgroundColor: Colors.yellow,
        ),
      );
    }

    if (!bluetoothPermission && !loading) {
      return Container(
        color: Colors.red,
      );
    }

    return StreamBuilder(
        stream: _bluetooth.onStateChanged(),
        initialData: _bluetoothState,
        builder: (context, snapshot) {
          var data = snapshot.data;
          log("Bluetooth State $data");

          if (data == BluetoothState.STATE_OFF) {
            if (actionsVisible) {
              actionsVisible = false;
              navBack();
            }
            connectionStatus = 0;
          }

          return Scaffold(
            key: _globalKey,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              leading: const Icon(
                Icons.bluetooth,
                color: Colors.white,
              ),
              centerTitle: true,
              title: Text(
                data == BluetoothState.STATE_ON && connectionStatus == 2
                    ? "Connected"
                    : data == BluetoothState.STATE_ON
                        ? "Bluetooth ON"
                        : "Bluetooth OFF",
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                Switch(
                    activeColor: Colors.white,
                    inactiveThumbColor: Colors.black,
                    value: data == BluetoothState.STATE_ON,
                    onChanged: (on) {
                      _toggleBluetooth();
                    }),
              ],
            ),
            backgroundColor: Colors.deepPurple,
            body: Center(
              child: Container(
                width: 250,
                height: 250,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.all(Radius.circular(150)),
                ),
                child: connectionStatus != 1
                    ? Column(
                        children: [
                          Image.asset("assets/asset_moonlight.png"),
                          const SizedBox(
                            height: 20,
                          ),
                          connectionStatus == 0
                              ? const Text(
                                  "Not Connected",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 24),
                                )
                              : const Text("Connected")
                        ],
                      )
                    : Stack(
                        children: const [
                          Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: CircularProgressIndicator(
                                color: Colors.yellow,
                              )),
                          Center(
                              child: Text(
                            "Connecting",
                            style: TextStyle(color: Colors.white, fontSize: 24),
                          )),
                        ],
                      ),
              ),
            ),
            floatingActionButton: Visibility(
              visible: data == BluetoothState.STATE_ON,
              child: FloatingActionButton.extended(
                  backgroundColor: Colors.black,
                  onPressed: () {
                    switch (connectionStatus) {
                      case 0:
                        _initConnect();
                        break;
                      case 1:
                        setState(() {
                          connectionStatus = 0;
                        });
                        break;
                      case 2:
                        if (actionsVisible) {
                          navBack();
                          setState(() {
                            actionsVisible = false;
                          });
                        } else {
                          showRobotActions();
                        }
                        break;
                    }
                  },
                  icon: connectionStatus == 0
                      ? const Icon(Icons.power_settings_new_outlined)
                      : connectionStatus == 1 || actionsVisible
                          ? const Icon(Icons.cancel)
                          : const Icon(Icons.settings_remote),
                  elevation: 0,
                  label: connectionStatus == 0
                      ? const Text("Connect")
                      : connectionStatus == 1
                          ? const Text("Cancel")
                          : actionsVisible
                              ? const Text("Close")
                              : const Text("Let's Go")),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          );
        });
  }
}
