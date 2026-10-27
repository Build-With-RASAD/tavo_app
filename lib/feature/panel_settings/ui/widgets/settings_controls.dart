// lib/feature/panel_settings/ui/widgets/settings_controls.dart
//
// The settings screen's small controls: a section shell, a toggle row, a
// numeric field, a time field and the inline error line. Everything is built
// from the Tavo web kit tokens, so the screen matches Orders, Tables, Menu and
// Feedback instead of falling back to bare Material defaults.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';

/// A titled card: the shell every settings section sits in.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.dirty = false,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  /// Shows the unsaved-changes dot beside the title.
  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TavoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TavoSectionHeader(
            title: title,
            subtitle: subtitle,
            dense: true,
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (dirty) ...<Widget>[
                  const SettingsDirtyDot(),
                  const SizedBox(width: TavoSpace.sm),
                ],
                if (action != null) action!,
              ],
            ),
          ),
          const SizedBox(height: TavoSpace.md),
          child,
        ],
      ),
    );
  }
}

/// A gold dot meaning "this section has unsaved edits".
class SettingsDirtyDot extends StatelessWidget {
  const SettingsDirtyDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: TavoColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A labelled switch. Custom-painted rather than `Switch` so the panel keeps
/// one geometry and one palette; semantics are supplied explicitly.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.icon,
    this.trailing,
  });

  final String label;
  final String? subtitle;
  final bool value;

  /// `null` renders the row read-only.
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final Widget? trailing;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: TavoSpace.sm),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            TavoIconTile(
              icon: Icon(icon!, size: 18),
              size: 36,
              tone: value ? TavoTone.brand : TavoTone.neutral,
            ),
            const SizedBox(width: TavoSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TavoType.body.copyWith(
                    color: _enabled
                        ? TavoColors.foreground
                        : TavoColors.mutedForeground,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TavoType.caption
                        .copyWith(color: TavoColors.mutedForeground),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            trailing!,
            const SizedBox(width: TavoSpace.md),
          ],
          _Toggle(
            value: value,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      toggled: value,
      enabled: _enabled,
      label: label,
      hint: subtitle,
      child: ExcludeSemantics(
        // The whole row is the control: a settings row that only responds on
        // its 46 px switch is a row people tap and nothing happens.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: row,
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: SizedBox(
        width: 52,
        height: TavoSpace.minTouchTarget,
        child: Center(
          child: AnimatedContainer(
            duration: TavoMotion.fast,
            curve: TavoMotion.out,
            width: 46,
            height: 26,
            padding: const EdgeInsets.all(3),
            alignment:
                value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
            decoration: BoxDecoration(
              color: value
                  ? TavoColors.primary
                  : (enabled ? TavoColors.grayBgLight : TavoColors.muted),
              borderRadius: BorderRadius.circular(TavoRadii.pill),
              border: Border.all(
                color: value ? TavoColors.primary : TavoColors.border,
              ),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: TavoColors.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact numeric field: one label, one value, digits only.
class SettingsNumberField extends StatelessWidget {
  const SettingsNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.helper,
    this.enabled = true,
    this.onChanged,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool enabled;
  final VoidCallback? onChanged;

  /// Allows one decimal separator (money).
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      style: TavoType.body.copyWith(
        color: enabled ? TavoColors.foreground : TavoColors.mutedForeground,
        fontFeatures: TavoType.tabular,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TavoSpace.md,
          vertical: TavoSpace.md,
        ),
      ),
    );
  }
}

/// A 24-hour `HH:mm` field with an optional picker button.
class SettingsTimeField extends StatelessWidget {
  const SettingsTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.onChanged,
    this.onPick,
    this.pickSemanticLabel,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback? onChanged;
  final VoidCallback? onPick;
  final String? pickSemanticLabel;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged == null ? null : (_) => onChanged!(),
      keyboardType: TextInputType.datetime,
      textAlign: TextAlign.center,
      maxLength: 5,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
      ],
      style: TavoType.body.copyWith(
        color: enabled ? TavoColors.foreground : TavoColors.mutedForeground,
        fontFeatures: TavoType.tabular,
      ),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TavoSpace.sm,
          vertical: TavoSpace.md,
        ),
        suffixIcon: (onPick != null && enabled)
            ? IconButton(
                tooltip: pickSemanticLabel,
                icon: const Icon(Icons.schedule, size: 18),
                onPressed: onPick,
              )
            : null,
      ),
    );
  }
}

/// The one-line error under a section, in the panel's danger red.
class SettingsInlineError extends StatelessWidget {
  const SettingsInlineError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: TavoSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: TavoColors.danger),
          const SizedBox(width: TavoSpace.xs),
          Expanded(
            child: Text(
              message,
              style: TavoType.bodySmall.copyWith(color: TavoColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
