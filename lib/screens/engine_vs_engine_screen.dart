// lib/screens/engine_vs_engine_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import '../logic/engine_vs_engine_manager.dart';

class EngineVsEngineScreen extends StatefulWidget {
  const EngineVsEngineScreen({Key? key}) : super(key: key);

  @override
  State<EngineVsEngineScreen> createState() => _EngineVsEngineScreenState();
}

class _EngineVsEngineScreenState extends State<EngineVsEngineScreen> {
  late final EngineVsEngineManager gameManager;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    gameManager = EngineVsEngineManager();
    gameManager.controller.addListener(_onStateChanged);
    gameManager.isGameRunning.addListener(_onStateChanged);
    gameManager.moveHistoryNotifier.addListener(_onStateChanged);
    gameManager.whiteMoveTime.addListener(_onStateChanged);
    gameManager.blackMoveTime.addListener(_onStateChanged);
    // NEW: Listen to the status notifier
    gameManager.statusNotifier.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    gameManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockfish vs. Stockfish'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _buildBoard(),
              const SizedBox(height: 10),
              // NEW: Add the status display text
              Text(
                gameManager.displayMessage,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildControlPanel(),
              const SizedBox(height: 10),
              _buildMoveHistory(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ChessBoard(
        controller: gameManager.controller,
        boardColor: BoardColor.orange,
        enableUserMoves: false,
      ),
    );
  }

  Widget _buildControlPanel() {
    // ... (This widget is unchanged and works perfectly) ...
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEngineDifficultyControl("White Engine", gameManager.whiteMoveTime),
                _buildEngineDifficultyControl("Black Engine", gameManager.blackMoveTime),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: gameManager.isGameRunning.value ? null : gameManager.startGame,
                  child: const Text('Start'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: !gameManager.isGameRunning.value ? null : gameManager.stopGame,
                  child: const Text('Stop'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: gameManager.resetGame,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineDifficultyControl(String title, ValueNotifier<int> moveTimeNotifier) {
    // ... (This widget is unchanged and works perfectly) ...
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<int>(
          value: moveTimeNotifier.value,
          onChanged: gameManager.isGameRunning.value
              ? null
              : (int? newValue) {
                  if (newValue != null) {
                    moveTimeNotifier.value = newValue;
                  }
                },
          items: <int>[50, 100, 250, 500, 1000, 2000, 5000]
              .map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text('${value / 1000}s'),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMoveHistory() {
    // ... (This widget is unchanged and works perfectly) ...
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
              final formattedMoves = <String>[];
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
}