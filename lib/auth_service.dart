import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String adminEmail = 'jeremyfriemoth@gmail.com'; // Admin email
  static const String adminPassword = 'tigerskydiveabout'; // <-- CHANGE THIS PASSWORD
  
  String? _currentUserEmail;
  String? _pendingVerificationCode;
  String? _pendingUserEmail;
  bool _passwordVerified = false;
  DateTime? _codeGeneratedAt;
  int _failedAttempts = 0;
  DateTime? _lastFailedAttempt;
  
  // Security constants
  static const int maxFailedAttempts = 3;
  static const int codeExpiryMinutes = 5;
  static const int lockoutMinutes = 15;

  // Get current user email
  String? get currentUserEmail => _currentUserEmail;

  // Check if current user is admin
  bool get isAdmin {
    return _currentUserEmail == adminEmail;
  }

  // Check if user is logged in
  bool get isLoggedIn => _currentUserEmail != null;

  // Get user display info
  String get userDisplayName => isLoggedIn ? 'Admin User' : 'Guest';
  String get userEmail => _currentUserEmail ?? '';

  // Initialize - load saved auth state
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserEmail = prefs.getString('current_user_email');
  }

  // Verify password first step
  bool verifyPassword(String enteredPassword) {
    _passwordVerified = enteredPassword == adminPassword;
    return _passwordVerified;
  }

  // Generate cryptographically secure random verification code
  String _generateSecureCode() {
    final random = Random.secure(); // Cryptographically secure
    final code = List.generate(6, (index) => random.nextInt(10)).join();
    return code;
  }

  // Send verification code (only after password is verified)
  Future<bool> sendVerificationCode() async {
    if (!_passwordVerified) {
      return false; // Password must be verified first
    }

    // Automatically use the admin email address
    final emailAddress = adminEmail;

    // Generate a cryptographically secure random 6-digit code
    _pendingVerificationCode = _generateSecureCode();
    _pendingUserEmail = emailAddress;
    _codeGeneratedAt = DateTime.now(); // Track when code was generated
    
    // In a real app, you'd use a service like SendGrid, AWS SES, etc.
    // For demo purposes, we'll just show the code in console/dialog
    print('Email Code for $emailAddress: $_pendingVerificationCode (expires in $codeExpiryMinutes minutes)');
    
    // Try to send real email (optional - requires setup)
    try {
      await _sendEmailViaService(emailAddress, _pendingVerificationCode!);
    } catch (e) {
      print('Email sending failed (using demo mode): $e');
    }
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    return true; // Success
  }

  // Send real email using EmailJS (free service)
  Future<void> _sendEmailViaService(String emailAddress, String code) async {
    // EmailJS configuration - YOUR ACTUAL VALUES:
    const serviceId = 'service_55uhejo';     // Your Gmail service
    const templateId = 'template_byy08bg';   // Your verification template
    const publicKey = 'jfGdGO45ZdMgQR5cY';  // Your public key
    
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'to_email': emailAddress,
          'passcode': code,  // Matches {{passcode}} in your template
          'time': _getExpiryTime(), // Matches {{time}} in your template
        }
      }),
    );
    
    if (response.statusCode == 200) {
      print('✅ Email sent successfully to $emailAddress');
    } else {
      throw Exception('Failed to send email: ${response.body}');
    }
  }

  // Calculate expiry time for email template
  String _getExpiryTime() {
    if (_codeGeneratedAt == null) return 'N/A';
    
    final expiryTime = _codeGeneratedAt!.add(Duration(minutes: codeExpiryMinutes));
    final hour = expiryTime.hour.toString().padLeft(2, '0');
    final minute = expiryTime.minute.toString().padLeft(2, '0');
    
    return '$hour:$minute';
  }

  // Verify the code entered by user
  Future<bool> verifyCode(String enteredCode) async {
    if (_pendingVerificationCode == null || _pendingUserEmail == null) {
      return false;
    }

    // Check if user is locked out due to failed attempts
    if (_isLockedOut()) {
      return false;
    }

    // Check if code has expired
    if (_isCodeExpired()) {
      _clearPendingVerification();
      return false;
    }

    if (enteredCode == _pendingVerificationCode) {
      // Code is correct, sign in the user
      _currentUserEmail = _pendingUserEmail;
      
      // Save to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_email', _currentUserEmail!);
      
      // Clear pending verification and reset failed attempts
      _clearPendingVerification();
      _failedAttempts = 0;
      _lastFailedAttempt = null;
      
      return true;
    } else {
      // Wrong code - increment failed attempts
      _failedAttempts++;
      _lastFailedAttempt = DateTime.now();
      return false;
    }
  }

  // Check if user is currently locked out
  bool _isLockedOut() {
    if (_failedAttempts >= maxFailedAttempts && _lastFailedAttempt != null) {
      final lockoutEnd = _lastFailedAttempt!.add(Duration(minutes: lockoutMinutes));
      return DateTime.now().isBefore(lockoutEnd);
    }
    return false;
  }

  // Check if the current code has expired
  bool _isCodeExpired() {
    if (_codeGeneratedAt == null) return true;
    final expiryTime = _codeGeneratedAt!.add(Duration(minutes: codeExpiryMinutes));
    return DateTime.now().isAfter(expiryTime);
  }

  // Clear all pending verification data
  void _clearPendingVerification() {
    _pendingVerificationCode = null;
    _pendingUserEmail = null;
    _codeGeneratedAt = null;
    _passwordVerified = false;
  }

  // Get the pending verification code (for demo UI)
  String? get pendingVerificationCode => _pendingVerificationCode;
  String? get pendingUserEmail => _pendingUserEmail;

  // Sign out
  Future<void> signOut() async {
    _currentUserEmail = null;
    _pendingVerificationCode = null;
    _pendingUserEmail = null;
    _passwordVerified = false; // Reset password verification
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_email');
  }

  // Get user permission level
  UserPermission getUserPermission() {
    if (!isLoggedIn) {
      return UserPermission.readOnly;
    }
    if (isAdmin) {
      return UserPermission.admin;
    }
    return UserPermission.readOnly;
  }

  // Get remaining lockout time in minutes (returns 0 if not locked out)
  int getRemainingLockoutMinutes() {
    if (!_isLockedOut()) return 0;
    
    final lockoutEnd = _lastFailedAttempt!.add(Duration(minutes: lockoutMinutes));
    final remaining = lockoutEnd.difference(DateTime.now()).inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  // Get number of failed attempts
  int getFailedAttempts() => _failedAttempts;

  // Check if currently locked out (public method)
  bool isLockedOut() => _isLockedOut();

  // Get remaining code validity time in minutes
  int getRemainingCodeMinutes() {
    if (_codeGeneratedAt == null) return 0;
    
    final expiryTime = _codeGeneratedAt!.add(Duration(minutes: codeExpiryMinutes));
    final remaining = expiryTime.difference(DateTime.now()).inMinutes;
    return remaining > 0 ? remaining : 0;
  }
}

enum UserPermission {
  admin,     // Can edit everything
  readOnly,  // Can only view
}

// Extension to make permission checking easier
extension UserPermissionExtension on UserPermission {
  bool get canEdit => this == UserPermission.admin;
  bool get canSave => this == UserPermission.admin;
  bool get canClear => this == UserPermission.admin;
  
  String get displayName {
    switch (this) {
      case UserPermission.admin:
        return 'Admin';
      case UserPermission.readOnly:
        return 'Read Only';
    }
  }
}