import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum PreviewTab { dart, json, hex }

/// Bottom payload preview — SegmentedButton instead of TabBar for reliable web layout.
class PayloadPreviewPanel extends StatelessWidget {
  const PayloadPreviewPanel({
    super.key,
    required this.expanded,
    required this.loading,
    required this.dartCode,
    required this.jsonCode,
    required this.hexCode,
    required this.selectedTab,
    required this.onToggleExpanded,
    required this.onRefresh,
    required this.onTabChanged,
    required this.onCopy,
  });

  final bool expanded;
  final bool loading;
  final String dartCode;
  final String jsonCode;
  final String hexCode;
  final PreviewTab selectedTab;
  final VoidCallback onToggleExpanded;
  final VoidCallback onRefresh;
  final ValueChanged<PreviewTab> onTabChanged;
  final ValueChanged<String> onCopy;

  String get _currentText => switch (selectedTab) {
        PreviewTab.dart => dartCode,
        PreviewTab.json => jsonCode,
        PreviewTab.hex => hexCode,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelHeight = kIsWeb ? 260.0 : 240.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
        boxShadow: kIsWeb
            ? null
            : const [
                BoxShadow(
                  blurRadius: 8,
                  offset: Offset(0, -2),
                  color: Color(0x22000000),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            child: InkWell(
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payload sent to print_worker',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        tooltip: 'Refresh preview',
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh, size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SegmentedButton<PreviewTab>(
                segments: const [
                  ButtonSegment(
                    value: PreviewTab.dart,
                    label: Text('Dart'),
                    icon: Icon(Icons.code, size: 16),
                  ),
                  ButtonSegment(
                    value: PreviewTab.json,
                    label: Text('JSON'),
                    icon: Icon(Icons.data_object, size: 16),
                  ),
                  ButtonSegment(
                    value: PreviewTab.hex,
                    label: Text('Bytes'),
                    icon: Icon(Icons.memory, size: 16),
                  ),
                ],
                selected: {selectedTab},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) onTabChanged(selection.first);
                },
              ),
            ),
            SizedBox(
              height: panelHeight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectionArea(
                              child: Text(
                                _currentText.isEmpty
                                    ? '(refresh to load preview)'
                                    : _currentText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'Courier New',
                                  fontFamilyFallback: const [
                                    'Consolas',
                                    'monospace',
                                  ],
                                  height: 1.4,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: _currentText.isEmpty
                              ? null
                              : () => onCopy(_currentText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
