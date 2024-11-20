import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

class VectorStore {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String dbFolder = await getDatabasesPath();
    String path = join(dbFolder, 'vector_store.db');

    // Check if database exists
    bool exists = await databaseExists(path);

    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Copy database from assets
      ByteData data = await rootBundle.load('assets/chess_knowledge_db/vector_store.db');
      List<int> bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }

    Database db = await openDatabase(path, readOnly: true);
    return db;
  }

  // Compute cosine similarity between two vectors
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) throw Exception('Vectors must be of same length');

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  static Future<List<Map<String, dynamic>>> findSimilar(
      List<double> queryEmbedding,
      {int limit = 5}) async {
    final db = _database;

    // Get all documents and their embeddings
    final List<Map<String, dynamic>> documents = await db!.query('documents');
    List<Map<String, dynamic>> results = documents.map((doc) {
      List<double> embedding = List<double>.from(jsonDecode(doc['embedding']));
      double similarity = cosineSimilarity(queryEmbedding, embedding);
      return {
        ...doc,
        'similarity': similarity,
      };
    }).toList();

    // Sort by similarity
    results.sort((a, b) => b['similarity'].compareTo(a['similarity']));

    return results.take(limit).toList();
  }
}

class ChatService {
  final String llmApiKey;
  final String embedmentApiKey;

  ChatService({
    required this.llmApiKey,
    required this.embedmentApiKey,
  });

  Future<List<double>> getEmbedding(String text) async {
    final url = Uri.parse('https://api.mixedbread.ai/v1/embeddings');

    final headers = {
      'Authorization': 'Bearer $embedmentApiKey',
      'Content-Type': 'application/json',
    };

    final body = json.encode({
      'model': 'mxbai-embed-large-v1',
      'input': text,
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final embedding = (responseData['data'][0]['embedding'] as List)
          .map((e) => e as double)
          .toList();

      return embedding;
    } else {
      throw Exception('Failed to load embedding: ${response.body}');
    }
  }

  Future<String> getResponse(String userQuery) async {
    try {
      final queryEmbedding = await getEmbedding(userQuery);

      final similarDocs = await VectorStore.findSimilar(queryEmbedding, limit: 1);
      String context = similarDocs
          .map((doc) => doc['text'])
          .join('\n\n---\n\n');

      dev.log("sql manager, line 126:\n ${_cleanText(context).length}");
      String cleanContext = _cleanText(context);
      if (cleanContext.length > 4000) {
        cleanContext = cleanContext.substring(0, 4000);
      }
      final input = "Answer the question this context can help you:"
          " context: $cleanContext \n --- \nQuestion: $userQuery in chess\nAnswer:";
      final response = await http.post(
        Uri.parse('https://api-inference.huggingface.co/models/bigscience/bloom'),
        headers: {
          'Authorization': 'Bearer $llmApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "inputs": input,
          "parameters": {
            "max_new_tokens": 80,
            "temperature": 0.7,
            "top_p": 0.9
          }
        }),
      );

      dev.log("sql manager, line 144:\n ${response.body}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        dev.log('sql manager, line 148:\n ${result[0]['generated_text']}');
        String generatedText = result[0]['generated_text'];
        generatedText = generatedText.substring(input.length).trim();
        generatedText = generatedText.replaceAll('Answer:', '');
        final questionIndex = generatedText.indexOf('Question:');
        if (questionIndex != -1) {
          generatedText = generatedText.substring(0, questionIndex).trim();
        }
        return generatedText;
      } else {
        throw Exception('Failed to get LLM response: ${response.body}');
      }
    } catch (e) {
      return 'Sorry, I encountered an error processing your request: $e';
    }
  }

  String _cleanText(String text) {
    // Remove non-ASCII characters
    text = text.replaceAll(RegExp(r'[^\x00-\x7F]'), '');

    // Remove multiple newlines and trim
    text = text.replaceAll(RegExp(r'\n+'), '\n');
    text = text.trim();

    return text;
  }

  static Future<List<Map<String, dynamic>>> querySimilarEmbeddings(
      Database db,
      List<double> queryEmbedding,
      int topK,
      ) async {
    // Fetch all embeddings from the database
    final List<Map<String, dynamic>> results = await db.query('embeddings');

    // Compute cosine similarities
    final List<Map<String, dynamic>> scoredResults = results.map((row) {
      final storedEmbedding = List<double>.from(jsonDecode(row['embedding']));
      final similarity = _cosineSimilarity(queryEmbedding, storedEmbedding);
      return {
        'id': row['id'],
        'chunk': row['chunk'],
        'similarity': similarity,
      };
    }).toList();

    // Sort by similarity in descending order
    scoredResults.sort((a, b) => b['similarity'].compareTo(a['similarity']));

    // Return the top K results
    return scoredResults.take(topK).toList();
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vectors must have the same length');
    }

    final dotProduct = _dotProduct(a, b);
    final magnitudeA = _magnitude(a);
    final magnitudeB = _magnitude(b);

    return magnitudeA > 0 && magnitudeB > 0
        ? dotProduct / (magnitudeA * magnitudeB)
        : 0.0;
  }

  static double _dotProduct(List<double> a, List<double> b) {
    return a.asMap().entries.fold(0.0, (sum, entry) {
      final index = entry.key;
      return sum + (entry.value * b[index]);
    });
  }

  static double _magnitude(List<double> vector) {
    return sqrt(vector.fold(0.0, (sum, value) => sum + pow(value, 2)));
  }
}