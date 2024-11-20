import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:camera/camera.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sup_gambit/managers/chess_engine.dart';
import 'dart:async';

import '../managers/models_manager.dart';

class ChessMainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ChessMainScreen({
    super.key,
    required this.cameras,
  });

  @override
  State<ChessMainScreen> createState() => _ChessMainScreenState();
}

class _ChessMainScreenState extends State<ChessMainScreen> {
  late ChessVisionController _visionController;
  late ChessBoardController _boardController;
  final ChessEngine _chessEngine = ChessEngine();
  List<BoardArrow> _arrows = [];
  late Timer _achievementTimer;
  int _hintsRemaining = 3;
  String _selectedDifficulty = 'medium';
  List<String> _currentAchievements = [];
  String? _currentOpening;
  String? _currentError;
  bool _showCamera = true;
  bool _initialized = false;
  // Achievement display queue
  final Queue<String> _achievementQueue = Queue<String>();

  @override
  void initState() {
    super.initState();

    _initializeControllers();
    _startAchievementTimer();
    _boardController = ChessBoardController();

    // Listen to possible moves from the board controller
    _boardController.addListener(() {
      setState(() {
        _arrows = [];
        List<Move> possibleMoves = _boardController.getPossibleMoves();

        _arrows = possibleMoves.map((move) {
          return BoardArrow(
            from: move.fromAlgebraic,
            to: move.toAlgebraic,
            color: Colors.blue.withOpacity(0.5),
          );
          }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview (conditionally shown)
            if (_visionController.cameraController != null && _showCamera)
                Stack(
                  children: [
                    CameraPreview(_visionController.cameraController),
                    CustomPaint(
                      painter: CornerPainter(_visionController.corners,
                          previewSize: _visionController.cameraController.value.previewSize
                      ),
                    ),
                  ],
                ),
            Column(
              children: [
                // Top Bar
                _buildTopBar(),

                if(!_showCamera)
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ChessBoard(
                          enableUserMoves: true,
                          controller: _boardController,
                          boardColor: BoardColor.orange,
                          arrows: _arrows,
                          onMove: () async {
                            // final playerMove = _boardController.value
                            //     .getHistory({"verbose": true}).last;
                            //
                            setState(() {
                              _chessEngineMove(_boardController.value.fen);
                              _checkGameState();
                            });
                          },
                        ),
                      ),
                    ),
                ),
                Expanded(
                  child: ValueListenableBuilder<Chess>(
                    valueListenable: _boardController,
                    builder: (context, game, _) {
                      return Text(
                        _boardController.getSan().fold(
                          '',
                              (previousValue, element) =>
                          '$previousValue\n${element ?? ''}',
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls
                _buildBottomControls(),
              ],
            ),

            if (_currentAchievements.isNotEmpty)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: _buildAchievementBanner(),
              ),

            // Error Messages
            if (_currentError != null)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: _buildErrorBanner(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkGameState() async {
    if (_boardController.isInCheck()) {
      Fluttertoast.showToast(msg: 'Check! Defend your king!');
    } else {
      String msg = '';
      if (_boardController.game.king_attacked(Color.BLACK)) {
        msg = 'Checkmate! You win!';
      } else if (_boardController.game.king_attacked(Color.WHITE)) {
        msg = 'Checkmate! You lose!';
      } else if (_boardController.isDraw()) {
        msg = 'Draw!';
      } else if (_boardController.isStaleMate()) {
        msg = 'Stalemate! Draw!';
      } else if (_boardController.isThreefoldRepetition()) {
        msg = 'Threefold Repetition! Draw!';
      } else if (_boardController.isInsufficientMaterial()) {
        msg = 'Insufficient Material! Draw!';
      }
      if(msg!= "") _showPlayAgainDialog(context, msg);
    }
  }

  void _showPlayAgainDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(message),
          content: const Text('Would you like to play again?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _boardController.resetBoard(); // Reset the game state
              },
            ),
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _chessEngineMove(String fen) async {
     int diffucultyLevel = _visionController.adjustDifficulty(_boardController.getSan());
    final move = _chessEngine.getBestMoveUCI(
      _boardController.value.fen,
      diffucultyLevel,
    );

    final from = move.toString().substring(0,2);
    final to = move.toString().substring(2,4);
    if(move.toString().length == 4){
      _boardController.makeMove(from: from, to: to);
    } else if (move.toString().length == 5){
      final promotion = move.toString().substring(4,5);
      _boardController.makeMoveWithPromotion(from: from, to: to, pieceToPromoteTo: promotion);
    }
    _arrows = [
      BoardArrow(
        from: from,
        to: to,
        color: Colors.red.withOpacity(0.8),
      ),
    ];

  }

  void showHintArrows(String move) {
    if(move.isEmpty) {
      return;
    }

    setState(() {
      _arrows = [BoardArrow(
      from: move.substring(0, 2),
      to: move.substring(2, 4),
      color: Colors.green.withOpacity(0.5),
      )];
    });
  }

  Future<void> _requestHint() async {
    if (_hintsRemaining > 0) {
      try {
        final hintMove = _chessEngine
            .getBestMoveUCI(_boardController.value.fen, 4);
        showHintArrows(hintMove);

        setState(() {
          _hintsRemaining--;
        });
      } catch (e) {
        Fluttertoast.showToast(msg: 'Error getting hint: $e');
      }
    } else {
      Fluttertoast.showToast(msg: 'No hints remaining');
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Opening Name
          if (_currentOpening != null)
            Expanded(
              child: Text(
                _currentOpening!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Difficulty Dropdown
          DropdownButton<String>(
            value: _selectedDifficulty,
            dropdownColor: Colors.black87,
            style: const TextStyle(color: Colors.white),
            items: ['easy', 'medium', 'hard'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toUpperCase()),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedDifficulty = newValue;
                });
                _visionController.setDifficulty(newValue);
              }
            },
          ),

          // Camera Toggle
          IconButton(
            icon: Icon(
              _showCamera ? Icons.videocam : Icons.videocam_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showCamera = !_showCamera;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black54,
      child: Column(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hints: $_hintsRemaining',
                style: const TextStyle(color: Colors.white),
              ),
              ElevatedButton(
                onPressed: _requestHint,
                child: const Text('Get Hint'),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Undo Button
              ElevatedButton.icon(
                onPressed: () {
                  _boardController.undoMove();
                },
                icon: const Icon(Icons.undo),
                label: const Text('Undo'),
              ),

              // New Game Button
              ElevatedButton.icon(
                onPressed: () {
                  _boardController.resetBoard();
                  setState(() {
                    _hintsRemaining = 3;
                    _currentOpening = null;
                    _currentError = null;
                    _achievementQueue.clear();
                    _currentAchievements = [];
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('New Game'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // String _convertToUCI(Map<String, dynamic> move) {
  //   String uciMove = move['from'] + move['to'];
  //
  //   if (move['flags'] != null && move['flags'].contains('p')) {
  //     if (move['promotion'] != null) {
  //       // Convert piece name to UCI format
  //       final piece = move['promotion'].toString().toLowerCase();
  //       switch (piece) {
  //         case 'q':
  //         case 'queen':
  //           uciMove += 'q';
  //           break;
  //         case 'r':
  //         case 'rook':
  //           uciMove += 'r';
  //           break;
  //         case 'b':
  //         case 'bishop':
  //           uciMove += 'b';
  //           break;
  //         case 'n':
  //         case 'knight':
  //           uciMove += 'n';
  //           break;
  //         default:
  //         // Default to queen if not specified
  //           uciMove += 'q';
  //       }
  //     } else {
  //       // Default to queen promotion if not specified
  //       uciMove += 'q';
  //     }
  //   }
  //
  //   return uciMove;
  // }

  Future<void> _initializeControllers() async {
    _visionController = ChessVisionController(
        cameras: widget.cameras,
        mqttBroker: "chateresp.broker.mqtt.lt", // Your Local Tunnel URL
        mqttPort: 1883,
        mqttTopic: "chess/moves"
    );

    await _visionController.initialize();
    setState(() {
      _initialized = true;
    });
    // Listen to game state updates
    _visionController.gameStateStream.listen(_handleGameStateUpdate);
  }

  void _handleGameStateUpdate(ChessGameState state) {
    setState(() {
      // Update board position if valid move
      if (state.engineMove != null) {
        _boardController.makeMove(from: _boardController.value.fen, to: state.engineMove!);
      }

      // Update opening information
      _currentOpening = state.opening;

      // Update error message
      _currentError = state.moveError;

      // Add new achievements to queue
      for (var achievement in state.achievements) {
        _achievementQueue.add(achievement);
      }
    });
  }

  void _startAchievementTimer() {
    _achievementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_achievementQueue.isNotEmpty) {
        setState(() {
          _currentAchievements = [_achievementQueue.removeFirst()];
        });
      } else {
        setState(() {
          _currentAchievements = [];
        });
      }
    });
  }

  // Future<void> _reset() async {
  //   _boardController.resetBoard();
  //   Stream<dynamic> moveStream = await _visionController.startGame();
  //   moveStream.listen(
  //         (move) {
  //           if(move.toString().length == 4){
  //             final from = move.toString().substring(0,2);
  //             final to = move.toString().substring(2,4);
  //             _boardController.makeMove(from: from, to: to);
  //           } else if (move.toString().length == 5){
  //             final from = move.toString().substring(0,2);
  //             final to = move.toString().substring(2,4);
  //             final promotion = move.toString().substring(4,5);
  //             _boardController.makeMoveWithPromotion(from: from, to: to, pieceToPromoteTo: promotion);
  //           }
  //       final from = move.toString().substring(0,2);
  //       final to = move.toString().substring(2,4);
  //           _boardController.makeMove(from: from, to: to);
  //     },
  //     onDone: () {
  //       // TODO: Handle game end
  //     },
  //   );
  // }

  Widget _buildAchievementBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: _currentAchievements.map((achievement) {
          return Text(
            achievement,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _currentError!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void dispose() {
    _visionController.dispose();
    _achievementTimer.cancel();
    super.dispose();
  }
}

class ChessGameState {
  final String? moveError;
  final String? engineMove;
  final String? opening;
  final List<String> achievements;
  final String? hint;

  ChessGameState({
    this.moveError,
    this.engineMove,
    this.opening,
    this.achievements = const [],
    this.hint,
  });
}

class CornerPainter extends CustomPainter {
  final List<dynamic> corners;
  final Size? previewSize;

  CornerPainter(this.corners, {this.previewSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize == null) return;

    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    for (var point in corners) {
      // Calculate scaled coordinates based on preview size
      double x = point[0] * (size.width / previewSize!.width);
      double y = point[1] * (size.height / previewSize!.height);

      canvas.drawCircle(Offset(x, y), 5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}