import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_service.dart';

class EmailAuthDialog extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAuthSuccess;

  const EmailAuthDialog({
    super.key,
    required this.authService,
    required this.onAuthSuccess,
  });

  @override
  State<EmailAuthDialog> createState() => _EmailAuthDialogState();
}

class _EmailAuthDialogState extends State<EmailAuthDialog> {
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVerified = false;
  bool _codeSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulate a small delay for security
    await Future.delayed(const Duration(milliseconds: 500));

    final success = widget.authService.verifyPassword(_passwordController.text.trim());
    
    if (success) {
      setState(() {
        _passwordVerified = true;
      });
      
      // Automatically send email code to the admin address
      await _sendCode();
    } else {
      setState(() {
        _errorMessage = 'Incorrect password';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.authService.sendVerificationCode();
      
      if (success) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        
        // Show the verification code in a snackbar for demo purposes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Demo Code: ${widget.authService.pendingVerificationCode}\n'
                '(In production, this would be sent via email to jeremyfriemoth@gmail.com)',
              ),
              duration: const Duration(seconds: 10),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to send verification code';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.authService.verifyCode(_codeController.text.trim());
      
      if (success) {
        setState(() {
          _isLoading = false;
        });
        
        Navigator.of(context).pop();
        widget.onAuthSuccess();
      } else {
        setState(() {
          _errorMessage = 'Invalid verification code';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Admin Password Required';
    if (_codeSent) {
      title = 'Enter Email Verification Code';
    }

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_passwordVerified) ...[
            const Text('Enter the admin password to continue:'),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onSubmitted: (_) => _verifyPassword(),
            ),
          ] else if (_codeSent) ...[
            Text('Code sent to: ${widget.authService.pendingUserEmail}'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                hintText: '6-digit code',
                prefixIcon: Icon(Icons.security),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
          ] else ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending email verification code...'),
                ],
              ),
            ),
          ],
          
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_passwordVerified)
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyPassword,
            child: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify Password'),
          )
        else if (_codeSent) ...[
          TextButton(
            onPressed: _isLoading ? null : () {
              setState(() {
                _codeSent = false;
                _passwordVerified = false;
                _codeController.clear();
                _passwordController.clear();
                _errorMessage = null;
              });
            },
            child: const Text('Start Over'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _verifyCode,
            child: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
        ],
      ],
    );
  }
}