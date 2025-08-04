// lib/screens/chess_game_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess_logic;
import '../logic/game_manager.dart';
import '../models/game_status.dart';
import 'engine_vs_engine_screen.dart';

class ChessGameScreen extends StatefulWidget {
  const ChessGameScreen({Key? key}) : super(key: key);
  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  late final GameManager gameManager;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    gameManager = GameManager();
    gameManager.statusNotifier.addListener(_onStateChanged);
    gameManager.possibleMovesNotifier.addListener(_onStateChanged);
    gameManager.moveHistoryNotifier.addListener(_onStateChanged);
    gameManager.whiteCapturedNotifier.addListener(_onStateChanged);
    gameManager.blackCapturedNotifier.addListener(_onStateChanged);
    gameManager.hintNotifier.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
      if (gameManager.statusNotifier.value == GameStatus.gameOver && ModalRoute.of(context)?.isCurrent != false) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showGameOverDialog();
        });
      }
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text(gameManager.displayMessage),
          actions: <Widget>[
            TextButton(
              child: const Text('New Game'),
              onPressed: () {
                Navigator.of(context).pop();
                gameManager.resetGame();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    gameManager.statusNotifier.removeListener(_onStateChanged);
    gameManager.possibleMovesNotifier.removeListener(_onStateChanged);
    gameManager.moveHistoryNotifier.removeListener(_onStateChanged);
    gameManager.whiteCapturedNotifier.removeListener(_onStateChanged);
    gameManager.blackCapturedNotifier.removeListener(_onStateChanged);
    gameManager.hintNotifier.removeListener(_onStateChanged);
    gameManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User vs. Stockfish'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _buildCapturedPieces(isWhitePlayer: true),
              const SizedBox(height: 8),
              _buildBoardWithHighlights(),
              const SizedBox(height: 8),
              _buildCapturedPieces(isWhitePlayer: false),
              const SizedBox(height: 10),
              _buildGameControls(),
              const SizedBox(height: 10),
              _buildMoveHistory(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameControls() {
    final hasGameStarted = gameManager.controller.game.history.isNotEmpty;
    return Column(
      children: [
        Text(
          gameManager.displayMessage,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        if (gameManager.statusNotifier.value == GameStatus.gameOver || !hasGameStarted)
          _buildGameSettings(),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: gameManager.resetGame,
              child: const Text('Reset'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: gameManager.undoMove,
              child: const Text('Undo'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: gameManager.statusNotifier.value == GameStatus.playerTurn ? gameManager.requestHint : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: const Text('Hint'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EngineVsEngineScreen()),
            );
          },
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EngineVsEngineScreen()),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                'Watch Stockfish vs. Stockfish',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoardWithHighlights() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTapUp: (details) {
          if (gameManager.statusNotifier.value != GameStatus.playerTurn) return;
          final boardSize = (context.findRenderObject() as RenderBox).size.width - 16;
          final squareSize = boardSize / 8;
          final file = gameManager.playerSide == PlayerColor.white
              ? (details.localPosition.dx / squareSize).floor()
              : 7 - (details.localPosition.dx / squareSize).floor();
          final rank = gameManager.playerSide == PlayerColor.white
              ? 7 - (details.localPosition.dy / squareSize).floor()
              : (details.localPosition.dy / squareSize).floor();
          final squareName = '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';
          gameManager.onSquareTapped(squareName, context);
        },
        child: Stack(
          children: [
            ChessBoard(
              controller: gameManager.controller,
              boardColor: BoardColor.green,
              boardOrientation: gameManager.playerSide,
              enableUserMoves: false,
              onMove: () {},
            ),
            ValueListenableBuilder<List<String>>(
              valueListenable: gameManager.possibleMovesNotifier,
              builder: (context, moves, _) {
                return AspectRatio(
                  aspectRatio: 1.0,
                  child: CustomPaint(
                    painter: MoveHighlighterPainter(
                      moves: moves,
                      kingInCheckSquare: gameManager.kingInCheckSquare,
                      orientation: gameManager.playerSide,
                      hintMove: gameManager.hintNotifier.value,
                    ),
                    child: Container(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCapturedPieces({required bool isWhitePlayer}) {
    final notifier = isWhitePlayer ? gameManager.blackCapturedNotifier : gameManager.whiteCapturedNotifier;
    return ValueListenableBuilder<List<chess_logic.Piece>>(
      valueListenable: notifier,
      builder: (context, pieces, _) {
        if (pieces.isEmpty) return const SizedBox(height: 30);
        return SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: pieces.map((piece) => Text(
              _getPieceUnicode(piece),
              style: const TextStyle(fontSize: 24),
            )).toList(),
          ),
        );
      },
    );
  }

  String _getPieceUnicode(chess_logic.Piece piece) {
    switch (piece.type.toString()) {
      case 'p': return piece.color == chess_logic.Color.WHITE ? '♙' : '♟';
      case 'r': return piece.color == chess_logic.Color.WHITE ? '♖' : '♜';
      case 'n': return piece.color == chess_logic.Color.WHITE ? '♘' : '♞';
      case 'b': return piece.color == chess_logic.Color.WHITE ? '♗' : '♝';
      case 'q': return piece.color == chess_logic.Color.WHITE ? '♕' : '♛';
      case 'k': return piece.color == chess_logic.Color.WHITE ? '♔' : '♚';
      default: return '';
    }
  }

  Widget _buildMoveHistory() {
    return Column(
      children: [
        const Text("Move History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const Divider(),
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ValueListenableBuilder<List<String>>(
            valueListenable: gameManager.moveHistoryNotifier,
            builder: (context, moves, _) {
              final List<String> formattedMoves = [];
              for (int i = 0; i < moves.length; i += 2) {
                final moveNumber = (i / 2).floor() + 1;
                final whiteMove = moves[i];
                final blackMove = (i + 1) < moves.length ? moves[i + 1] : '';
                formattedMoves.add('$moveNumber. $whiteMove  $blackMove');
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: formattedMoves.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    child: Text(
                      formattedMoves[index],
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameSettings() {
    return Column(
      children: [
        const Text("Difficulty", style: TextStyle(fontWeight: FontWeight.bold)),
        _buildDifficultySelector(),
        const SizedBox(height: 10),
        const Text("Play As", style: TextStyle(fontWeight: FontWeight.bold)),
        _buildColorSelector(),
      ],
    );
  }

  Widget _buildDifficultySelector() {
    return Wrap(
      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
      children: [
        _difficultyButton('Easy', 100),
        _difficultyButton('Medium', 500),
        _difficultyButton('Hard', 2000),
        _difficultyButton('Expert', 5000),
      ],
    );
  }
  
  Widget _difficultyButton(String label, int moveTime) {
     final isSelected = gameManager.engineMoveTime == moveTime;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.green : Colors.blueGrey,
      ),
      onPressed: () {
        setState(() {
          gameManager.engineMoveTime = moveTime;
        });
        gameManager.resetGame();
      },
      child: Text(label),
    );
  }

  Widget _buildColorSelector() {
    return ToggleButtons(
      isSelected: [
        gameManager.playerSide == PlayerColor.white,
        gameManager.playerSide == PlayerColor.black,
      ],
      onPressed: (index) {
        final color = index == 0 ? PlayerColor.white : PlayerColor.black;
        gameManager.setPlayerSide(color);
      },
      children: const [
        Text('White'),
        Text('Black'),
      ],
    );
  }
}

class MoveHighlighterPainter extends CustomPainter {
  final List<String> moves;
  final String? kingInCheckSquare;
  final PlayerColor orientation;
  final List<String>? hintMove;

  MoveHighlighterPainter({
    required this.moves,
    this.kingInCheckSquare,
    required this.orientation,
    this.hintMove,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 8;
    
    final movePaint = Paint()..color = Colors.green.withAlpha(120);
    
    for (final move in moves) {
      final rect = _getSquareRect(move, squareSize);
      canvas.drawRect(rect, movePaint);
    }
    
    if (kingInCheckSquare != null) {
      final checkPaint = Paint()..color = Colors.red.withAlpha(150);
      final rect = _getSquareRect(kingInCheckSquare!, squareSize);
      canvas.drawRect(rect, checkPaint);
    }
    
    if (hintMove != null && hintMove!.length == 2) {
      final from = _getSquareCenter(hintMove![0], squareSize);
      final to = _getSquareCenter(hintMove![1], squareSize);

      final hintPaint = Paint()
        ..strokeWidth = 8
        ..color = Colors.amber.withAlpha(200);
      
      canvas.drawLine(from, to, hintPaint);
    }
  }

  Rect _getSquareRect(String square, double squareSize) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square.substring(1)) - 1;

    final dx = orientation == PlayerColor.white
        ? file * squareSize
        : (7 - file) * squareSize;
        
    final dy = orientation == PlayerColor.white
        ? (7 - rank) * squareSize
        : rank * squareSize;
        
    return Rect.fromLTWH(dx, dy, squareSize, squareSize);
  }

  Offset _getSquareCenter(String square, double squareSize) {
    final rect = _getSquareRect(square, squareSize);
    return rect.center;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}