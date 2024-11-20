import 'dart:core';
import 'package:dartchess/dartchess.dart';

class ChessEngine {
  int _maxDepth = 5;
  String _finalChoice = "";
  int _numberOfNodesExplored = 0;

  final Map<PieceKind, double> _pieceValues = {
    PieceKind.whiteKing: 200,
    PieceKind.blackKing: 200,
    PieceKind.whiteQueen: 9,
    PieceKind.blackQueen: 9,
    PieceKind.whiteRook: 5,
    PieceKind.blackRook: 5,
    PieceKind.whiteBishop: 3,
    PieceKind.blackBishop: 3,
    PieceKind.whiteKnight: 3,
    PieceKind.blackKnight: 3,
    PieceKind.whitePawn: 1,
    PieceKind.blackPawn: 1,
  };

  String getBestMove(String fen, [int depth = 3]) {
    _maxDepth = depth;
    _finalChoice = ""; // Reset final choice
    bool isWhite = Chess.fromSetup(Setup.parseFen(fen)).turn == Side.white;
    _numberOfNodesExplored = 0;

    try {
      _minimax(fen, depth, -1000000000, 1000000000, true, isWhite);
      return _finalChoice;
    } catch (e) {
      print("Error in getBestMove: $e");
      return "";
    }
  }

  double _evaluate(String boardState) {
    Chess board = Chess.fromSetup(Setup.parseFen(boardState));
    double score = 0, materialScore = 0, pawnStructureScore = 0;
    double doubledPawns = 0, isolatedPawns = 0, blockedPawns = 0;
    List<int> whitePawns = List.filled(8, 0);
    List<int> blackPawns = List.filled(8, 0);

    // Evaluate material and collect pawn positions
    for (int file = 0; file < 8; file++) {
      for (int rank = 0; rank < 8; rank++) {
        Piece? piece = board.board.pieceAt(Square.fromCoords(File(file), Rank(rank)));
        if (piece != null) {
          double pieceValue = _pieceValues[piece.kind] ?? 0.0;
          if (piece.color == Side.white) {
            materialScore += pieceValue;
            if (piece.kind == PieceKind.whitePawn) {
              whitePawns[file]++;
            }
          } else {
            materialScore -= pieceValue;
            if (piece.kind == PieceKind.blackPawn) {
              blackPawns[file]++;
            }
          }
        }
      }
      if (whitePawns[file] > 1) doubledPawns++;
      if (blackPawns[file] > 1) doubledPawns--;
    }

    // Evaluate pawn structure
    for (int i = 0; i < 8; i++) {
      if (i == 0) {
        if (whitePawns[i + 1] == 0) isolatedPawns += whitePawns[i];
        if (blackPawns[i + 1] == 0) isolatedPawns -= blackPawns[i];
      } else if (i == 7) {
        if (whitePawns[i - 1] == 0) isolatedPawns += whitePawns[i];
        if (blackPawns[i - 1] == 0) isolatedPawns -= blackPawns[i];
      } else {
        if (whitePawns[i + 1] == 0 && whitePawns[i - 1] == 0) {
          isolatedPawns += whitePawns[i];
        }
        if (blackPawns[i + 1] == 0 && blackPawns[i - 1] == 0) {
          isolatedPawns -= blackPawns[i];
        }
      }
    }

    pawnStructureScore = -0.5 * (isolatedPawns + doubledPawns + blockedPawns);
    score = materialScore + pawnStructureScore;
    return score;
  }

  bool _isGameOver(String boardState) {
    return Chess.fromSetup(Setup.parseFen(boardState)).isGameOver;
  }

  List<String> _getAllPossibleNextStates(String boardState) {
    Chess board = Chess.fromSetup(Setup.parseFen(boardState));
    List<String> nextStates = [];
    var moves = board.legalMoves;

    moves.forEach((key, value) {
      for (var sqr in value.squares) {
        var move = NormalMove(from: key, to: sqr);
        Chess newBoard = Chess.fromSetup(Setup.parseFen(boardState));
        try {
          nextStates.add(newBoard.play(move).fen);
        } catch (e) {
          print("Error generating move: $e");
        }
      }
    });

    return nextStates;
  }

  double _minimax(String currentBoardState, int depth, double alpha, double beta,
      bool maximizingPlayer, bool white) {
    _numberOfNodesExplored++;

    if (depth == 0 || _isGameOver(currentBoardState)) {
      return white ? _evaluate(currentBoardState) : -_evaluate(currentBoardState);
    }

    var states = _getAllPossibleNextStates(currentBoardState);
    if (states.isEmpty) {
      return white ? _evaluate(currentBoardState) : -_evaluate(currentBoardState);
    }

    if (maximizingPlayer) {
      double mx = -1e9;
      String bestState = states[0];

      for (var state in states) {
        double eval = _minimax(state, depth - 1, alpha, beta, false, white);
        if (eval > mx) {
          mx = eval;
          bestState = state;
        }
        if (alpha < mx) alpha = mx;
        if (beta <= alpha) break;
      }

      if (depth == _maxDepth) {
        _finalChoice = bestState;
      }
      return mx;
    } else {
      double mn = 1e9;
      String bestState = states[0];

      for (var state in states) {
        double eval = _minimax(state, depth - 1, alpha, beta, true, white);
        if (eval < mn) {
          mn = eval;
          bestState = state;
        }
        if (mn < beta) beta = mn;
        if (beta <= alpha) break;
      }

      if (depth == _maxDepth) {
        _finalChoice = bestState;
      }
      return mn;
    }
  }

  String getUciMoveFromFens(String startFen, String endFen) {
    try {
      Chess startPos = Chess.fromSetup(Setup.parseFen(startFen));

      var moves = startPos.legalMoves;

      for (var from in moves.keys) {
        for (var to in moves[from]!.squares) {
          var move = NormalMove(from: from, to: to);
          Chess newPos = Chess.fromSetup(Setup.parseFen(startFen));
          String newFen = newPos.play(move).fen;

          if (_compareFenPositions(newFen, endFen)) {
            return '${from.name}${(to.name)}';
          }
        }
      }

      return ''; // No matching move found
    } catch (e) {
      print("Error in getUciMoveFromFens: $e");
      return '';
    }
  }

  bool _compareFenPositions(String fen1, String fen2) {
    List<String> components1 = fen1.split(' ');
    List<String> components2 = fen2.split(' ');

    return components1.take(4).join(' ') == components2.take(4).join(' ');
  }

  String getBestMoveUCI(String fen, [int depth = 3]) {
    String bestMoveFen = getBestMove(fen, depth);
    if (bestMoveFen.isEmpty) return '';

    return getUciMoveFromFens(fen, bestMoveFen);
  }

  /// Returns the number of positions evaluated in the last search
  int get nodesExplored => _numberOfNodesExplored;
}