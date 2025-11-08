import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';

void main() async {
  // Test the API to see what's available
  final bluetooth = FlutterWebBluetooth.instance;
  
  // This will show us the correct API
  print('Bluetooth instance: $bluetooth');
}