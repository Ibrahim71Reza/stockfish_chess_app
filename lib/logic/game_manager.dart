// lib/logic/game_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:stockfish/stockfish.dart';
import 'package:chess/chess.dart' as chess_logic;
import '../models/game_status.dart';
import 'stockfish_service.dart';

class GameManager {
  final ChessBoardController controller = ChessBoardController();
  final Stockfish stockfish;
  final ValueNotifier<GameStatus> statusNotifier = ValueNotifier(GameStatus.playerTurn);
  final ValueNotifier<List<String>> possibleMovesNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>> moveHistoryNotifier = ValueNotifier([]);
  final ValueNotifier<List<chess_logic.Piece>> whiteCapturedNotifier = ValueNotifier([]);
  final ValueNotifier<List<chess_logic.Piece>> blackCapturedNotifier = ValueNotifier([]);
  final ValueNotifier<List<String>?> hintNotifier = ValueNotifier(null);

  int engineMoveTime = 1000;
  PlayerColor playerSide = PlayerColor.white;
  String? selectedSquare;

  GameManager() : stockfish = StockfishService.instance.engine {
    _listenToEngine();
  }

  String? get kingInCheckSquare {
    if (controller.game.in_check) {
      final kingColor = controller.game.turn;
      final kingIndex = controller.game.kings[kingColor];
      if (kingIndex != null) {
        return chess_logic.Chess.SQUARES[kingIndex];
      }
    }
    return null;
  }

  String get displayMessage {
    switch (statusNotifier.value) {
      case GameStatus.playerTurn:
        return 'Your Turn';
      case GameStatus.engineTurn:
        return 'Stockfish is thinking...';
      case GameStatus.gameOver:
        final fen = controller.getFen();
        final isWhiteTurn = fen.split(' ')[1] == 'w';
        if (controller.isCheckMate()) {
          return isWhiteTurn ? 'Checkmate! Black wins.' : 'Checkmate! White wins.';
        } else {
          return 'Draw!';
        }
    }
  }

  void _listenToEngine() {
    stockfish.stdout.listen((line) {
      if (line.contains('bestmove')) {
        if (statusNotifier.value == GameStatus.engineTurn) {
          _handleBestMove(line);
        } else {
          _handleHintResponse(line);
        }
      }
    });
  }

  void _handleBestMove(String line) {
    final bestMove = line.split(' ')[1];
    final from = bestMove.substring(0, 2);
    final to = bestMove.substring(2, 4);
    final promotion = bestMove.length > 4 ? bestMove.substring(4, 5) : null;
    _makeMove(from, to, promotion: promotion, isPlayerMove: false);
  }

  void _handleHintResponse(String line) {
    final bestMove = line.split(' ')[1];
    final from = bestMove.substring(0, 2);
    final to = bestMove.substring(2, 4);
    hintNotifier.value = [from, to];
    Future.delayed(const Duration(seconds: 3), () {
      if (hintNotifier.value != null) {
        hintNotifier.value = null;
      }
    });
  }

  void requestHint() {
    if (statusNotifier.value == GameStatus.playerTurn) {
      final fen = controller.getFen();
      stockfish.stdin = 'position fen $fen';
      stockfish.stdin = 'go movetime 250'; 
    }
  }

  void onSquareTapped(String squareName, BuildContext context) async {
    final game = chess_logic.Chess.fromFEN(controller.getFen());

    if (possibleMovesNotifier.value.contains(squareName) && selectedSquare != null) {
      final from = selectedSquare!;
      String? promotion;
      final piece = game.get(from);
      if (piece?.type == chess_logic.PieceType.PAWN && 
         ((piece?.color == chess_logic.Color.WHITE && from[1] == '7' && squareName[1] == '8') ||
          (piece?.color == chess_logic.Color.BLACK && from[1] == '2' && squareName[1] == '1'))) {
        promotion = await _showPromotionDialog(context);
        if (promotion == null) return;
      }
      _makeMove(from, squareName, promotion: promotion, isPlayerMove: true);
      return;
    }
    
    final piece = game.get(squareName);
    if (piece != null && piece.color == (playerSide == PlayerColor.white ? chess_logic.Color.WHITE : chess_logic.Color.BLACK)) {
      selectedSquare = squareName;
      final List<String> highlightedMoves = [];
      final moves = game.moves({'square': squareName, 'verbose': true});
      for (final move in moves) {
        highlightedMoves.add(move['to']);
      }
      possibleMovesNotifier.value = highlightedMoves;
    } else {
      selectedSquare = null;
      possibleMovesNotifier.value = [];
    }
  }

  void _makeMove(String from, String to, {String? promotion, required bool isPlayerMove}) {
    final capturedPiece = controller.game.get(to);
    final moveResult = controller.game.move({'from': from, 'to': to, 'promotion': promotion});
    if (moveResult == null) return;

    if (capturedPiece != null) {
      if (capturedPiece.color == chess_logic.Color.WHITE) {
        blackCapturedNotifier.value = List.from(blackCapturedNotifier.value)..add(capturedPiece);
      } else {
        whiteCapturedNotifier.value = List.from(whiteCapturedNotifier.value)..add(capturedPiece);
      }
    }
    
    controller.makeMove(from: from, to: to); // Promotion is handled by internal game.move
    hintNotifier.value = null;
    _updateHistoryFromPgn();
    possibleMovesNotifier.value = [];
    selectedSquare = null;
    _updateGameStatus();
    
    if (isPlayerMove && statusNotifier.value == GameStatus.playerTurn) {
      statusNotifier.value = GameStatus.engineTurn;
      _requestEngineMove();
    }
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
  
  void undoMove() {
    if (statusNotifier.value == GameStatus.gameOver || controller.game.history.isEmpty) {
      return;
    }
    controller.game.undo();
    if (controller.game.history.isNotEmpty && controller.game.turn == (playerSide == PlayerColor.white ? chess_logic.Color.BLACK : chess_logic.Color.WHITE)) {
      controller.game.undo();
    }
    controller.loadFen(controller.game.fen);
    _updateHistoryFromPgn();
    _recalculateCapturedPieces();
    possibleMovesNotifier.value = [];
    selectedSquare = null;
    statusNotifier.value = GameStatus.playerTurn;
    hintNotifier.value = null;
  }
  
  void _recalculateCapturedPieces() {
    final initialPieceCount = {'p': 8, 'r': 2, 'n': 2, 'b': 2, 'q': 1,'P': 8, 'R': 2, 'N': 2, 'B': 2, 'Q': 1};
    final currentPieces = <String, int>{};
    for (var square in chess_logic.Chess.SQUARES.values) {
      final piece = controller.game.get(square);
      if (piece != null) {
        final key = piece.color == chess_logic.Color.WHITE ? piece.type.toUpperCase() : piece.type.toLowerCase();
        currentPieces[key] = (currentPieces[key] ?? 0) + 1;
      }
    }
    final wCaptured = <chess_logic.Piece>[];
    final bCaptured = <chess_logic.Piece>[];
    initialPieceCount.forEach((key, count) {
      final capturedCount = count - (currentPieces[key] ?? 0);
      if (capturedCount > 0) {
        final pieceChar = key.toLowerCase();
        final type = _getPieceTypeFromChar(pieceChar);
        final color = key == key.toUpperCase() ? chess_logic.Color.WHITE : chess_logic.Color.BLACK;
        if (type != null) {
          for (var i = 0; i < capturedCount; i++) {
            if (color == chess_logic.Color.WHITE) {
              bCaptured.add(chess_logic.Piece(type, color));
            } else {
              wCaptured.add(chess_logic.Piece(type, color));
            }
          }
        }
      }
    });
    whiteCapturedNotifier.value = wCaptured;
    blackCapturedNotifier.value = bCaptured;
  }
  
  chess_logic.PieceType? _getPieceTypeFromChar(String char) {
    switch (char) {
      case 'p': return chess_logic.PieceType.PAWN;
      case 'r': return chess_logic.PieceType.ROOK;
      case 'n': return chess_logic.PieceType.KNIGHT;
      case 'b': return chess_logic.PieceType.BISHOP;
      case 'q': return chess_logic.PieceType.QUEEN;
      case 'k': return chess_logic.PieceType.KING;
      default: return null;
    }
  }
  
  void _requestEngineMove() {
    final fen = controller.getFen();
    stockfish.stdin = 'position fen $fen';
    stockfish.stdin = 'go movetime $engineMoveTime';
  }

  void _updateGameStatus() {
    if (controller.isCheckMate() || controller.isDraw() || controller.isStaleMate()) {
      statusNotifier.value = GameStatus.gameOver;
    } else {
      statusNotifier.value = GameStatus.playerTurn;
    }
  }

  void setPlayerSide(PlayerColor side) {
    playerSide = side;
    resetGame();
  }

  void resetGame() {
    controller.resetBoard();
    possibleMovesNotifier.value = [];
    selectedSquare = null;
    moveHistoryNotifier.value = [];
    whiteCapturedNotifier.value = [];
    blackCapturedNotifier.value = [];
    hintNotifier.value = null;
    if (playerSide == PlayerColor.black) {
      statusNotifier.value = GameStatus.engineTurn;
      _requestEngineMove();
    } else {
      statusNotifier.value = GameStatus.playerTurn;
    }
  }
  
  Future<String?> _showPromotionDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Promote Pawn'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _promotionButton(context, 'q', 'Queen'),
              _promotionButton(context, 'r', 'Rook'),
              _promotionButton(context, 'b', 'Bishop'),
              _promotionButton(context, 'n', 'Knight'),
            ],
          ),
        );
      },
    );
  }
  
  Widget _promotionButton(BuildContext context, String piece, String label) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(piece),
      child: Text(label),
    );
  }

  @override
  void dispose() {
    // stockfish.dispose(); // DO NOT DISPOSE THE SHARED ENGINE
    statusNotifier.dispose();
    possibleMovesNotifier.dispose();
    moveHistoryNotifier.dispose();
    whiteCapturedNotifier.dispose();
    blackCapturedNotifier.dispose();
    hintNotifier.dispose();
  }
}