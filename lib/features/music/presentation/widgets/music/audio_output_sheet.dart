import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/data/models/audio_output.dart';
import 'package:mechanix_music/features/music/data/services/audio_output_service.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Opens the "Audio output device" sheet (from the cast button). Picking a
/// device plays audio on it and closes the sheet.
Future<void> showAudioOutputSheet(BuildContext context) {
  final service = context.read<AudioOutputService>();
  return MechanixBottomSheet.showModal<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => AudioOutputSheet(service: service),
  );
}

class AudioOutputSheet extends StatefulWidget {
  const AudioOutputSheet({super.key, required this.service});

  final AudioOutputService service;

  @override
  State<AudioOutputSheet> createState() => _AudioOutputSheetState();
}

class _AudioOutputSheetState extends State<AudioOutputSheet> {
  List<AudioOutput>? _outputs;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final outputs = await widget.service.getOutputs();
    if (mounted) setState(() => _outputs = outputs);
  }

  Future<void> _select(AudioOutput output) async {
    if (_switching) return;
    if (output.isSelected) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _switching = true);
    try {
      await widget.service.select(output);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _switching = false);
      MechanixSnackbar.text(
        position: MechanixSnackbarPosition.top,
        text: l10n.audioOutputFailed,
      ).show(context);
    }
  }

  /// The device's own output is shown as "Comet" (when there is only one).
  String _label(
    AudioOutput output,
    List<AudioOutput> all,
    AppLocalizations l10n,
  ) {
    final internal = all.where((o) => o.kind == AudioOutputKind.internal);
    return output.kind == AudioOutputKind.internal && internal.length == 1
        ? l10n.thisDeviceOutput
        : output.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final outputs = _outputs;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 16),
            child: Row(
              spacing: 4,
              children: [
                MechanixIconButton.standard(
                  key: const ValueKey('audio_output_back'),
                  type: IconButtonType.rounded,
                  icon: ImageIcon(
                    const AssetImage(MusicIcons.backIcon),
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.audioOutputDevice,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (outputs == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (outputs.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
              child: Text(
                l10n.noAudioOutputs,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final output in outputs)
              MechanixListTile(
                key: ValueKey('audio_output_${output.id}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leadingWidgets: [
                  MechanixRadio<String>(
                    value: output.id,
                    groupValue: outputs
                        .where((o) => o.isSelected)
                        .firstOrNull
                        ?.id,
                    onChanged: (_) => _select(output),
                  ),
                ],
                label: Text(
                  _label(output, outputs, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge!.copyWith(
                    color: output.isSelected
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                trailingWidgets: [
                  Icon(
                    _icon(output.kind),
                    size: 20,
                    color: output.isSelected
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ],
                onTap: () => _select(output),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static IconData _icon(AudioOutputKind kind) => switch (kind) {
    AudioOutputKind.internal => Icons.smartphone_outlined,
    AudioOutputKind.display => Icons.laptop_outlined,
    AudioOutputKind.headphones => Icons.headphones_outlined,
    AudioOutputKind.bluetooth => Icons.speaker_outlined,
    AudioOutputKind.usb => Icons.speaker_outlined,
    AudioOutputKind.other => Icons.volume_up_outlined,
  };
}
