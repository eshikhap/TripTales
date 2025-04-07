// import 'package:http/http.dart' as http;
// import 'dart:convert';

// Future<void> sendFriendRequestEmail({
//   required String toName,
//   required String toEmail,
//   required String fromName,
//   required String acceptLink,
//   required String rejectLink,
// }) async {
//   const serviceId = 'service_k1hun3h';
//   const templateId = 'template_peysnko';
//   const publicKey = 'G_VQnVRZN9XCHoDNS'; // formerly user_id

//   final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

//   final response = await http.post(
//     url,
//     headers: {
//       'origin': 'http://localhost',
//       'Content-Type': 'application/json',
//     },
//     body: json.encode({
//       'service_id': serviceId,
//       'template_id': templateId,
//       'user_id': publicKey,
//       'template_params': {
//         'to_name': toName,
//         'to_email': toEmail,
//         'from_name': fromName,
//         'accept_link': acceptLink,
//         'reject_link': rejectLink,
//       },
//     }),
//   );

//   if (response.statusCode == 200) {
//     print('✅ Email sent successfully');
//   } else {
//     print('❌ Failed to send email: ${response.body}');
//   }
// }
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendRequestEmail({
  required String toName,
  required String toEmail,
  required String fromName,
  required String acceptLink,
  required String rejectLink,
  required String type, // 'friend' or 'trip'
  String? tripName,     // optional for trip invites
}) async {
  const serviceId = 'service_k1hun3h';

  // Use different templates for friend and trip if needed
  final templateId = type == 'friend' 
      ? 'template_peysnko'
      : 'template_17540fe'; // Replace with your actual trip template ID

  const publicKey = 'G_VQnVRZN9XCHoDNS'; // formerly user_id

  final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

  final templateParams = {
    'to_name': toName,
    'to_email': toEmail,
    'from_name': fromName,
    'accept_link': acceptLink,
    'reject_link': rejectLink,
    'trip_name': tripName ?? '', // used only for trip invites
  };

  final response = await http.post(
    url,
    headers: {
      'origin': 'http://localhost',
      'Content-Type': 'application/json',
    },
    body: json.encode({
      'service_id': serviceId,
      'template_id': templateId,
      'user_id': publicKey,
      'template_params': templateParams,
    }),
  );

  if (response.statusCode == 200) {
    print('✅ Email sent successfully');
  } else {
    print('❌ Failed to send email: ${response.body}');
  }
}
