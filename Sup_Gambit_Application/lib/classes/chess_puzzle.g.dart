// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chess_puzzle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChessPuzzle _$ChessPuzzleFromJson(Map<String, dynamic> json) => ChessPuzzle(
      puzzle: Puzzle.fromJson(json['puzzle'] as Map<String, dynamic>),
      game: Game.fromJson(json['game'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ChessPuzzleToJson(ChessPuzzle instance) =>
    <String, dynamic>{
      'puzzle': instance.puzzle,
      'game': instance.game,
    };

Puzzle _$PuzzleFromJson(Map<String, dynamic> json) => Puzzle(
      themes: json['themes'] as String,
      openingFamily: json['openingFamily'] as String,
      popularity: (json['popularity'] as num).toInt(),
      nbPlays: (json['nbPlays'] as num).toInt(),
      puzzleId: json['puzzleId'] as String,
      fen: json['fen'] as String,
      moves: json['moves'] as String,
      rating: (json['rating'] as num).toInt(),
      ratingDeviation: (json['ratingDeviation'] as num).toInt(),
      gameUrl: json['gameUrl'] as String,
    );

Map<String, dynamic> _$PuzzleToJson(Puzzle instance) => <String, dynamic>{
      'themes': instance.themes,
      'openingFamily': instance.openingFamily,
      'popularity': instance.popularity,
      'nbPlays': instance.nbPlays,
      'puzzleId': instance.puzzleId,
      'fen': instance.fen,
      'moves': instance.moves,
      'rating': instance.rating,
      'ratingDeviation': instance.ratingDeviation,
      'gameUrl': instance.gameUrl,
    };

Game _$GameFromJson(Map<String, dynamic> json) => Game(
      analysis: (json['analysis'] as List<dynamic>)
          .map((e) => Analysis.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: (json['createdAt'] as num).toInt(),
      variant: json['variant'] as String,
      status: json['status'] as String,
      pgn: json['pgn'] as String,
    );

Map<String, dynamic> _$GameToJson(Game instance) => <String, dynamic>{
      'analysis': instance.analysis,
      'createdAt': instance.createdAt,
      'variant': instance.variant,
      'status': instance.status,
      'pgn': instance.pgn,
    };

Analysis _$AnalysisFromJson(Map<String, dynamic> json) => Analysis(
      eval: (json['eval'] as num?)?.toInt(),
      judgment: json['judgment'] == null
          ? null
          : Judgment.fromJson(json['judgment'] as Map<String, dynamic>),
      variation: json['variation'] as String?,
      best: (json['best'] as num?)?.toInt(),
      mate: (json['mate'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AnalysisToJson(Analysis instance) => <String, dynamic>{
      'eval': instance.eval,
      'judgment': instance.judgment,
      'variation': instance.variation,
      'best': instance.best,
      'mate': instance.mate,
    };

Judgment _$JudgmentFromJson(Map<String, dynamic> json) => Judgment(
      name: json['name'] as String,
      comment: json['comment'] as String,
    );

Map<String, dynamic> _$JudgmentToJson(Judgment instance) => <String, dynamic>{
      'name': instance.name,
      'comment': instance.comment,
    };
