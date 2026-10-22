import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/backup_item.dart';
import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../common/app_button.dart';
import '../common/app_copy_badge.dart';
import '../common/app_dialog.dart';
import '../common/file_diff_list.dart';
import '../common/spinner.dart';
import '../common/status_badge.dart';

class HistoryDialog extends StatefulWidget {
  final Project project;
  final List<BackupItem> rows;
  final bool loading;
  final Future<bool> Function(List<String> filenames) onDeleteMultiple;
  final Function(String msg, String type) showToast;

  const HistoryDialog({
    super.key,
    required this.project,
    required this.rows,
    this.loading = false,
    required this.onDeleteMultiple,
    required this.showToast,
  });

  static Future<void> show(
    BuildContext context, {
    required Project project,
    required List<BackupItem> rows,
    bool loading = false,
    required Future<bool> Function(List<String> filenames) onDeleteMultiple,
    required Function(String msg, String type) showToast,
  }) {
    return AppDialog.show(
      context: context,
      builder: (context) => HistoryDialog(
        project: project,
        rows: rows,
        loading: loading,
        onDeleteMultiple: onDeleteMultiple,
        showToast: showToast,
      ),
    );
  }

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  late List<BackupItem> _items;
  final Set<String> _selectedFiles = {};
  String? _selectedDetailFilename;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _items = List<BackupItem>.from(widget.rows);
    if (_items.isNotEmpty) {
      _selectedDetailFilename = _items.first.filename;
    }
  }

  BackupItem? get _selectedItem {
    if (_items.isEmpty) return null;
    return _items.firstWhere(
      (it) => it.filename == _selectedDetailFilename,
      orElse: () => _items.first,
    );
  }

  int? _lastClickedIndex;

  void _handleItemClick(int index) {
    final item = _items[index];
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isControlPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    setState(() {
      if (isShiftPressed && _lastClickedIndex != null) {
        final start = _lastClickedIndex! < index ? _lastClickedIndex! : index;
        final end = _lastClickedIndex! > index ? _lastClickedIndex! : index;
        _selectedFiles.clear();
        for (int i = start; i <= end; i++) {
          _selectedFiles.add(_items[i].filename);
        }
      } else if (isControlPressed) {
        if (_selectedFiles.contains(item.filename)) {
          _selectedFiles.remove(item.filename);
        } else {
          _selectedFiles.add(item.filename);
        }
        _lastClickedIndex = index;
      } else {
        _selectedFiles.clear();
        _selectedFiles.add(item.filename);
        _lastClickedIndex = index;
      }
      _selectedDetailFilename = item.filename;
    });
  }

  Future<void> _handleDeleteSelected() async {
    if (_selectedFiles.isEmpty || _isDeleting) return;
    final targets = _selectedFiles.toList();
    setState(() => _isDeleting = true);
    try {
      final success = await widget.onDeleteMultiple(targets);
      if (success && mounted) {
        setState(() {
          _items.removeWhere((it) => targets.contains(it.filename));
          _selectedFiles.clear();
          if (_selectedDetailFilename != null &&
              targets.contains(_selectedDetailFilename)) {
            _selectedDetailFilename = _items.isNotEmpty
                ? _items.first.filename
                : null;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem;

    return AppDialog(
      width: 960,
      height: 680,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(
            titleWidget: Row(
              children: [
                Text(
                  widget.project.name,
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.neutral11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '· Backup History',
                  style: AppTypography.subtitle.copyWith(
                    color: AppColors.neutral8,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Ctrl+Click to toggle  ·  Shift+Click for range selection',
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral8,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Master-Detail Content
          Expanded(
            child: widget.loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Spinner(size: 28),
                        SizedBox(height: AppSpacing.md),
                        Text('Loading history...'),
                      ],
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'No backup versions recorded yet for this project.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.neutral7,
                        fontSize: 14,
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Left Column: Snapshot List
                      SizedBox(width: 300, child: _buildSnapshotList()),

                      const SizedBox(width: AppSpacing.md),

                      // Right Column: Detail View
                      Expanded(
                        child: selectedItem != null
                            ? _buildDetailPanel(selectedItem)
                            : Container(
                                decoration: BoxDecoration(
                                  color: AppColors.neutral1,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.neutral3),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Select a backup to view details',
                                  style: AppTypography.body.copyWith(
                                    color: AppColors.neutral7,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),

          if (_selectedFiles.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            AppDialogFooter(
              children: [
                AppButton(
                  variant: ButtonVariant.danger,
                  icon: const PhosphorIcon(
                    PhosphorIconsDuotone.trash,
                    size: 16,
                  ),
                  hoverIcon: const PhosphorIcon(
                    PhosphorIconsFill.trash,
                    size: 16,
                  ),
                  text: 'Delete Selected (${_selectedFiles.length})',
                  onClick: _handleDeleteSelected,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSnapshotList() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, idx) {
        final item = _items[idx];
        final isFocused = _selectedDetailFilename == item.filename;
        final isSelected = _selectedFiles.contains(item.filename);

        return _SnapshotListItem(
          key: ValueKey('${item.filename}_$idx'),
          item: item,
          isFocused: isFocused,
          isSelected: isSelected,
          onTap: () => _handleItemClick(idx),
        );
      },
    );
  }

  Widget _buildDetailPanel(BackupItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral3),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Detail Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Version ${item.version}',
                          style: AppTypography.subtitle.copyWith(
                            color: AppColors.neutral10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildIntegrityBadge(item.integrity),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.timestamp,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral8,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.formatBytes(item.size),
                    style: AppTypography.subtitle.copyWith(
                      color: AppColors.neutral10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    item.folderCount > 0
                        ? '${item.fileCount} files, ${item.folderCount} folders'
                        : '${item.fileCount} files',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral8,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Metadata Grid: Hash & Note
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.zipHash.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.zipHash,
                        style: AppTypography.body.copyWith(
                          color: AppColors.neutral10.withValues(alpha: .85),
                          letterSpacing: .5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AppCopyBadge(
                      text: item.zipHash,
                      toastMessage: 'Copied ZIP hash to clipboard!',
                      onToast: widget.showToast,
                    ),
                  ],
                ),
              ],
              if (item.note.isNotEmpty) ...[
                if (item.zipHash.isNotEmpty)
                  const SizedBox(height: AppSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: PhosphorIcon(
                        PhosphorIconsDuotone.chatText,
                        size: 20,
                        color: AppColors.neutral8,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item.note,
                        style: AppTypography.body.copyWith(
                          color: AppColors.neutral8,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // File Diff List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Files in this backup',
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral7,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FileDiffCounters(
                added: item.addedCount,
                modified: item.modifiedCount,
                deleted: item.deletedCount,
                skipped: item.excludedCount,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xs),

          // File List
          Expanded(child: FileDiffList(files: item.files)),
        ],
      ),
    );
  }

  Widget _buildIntegrityBadge(String integrity) {
    final Color color;
    final IconData icon;
    final String label;

    switch (integrity) {
      case 'corrupted':
        color = AppColors.dangerBase;
        icon = PhosphorIconsFill.warningOctagon;
        label = 'Corrupted';
        break;
      case 'untracked':
        color = AppColors.statusNewText;
        icon = PhosphorIconsFill.warning;
        label = 'Untracked';
        break;
      default:
        color = AppColors.successBase;
        icon = PhosphorIconsFill.checkCircle;
        label = 'Verified';
        break;
    }

    return StatusBadge(label: label, icon: icon, color: color);
  }
}

class _SnapshotListItem extends StatefulWidget {
  final BackupItem item;
  final bool isFocused;
  final bool isSelected;
  final VoidCallback onTap;

  const _SnapshotListItem({
    super.key,
    required this.item,
    required this.isFocused,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  State<_SnapshotListItem> createState() => _SnapshotListItemState();
}

class _SnapshotListItemState extends State<_SnapshotListItem> {
  @override
  Widget build(BuildContext context) {
    final isFocused = widget.isFocused || widget.isSelected;
    final bgColor = isFocused ? AppColors.neutral5 : AppColors.neutral0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: ShapeDecoration(
            color: bgColor,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Timestamp
              Text(
                widget.item.timestamp,
                style: AppTypography.caption.copyWith(
                  color: widget.isFocused
                      ? AppColors.neutral12
                      : AppColors.neutral8,
                  fontWeight: widget.isFocused
                      ? FontWeight.w600
                      : FontWeight.normal,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppSpacing.xxs),

              // Row 2: Version badge & Size
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neutral4,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'v${widget.item.version}',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    Formatters.formatBytes(widget.item.size),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral8,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              // Row 3: Comment / Note (if present)
              if (widget.item.note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  widget.item.note,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral7,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
