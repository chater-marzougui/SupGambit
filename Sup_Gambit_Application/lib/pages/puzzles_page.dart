import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';

import '../classes/chess_puzzle.dart';

class ChessPuzzlePage extends StatefulWidget {
  const ChessPuzzlePage({super.key});

  @override
  State<ChessPuzzlePage> createState() => _ChessPuzzlePageState();
}

class _ChessPuzzlePageState extends State<ChessPuzzlePage> {
  late Puzzle chessPuzzle;
  final ChessBoardController _chessBoardController = ChessBoardController();

  @override
  void initState() {
    super.initState();
    loadRandomPuzzle();
  }

  Future<void> loadRandomPuzzle() async {
    // Load your JSON file here
    String jsonString = await rootBundle.loadString('assets/puzzles.json');
    List<dynamic> jsonList = jsonDecode(jsonString);

    // Convert JSON to Puzzle objects
    List<Puzzle> puzzles = jsonList.map((json) => Puzzle.fromJson(json)).toList();

    // Select a random puzzle
    if (puzzles.isNotEmpty) {
      Random random = Random();
      int index = random.nextInt(puzzles.length);
      Puzzle randomPuzzle = puzzles[index];

      // Load the puzzle's FEN into the chess board
      _loadChessPuzzle(randomPuzzle);
    } else {
      print("No puzzles available.");
    }
  }

  void _loadChessPuzzle(Puzzle puzzle) {
    _chessBoardController.loadFen("r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Puzzle'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChessBoard(
              controller: _chessBoardController,
              boardColor: BoardColor.brown,
              boardOrientation: PlayerColor.white,
              onMove: () async {
                final move = _chessBoardController.value.getHistory({"verbose": true}).last;
                print(move);
                _chessBoardController.game.king_attacked(Color.BLACK);
                _onBoardMove(_convertToUCI(move));
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Puzzle ID: ${chessPuzzle.puzzleId}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Rating: ${chessPuzzle.rating}',
              style: const TextStyle(fontSize: 16),
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  loadRandomPuzzle();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('New Game'),
            ),
          ],
        ),
      ),
    );
  }

  void _onBoardMove(String move){
    print(chessPuzzle.moves.split(" "));
    print(move);
    if (move == chessPuzzle.moves.split(" ")[0]) {
      Fluttertoast.showToast(
          msg: "Correct Move!!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0
      );
      final from = chessPuzzle.moves.split(" ")[1].substring(0,2);
      final to = chessPuzzle.moves.split(" ")[1].substring(2,4);
      if(chessPuzzle.moves.split(" ")[0].length > 4){
        _chessBoardController.makeMoveWithPromotion(from: from, to: to,
        pieceToPromoteTo: chessPuzzle.moves.split(" ")[1].substring(4,5));
      } else {
        _chessBoardController.makeMove(from: from, to: to);
      }
      chessPuzzle.moves = chessPuzzle.moves.split(" ").sublist(2).join(" ");
    } else {
      Fluttertoast.showToast(
        msg: "Incorrect Move",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
      );
      _chessBoardController.undoMove();
    }
    _checkGameState();
  }

  String _convertToUCI(Map<String, dynamic> move) {
    String uciMove = move['from'] + move['to'];

    if (move['flags'] != null && move['flags'].contains('p')) {
      if (move['promotion'] != null) {
        // Convert piece name to UCI format
        final piece = move['promotion'].toString().toLowerCase();
        switch (piece) {
          case 'q':
          case 'queen':
            uciMove += 'q';
            break;
          case 'r':
          case 'rook':
            uciMove += 'r';
            break;
          case 'b':
          case 'bishop':
            uciMove += 'b';
            break;
          case 'n':
          case 'knight':
            uciMove += 'n';
            break;
          default:
          // Default to queen if not specified
            uciMove += 'q';
        }
      } else {
        // Default to queen promotion if not specified
        uciMove += 'q';
      }
    }

    return uciMove;
  }

  Future<void> _checkGameState() async {
    if (_chessBoardController.isInCheck()) {
      Fluttertoast.showToast(msg: 'Check! Defend your king!');
    } else {
      String msg = '';
      if (_chessBoardController.game.king_attacked(Color.BLACK)) {
        msg = 'Checkmate! You win!';
      } else if (_chessBoardController.game.king_attacked(Color.WHITE)) {
        msg = 'Checkmate! You lose!';
      } else if (_chessBoardController.isDraw()) {
        msg = 'Draw!';
      } else if (_chessBoardController.isStaleMate()) {
        msg = 'Stalemate! Draw!';
      } else if (_chessBoardController.isThreefoldRepetition()) {
        msg = 'Threefold Repetition! Draw!';
      } else if (_chessBoardController.isInsufficientMaterial()) {
        msg = 'Insufficient Material! Draw!';
      }
      if(msg != "") _showPlayAgainDialog(context, msg);
    }
    if(chessPuzzle.moves.isEmpty){
      _showPlayAgainDialog(context, "You have completed the puzzle!");
    }
  }

  void _showPlayAgainDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Game Over \n $message'),
          content: const Text('Would you like to play again?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _chessBoardController.loadFen(chessPuzzle.fen); // Reset the game state
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


}