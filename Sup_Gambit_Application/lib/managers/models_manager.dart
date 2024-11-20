import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:sup_gambit/managers/chess_engine.dart';
import 'package:dartchess/dartchess.dart';

import 'board_detection_manager.dart';

class ChessVisionController {
  // Camera and model related fields
  late CameraController _cameraController;
  late OrtSession _modelSession;
  final List<CameraDescription> cameras;
  bool _isModelLoaded = false;
  DateTime? _lastFrameTime;
  final int _frameIntervalMs = 5000; // Process every 500ms
  final String _currentFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"; // Initial chess position
  List<List<double>> corners = [];
  late Image image;

  // MQTT related fields
  late MqttServerClient _mqttClient;
  final String _mqttBroker;
  final int _mqttPort;
  final String _mqttTopic;

  // Streams
  final _fenStreamController = StreamController<String>.broadcast();
  Stream<String> get fenStream => _fenStreamController.stream;
  get currentFen => _currentFen;
  get cameraController => _cameraController;
  get gameStateStream => _fenStreamController.stream;

  ChessVisionController({
    required this.cameras,
    required String mqttBroker,
    required int mqttPort,
    required String mqttTopic,
  }) : _mqttBroker = mqttBroker,
        _mqttPort = mqttPort,
        _mqttTopic = mqttTopic;

  final detector = ChessDetector();
  Future<void> initialize() async {
    await detector.initialize();
    await _initializeCamera();
    await _initializeModel();
    await _initializeMqtt();
  }


  Future<void> _initializeCamera() async {
    final camera = cameras.first;
    _cameraController = CameraController(
      camera,
      fps: 2,
      ResolutionPreset.high,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController.initialize();
    await _cameraController.startImageStream(_processFrame);
  }

  Future<void> _initializeModel() async {
    const endGamePredictorModelPath = 'assets/models/end_game_predict.onnx';
    final endGamePredictorRawAssetFile = await rootBundle.load(endGamePredictorModelPath);
    final endGamePredictorBytes = endGamePredictorRawAssetFile.buffer.asUint8List();


    final endGamePredictorSessionOptions = OrtSessionOptions();

    _modelSession = OrtSession.fromBuffer(endGamePredictorBytes, endGamePredictorSessionOptions);

    _isModelLoaded = true;
  }

  Future<void> _initializeMqtt() async {
    _mqttClient = MqttServerClient(_mqttBroker, 'chess_vision_client');
    _mqttClient.port = _mqttPort;

    try {
      await _mqttClient.connect();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error connecting to MQTT $e");
    }
  }

  void _processFrame(CameraImage cameraImage) async {

    final currentTime = DateTime.now();
    if (_lastFrameTime != null &&
        currentTime.difference(_lastFrameTime!).inMilliseconds < _frameIntervalMs) {
      return;
    }
    _lastFrameTime = currentTime;

    if (!_isModelLoaded) return;

    try {
      final rgbImage = _convertYUVToRGB(cameraImage);

      if (rgbImage == null) return;
      img.Image resizedImage = img.copyResize(rgbImage, width: 640, height: 640);

      final fen = await detector.processImage(resizedImage);
      ChessEngine().getBestMove(fen);
      final String move = ChessEngine().getUciMoveFromFens(fen, fen);
      if (move.isNotEmpty && isValidMove(move, fen)) {
        _sendMoveToRobot(move);
      }
      corners = detector.corners;

    } catch (e) {
      throw e;
      //Fluttertoast.showToast(msg: "Error processing frame: $e");
    }
  }

  bool isValidMove(String move, String boardState) {
    final from = move.substring(0, 2);
    final to = move.substring(2, 4);
    if(!from.isNotEmpty || !to.isNotEmpty) {
      return false;
    };

    Chess board = Chess.fromSetup(Setup.parseFen(boardState));

    var moves = board.legalMoves;
    for (var key in moves.keys) {
      for (var sqr in moves[key]!.squares) {
        if (key == from && sqr == to) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _sendMoveToRobot(String fen) async {
    if (_mqttClient.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(fen);
      _mqttClient.publishMessage(_mqttTopic, MqttQos.atLeastOnce, builder.payload!);
    }
  }

  img.Image? _convertYUVToRGB(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final rgbImage = img.Image(width: width, height: height);

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        final vIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        int Y = yPlane[yIndex];
        int U = uPlane[uIndex];
        int V = vPlane[vIndex];

        int r = (Y + 1.402 * (V - 128)).clamp(0, 255).toInt();
        int g = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).clamp(0, 255).toInt();
        int b = (Y + 1.772 * (U - 128)).clamp(0, 255).toInt();

        rgbImage.setPixel(x, y, img.ColorFloat64.rgb(r, g, b));
      }
    }
    return rgbImage;
  }

  int adjustDifficulty(List<String?> moves) {
    // Adjust difficulty level based on the number of moves
    // Run inference
    final OrtRunOptions runOptions = OrtRunOptions();

    final inputs = {'images': OrtValueTensor.createTensorWithData(moves)};
    final output = _modelSession
        .run(runOptions, inputs, ['output0']);

    final List<dynamic>? batchOutput = output.first?.value as List<dynamic>?;
    runOptions.release();

    int result = 0;
    // 0 if white wins, 1 if black wins, 2 if draw

    if(batchOutput == null) {
      return 2;
    } else {
      for (var output in batchOutput) {
        if (output[0] > output[1] && output[0] > output[2]) {
          result = 0;
        } else if (output[1] > output[0] && output[1] > output[2]) {
          result = 1;
        } else {
          result = 2;
        }
      }
    }
    return result;
  }

  void setDifficulty(String difficulty) {
    // Set difficulty level
  }

  void dispose() {
    _cameraController.dispose();
    _fenStreamController.close();
    _mqttClient.disconnect();
    OrtEnv.instance.release();
  }
}