import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/engine_config_store.dart';
import '../../state/providers.dart';

/// Modal bottom sheet for engine connection settings.
///
/// Lets user pick engine type (Mock/KataGo/Leela Zero) and enter host/port.
/// Saves config to SharedPreferences and connects on "Connect" button press.
class EngineSettingsSheet extends ConsumerStatefulWidget {
  const EngineSettingsSheet({super.key});

  @override
  ConsumerState<EngineSettingsSheet> createState() => _EngineSettingsSheetState();
}

class _EngineSettingsSheetState extends ConsumerState<EngineSettingsSheet> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  EngineType _selectedType = EngineType.mock;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    _hostController = TextEditingController();
    _portController = TextEditingController();

    // Pre-fill with currently saved config.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = ref.read(engineConfigStoreProvider);
      final saved = await store.load();
      if (mounted) {
        setState(() {
          _selectedType = saved.type;
          _hostController.text = saved.host;
          _portController.text = saved.port.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;

    final port = int.tryParse(_portController.text.trim());
    if (port == null) return;

    final cfg = EngineConfigData(
      type: _selectedType,
      host: _hostController.text.trim(),
      port: port,
    );

    // Save config
    final store = ref.read(engineConfigStoreProvider);
    await store.save(cfg);

    // Connect
    setState(() => _isConnecting = true);
    final engineController = ref.read(engineProvider.notifier);
    try {
      await engineController.stop();
      await engineController.startWithType(cfg);
      await engineController.initGame(19);
      await engineController.startPonder();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${_labelFor(_selectedType)}'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMock = _selectedType == EngineType.mock;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Engine Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Engine type selector
            const Text('Engine Type'),
            const SizedBox(height: 8),
            SegmentedButton<EngineType>(
              selected: {_selectedType},
              onSelectionChanged: _isConnecting
                  ? null
                  : (Set<EngineType> s) {
                      if (s.isNotEmpty) {
                        setState(() => _selectedType = s.first);
                      }
                    },
              segments: [
                ButtonSegment(
                  value: EngineType.mock,
                  label: Text(_labelFor(EngineType.mock)),
                ),
                ButtonSegment(
                  value: EngineType.kataGo,
                  label: Text(_labelFor(EngineType.kataGo)),
                ),
                ButtonSegment(
                  value: EngineType.leelaZero,
                  label: Text(_labelFor(EngineType.leelaZero)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Host field
            TextFormField(
              controller: _hostController,
              enabled: !isMock && !_isConnecting,
              decoration: const InputDecoration(
                labelText: 'Host',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Host is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Port field
            TextFormField(
              controller: _portController,
              enabled: !isMock && !_isConnecting,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              validator: (v) {
                final port = int.tryParse(v ?? '');
                if (port == null || port < 1 || port > 65535) {
                  return 'Enter a valid port (1-65535)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Cancel / Connect buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isConnecting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isConnecting ? null : _connect,
                  child: _isConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _labelFor(EngineType type) {
    return switch (type) {
      EngineType.mock => 'Mock',
      EngineType.kataGo => 'KataGo',
      EngineType.leelaZero => 'LZ',
    };
  }
}