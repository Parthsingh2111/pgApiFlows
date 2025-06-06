import 'dart:async';
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
      initialRoute: '/payment',
      routes: {
        '/payment': (context) => const PayPage(),
        '/refund': (context) => const RefundPage(),
        '/status': (context) => const StatusPage(),
      },
    );
  }
}

class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => _PayPageState();
}

String  ngrokUrl = 'https://3bb8-122-172-85-41.ngrok-free.app';
   String get jwtPaymentUrl => '$ngrokUrl/api/pay/jwt';
   String get apiKeyPaymentUrl => '$ngrokUrl/api/pay/apikey';
   String get statusUrl => '$ngrokUrl/api/status';
   String get refundUrl => '$ngrokUrl/api/refund';
   String gid='';

class _PayPageState extends State<PayPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _waveController;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  String _selectedPaymentMethod = 'API Key'; // Default payment method
  String _selectedPage = 'Payment Page'; // Default selected page

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
  Future<void> _handleJwtPayment
  (
      // Prepare the minimum required payload for JWT-based payment
      String name,
      String email,
      String amount) async
       {
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
        final  paymentLink= responseData['payment_link'];
        gid = responseData['gid'];

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

        print('print gid: $gid');
        print('Calling statusUrl: $statusUrl');

        }
      }
        catch (error) {
      print('Unexpected error: $error');
      throw Exception('Error: $error');
    }
    } 

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Payment Portal'),
      backgroundColor: const Color(0xFF5E35B1),
      actions: [
        DropdownButton<String>(
          value: _selectedPage,
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedPage) {
              setState(() {
                _selectedPage = newValue;
              });
              switch (newValue) {
                case 'Payment Page':
                  Navigator.pushReplacementNamed(context, '/payment');
                  break;
                case 'Refund Page':
                  Navigator.pushReplacementNamed(context, '/refund');
                  break;
                case 'Status Page':
                  Navigator.pushReplacementNamed(context, '/status');
                  break;
              }
            }
          },
          items: const [
            DropdownMenuItem(
              value: 'Payment Page',
              child: Text('Payment Page', style: TextStyle(color: Colors.white)),
            ),
            DropdownMenuItem(
              value: 'Refund Page',
              child: Text('Refund Page', style: TextStyle(color: Colors.white)),
            ),
            DropdownMenuItem(
              value: 'Status Page',
              child: Text('Status Page', style: TextStyle(color: Colors.white)),
            ),
          ],
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          dropdownColor: const Color(0xFF5E35B1),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          underline: const SizedBox(),
        ),
        const SizedBox(width: 16),
      ],
    ),
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



//***********************************************************************************************************************************************/
  //refund page

  // Refund Page
class RefundPage extends StatefulWidget {
  const RefundPage({super.key});

  @override
  _RefundPageState createState() => _RefundPageState();
}

 class _RefundPageState extends State<RefundPage> {
  final TextEditingController gidController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  bool _isLoading = false;
  String? _refundResult;
  String _refundType = 'Full'; // Default to Full Refund

  Future<void> _requestRefund(String gid) async {
    print('Requesting refund for GID: $gid, Type: $_refundType');
    setState(() => _isLoading = true);

    try {
      final body = _refundType == 'Full'
          ? {
              'gid': gid,
              'refundType': 'F',
            }
          : {
              'gid': gid,
              'refundType': 'P',
              'paymentData': {
                'totalAmount': amountController.text.trim(),
              },
            };

      final response = await http
          .post(
            Uri.parse(refundUrl),
            headers: {
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20), onTimeout: () {
        throw Exception('Request timed out');
      });

      print('Refund response code: ${response.statusCode}');
      print('Refund response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final refundData = jsonDecode(response.body);
          final refundStatus = refundData['status'] ?? 'unknown';
          print('Parsed refund status: $refundStatus');
          if (mounted) {
            setState(() {
              _refundResult = 'Refund Status: $refundStatus';
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Refund Status: $refundStatus'),
                backgroundColor: refundStatus.toLowerCase().contains('SENT_FOR_REFUND')
                    ? Colors.redAccent
                    : Colors.green
              ),
            );
          }
        } catch (e) {
          print('JSON parse error: $e');
          print('Raw response: ${response.body}');
          if (mounted) {
            setState(() {
              _refundResult = 'Error: Failed to parse response - $e';
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: Failed to parse response - $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        print('Refund request failed: ${response.statusCode}');
        print('Raw response: ${response.body}');
        if (mounted) {
          setState(() {
            _refundResult = 'Error: Failed to process refund (${response.statusCode})';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Failed to process refund (${response.statusCode})'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      print('Error requesting refund: $e');
      if (mounted) {
        setState(() {
          _refundResult = 'Error: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    gidController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Portal'),
        backgroundColor: const Color(0xFF5E35B1),
        actions: [
          DropdownButton<String>(
            value: 'Refund Page',
            onChanged: (String? newValue) {
              if (newValue != null) {
                switch (newValue) {
                  case 'Payment Page':
                    Navigator.pushReplacementNamed(context, '/payment');
                    break;
                  case 'Refund Page':
                    break;
                  case 'Status Page':
                    Navigator.pushReplacementNamed(context, '/status');
                    break;
                }
              }
            },
            items: const [
              DropdownMenuItem(
                value: 'Payment Page',
                child: Text('Payment Page', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Refund Page',
                child: Text('Refund Page', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Status Page',
                child: Text('Status Page', style: TextStyle(color: Colors.white)),
              ),
            ],
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: const Color(0xFF5E35B1),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            underline: const SizedBox(),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Refund Request',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter transaction details to initiate a refund.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              BuiltTextField(
                label: 'GID', // kal sir se puchna h
                prefixIcon: const Icon(Icons.receipt_long, color: Colors.white70),
                controller: gidController,
              ),
              const SizedBox(height: 16),
             
              DropdownButton<String>(
                
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(15),
                dropdownColor: Color(0xFF5E35B1),
                value: _refundType,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _refundType = newValue);
                  }
                },
                items: const [
                  DropdownMenuItem(
                    value: 'Full',
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text('Full Refund'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Partial',
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text('Partial Refund'),
                    ),
                  ),
                ],
                
                // isExpanded: false,
                isExpanded: true,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
              ),



              if (_refundType == 'Partial') ...[
                const SizedBox(height: 16),
                BuiltTextField(
                  label: 'Refund Amount',
                  prefixIcon: const Icon(Icons.money_rounded, color: Colors.white30),
                  controller: amountController,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 24),
              if (_refundResult != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _refundResult!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final gid = gidController.text.trim();
                          if (gid.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a GID.',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          if (_refundType == 'Partial' && amountController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a refund amount.',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          _requestRefund(gid);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                          'Request Refund',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//******************************************************************************************************************* */
    
// Status Page



// Status Page
class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  _StatusPageState createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  final TextEditingController gidController = TextEditingController();
  bool _isLoading = false;
  String? _statusResult;

  Future<void> _checkStatus(String gid) async {
    print('Checking status for GID: $gid');
    setState(() => _isLoading = true);
    try {
      final response = await http
          .get(
            Uri.parse('$statusUrl?gid=$gid'),
            headers: {'ngrok-skip-browser-warning': 'true'},
          )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timed out');
      });

      print('Status response code: ${response.statusCode}');
      print('Status response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final statusData = jsonDecode(response.body);
          final paymentStatus = statusData['status'] ?? 'unknown';
          print('Parsed status: $paymentStatus');
          if (mounted) {
            setState(() {
              _statusResult = 'Status: $paymentStatus';
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status: $paymentStatus'),
                backgroundColor: paymentStatus == 'SUCCESS' || paymentStatus == 'SENT_FOR_CAPTURE'
                    ? Colors.green
                    : Colors.redAccent,
              ),
            );
          }
        } catch (e) {
          print('JSON parse error: $e');
          print('Raw response: ${response.body}');
          if (mounted) {
            setState(() {
              _statusResult = 'Error: Failed to parse response - $e';
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: Failed to parse response - $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } else {
        print('Status check failed: ${response.statusCode}');
        print('Raw response: ${response.body}');
        if (mounted) {
          setState(() {
            _statusResult = 'Error: Failed to fetch status (${response.statusCode})';
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: Failed to fetch status (${response.statusCode})'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking status: $e');
      if (mounted) {
        setState(() {
          _statusResult = 'Error: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    gidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Check'),
        backgroundColor: const Color(0xFF5E35B1),
        actions: [
          DropdownButton<String>(
            value: 'Status Page',
            onChanged: (String? newValue) {
              if (newValue != null) {
                switch (newValue) {
                  case 'Payment Page':
                    Navigator.pushReplacementNamed(context, '/payment');
                    break;
                  case 'Refund Page':
                    Navigator.pushReplacementNamed(context, '/refund');
                    break;
                  case 'Status Page':
                    break;
                }
              }
            },
            items: const [
              DropdownMenuItem(
                value: 'Payment Page',
                child: Text('Payment Page', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Refund Page',
                child: Text('Refund Page', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Status Page',
                child: Text('Status Page', style: TextStyle(color: Colors.white)),
              ),
            ],
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            dropdownColor: const Color(0xFF5E35B1),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            underline: const SizedBox(),
          ),
          const SizedBox(width: 16), 
        ],
      ),
      body: Center(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Check Payment Status',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the GID to check the payment status.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              BuiltTextField(
                label: 'GID',
                prefixIcon: const Icon(Icons.receipt_long, color: Colors.white70),
                controller: gidController,
              ),
              const SizedBox(height: 24),
              if (_statusResult != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _statusResult!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final gid = gidController.text.trim();
                          if (gid.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Please enter a GID.',
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          _checkStatus(gid);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E35B1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                          'Check Status',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//*************************************************************RRRRRRRRRRRRRRRRRRRRRREEEEEEEEEEEEEEEEFFFFFFFFFFUUUUUUUUUUUUUUUUUUUUUUNNNNNNNNNNNNNNNNNNNNDDDDDDDDDDDDDDDDDD****************************** */
//refund




// // Assume BuiltTextField is defined elsewhere
// class _BuiltTextField extends StatelessWidget {
//   final String label;
//   final Icon prefixIcon;
//   final TextEditingController controller;
//   final TextInputType? keyboardType;

//   const _BuiltTextField({
//     super.key,
//     required this.label,
//     required this.prefixIcon,
//     required this.controller,
//     this.keyboardType,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return TextField(
//       controller: controller,
//       keyboardType: keyboardType,
//       style: GoogleFonts.inter(color: Colors.white),
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: GoogleFonts.inter(color: Colors.white70),
//         prefixIcon: prefixIcon,
//         filled: true,
//         fillColor: Colors.white.withOpacity(0.1),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide.none,
//         ),
//       ),
//     );
//   }
// }

// class RefundPage extends StatefulWidget {
//   const RefundPage({super.key});

//   @override
//   _RefundPageState createState() => _RefundPageState();
// }

// class _RefundPageState extends State<RefundPage> {
//   final TextEditingController merchantTxnIdController = TextEditingController();
//   final TextEditingController amountController = TextEditingController();
//   bool _isLoading = false;
//   String? _refundResult;
//   String _refundType = 'Full'; // Default to Full Refund

//   Future<void> _requestRefund(String merchantTxnId) async {
//     print('Requesting refund for Merchant Txn ID: $merchantTxnId, Type: $_refundType');
//     setState(() => _isLoading = true);

//     try {
//       final body = _refundType == 'Full'
//           ? {
//               'merchantTxnId': merchantTxnId,
//               'refundType': 'F',
//             }
//           : {
//               'merchantTxnId': merchantTxnId,
//               'refundType': 'P',
//               'paymentData': {
//                 'totalAmount': amountController.text.trim(),
//               },
//             };

//       final response = await http
//           .post(
//             Uri.parse(refundUrl),
//             headers: {
//               'Content-Type': 'application/json',
//               'ngrok-skip-browser-warning': 'true',
//             },
//             body: jsonEncode(body),
//           )
//           .timeout(const Duration(seconds: 20), onTimeout: () {
//         throw Exception('Request timed out');
//       });

//       print('Refund response code: ${response.statusCode}');
//       print('Refund response body: ${response.body}');

//       if (response.statusCode == 200) {
//         try {
//           final refundData = jsonDecode(response.body);
//           final refundStatus = refundData['status'] ?? 'unknown';
//           final refundMessage = refundData['message'] ?? '';
//           print('Parsed refund status: $refundStatus');
//           if (mounted) {
//             setState(() {
//               _refundResult = 'Refund Status: $refundStatus${refundMessage.isNotEmpty ? ' ($refundMessage)' : ''}';
//               _isLoading = false;
//             });
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Refund Status: $refundStatus${refundMessage.isNotEmpty ? ' ($refundMessage)' : ''}'),
//                 backgroundColor: refundStatus.toLowerCase().contains('success') ||
//                         refundStatus.toLowerCase().contains('initiated')
//                     ? Colors.green
//                     : Colors.redAccent,
//               ),
//             );
//           }
//         } catch (e) {
//           print('JSON parse error: $e');
//           print('Raw response: ${response.body}');
//           if (mounted) {
//             setState(() {
//               _refundResult = 'Error: Failed to parse response - $e';
//               _isLoading = false;
//             });
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Error: Failed to parse response - $e'),
//                 backgroundColor: Colors.redAccent,
//               ),
//             );
//           }
//         }
//       } else {
//         print('Refund request failed: ${response.statusCode}');
//         print('Raw response: ${response.body}');
//         if (mounted) {
//           setState(() {
//             _refundResult = 'Error: Failed to process refund (${response.statusCode})';
//             _isLoading = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text('Error: Failed to process refund (${response.statusCode})'),
//               backgroundColor: Colors.redAccent,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       print('Error requesting refund: $e');
//       if (mounted) {
//         setState(() {
//           _refundResult = 'Error: $e';
//           _isLoading = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Error: $e'),
//             backgroundColor: Colors.redAccent,
//           ),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     merchantTxnIdController.dispose();
//     amountController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Refund Portal'),
//         backgroundColor: const Color(0xFF5E35B1),
//         actions: [
//           DropdownButton<String>(
//             value: 'Refund Page',
//             onChanged: (String? newValue) {
//               if (newValue != null) {
//                 switch (newValue) {
//                   case 'Payment Page':
//                     Navigator.pushReplacementNamed(context, '/payment');
//                     break;
//                   case 'Refund Page':
//                     break;
//                   case 'Status Page':
//                     Navigator.pushReplacementNamed(context, '/status');
//                     break;
//                 }
//               }
//             },
//             items: const [
//               DropdownMenuItem(
//                 value: 'Payment Page',
//                 child: Text('Payment Page', style: TextStyle(color: Colors.white)),
//               ),
//               DropdownMenuItem(
//                 value: 'Refund Page',
//                 child: Text('Refund Page', style: TextStyle(color: Colors.white)),
//               ),
//               DropdownMenuItem(
//                 value: 'Status Page',
//                 child: Text('Status Page', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//             icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
//             dropdownColor: const Color(0xFF5E35B1),
//             style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
//             underline: const SizedBox(),
//           ),
//           const SizedBox(width: 16),
//         ],
//       ),
//       body: Center(
//         child: Container(
//           constraints: const BoxConstraints(maxWidth: 400),
//           margin: const EdgeInsets.symmetric(horizontal: 24),
//           padding: const EdgeInsets.all(32),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: Colors.white.withOpacity(0.3)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 20,
//                 spreadRadius: 5,
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Refund Request',
//                 style: GoogleFonts.inter(
//                   fontSize: 28,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 'Enter transaction details to initiate a refund.',
//                 style: GoogleFonts.inter(
//                   fontSize: 16,
//                   color: Colors.white70,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               _BuiltTextField(
//                 label: 'Merchant Transaction ID',
//                 prefixIcon: const Icon(Icons.receipt_long, color: Colors.white70),
//                 controller: merchantTxnIdController,
//               ),
//               const SizedBox(height: 16),
//               DropdownButton<String>(
//                 underline: const SizedBox(),
//                 borderRadius: BorderRadius.circular(15),
//                 dropdownColor: const Color(0xFF5E35B1),
//                 value: _refundType,
//                 onChanged: (String? newValue) {
//                   if (newValue != null) {
//                     setState(() => _refundType = newValue);
//                   }
//                 },
//                 items: const [
//                   DropdownMenuItem(
//                     value: 'Full',
//                     child: Padding(
//                       padding: EdgeInsets.all(10.0),
//                       child: Text('Full Refund', style: TextStyle(color: Colors.white)),
//                     ),
//                   ),
//                   DropdownMenuItem(
//                     value: 'Partial',
//                     child: Padding(
//                       padding: EdgeInsets.all(10.0),
//                       child: Text('Partial Refund', style: TextStyle(color: Colors.white)),
//                     ),
//                   ),
//                 ],
//                 isExpanded: true,
//                 style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
//               ),
//               if (_refundType == 'Partial') ...[
//                 const SizedBox(height: 16),
//                 BuiltTextField(
//                   label: 'Refund Amount',
//                   prefixIcon: const Icon(Icons.money_rounded, color: Colors.white70),
//                   controller: amountController,
//                   keyboardType: TextInputType.numberWithOptions(decimal: true),
//                 ),
//               ],
//               const SizedBox(height: 24),
//               if (_refundResult != null)
//                 Padding(
//                   padding: const EdgeInsets.only(bottom: 16),
//                   child: Text(
//                     _refundResult!,
//                     style: GoogleFonts.inter(
//                       fontSize: 16,
//                       color: Colors.white,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               Center(
//                 child: ElevatedButton(
//                   onPressed: _isLoading
//                       ? null
//                       : () {
//                           final merchantTxnId = merchantTxnIdController.text.trim();
//                           if (merchantTxnId.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               SnackBar(
//                                 content: Text(
//                                   'Please enter a Merchant Transaction ID.',
//                                   style: GoogleFonts.inter(color: Colors.white),
//                                 ),
//                                 backgroundColor: Colors.redAccent,
//                               ),
//                             );
//                             return;
//                           }
//                           if (_refundType == 'Partial') {
//                             final amount = double.tryParse(amountController.text.trim());
//                             if (amount == null || amount <= 0) {
//                               ScaffoldMessenger.of(context).showSnackBar(
//                                 SnackBar(
//                                   content: Text(
//                                     'Please enter a valid refund amount.',
//                                     style: GoogleFonts.inter(color: Colors.white),
//                                   ),
//                                   backgroundColor: Colors.redAccent,
//                                 ),
//                               );
//                               return;
//                             }
//                           }
//                           _requestRefund(merchantTxnId);
//                         },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF5E35B1),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                   ),
//                   child: _isLoading
//                       ? const SizedBox(
//                           width: 24,
//                           height: 24,
//                           child: CircularProgressIndicator(
//                             color: Colors.white,
//                             strokeWidth: 2,
//                           ),
//                         )
//                       : Text(
//                           'Request Refund',
//                           style: GoogleFonts.inter(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w700,
//                           ),
//                         ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

