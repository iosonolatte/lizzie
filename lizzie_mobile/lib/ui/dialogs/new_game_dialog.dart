import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';

/// Dialog to configure and start a new Go game.
///
/// Allows the user to set board size, komi, and handicap before
/// resetting the board.
class NewGameDialog extends ConsumerStatefulWidget {
  const NewGameDialog({super.key});

  @override
  ConsumerState<NewGameDialog> createState() => _NewGameDialogState();
}

class _NewGameDialogState extends ConsumerState<NewGameDialog> {
  final _formKey = GlobalKey<FormState>();
  int _boardSize = 19;
  double _komi = 6.5;
  int _handicap = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Game'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Board size.
              DropdownButtonFormField<int>(
                initialValue: _boardSize,
                decoration: const InputDecoration(
                  labelText: 'Board Size',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 9, child: Text('9 × 9')),
                  DropdownMenuItem(value: 13, child: Text('13 × 13')),
                  DropdownMenuItem(value: 19, child: Text('19 × 19')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _boardSize = v);
                },
              ),
              const SizedBox(height: 16),

              // Komi.
              TextFormField(
                initialValue: _komi.toString(),
                decoration: const InputDecoration(
                  labelText: 'Komi',
                  border: OutlineInputBorder(),
                  helperText: 'Typically 6.5 (or 0.5 with handicap)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a value';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null) _komi = parsed;
                },
              ),
              const SizedBox(height: 16),

              // Handicap.
              DropdownButtonFormField<int>(
                initialValue: _handicap,
                decoration: const InputDecoration(
                  labelText: 'Handicap',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(
                  10,
                  (i) => DropdownMenuItem(
                    value: i,
                    child: Text(i == 0 ? 'None' : '$i stones'),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _handicap = v);
                },
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
        FilledButton(onPressed: _onStart, child: const Text('Start')),
      ],
    );
  }

  void _onStart() {
    if (!_formKey.currentState!.validate()) return;

    final gameController = ref.read(gameProvider.notifier);
    gameController.newGame(_boardSize, komi: _komi, handicap: _handicap);

    // Stop engine pondering so it realises the game changed.
    final engineController = ref.read(engineProvider.notifier);
    engineController.stopPonder();

    Navigator.of(context).pop();
  }
}
