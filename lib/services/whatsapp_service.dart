import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'user_service.dart';

class WhatsAppService {
  // Support number in E.164 format without '+' or spaces (e.g. 919876543210 for India)
  static const String supportNumber = '919876543210';

  /// Formats and launches WhatsApp with the purchase receipt.
  static Future<void> sendPurchaseReceipt({
    required String courseTitle,
    required double price,
    required String transactionId,
    required String planType,
    String? purchaseType,
  }) async {
    try {
      final userService = UserService();
      final currentUserId = userService.currentUserId;

      String studentName = 'Student';
      String studentPhone = '';

      // Try fetching the student's info from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('bharatam_users')
            .doc(currentUserId)
            .get();
        if (userDoc.exists) {
          studentName = userDoc.data()?['name'] ?? studentName;
          studentPhone = userDoc.data()?['phoneNumber'] ?? studentPhone;
        } else {
          // Fallback to learners collection
          final learnerDoc = await FirebaseFirestore.instance
              .collection('learners')
              .doc(currentUserId)
              .get();
          if (learnerDoc.exists) {
            studentName = learnerDoc.data()?['name'] ?? studentName;
            studentPhone = learnerDoc.data()?['phoneNumber'] ?? studentPhone;
          }
        }
      } catch (e) {
        debugPrint('Error loading user profile for WhatsApp receipt: $e');
      }

      final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
      final typeLabel = purchaseType ?? 'course';

      // Construct a clean, receipt-like message block
      final message = '''
*Bharatam LMS Purchase Receipt*
----------------------------------
*Date:* $formattedDate
*Student Name:* $studentName
${studentPhone.isNotEmpty ? '*Student Phone:* +91 $studentPhone\n' : ''}*Course:* $courseTitle
*Type:* ${typeLabel.toUpperCase()}
*Plan:* ${planType.toUpperCase()}
*Amount Paid:* ₹${price.toInt()}
*Transaction ID:* $transactionId
*Status:* SUCCESS
----------------------------------
Thank you for your purchase! Start learning now.
''';

      final Uri whatsappUrl = Uri.parse(
        "https://wa.me/$supportNumber?text=${Uri.encodeComponent(message)}"
      );

      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch WhatsApp URL: $whatsappUrl');
      }
    } catch (e) {
      debugPrint('Error sending WhatsApp receipt: $e');
    }
  }
}
