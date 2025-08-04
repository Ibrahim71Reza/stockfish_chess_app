// lib/logic/stockfish_service.dart
import 'package:stockfish/stockfish.dart';

class StockfishService {
  // A private constructor.
  StockfishService._privateConstructor();

  // The single, static instance of this class.
  static final StockfishService instance = StockfishService._privateConstructor();

  // The single, static instance of the Stockfish engine.
  final Stockfish _engine = Stockfish();

  // A public getter to access the engine.
  Stockfish get engine => _engine;
}