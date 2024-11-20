import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;


String extractTextFromPDF(String filePath) {
  final file = File(filePath);
  final PdfDocument document = PdfDocument(inputBytes: file.readAsBytesSync());
  final String text = PdfTextExtractor(document).extractText();
  document.dispose();
  return text;
}

Future<String> fetchWebPageContent(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response.body;
  } else {
    throw Exception('Failed to load web page');
  }
}

List<String> splitText(String text, {int chunkSize = 1000, int overlap = 100}) {
  final chunks = <String>[];
  for (int i = 0; i < text.length; i += chunkSize - overlap) {
    chunks.add(text.substring(i, (i + chunkSize).clamp(0, text.length)));
  }
  return chunks;
}

