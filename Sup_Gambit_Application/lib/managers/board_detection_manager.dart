import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'dart:typed_data';
import 'dart:developer' as dev;

class ChessDetector {
  late OrtSession cornerSession;
  late OrtSession pieceSession;
  final Map<int, String> pieceMapping = {
    1: "b", 2: "k", 3: "n", 4: "p", 5: "q", 6: "r",
    7: "B", 8: "K", 9: "N", 10: "P", 11: "Q", 12: "R"
  };

  final Map<String, int> maxPieces = {
    "b": 2, "k": 1, "n": 2, "p": 8, "q": 1, "r": 2,
    "B": 2, "K": 1, "N": 2, "P": 8, "Q": 1, "R": 2
  };

  List<List<double>> corners = [];
  late Image transformedImage;

  Future<void> initialize() async {
    try {
      const cornersModelPath = 'assets/models/best_corners.onnx';
      final cornersRawAssetFile = await rootBundle.load(cornersModelPath);
      final cornersBytes = cornersRawAssetFile.buffer.asUint8List();


      const piecesModelPath = 'assets/models/best_pieces.onnx';
      final piecesRawAssetFile = await rootBundle.load(piecesModelPath);
      final piecesBytes = piecesRawAssetFile.buffer.asUint8List();

      final cornerSessionOptions = OrtSessionOptions();
      final piecesSessionOptions = OrtSessionOptions();

      cornerSession = OrtSession.fromBuffer(cornersBytes, cornerSessionOptions);
      pieceSession = OrtSession.fromBuffer(piecesBytes, piecesSessionOptions);

    } catch (e) {
      print('Error initializing models: $e');
      rethrow;
    }
  }



  Future<String> processImage(img.Image image) async {
    try {
      // Detect corners
      final cornerResults = await detectCorners(image);
      if (cornerResults.isEmpty) {
        return '';
      }

      // Transform image using detected corners
      transformedImage = _transformImage(image, cornerResults);

      // Detect pieces
      final pieceResults = await detectPieces(transformedImage);
      for (var i = 0; i < pieceResults.length; i++) {
        dev.log("Line 59, Model: pieces detector, $pieceResults[i]");
      }

      // Generate FEN notation
      return generateFEN(pieceResults, transformedImage.width, transformedImage.height);
    } catch (e) {
      throw e;
    }
  }

  Future<List<List<double>>> detectCorners(img.Image image) async {
    final inputShape = [1, 3, 640, 640];
    final inputArray = Float32List(inputShape.reduce((a, b) => a * b));

    // Normalize and transform image data
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = image.getPixel(x, y);
          final value = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
          // YOLO expects normalized values [0-1]
          inputArray[c * 640 * 640 + y * 640 + x] = value / 255.0;
        }
      }
    }

    // Run inference
    final OrtRunOptions runOptions = OrtRunOptions();

  final inputs = {'images': OrtValueTensor.createTensorWithDataList(inputArray, inputShape)};
  final output = cornerSession
      .run(runOptions, inputs, ['output0']);

    final List<dynamic>? batchOutput = output.first?.value as List<dynamic>?;
    runOptions.release();

    return _processCorners(batchOutput?.first as List<List<double>>);
  }

  double _dist(double x1, double y1, double x2, double y2) {
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
  }

  List<List<double>> _processCorners(List<List<double>> cornersOutput) {
    final results = <List<double>>[];
    const confidenceThreshold = 0.1;
    List<List<double>> newCorners=[];
    newCorners.add([1000000000, 1000000000]); // First corner (x1, y1)
    newCorners.add([0, 1000000000]); // Second corner (x2, y2)
    newCorners.add([1000000000, 0]); // Third corner (x3, y3)
    newCorners.add([0, 0]); // Fourth corner (x4, y4)

    for (int i = 0; i < cornersOutput[0].length; i++) {
      final x = cornersOutput[0][i];
      final y = cornersOutput[1][i];
      final confidence = cornersOutput[4][i];

      if (confidence >= confidenceThreshold) {
        results.add([x, y]);
      }
    }
    for(var a in results){
      double x=a[0],y=a[1];
      if(_dist(x,y,0,0)<_dist(newCorners[0][0],newCorners[0][1],0,0)){
        newCorners[0][0]=x;
        newCorners[0][1]=y;
      }
      if(_dist(x,y,640,0)<_dist(newCorners[1][0],newCorners[1][1],640,0)){
        newCorners[1][0]=x;
        newCorners[1][1]=y;
      }
      if(_dist(x,y,0,640)<_dist(newCorners[2][0],newCorners[2][1],0,640)){
        newCorners[2][0]=x;
        newCorners[2][1]=y;
      }
      if(_dist(x,y,640,640)<_dist(newCorners[3][0],newCorners[3][1],640,640)){
        newCorners[3][0]=x;
        newCorners[3][1]=y;
      }
    }

    corners = newCorners;
    return newCorners;
  }


  img.Image _transformImage(img.Image image, List<List<double>> corners) {
    // Implement perspective transform similar to OpenCV's warpPerspective
    // This is a simplified version - you might want to use a more sophisticated transform
    const width = 640; // Standard size for chess board detection
    const height = 640;

    final transformed = img.Image(width: width, height: height);

    // Calculate transformation matrix
    final matrix = getPerspectiveTransform(corners, [
      [0, 0],
      [width - 1, 0],
      [width - 1, height - 1],
      [0, height - 1]
    ]);

    // Apply transformation
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final srcPoint = applyTransform(matrix, [x.toDouble(), y.toDouble()]);
        final srcX = srcPoint[0].round();
        final srcY = srcPoint[1].round();

        if (srcX >= 0 && srcX < image.width && srcY >= 0 && srcY < image.height) {
          transformed.setPixel(x, y, image.getPixel(srcX, srcY));
        }
      }
    }

    return transformed;
  }

  Future<List<Detection>> detectPieces(img.Image image) async {
    // Similar to corner detection, but process outputs differently
    final inputShape = [1, 3, image.height, image.width];
    final inputArray = Float32List(inputShape.reduce((a, b) => a * b));

    // Normalize and transform image data
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        inputArray[y * image.width + x] = pixel.r / 255.0;
        inputArray[image.height * image.width + y * image.width + x] = pixel.g / 255.0;
        inputArray[2 * image.height * image.width + y * image.width + x] = pixel.b / 255.0;
      }
    }

    final OrtRunOptions runOptions = OrtRunOptions();
    final inputs = {'images': OrtValueTensor.createTensorWithDataList(inputArray, inputShape)};
    final outputs = pieceSession.run(runOptions, inputs);

    runOptions.release();
    // Process outputs to get piece detections
    return processDetections(outputs);
  }

  String generateFEN(List<Detection> detections, int width, int height) {
    final board = List.generate(8, (_) => List.filled(8, '1'));
    final pieceCounts = Map<String, int>.fromIterables(
        pieceMapping.values,
        List.filled(pieceMapping.length, 0)
    );

    // Process each detection
    for (final detection in detections) {
      final squareIndex = mapDetectionToSquare(detection, width, height);
      if (squareIndex != null) {
        final piece = pieceMapping[detection.classId];
        if (piece != null && pieceCounts[piece]! < maxPieces[piece]!) {
          final row = squareIndex ~/ 8;
          final col = squareIndex % 8;
          board[row][col] = piece;
          pieceCounts[piece] = pieceCounts[piece]! + 1;
        }
      }
    }

    // Convert board to FEN notation
    return board.map((row) => row.join('')).join('/');
  }

  // Mathematical utility functions for perspective transform
  List<List<double>> multiplyMatrices(List<List<double>> a, List<List<double>> b) {
    final rows = a.length;
    final cols = b[0].length;
    final List<List<double>> result = List.generate(
      rows,
          (_) => List.filled(cols, 0.0),
    );

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        for (int k = 0; k < b.length; k++) {
          result[i][j] += a[i][k] * b[k][j];
        }
      }
    }
    return result;
  }

  List<List<double>> getPerspectiveTransform(
      List<List<double>> src, List<List<double>> dst) {
    // Create the coefficient matrix A and vectors b for solving the equation Ax = b
    final List<List<double>> A = List.generate(8, (_) => List.filled(8, 0.0));
    final List<double> b = List.filled(8, 0.0);

    for (int i = 0; i < 4; i++) {
      final srcX = src[i][0];
      final srcY = src[i][1];
      final dstX = dst[i][0];
      final dstY = dst[i][1];

      // Fill matrix A
      A[i] = [srcX, srcY, 1.0, 0.0, 0.0, 0.0, -srcX * dstX, -srcY * dstX];
      A[i + 4] = [0.0, 0.0, 0.0, srcX, srcY, 1.0, -srcX * dstY, -srcY * dstY];

      // Fill vector b
      b[i] = dstX;
      b[i + 4] = dstY;
    }

    // Solve the system of equations using Gaussian elimination
    final List<double> x = solveSystem(A, b);

    // Construct the transformation matrix
    return [
      [x[0], x[1], x[2]],
      [x[3], x[4], x[5]],
      [x[6], x[7], 1.0],
    ];
  }

  List<double> solveSystem(List<List<double>> A, List<double> b) {
    final n = A.length;
    final List<List<double>> augmented = List.generate(
      n,
          (i) => [...A[i], b[i]],
    );

    // Gaussian elimination
    for (int i = 0; i < n; i++) {
      // Find pivot
      var maxEl = augmented[i][i].abs();
      var maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (augmented[k][i].abs() > maxEl) {
          maxEl = augmented[k][i].abs();
          maxRow = k;
        }
      }

      // Swap maximum row with current row
      if (maxRow != i) {
        final temp = augmented[i];
        augmented[i] = augmented[maxRow];
        augmented[maxRow] = temp;
      }

      // Make all rows below this one 0 in current column
      for (int k = i + 1; k < n; k++) {
        final c = -augmented[k][i] / augmented[i][i];
        for (int j = i; j <= n; j++) {
          if (i == j) {
            augmented[k][j] = 0;
          } else {
            augmented[k][j] += c * augmented[i][j];
          }
        }
      }
    }

    // Back substitution
    final List<double> x = List.filled(n, 0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = augmented[i][n] / augmented[i][i];
      for (int k = i - 1; k >= 0; k--) {
        augmented[k][n] -= augmented[k][i] * x[i];
      }
    }

    return x;
  }

  List<double> applyTransform(List<List<double>> matrix, List<double> point) {
    final double x = point[0];
    final double y = point[1];

    final double w = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2];
    if (w.abs() < 1e-10) return [0, 0]; // Handle division by zero

    final double transformedX =
        (matrix[0][0] * x + matrix[0][1] * y + matrix[0][2]) / w;
    final double transformedY =
        (matrix[1][0] * x + matrix[1][1] * y + matrix[1][2]) / w;

    return [transformedX, transformedY];
  }

  List<Detection> processDetections(List<OrtValue?> outputs) {
    final List<Detection> detections = [];
    print("Line 319, Model: pieces detector, ${outputs.length}");
    print("Line 320, Model: pieces detector, ${outputs[0]?.value}");

    // Extract boxes, scores, and classes from the model output
    // final boxes = outputs['output0']?.value as List<List<double>>;
    // final scores = outputs['output1']?.value as List<double>;
    // final classes = outputs['output2']?.value as List<int>;
    //
    // // Apply confidence threshold
    // const confidenceThreshold = 0.25;
    //
    // for (int i = 0; i < scores.length; i++) {
    //   if (scores[i] >= confidenceThreshold) {
    //     detections.add(Detection(
    //       x1: boxes[i][0],
    //       y1: boxes[i][1],
    //       x2: boxes[i][2],
    //       y2: boxes[i][3],
    //       classId: classes[i],
    //       confidence: scores[i],
    //     ));
    //   }
    // }

    return detections;
  }

  int? mapDetectionToSquare(Detection detection, int imageWidth, int imageHeight) {
    // Calculate the center point of the detection
    final centerX = (detection.x1 + detection.x2) / 2;
    final centerY = (detection.y1 + detection.y2) / 2;

    // Calculate square size based on image dimensions
    final squareWidth = imageWidth / 8;
    final squareHeight = imageHeight / 8;

    // Calculate which square the center falls into
    final col = (centerX / squareWidth).floor();
    final row = (centerY / squareHeight).floor();

    // Validate the square is within bounds
    if (row >= 0 && row < 8 && col >= 0 && col < 8) {
      return row * 8 + col;
    }

    return null;
  }
}

class Detection {
  final double x1, y1, x2, y2;
  final int classId;
  final double confidence;

  Detection({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.classId,
    required this.confidence,
  });
}