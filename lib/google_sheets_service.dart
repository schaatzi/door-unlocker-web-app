import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleSheetsService {
  static const String _webAppUrl = 'https://script.google.com/macros/s/AKfycbyHW---NZsyRtgDu49UqOEMU3vW5gvrZ1c5pVbWp-jsiKKwPsJ_YSUhjTJt-PgsEChn/exec';
  
  static Future<Map<String, dynamic>?> loadSchedule() async {
    try {
      print('📥 Loading schedule from Google Sheets...');
      
      // Request the stored schedule data
      final response = await http.get(Uri.parse('$_webAppUrl?action=getSchedule'));
      
      print('📨 Load Response status: ${response.statusCode}');
      print('📨 Load Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['scheduleData'] != null) {
          print('✅ Schedule loaded from Google Sheets!');
          return responseData['scheduleData'] as Map<String, dynamic>;
        }
      }
      
      print('⚠️ No schedule data found in Google Sheets');
      return null;
    } catch (e) {
      print('❌ Error loading from Google Sheets: $e');
      return null;
    }
  }
  
  static Future<void> updateSchedule(Map<String, dynamic> scheduleData) async {
    try {
      print('📊 Sending data to Google Apps Script...');
      
      // Try POST first
      try {
        final response = await http.post(
          Uri.parse(_webAppUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'scheduleData': scheduleData,
          }),
        );
        
        print('📨 POST Response status: ${response.statusCode}');
        print('📨 POST Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            print('✅ Google Sheet updated successfully via POST!');
            return;
          }
        }
      } catch (postError) {
        print('POST failed, trying GET: $postError');
      }
      
      // Fallback to GET request with URL parameters
      final encodedData = Uri.encodeComponent(json.encode({'scheduleData': scheduleData}));
      final getUrl = '$_webAppUrl?data=$encodedData';
      
      final response = await http.get(Uri.parse(getUrl));
      
      print('📨 GET Response status: ${response.statusCode}');
      print('📨 GET Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          print('✅ Google Sheet updated successfully via GET!');
        } else if (responseData['error'] != null) {
          throw Exception('Google Apps Script error: ${responseData['error']}');
        }
      } else {
        throw Exception('Failed to update Google Sheet: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      print('❌ Error updating Google Sheet: $e');
      rethrow;
    }
  }
}