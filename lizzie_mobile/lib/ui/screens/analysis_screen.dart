import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/analysis.dart';
import '../../go/sgf_parser.dart';
import '../../go/stone.dart';
import '../../state/engine_config_store.dart';
import '../../state/providers.dart';
import '../board/board_widget.dart';
import '../panels/analysis_panel.dart';
import '../panels/engine_settings_sheet.dart';
import '../dialogs/new_game_dialog.dart';
import '../dialogs/scoring_result_dialog.dart';
import '../dialogs/comment_dialog.dart';
import '../dialogs/game_metadata_dialog.dart';

/// Main analysis screen — the primary UI of Lizzie Mobile.
///
/// Shows the Go board with analysis overlays, a status bar, and
/// basic controls.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _isPondering = false;
  bool _scoringMode = false;

  @override
  void initState() {
    super.initState();
    // Auto-start with the saved engine config.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToSavedEngine();
    });
  }

  Future<void> _connectToSavedEngine() async {
    final store = ref.read(engineConfigStoreProvider);
    final saved = await store.load();
    final engineController = ref.read(engineProvider.notifier);

    try {
      await engineController.startWithType(saved);
      await engineController.initGame(19);
      await engineController.startPonder();
      if (mounted) {
        setState(() {
          _isPondering = true;
        });
      }
    } catch (e) {
      // Connection failed; silently fall back to Mock for usability.
      // The user can try again via the settings sheet.
      if (saved.type != EngineType.mock && mounted) {
        final mockCfg = saved.copyWith(type: EngineType.mock);
        await engineController.startWithType(mockCfg);
        await engineController.initGame(19);
        await engineController.startPonder();
        if (mounted) {
          setState(() {
            _isPondering = true;
          });
        }
      }
    }
  }

  Future<void> _togglePonder() async {
    final engineController = ref.read(engineProvider.notifier);
    if (_isPondering) {
      await engineController.stopPonder();
    } else {
      await engineController.startPonder();
    }
    setState(() {
      _isPondering = !_isPondering;
    });
  }

  Future<void> _openSgf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sgf'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final content = await file.readAsString();

      final (parsed, gameInfo) = SgfParser.parse(content);
      final gameController = ref.read(gameProvider.notifier);
      gameController.loadSgf(parsed, gameInfo: gameInfo);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SGF loaded successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load SGF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openNewGameDialog() {
    showDialog(context: context, builder: (_) => const NewGameDialog());
  }

  Future<void> _saveSgf() async {
    try {
      final gameController = ref.read(gameProvider.notifier);
      final sgfContent = gameController.toSgf();

      final result = await FilePicker.saveFile(
        dialogTitle: 'Save SGF',
        fileName: 'game.sgf',
        type: FileType.custom,
        allowedExtensions: ['sgf'],
      );
      if (result == null) return; // User cancelled.

      final file = File(result);
      await file.writeAsString(sgfContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SGF saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save SGF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleScoringMode() {
    setState(() {
      _scoringMode = !_scoringMode;
    });

    final gameController = ref.read(gameProvider.notifier);
    gameController.toggleScoringMode();

    if (_scoringMode) {
      // Stop pondering while scoring.
      if (_isPondering) {
        ref.read(engineProvider.notifier).stopPonder();
        _isPondering = false;
      }
    } else {
      // Show scoring result when exiting.
      _showScoringResult();
    }
  }

  void _showScoringResult() {
    final board = ref.read(gameProvider);
    final gameInfo = ref.read(gameProvider.notifier).gameInfo;
    final (blackTerritory, whiteTerritory, dame) = board.countTerritory();
    final scoreDiff = board.computeScoreDifference(komi: gameInfo.komi);

    showDialog(
      context: context,
      builder: (_) => ScoringResultDialog(
        blackTerritory: blackTerritory,
        whiteTerritory: whiteTerritory,
        dame: dame,
        blackCaptures: board.data.blackCaptures,
        whiteCaptures: board.data.whiteCaptures,
        komi: gameInfo.komi,
        scoreDiff: scoreDiff,
      ),
    );
  }

  void _openCommentDialog() {
    final board = ref.read(gameProvider);
    final currentComment = board.data.comment;

    showDialog(
      context: context,
      builder: (_) => CommentDialog(
        initialComment: currentComment,
        onSave: (newComment) {
          ref.read(gameProvider.notifier).setComment(newComment);
        },
      ),
    );
  }

  void _openMetadataDialog() {
    showDialog(context: context, builder: (_) => const GameMetadataDialog());
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const EngineSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engineStatus = ref.watch(engineProvider);
    final engineController = ref.read(engineProvider.notifier);
    final lastAnalysis = engineController.lastAnalysis;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lizzie Mobile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // New game.
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Game',
            onPressed: _openNewGameDialog,
          ),
          // Open SGF file.
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Open SGF',
            onPressed: _openSgf,
          ),
          // Save SGF file.
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save SGF',
            onPressed: _saveSgf,
          ),
          // Game info / metadata.
          IconButton(
            icon: const Icon(Icons.info),
            tooltip: 'Game Info',
            onPressed: _openMetadataDialog,
          ),
          // Scoring mode.
          IconButton(
            icon: Icon(_scoringMode ? Icons.square_foot : Icons.flag),
            tooltip: _scoringMode ? 'Exit Scoring' : 'Scoring Mode',
            onPressed: _toggleScoringMode,
          ),
          // Engine settings.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Engine Settings',
            onPressed: _openSettings,
          ),
          // Engine status indicator.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildStatusIcon(engineStatus),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar or scoring bar.
            _scoringMode
                ? _buildScoringBar()
                : _buildStatusBar(engineStatus, lastAnalysis),

            // Board.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: BoardWidget(
                  onPointTap: (x, y) {
                    final gameController = ref.read(gameProvider.notifier);
                    gameController.place(x, y);
                  },
                  analysis: _scoringMode ? null : lastAnalysis,
                  scoringMode: _scoringMode,
                ),
              ),
            ),

            // Controls.
            _buildControls(),

            // Analysis panel (winrate chart, subboard, move list).
            const AnalysisPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(AsyncValue<EngineStatus> status) {
    return status.when(
      data: (s) {
        if (s is Ready) {
          return const Icon(Icons.link, color: Colors.green);
        } else if (s is Connecting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        } else if (s is EngineError) {
          return const Icon(Icons.error, color: Colors.red);
        }
        return const Icon(Icons.link_off, color: Colors.grey);
      },
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const Icon(Icons.error, color: Colors.red),
    );
  }

  Widget _buildStatusBar(
    AsyncValue<EngineStatus> status,
    AnalysisResult? analysis,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.grey[100],
      child: Row(
        children: [
          // Move number.
          Text(
            'Move ${ref.watch(gameProvider).data.moveNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          // Winrate.
          if (analysis != null && analysis.bestMoves.isNotEmpty)
            Text(
              'WR: ${analysis.bestMoves.first.winrate.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 13),
            ),
          if (analysis != null && analysis.bestMoves.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text(
              'Visits: ${analysis.currentPlayouts}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          // Comment indicator.
          if (ref.watch(gameProvider).data.comment.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openCommentDialog,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.comment, size: 16, color: Colors.blueGrey[400]),
                  const SizedBox(width: 2),
                  Text(
                    ref.watch(gameProvider).data.comment.length > 15
                        ? '${ref.watch(gameProvider).data.comment.substring(0, 15)}...'
                        : ref.watch(gameProvider).data.comment,
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey[400]),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          // Engine name.
          status.whenOrNull(
                data: (s) => s is Ready
                    ? Text(
                        s.engineName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildScoringBar() {
    final board = ref.read(gameProvider);
    final gameInfo = ref.read(gameProvider.notifier).gameInfo;
    final (blackTerritory, whiteTerritory, dame) = board.countTerritory();

    // Count alive stones.
    int blackStones = 0;
    int whiteStones = 0;
    for (final s in board.data.stones) {
      if (s == Stone.black) blackStones++;
      if (s == Stone.white) whiteStones++;
    }

    final blackArea = blackTerritory + blackStones;
    final whiteArea = whiteTerritory + whiteStones;
    final blackScore = blackArea;
    final whiteScore = whiteArea + gameInfo.komi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.amber[50],
      child: Row(
        children: [
          // Black score.
          Icon(Icons.circle, size: 12, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            '$blackArea ($blackTerritory T + $blackStones S)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          // White score.
          Icon(Icons.circle, size: 12, color: Colors.grey[300]),
          const SizedBox(width: 4),
          Text(
            '$whiteArea ($whiteTerritory T + $whiteStones S)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          // Dame.
          if (dame > 0)
            Text(
              'Dame: $dame',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          const Spacer(),
          // Result.
          Text(
            blackScore > whiteScore
                ? 'B+${(blackScore - whiteScore).toStringAsFixed(1)}'
                : whiteScore > blackScore
                ? 'W+${(whiteScore - blackScore).toStringAsFixed(1)}'
                : 'Draw',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: blackScore > whiteScore ? Colors.black : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          // Done button.
          TextButton(
            onPressed: _toggleScoringMode,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Done', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final gameController = ref.read(gameProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            tooltip: 'Start',
            onPressed: () => gameController.toStart(),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous',
            onPressed: () => gameController.previous(),
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: () => gameController.undo(),
          ),
          IconButton(
            icon: Icon(_isPondering ? Icons.pause : Icons.play_arrow),
            tooltip: _isPondering ? 'Stop Analysis' : 'Start Analysis',
            onPressed: _togglePonder,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: () => gameController.redo(),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next',
            onPressed: () => gameController.next(),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            tooltip: 'End',
            onPressed: () => gameController.toEnd(),
          ),
        ],
      ),
    );
  }
}
