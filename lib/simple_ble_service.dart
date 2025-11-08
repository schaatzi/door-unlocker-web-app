import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';
import 'dart:typed_data';

class SimpleBLEService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  bool _isConnected = false;
  
  bool get isConnected => _isConnected;
  String get deviceName => _device?.name ?? 'Unknown Device';
  
  Future<bool> connectToAnyDevice() async {
    try {
      print('🔍 Requesting Bluetooth device...');
      
      // Use RequestOptionsBuilder.acceptAllDevices() directly
      _device = await FlutterWebBluetooth.instance.requestDevice(
        RequestOptionsBuilder.acceptAllDevices()
      );
      
      if (_device == null) {
        print('❌ No device selected');
        return false;
      }
      
      print('📱 Connecting to: ${_device!.name}');
      
      // Connect to device
      await _device!.connect();
      
      print('🔗 Connected! Discovering services...');
      
      // Discover services and find a writable characteristic
      final services = await _device!.discoverServices();
      print('📋 Found ${services.length} services');
      
      for (final service in services) {
        print('🔧 Checking service: ${service.uuid}');
        try {
          final characteristics = await service.getCharacteristics();
          for (final char in characteristics) {
            print('📝 Characteristic: ${char.uuid}, Properties: ${char.properties}');
            
            // Look for a characteristic that supports writing
            if (char.properties.write || char.properties.writeWithoutResponse) {
              _characteristic = char;
              print('✅ Found writable characteristic: ${char.uuid}');
              break;
            }
          }
          if (_characteristic != null) break;
        } catch (e) {
          print('⚠️ Error checking service ${service.uuid}: $e');
        }
      }
      
      if (_characteristic == null) {
        print('⚠️ No writable characteristic found, will use first available');
        // Try to use any characteristic from the first service
        if (services.isNotEmpty) {
          final firstService = services.first;
          final characteristics = await firstService.getCharacteristics();
          if (characteristics.isNotEmpty) {
            _characteristic = characteristics.first;
            print('📝 Using characteristic: ${_characteristic!.uuid}');
          }
        }
      }
      
      _isConnected = true;
      print('🎉 BLE connection successful!');
      return true;
      
    } catch (e) {
      print('❌ BLE connection failed: $e');
      _isConnected = false;
      return false;
    }
  }
  
  Future<bool> sendMessage(String message) async {
    if (!_isConnected || _characteristic == null) {
      print('❌ Not connected to BLE device');
      return false;
    }
    
    try {
      print('📤 Sending message: "$message"');
      
      final data = Uint8List.fromList(message.codeUnits); // Convert string to bytes
      await _characteristic!.writeValueWithResponse(data);
      
      print('✅ Message sent successfully!');
      return true;
      
    } catch (e) {
      print('❌ Failed to send message: $e');
      return false;
    }
  }
  
  Future<void> disconnect() async {
      if (_device != null && _isConnected) {
      try {
        _device!.disconnect();
        print('🔌 Disconnected from BLE device');
      } catch (e) {
        print('⚠️ Error disconnecting: $e');
      }
    }
    _isConnected = false;
    _device = null;
    _characteristic = null;
  }
}