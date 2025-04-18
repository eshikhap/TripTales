import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_html_to_pdf/flutter_html_to_pdf.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

String safeUrl(String url) {
  return url.replaceFirst("http://", "https://");
}

Future<String> fetchChatHtmlGrouped(String tripId) async {
  print("[fetchChatHtmlGrouped] Start for tripId: $tripId");
  final firestore = FirebaseFirestore.instance;

  try {
    final querySnapshot = await firestore
        .collection("trips")
        .doc(tripId)
        .collection("chat")
        .orderBy("timestamp", descending: false)
        .get();

    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final timestamp = (data["timestamp"] as Timestamp).toDate();
      final type = data["type"];
      final text = data["text"] ?? data["caption"] ?? "";
      final url = data["url"] ?? "";
      final dateKey = "${timestamp.year}-${timestamp.month}-${timestamp.day}";

      grouped.putIfAbsent(dateKey, () => []).add({
        "type": type,
        "text": type == "text" ? text : url,
        "caption": type != "text" ? text : null,
        "timestamp": timestamp,
      });
    }

    StringBuffer html = StringBuffer();
    html.writeln('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta charset="UTF-8">
  <title>Trip Scrapbook</title>
  <link href="https://fonts.googleapis.com/css2?family=Patrick+Hand&family=Shadows+Into+Light&display=swap" rel="stylesheet">
  <style>
    body {
      background: #fdf6e3;
      font-family: 'Patrick Hand', cursive;
      padding: 20px;
    }

    header {
      text-align: center;
      margin-bottom: 40px;
    }

    header h1 {
      font-family: 'Shadows Into Light', cursive;
      font-size: 3em;
      color: #8b5e3c;
    }

    .day-section {
      margin-bottom: 50px;
      border-left: 8px dashed #e0c097;
      padding-left: 20px;
    }

    .date-title {
      font-size: 1.8em;
      margin-bottom: 20px;
      background: #fffae6;
      padding: 10px 20px;
      display: inline-block;
      border-radius: 15px;
      box-shadow: 2px 2px 8px rgba(0,0,0,0.1);
    }

    .polaroid {
      position: relative;
      background: white;
      padding: 15px 15px 50px;
      margin: 20px auto;
      max-width: 400px;
      border-radius: 10px;
      box-shadow: 5px 5px 15px rgba(0,0,0,0.1);
    }

    .polaroid img {
      width: 100%;
      border-radius: 8px;
    }

    .caption {
      font-style: italic;
      text-align: center;
      margin-top: 12px;
      font-size: 1.1em;
      color: #5c4033;
    }

    .tape {
      width: 80px;
      height: 30px;
      background: url('https://i.imgur.com/lcgO5Wx.png') center/cover no-repeat;
      position: absolute;
      top: -15px;
      left: calc(50% - 40px);
    }

    .sticker {
      position: absolute;
      bottom: 10px;
      right: 10px;
      font-size: 2em;
      transform: rotate(-15deg);
    }

    .entry-wrapper {
      display: flex;
      flex-wrap: wrap;
      gap: 30px;
      justify-content: center;
    }
  </style>
</head>
<body>
  <header>
    <h1>My Trip Scrapbook</h1>
  </header>
''');

    grouped.forEach((date, entries) {
      html.writeln('<div class="day-section"><div class="date-title">📅 $date</div><div class="entry-wrapper">');

      for (var entry in entries) {
        if (entry["type"] == "image") {
          html.writeln('''
            <div class="polaroid">
              <div class="tape"></div>
              <img src="${safeUrl(entry["text"])}" alt="photo" />
              <div class="caption">${entry["caption"] ?? ""}</div>
              <div class="sticker">📸</div>
            </div>
          ''');
        }
      }

      html.writeln('</div></div>');
    });

    html.writeln('</body></html>');

    print("[fetchChatHtmlGrouped] HTML scrapbook generated.");
    return html.toString();
  } catch (e, stackTrace) {
    print("[fetchChatHtmlGrouped] Error: $e");
    print(stackTrace);
    rethrow;
  }
}
Future<String> convertHtmlToPdfAndSave(String htmlContent, String tripId) async {
  try {
    print("[convertHtmlToPdfAndSave] Starting PDF conversion...");

    final outputDir = await getTemporaryDirectory();
    final file = await FlutterHtmlToPdf.convertFromHtmlContent(
      htmlContent,
      outputDir.path,
      "trip_album_$tripId",
    );

    print("[convertHtmlToPdfAndSave] PDF saved at: ${file.path}");
    return file.path;
  } catch (e, stackTrace) {
    print("[convertHtmlToPdfAndSave] PDF generation failed: $e");
    print(stackTrace);
    rethrow;
  }
}


Future<void> generateAndShareTripAlbum(BuildContext context, String tripId) async {
  try {
    print("[generateAndShareTripAlbum] Starting for tripId: $tripId");

    final htmlContent = await fetchChatHtmlGrouped(tripId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumPreview(html: htmlContent, tripId: tripId),
      ),
    );
  } catch (e, stackTrace) {
    print("[generateAndShareTripAlbum] Error: $e");
    print(stackTrace);
  }
}

class AlbumPreview extends StatelessWidget {
  final String html;
  final String tripId;

  const AlbumPreview({
    Key? key,
    required this.html,
    required this.tripId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final contentBase64 = base64Encode(const Utf8Encoder().convert(html));
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('data:text/html;base64,$contentBase64'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Album Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download PDF',
            onPressed: () async {
              try {
                final pdfPath = await convertHtmlToPdfAndSave(html, tripId);
                await OpenFilex.open(pdfPath);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PDF saved at $pdfPath')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to generate PDF: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
