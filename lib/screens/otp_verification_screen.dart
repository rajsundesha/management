import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/approved_request_provider.dart';

class OTPVerificationScreen extends StatelessWidget {
  final TextEditingController _otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _otpController,
              decoration: InputDecoration(labelText: 'Enter OTP'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final userName = ''; // Get the username from context or state
                final otp = _otpController.text;
                final otpProvider = Provider.of<ApprovedRequestProvider>(
                    context,
                    listen: false);
                final correctOtp = otpProvider.getOTPForUser(userName);

                if (correctOtp == otp) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('OTP Verified! Items received by $userName.')),
                  );
                  // Perform further actions if needed
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid OTP. Please try again.')),
                  );
                }
              },
              child: Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
