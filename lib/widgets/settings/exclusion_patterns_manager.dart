import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/exclusions_config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_icon_button.dart';
import '../common/app_text_field.dart';

class ExclusionPatternsManager extends StatefulWidget {
  final List<String> initialPatterns;
  final String? sourcePath;
  final ValueChanged<List<String>> onChanged;

  const ExclusionPatternsManager({
    super.key,
    required this.initialPatterns,
    this.sourcePath,
    required this.onChanged,
  });

  @override
  State<ExclusionPatternsManager> createState() =>
      _ExclusionPatternsManagerState();
}

class _ExclusionPatternsManagerState extends State<ExclusionPatternsManager> {
  late List<String> _patterns;
  final TextEditingController _addController = TextEditingController();
  String? _feedbackMessage;
  Color? _feedbackColor;

  @override
  void initState() {
    super.initState();
    _patterns = List.from(widget.initialPatterns);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(_patterns);
  }

  void _setFeedback(String message, Color color) {
    setState(() {
      _feedbackMessage = message;
      _feedbackColor = color;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _feedbackMessage == message) {
        setState(() {
          _feedbackMessage = null;
        });
      }
    });
  }

  bool get _hasGitignore {
    if (widget.sourcePath == null || widget.sourcePath!.isEmpty) return false;
    try {
      final file = File(p.join(widget.sourcePath!, '.gitignore'));
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  void _importGitignore() {
    if (widget.sourcePath == null) return;
    try {
      final file = File(p.join(widget.sourcePath!, '.gitignore'));
      final gitPatterns = ExclusionsConfig.parseGitignoreFile(file);
      if (gitPatterns.isEmpty) {
        _setFeedback('No valid rules found in .gitignore', AppColors.neutral7);
        return;
      }

      int addedCount = 0;
      for (final rule in gitPatterns) {
        if (!_patterns.any((p) => p.toLowerCase() == rule.toLowerCase())) {
          _patterns.add(rule);
          addedCount++;
        }
      }

      if (addedCount > 0) {
        setState(() {});
        _notifyChange();
        _setFeedback(
          'Imported $addedCount pattern${addedCount > 1 ? "s" : ""} from .gitignore',
          AppColors.successBase,
        );
      } else {
        _setFeedback(
          'All .gitignore rules are already present',
          AppColors.neutral7,
        );
      }
    } catch (e) {
      _setFeedback('Failed to read .gitignore: $e', AppColors.dangerBase);
    }
  }

  void _addPattern() {
    final input = _addController.text.trim();
    if (input.isEmpty) return;

    final candidates = ExclusionsConfig.parseRulesString(input);
    if (candidates.isEmpty) return;

    final added = <String>[];
    final duplicates = <String>[];

    for (final item in candidates) {
      final exists = _patterns.any(
        (p) => p.toLowerCase() == item.toLowerCase(),
      );
      if (exists) {
        duplicates.add(item);
      } else {
        added.add(item);
      }
    }

    if (duplicates.isNotEmpty && added.isEmpty) {
      _setFeedback(
        'Pattern "${duplicates.first}" already exists in exclusion list.',
        AppColors.statusNewText,
      );
      return;
    }

    if (added.isNotEmpty) {
      setState(() {
        _patterns.addAll(added);
        _addController.clear();
      });
      _notifyChange();
      _setFeedback(
        'Added ${added.length} exclusion pattern${added.length > 1 ? "s" : ""}.',
        AppColors.successBase,
      );
    }
  }

  void _togglePreset(String presetName, List<String> presetItems) {
    setState(() {
      final allPresent = presetItems.every(
        (item) => _patterns.any((p) => p.toLowerCase() == item.toLowerCase()),
      );
      if (allPresent) {
        _patterns.removeWhere(
          (item) =>
              presetItems.any((p) => p.toLowerCase() == item.toLowerCase()),
        );
        _setFeedback(
          'Removed "$presetName" preset patterns.',
          AppColors.neutral8,
        );
      } else {
        for (final item in presetItems) {
          if (!_patterns.any((p) => p.toLowerCase() == item.toLowerCase())) {
            _patterns.add(item);
          }
        }
        _setFeedback(
          'Added "$presetName" preset patterns.',
          AppColors.successBase,
        );
      }
    });
    _notifyChange();
  }

  void _removePattern(int index) {
    final removed = _patterns[index];
    setState(() {
      _patterns.removeAt(index);
    });
    _notifyChange();
    _setFeedback('Removed "$removed".', AppColors.neutral8);
  }

  Future<void> _copyPattern(String pattern) async {
    await Clipboard.setData(ClipboardData(text: pattern));
    _setFeedback('Copied "$pattern" to clipboard.', AppColors.primary300);
  }

  void _clearAll() {
    setState(() {
      _patterns.clear();
    });
    _notifyChange();
    _setFeedback('Cleared all exclusion patterns.', AppColors.dangerBase);
  }

  void _resetDefaults() {
    setState(() {
      _patterns = List.from(ExclusionsConfig.defaultExclusions);
    });
    _notifyChange();
    _setFeedback('Reset to default patterns.', AppColors.successBase);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exclusion Rules & Filters',
              style: AppTypography.body.copyWith(
                color: AppColors.neutral9,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Excluded folders (like node_modules) are pruned early to prevent scanning lag.',
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral7,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),
        // Quick Preset Templates
        Row(
          children: [
            Text(
              'Quick Presets:',
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral8,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (_hasGitignore) ...[
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(16),
                onTap: _importGitignore,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxxs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBase.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryBase.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsDuotone.gitBranch,
                        color: AppColors.primary300,
                        size: 13,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        'Import .gitignore',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary300,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: ExclusionsConfig.presetTemplates.entries.map((entry) {
            final active = entry.value.every(
              (item) =>
                  _patterns.any((p) => p.toLowerCase() == item.toLowerCase()),
            );
            return InkWell(
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(16),
              onTap: () => _togglePreset(entry.key, entry.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primaryBase.withValues(alpha: 0.2)
                      : AppColors.neutral3,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active ? AppColors.primaryBase : AppColors.neutral5,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) ...[
                      const PhosphorIcon(
                        PhosphorIconsBold.check,
                        color: AppColors.primary300,
                        size: 12,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                    ],
                    Text(
                      entry.key,
                      style: AppTypography.caption.copyWith(
                        color: active
                            ? AppColors.primary300
                            : AppColors.neutral9,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: AppSpacing.md),

        // Add Pattern Input
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _addController,
                placeholder: 'Add pattern (e.g. node_modules, *.log, dist/)',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              variant: ButtonVariant.primary,
              text: 'Add Rule',
              icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 14),
              onClick: _addPattern,
            ),
          ],
        ),

        if (_feedbackMessage != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _feedbackMessage!,
            style: AppTypography.caption.copyWith(
              color: _feedbackColor ?? AppColors.neutral8,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),

        // Active Exclusions Header
        Row(
          children: [
            Text(
              'Active Exclusions (${_patterns.length})',
              style: AppTypography.body.copyWith(
                color: AppColors.neutral9,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            AppButton(
              variant: ButtonVariant.text,
              text: 'Reset Defaults',
              onClick: _resetDefaults,
            ),
            const SizedBox(width: AppSpacing.xxxs),
            AppButton(
              variant: ButtonVariant.text,
              text: 'Clear All',
              disabled: _patterns.isEmpty,
              onClick: _patterns.isEmpty ? null : _clearAll,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xs),

        // Scrollable Box for active patterns
        Container(
          height: 300,
          decoration: ShapeDecoration(
            color: AppColors.neutral1,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.neutral3, width: 2),
            ),
          ),
          child: _patterns.isEmpty
              ? Center(
                  child: Text(
                    'No exclusion rules configured. All files will be scanned.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral7,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  itemCount: _patterns.length,
                  itemExtent: 44.0,
                  itemBuilder: (context, index) {
                    final item = _patterns[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs - 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neutral2,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.neutral3, width: 2),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${index + 1}.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.neutral7,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              item,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.neutral9,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          AppIconButton.ghost(
                            size: 24,
                            icon: const PhosphorIcon(
                              PhosphorIconsRegular.copy,
                              color: AppColors.neutral7,
                              size: 14,
                            ),
                            onClick: () => _copyPattern(item),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          AppIconButton.ghost(
                            size: 24,
                            icon: const PhosphorIcon(
                              PhosphorIconsRegular.trash,
                              color: AppColors.dangerBase,
                              size: 14,
                            ),
                            onClick: () => _removePattern(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
