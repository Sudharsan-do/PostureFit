// main.dart - Main application file
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(PostureFitApp());
}

class PostureFitApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostureFit',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? postureCharacteristic;
  BluetoothCharacteristic? batteryCharacteristic;
  
  bool isConnected = false;
  bool isScanning = false;
  int batteryLevel = 0;
  String currentPostureStatus = "Unknown";
  double postureDeviation = 0.0;
  
  List<PostureData> postureHistory = [];
  Timer? dataCollectionTimer;
  
  TabController? _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadPostureHistory();
    initBluetooth();
  }
  
  @override
  void dispose() {
    _tabController?.dispose();
    dataCollectionTimer?.cancel();
    super.dispose();
  }
  
  void loadPostureHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('postureHistory');
    if (historyJson != null) {
      List<dynamic> historyList = jsonDecode(historyJson);
      setState(() {
        postureHistory = historyList
            .map((item) => PostureData.fromJson(item))
            .toList();
      });
    }
  }
  
  void savePostureHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> historyList = 
        postureHistory.map((data) => data.toJson()).toList();
    await prefs.setString('postureHistory', jsonEncode(historyList));
  }
  
  void initBluetooth() {
    // Listen for scan results
    flutterBlue.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.name == 'PostureFit') {
          stopScan();
          connectToDevice(result.device);
          break;
        }
      }
    });
  }
  
  void startScan() {
    setState(() {
      isScanning = true;
    });
    flutterBlue.startScan(timeout: Duration(seconds: 10));
  }
  
  void stopScan() {
    setState(() {
      isScanning = false;
    });
    flutterBlue.stopScan();
  }
  
  void connectToDevice(BluetoothDevice device) async {
    setState(() {
      targetDevice = device;
    });
    
    await device.connect();
    
    setState(() {
      isConnected = true;
    });
    
    discoverServices();
  }
  
  void discoverServices() async {
    if (targetDevice == null) return;
    
    List<BluetoothService> services = await targetDevice!.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == '4fafc201-1fb5-459e-8fcc-c5c9c331914b') {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == 'beb5483e-36e1-4688-b7f5-ea07361b26a8') {
            postureCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            characteristic.value.listen(onPostureData);
          } else if (characteristic.uuid.toString() == 'e12267d8-24f3-41d5-a742-c48fdbf8f661') {
            batteryCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            characteristic.value.listen(onBatteryData);
          }
        }
      }
    }
    
    // Start collecting data periodically for history
    dataCollectionTimer = Timer.periodic(Duration(minutes: 15), (timer) {
      if (isConnected && postureDeviation > 0) {
        PostureData newData = PostureData(
          timestamp: DateTime.now(),
          deviation: postureDeviation,
        );
        setState(() {
          postureHistory.add(newData);
        });
        savePostureHistory();
      }
    });
  }
  
  void onPostureData(List<int> data) {
    String dataString = String.fromCharCodes(data);
    List<String> values = dataString.split(',');
    
    if (values.length >= 4) {
      setState(() {
        postureDeviation = double.parse(values[3]);
        if (postureDeviation > 15) {
          currentPostureStatus = "Bad Posture";
        } else if (postureDeviation > 8) {
          currentPostureStatus = "Moderate Posture";
        } else {
          currentPostureStatus = "Good Posture";
        }
      });
    }
  }
  
  void onBatteryData(List<int> data) {
    String dataString = String.fromCharCodes(data);
    setState(() {
      batteryLevel = int.parse(dataString);
    });
  }
  
  void disconnectDevice() async {
    if (targetDevice != null) {
      await targetDevice!.disconnect();
      setState(() {
        isConnected = false;
        targetDevice = null;
      });
    }
    dataCollectionTimer?.cancel();
  }
  
  void calibrateDevice() async {
    if (postureCharacteristic != null) {
      await postureCharacteristic!.write([1]); // Send calibration command
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration started. Please maintain good posture for 3 seconds.')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PostureFit'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.home), text: 'Dashboard'),
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.fitness_center), text: 'Exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildHistoryTab(),
          _buildExercisesTab(),
        ],
      ),
      floatingActionButton: !isConnected
          ? FloatingActionButton(
              onPressed: startScan,
              child: Icon(isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
              tooltip: isScanning ? 'Scanning...' : 'Connect Device',
            )
          : FloatingActionButton(
              onPressed: calibrateDevice,
              child: Icon(Icons.refresh),
              tooltip: 'Calibrate Device',
            ),
    );
  }
  
  Widget _buildDashboardTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Device Status:', style: TextStyle(fontSize: 18)),
                      Text(isConnected ? 'Connected' : 'Disconnected', 
                           style: TextStyle(
                             fontSize: 18, 
                             fontWeight: FontWeight.bold,
                             color: isConnected ? Colors.green : Colors.red,
                           )),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Battery Level:', style: TextStyle(fontSize: 18)),
                      Text('$batteryLevel%', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                  SizedBox(height: 12),
                  isConnected
                      ? ElevatedButton(
                          onPressed: disconnectDevice,
                          child: Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            primary: Colors.red,
                          ),
                        )
                      : Container(),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          isConnected
              ? Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Current Posture', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        SizedBox(height: 16),
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentPostureStatus == "Good Posture"
                                  ? Colors.green
                                  : currentPostureStatus == "Moderate Posture"
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                            child: Center(
                              child: Text(
                                currentPostureStatus,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text('Posture Deviation: ${postureDeviation.toStringAsFixed(2)}°',
                            style: TextStyle(fontSize: 16)),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: postureDeviation / 30.0, // Max deviation around 30
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            postureDeviation < 8
                                ? Colors.green
                                : postureDeviation < 15
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    'Connect your PostureFit device to start monitoring',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
        ],
      ),
    );
  }
  
  Widget _buildHistoryTab() {
    if (postureHistory.isEmpty) {
      return Center(
        child: Text('No posture history available yet'),
      );
    }
    
    List<charts.Series<PostureData, DateTime>> seriesList = [
      charts.Series<PostureData, DateTime>(
        id: 'Posture',
        colorFn: (PostureData data, _) => data.deviation < 8
            ? charts.MaterialPalette.green.shadeDefault
            : data.deviation < 15
                ? charts.MaterialPalette.yellow.shadeDefault
                : charts.MaterialPalette.red.shadeDefault,
        domainFn: (PostureData data, _) => data.timestamp,
        measureFn: (PostureData data, _) => data.deviation,
        data: postureHistory,
      )
    ];
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posture History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: charts.TimeSeriesChart(
              seriesList,
              animate: true,
              dateTimeFactory: const charts.LocalDateTimeFactory(),
              defaultRenderer: charts.LineRendererConfig(includePoints: true),
              domainAxis: charts.DateTimeAxisSpec(
                renderSpec: charts.SmallTickRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                    fontSize: 12,
                    color: charts.MaterialPalette.black,
                  ),
                ),
              ),
              primaryMeasureAxis: charts.NumericAxisSpec(
                tickProviderSpec: charts.BasicNumericTickProviderSpec(desiredTickCount: 5),
                renderSpec: charts.GridlineRendererSpec(
                  labelStyle: charts.TextStyleSpec(
                    fontSize: 12,
                    color: charts.MaterialPalette.black,
                  ),
                  lineStyle: charts.LineStyleSpec(
                    color: charts.MaterialPalette.gray.shadeDefault,
                  ),
                ),
              ),
              behaviors: [
                charts.ChartTitle('Date',
                    behaviorPosition: charts.BehaviorPosition.bottom,
                    titleStyleSpec: charts.TextStyleSpec(fontSize: 14)),
                charts.ChartTitle('Posture Deviation (°)',
                    behaviorPosition: charts.BehaviorPosition.start,
                    titleStyleSpec: charts.TextStyleSpec(fontSize: 14)),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text('Posture Summary:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          _buildPostureSummary(),
        ],
      ),
    );
  }
  
  Widget _buildPostureSummary() {
    int goodPostureCount = postureHistory.where((data) => data.deviation < 8).length;
    int moderatePostureCount = postureHistory.where((data) => data.deviation >= 8 && data.deviation < 15).length;
    int badPostureCount = postureHistory.where((data) => data.deviation >= 15).length;
    
    return Column(
      children: [
        Row(
          children: [
            Container(width: 20, height: 20, color: Colors.green),
            SizedBox(width: 8),
            Text('Good Posture: $goodPostureCount times'),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Container(width: 20, height: 20, color: Colors.orange),
            SizedBox(width: 8),
            Text('Moderate Posture: $moderatePostureCount times'),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Container(width: 20, height: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('Bad Posture: $badPostureCount times'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildExercisesTab() {
    List<ExerciseData> exercises = [
      ExerciseData(
        name: 'Chin Tucks',
        description: 'Sit or stand with your shoulders rolled back. Slowly draw your head back, creating a "double chin". Hold for 5 seconds and repeat 10 times.',
        imageAsset: 'assets/chin_tuck.png',
        duration: '5 minutes',
        focus: 'Neck',
      ),
      ExerciseData(
        name: 'Shoulder Blade Squeezes',
        description: 'Sit or stand with your arms at your sides. Squeeze your shoulder blades together as if trying to hold a pencil between them. Hold for 5 seconds, then release. Repeat 10 times.',
        imageAsset: 'assets/shoulder_squeeze.png',
        duration: '5 minutes',
        focus: 'Upper Back',
      ),
      ExerciseData(
        name: 'Wall Angels',
        description: 'Stand with your back against a wall, feet shoulder-width apart. Place your arms against the wall, elbows bent at 90 degrees. Slowly slide your arms up and down the wall, maintaining contact. Repeat 10 times.',
        imageAsset: 'assets/wall_angels.png',
        duration: '7 minutes',
        focus: 'Shoulders & Upper Back',
      ),
      ExerciseData(
        name: 'Thoracic Extension',
        description: 'Sit on a chair with your hands behind your head. Gently arch backward, looking up toward the ceiling. Hold for 5 seconds, then return to starting position. Repeat 10 times.',
        imageAsset: 'assets/thoracic_extension.png',
        duration: '5 minutes',
        focus: 'Mid Back',
      ),
      ExerciseData(
        name: 'Pectoral Stretch',
        description: 'Stand in a doorway with your arms on the doorframe at shoulder height. Gently lean forward until you feel a stretch in your chest. Hold for 20-30 seconds. Repeat 3 times.',
        imageAsset: 'assets/pectoral_stretch.png',
        duration: '3 minutes',
        focus: 'Chest',
      ),
    ];
    
    return ListView.builder(
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(exercises[index].name),
            subtitle: Text('Duration: ${exercises[index].duration} | Focus: ${exercises[index].focus}'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey[300],
                        child: Center(
                          child: Text('Exercise Image\n(Placeholder)', textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(exercises[index].description),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Start exercise guidance
                      },
                      child: Text('Start Exercise'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
