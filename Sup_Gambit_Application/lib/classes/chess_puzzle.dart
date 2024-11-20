import 'package:json_annotation/json_annotation.dart';

part 'chess_puzzle.g.dart';

@JsonSerializable()
class ChessPuzzle {
  final Puzzle puzzle;
  final Game game;

  ChessPuzzle({
    required this.puzzle,
    required this.game,
  });

  factory ChessPuzzle.fromJson(Map<String, dynamic> json) => _$ChessPuzzleFromJson(json);
  Map<String, dynamic> toJson() => _$ChessPuzzleToJson(this);
}

@JsonSerializable()
class Puzzle {
  final String themes;
  final String openingFamily;
  final int popularity;
  final int nbPlays;
  final String puzzleId;
  String fen;
  String moves;
  final int rating;
  final int ratingDeviation;
  final String gameUrl;

  Puzzle({
    required this.themes,
    required this.openingFamily,
    required this.popularity,
    required this.nbPlays,
    required this.puzzleId,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.ratingDeviation,
    required this.gameUrl,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) => _$PuzzleFromJson(json);
  Map<String, dynamic> toJson() => _$PuzzleToJson(this);
}

@JsonSerializable()
class Game {
  final List<Analysis> analysis;
  final int createdAt;
  final String variant;
  final String status;
  final String pgn;

  Game({
    required this.analysis,
    required this.createdAt,
    required this.variant,
    required this.status,
    required this.pgn,
  });

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);
  Map<String, dynamic> toJson() => _$GameToJson(this);
}

@JsonSerializable()
class Analysis {
  final int? eval;
  final Judgment? judgment;
  final String? variation;
  final int? best;
  final int? mate;

  Analysis({
    this.eval,
    this.judgment,
    this.variation,
    this.best,
    this.mate,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) => _$AnalysisFromJson(json);
  Map<String, dynamic> toJson() => _$AnalysisToJson(this);
}

@JsonSerializable()
class Judgment {
  final String name;
  final String comment;

  Judgment({
    required this.name,
    required this.comment,
  });

  factory Judgment.fromJson(Map<String, dynamic> json) => _$JudgmentFromJson(json);
  Map<String, dynamic> toJson() => _$JudgmentToJson(this);
}