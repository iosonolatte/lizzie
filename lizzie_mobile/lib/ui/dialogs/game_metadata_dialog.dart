import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../go/game_info.dart';
import '../../state/providers.dart';

/// Dialog for viewing and editing game metadata (player names, result, etc.).
class GameMetadataDialog extends ConsumerStatefulWidget {
  const GameMetadataDialog({super.key});

  @override
  ConsumerState<GameMetadataDialog> createState() => _GameMetadataDialogState();
}

class _GameMetadataDialogState extends ConsumerState<GameMetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _blackController;
  late TextEditingController _whiteController;
  late TextEditingController _nameController;
  late TextEditingController _dateController;
  late TextEditingController _resultController;

  @override
  void initState() {
    super.initState();
    final info = ref.read(gameProvider.notifier).gameInfo;
    _blackController = TextEditingController(text: info.playerBlack);
    _whiteController = TextEditingController(text: info.playerWhite);
    _nameController = TextEditingController(text: info.gameName);
    _dateController = TextEditingController(text: info.gameDate);
    _resultController = TextEditingController(text: info.result);
  }

  @override
  void dispose() {
    _blackController.dispose();
    _whiteController.dispose();
    _nameController.dispose();
    _dateController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Game Info'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _blackController,
                decoration: const InputDecoration(
                  labelText: 'Black Player',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whiteController,
                decoration: const InputDecoration(
                  labelText: 'White Player',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Game Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. 2025-01-15',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _resultController,
                decoration: const InputDecoration(
                  labelText: 'Result',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. B+R, W+3.5',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _onSave, child: const Text('Save')),
      ],
    );
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final gameController = ref.read(gameProvider.notifier);
    gameController.updateGameInfo(
      GameInfo(
        komi: gameController.gameInfo.komi,
        handicap: gameController.gameInfo.handicap,
        playerBlack: _blackController.text,
        playerWhite: _whiteController.text,
        gameName: _nameController.text,
        gameDate: _dateController.text,
        result: _resultController.text,
      ),
    );

    Navigator.of(context).pop();
  }
}
