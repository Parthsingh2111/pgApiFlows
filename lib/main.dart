import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
// import 'package:uuid/uuid.dart'; // Add uuid package for generating merchantTxnId

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pay Now',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E35B1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PayPage(),
    );
  }
}

class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _waveController;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  String _selectedPaymentMethod = 'API Key'; // Default payment method

  // Backend endpoints (replace with your deployed URLs)
  // static const String apiKeyPaymentUrl = 'http://localhost:3000/api/pay/apikey';
  // static const String jwtPaymentUrl = 'http://localhost:3000/api/pay/jwt';

//ngrok for external url
  // static const String ngrokUrl = 'https://ff6d-31-13-189-18.ngrok-free.app';
  static const String ngrokUrl = 'https://28c1-2401-4900-1f24-3aa8-6cfa-4d3a-d55-953c.ngrok-free.app';

  // API URLs dynamically constructed using the ngrok base URL
  static String get jwtPaymentUrl => '$ngrokUrl/api/pay/jwt';
  static String get apiKeyPaymentUrl => '$ngrokUrl/api/pay/apikey';
  // Merchant Unique ID provided by PayGlocal (replace with your actual merchant ID)

  static String get merchantCallbackUrlIs =>
      'https://api.uat.payglocal.in/gl/v1/payments/merchantCallback';

  // static const String merchantUniqueId = 'testnewgcc26';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    nameController.dispose();
    emailController.dispose();
    amountController.dispose();
    super.dispose();
  }

//ramdom merchant id generator

  String generateMerchantTxnId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final randomDigits =
        List.generate(6, (_) => random.nextInt(10)).join(); // 6-digit suffix
    return '$timestamp$randomDigits';
  }

  String generateMerchantUniqueId(
      {String prefix = 'ABCD', String suffix = 'WXYZ'}) {
    if (prefix.length > 4 || suffix.length > 4) {
      throw ArgumentError(
          'Prefix and suffix must each be up to 4 characters long');
    }

    const totalLength = 14;
    final middleLength = totalLength - prefix.length - suffix.length;

    final random = Random();
    final randomMiddle =
        List.generate(middleLength, (_) => random.nextInt(10)).join();

    return '$prefix$randomMiddle$suffix';
  }

//api key based **********************************************************AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPPPPPPPPPPPPPPPPPPPPPPIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
  Future<void> _handleApiKeyPayment(
      String name, String email, String amount) async {
    try {
      final merchantTxnId =
          generateMerchantTxnId(); // Generate a unique merchant transaction ID

      final payload = {
        "merchantTxnId": merchantTxnId, // Add the merchantTxnId
        "paymentData": {
          "totalAmount": amount, // Amount passed to totalAmount
          "txnCurrency": "INR", // Currency (INR assumed as static here)
          "billingData": {
            "emailId": email, // Email passed here
          },
        },
        "merchantCallbackURL":
            "https://api.uat.payglocal.in/gl/v1/payments/merchantCallback", // Static callback URL
      };

      final response = await http.post(
        Uri.parse(
            apiKeyPaymentUrl.trim()), // Replace with your actual backend URL
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final paymentLink = responseData['payment_link'];

        if (paymentLink == null || paymentLink.isEmpty) {
          throw Exception('No payment link received.');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment Initiated! Redirecting...',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF5E35B1),
            behavior: SnackBarBehavior.floating,
          ),
        );

        final paymentUri = Uri.parse(paymentLink);
        if (await canLaunchUrl(paymentUri)) {
          await launchUrl(paymentUri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch payment link');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Payment Failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } on http.ClientException {
      throw Exception(
          'Failed to connect to the server. Please check your network and try again.');
    } catch (error) {
      print('Unexpected error: $error');
      throw Exception('Error: $error');
    }
  }

//***********************************************************************jwt***********************************************************************************************************************************************

// jwt based
  Future<void> _handleJwtPayment(
      // Prepare the minimum required payload for JWT-based payment
      String name,
      String email,
      String amount) async {
    try {
      final merchantTxnId = generateMerchantTxnId();

      final merchantUniId = generateMerchantUniqueId(); // adjust as needed

      final payload = {
        "merchantTxnId": merchantTxnId,
        "merchantUniqueId": merchantUniId,
        "paymentData": {
          "totalAmount": amount,
          "txnCurrency": "INR",
          "billingData": {
            "emailId": email,
          },
        },
        "merchantCallbackURL":
            "https://api.uat.payglocal.in/gl/v1/payments/merchantCallback", // Static callback URL
      };

      print('Sending JWT request to: $jwtPaymentUrl');
      print('Request body: ${jsonEncode(payload)}');

      final response = await http
          .post(
        Uri.parse(jwtPaymentUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out');
      });

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final paymentLink = responseData['payment_link'];
        if (paymentLink == null || paymentLink.isEmpty) {
          throw Exception('No payment link received');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment Initiated! Redirecting...',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF5E35B1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Redirect to payment link
        final paymentUri = Uri.parse(paymentLink);
        if (await canLaunchUrl(paymentUri)) {
          await launchUrl(paymentUri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch payment link');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
            'Payment Failed: ${errorData['error'] ?? 'Unknown error'}');
      }
    } on http.ClientException catch (e) {
      throw Exception(
          'Failed to connect to the server. Please check your network and try again.');
    } catch (error) {
      print('Unexpected error: $error');
      throw Exception('Error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                painter: WavePainter(_waveController.value),
                child: Container(),
              );
            },
          ).animate().fadeIn(duration: 1200.ms),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make a Payment',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 200.ms),
                      const SizedBox(height: 8),
                      Text(
                        'Secure and seamless',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ).animate().fadeIn(duration: 800.ms, delay: 300.ms),
                      const SizedBox(height: 32),
                      BuiltTextField(
                        label: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline,
                            color: Colors.white70),
                        keyboardType: TextInputType.name,
                        controller: nameController,
                      )
                          .animate()
                          .slideY(begin: 0.1, duration: 600.ms, delay: 400.ms),
                      const SizedBox(height: 16),
                      BuiltTextField(
                        label: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: Colors.white70),
                        keyboardType: TextInputType.emailAddress,
                        controller: emailController,
                      )
                          .animate()
                          .slideY(begin: 0.1, duration: 600.ms, delay: 500.ms),
                      const SizedBox(height: 16),
                      BuiltTextField(
                        label: 'Amount',
                        prefixIcon: const Icon(Icons.currency_rupee,
                            color: Colors.white70),
                        keyboardType: TextInputType.number,
                        controller: amountController,
                      )
                          .animate()
                          .slideY(begin: 0.1, duration: 600.ms, delay: 600.ms),
                      const SizedBox(height: 32),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5E35B1).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            final name =
                                                nameController.text.trim();
                                            final email =
                                                emailController.text.trim();
                                            final amount =
                                                amountController.text.trim();

                                            if (name.isEmpty ||
                                                email.isEmpty ||
                                                amount.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Please fill in all fields.',
                                                    style: GoogleFonts.inter(
                                                        color: Colors.white),
                                                  ),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                              return;
                                            }

                                            setState(() => _isLoading = true);

                                            try {
                                              if (_selectedPaymentMethod ==
                                                  'API Key') {
                                                await _handleApiKeyPayment(
                                                    name, email, amount);
                                              } else {
                                                await _handleJwtPayment(
                                                    name, email, amount);
                                              }
                                            } catch (error) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error: $error',
                                                    style: GoogleFonts.inter(
                                                        color: Colors.white),
                                                  ),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }

                                            setState(() => _isLoading = false);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5E35B1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 18),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            'Pay Now',
                                            style: GoogleFonts.inter(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: _selectedPaymentMethod,
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedPaymentMethod = newValue!;
                                      });
                                    },
                                    items: ['API Key', 'JWT']
                                        .map<DropdownMenuItem<String>>(
                                            (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: GoogleFonts.inter(
                                            color: Colors
                                                .black, // Changed text color to black
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    underline: const SizedBox(),
                                    icon:
                                        const SizedBox(), // Remove default icon
                                    dropdownColor:
                                        Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                    // Wrap with Row to place icon on the left
                                    selectedItemBuilder:
                                        (BuildContext context) {
                                      return ['API Key', 'JWT']
                                          .map<Widget>((String value) {
                                        return Row(
                                          children: [
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.white70,
                                              size: 20,
                                            ),
                                            const SizedBox(
                                                width:
                                                    8), // Space between icon and text
                                            Text(
                                              value,
                                              style: GoogleFonts.inter(
                                                color: Colors
                                                    .black, // Changed text color to black
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().scale(duration: 600.ms, delay: 700.ms),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(70, 10, 50, 0),
                        child: Row(
                          children: [
                            Text(
                              'Secured by ',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  width: 115,
                                  height: 25,
                                  decoration: BoxDecoration(
                                    color: Colors.white70.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.asset(
                                    'assets/images/pgs.png',
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BuiltTextField extends StatefulWidget {
  final String label;
  final Icon prefixIcon;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  const BuiltTextField({
    super.key,
    required this.label,
    required this.prefixIcon,
    this.keyboardType,
    this.controller,
  });

  @override
  State<BuiltTextField> createState() => _BuiltTextFieldState();
}

class _BuiltTextFieldState extends State<BuiltTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (_isFocused)
            BoxShadow(
              color: const Color(0xFF5E35B1).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        onTap: () => setState(() => _isFocused = true),
        onSubmitted: (_) => setState(() => _isFocused = false),
        decoration: InputDecoration(
          prefixIcon: widget.prefixIcon,
          labelText: widget.label,
          labelStyle: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: GoogleFonts.inter(
            color: const Color.fromARGB(255, 223, 221, 227),
            fontWeight: FontWeight.w600,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color(0xFF5E35B1),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF5E35B1).withOpacity(0.7),
          const Color(0xFF3F51B5).withOpacity(0.7),
          const Color(0xFF311B92).withOpacity(0.7),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height * 0.6);

    for (double x = 0; x <= size.width; x++) {
      path.lineTo(
        x,
        size.height * 0.6 +
            sin((x / size.width * 2 * 3.14) + (animationValue * 2 * 3.14)) * 50,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
