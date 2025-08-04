// lib/logic/engine_vs_engine_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:stockfish/stockfish.dart';
import '../models/game_status.dart';
// NEW: Import our singleton service
import 'stockfish_service.dart';

class EngineVsEngineManager {
  final ChessBoardController controller = ChessBoardController();
  final Stockfish stockfish;
  final ValueNotifier<bool> isGameRunning = ValueNotifier(false);
  final ValueNotifier<List<String>> moveHistoryNotifier = ValueNotifier([]);
  final ValueNotifier<GameStatus> statusNotifier = ValueNotifier(GameStatus.playerTurn);

  final ValueNotifier<int> whiteMoveTime = ValueNotifier(1000);
  final ValueNotifier<int> blackMoveTime = ValueNotifier(1000);

  // THE FIX, PART 1: Get the shared engine instance from our singleton service.
  EngineVsEngineManager() : stockfish = StockfishService.instance.engine {
    _listenToEngine();
  }

  String get displayMessage {
    switch (statusNotifier.value) {
      case GameStatus.gameOver:
        if (controller.game.in_checkmate) {
          final winner = controller.game.turn == Color.WHITE ? 'Black' : 'White';
          return 'Checkmate! $winner wins.';
        } else if (controller.game.in_draw || controller.game.in_stalemate) {
          return 'Draw!';
        }
        return "Game Over";
      default:
        return controller.game.turn == Color.WHITE ? "White's Turn" : "Black's Turn";
    }
  }

  void _listenToEngine() {
    stockfish.stdout.listen((line) {
      if (line.contains('bestmove')) {
        final bestMove = line.split(' ')[1];
        final from = bestMove.substring(0,2);
        final to = bestMove.substring(2,4);

        // THE FIX, PART 2: The `promotion` parameter is removed from this call.
        controller.makeMove(from: from, to: to);
        _updateHistoryFromPgn();
        _updateGameStatus();

        if (isGameRunning.value && !controller.game.game_over) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (isGameRunning.value) requestNextMove();
          });
        } else {
          isGameRunning.value = false;
        }
      }
    });
  }
  
  void _updateGameStatus() {
    if (controller.game.in_checkmate || controller.game.in_draw || controller.game.in_stalemate) {
      statusNotifier.value = GameStatus.gameOver;
      isGameRunning.value = false;
    } else {
      statusNotifier.value = GameStatus.playerTurn;
    }
  }

  void startGame() {
    if (isGameRunning.value || controller.game.game_over) return;
    isGameRunning.value = true;
    requestNextMove();
  }

  void stopGame() {
    isGameRunning.value = false;
  }
  
  void resetGame() {
    stopGame();
    controller.resetBoard();
    _updateHistoryFromPgn();
    statusNotifier.value = GameStatus.playerTurn;
  }

  void requestNextMove() {
    final fen = controller.getFen();
    final moveTime = controller.game.turn == Color.WHITE ? whiteMoveTime.value : blackMoveTime.value;
    
    stockfish.stdin = 'position fen $fen';
    stockfish.stdin = 'go movetime $moveTime';
  }

  void _updateHistoryFromPgn() {
    final pgn = controller.game.pgn();
    if (pgn == null || pgn.isEmpty) {
      moveHistoryNotifier.value = [];
      return;
    }
    final lines = pgn.split('\n');
    final moveLine = lines.last;
    final moves = moveLine
        .replaceAll(RegExp(r'\d+\.\s?'), '')
        .split(' ')
        .where((s) => s.isNotEmpty && s != '*')
        .toList();
    moveHistoryNotifier.value = moves;
  }

  void dispose() {
    // We do NOT dispose the shared stockfish instance here.
    isGameRunning.dispose();
    whiteMoveTime.dispose();
    blackMoveTime.dispose();
    moveHistoryNotifier.dispose();
    statusNotifier.dispose();
  }
}