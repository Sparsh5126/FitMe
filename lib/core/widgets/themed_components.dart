import 'package:flutter/material.dart';
import 'package:fitme/core/theme/models/theme_config.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEMED CARD COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final double? elevation;
  final VoidCallback? onTap;
  final bool outlined;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.shadows,
    this.elevation,
    this.onTap,
    this.outlined = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    final padding = this.padding ?? EdgeInsets.all(theme.spacing.md);
    final bgColor =
        backgroundColor ?? (outlined ? Colors.transparent : theme.colors.surfacePrimary);
    final borderColor = this.borderColor ??
        (outlined ? theme.colors.surfaceBorder : Colors.transparent);
    final borderRadius =
        this.borderRadius ?? BorderRadius.circular(theme.radius.lg);

    final decoration = BoxDecoration(
      color: bgColor,
      borderRadius: borderRadius,
      border:
          Border.all(color: borderColor, width: outlined ? 1 : 0),
      boxShadow: shadows,
    );

    final card = Container(
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED BUTTON VARIANTS
// ─────────────────────────────────────────────────────────────────────────────
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final double? width;
  final double? height;

  const AppButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    final bgColor = backgroundColor ?? theme.colors.accent;
    final fgColor = foregroundColor ?? theme.colors.backgroundPrimary;

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: ElevatedButton.icon(
        onPressed: (isLoading || isDisabled) ? null : onPressed,
        icon: isLoading
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(fgColor),
          ),
        )
            : icon != null ? Icon(icon) : const SizedBox.shrink(),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.lg),
          ),
          disabledBackgroundColor: theme.colors.disabled,
          disabledForegroundColor: theme.colors.textDisabled,
        ),
        label: Text(label),
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? foregroundColor;
  final IconData? icon;
  final double? width;
  final double? height;

  const AppOutlinedButton({
    Key? key,
    required this.label,
    this.onPressed,
    this.borderColor,
    this.foregroundColor,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    final borderColor = this.borderColor ?? theme.colors.textSecondary;
    final fgColor = foregroundColor ?? theme.colors.textPrimary;

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        style: OutlinedButton.styleFrom(
          foregroundColor: fgColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.lg),
          ),
        ),
        label: Text(label),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED TEXT INPUT
// ─────────────────────────────────────────────────────────────────────────────
class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final int maxLines;
  final int minLines;
  final Widget? suffix;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const AppTextField({
    Key? key,
    required this.label,
    this.hint,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.suffix,
    this.prefixIcon,
    this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        color: theme.colors.textPrimary,
        fontSize: theme.typography.bodyMediumSize,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: theme.colors.textSecondary,
          fontSize: theme.typography.bodyMediumSize,
        ),
        hintStyle: TextStyle(
          color: theme.colors.textSecondary,
        ),
        filled: true,
        fillColor: theme.colors.surfacePrimary,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
          borderSide: BorderSide(color: theme.colors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
          borderSide: BorderSide(color: theme.colors.error, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.md,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? primaryActionLabel;
  final String? secondaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onDismiss;

  const AppDialog({
    Key? key,
    required this.title,
    required this.message,
    this.primaryActionLabel,
    this.secondaryActionLabel,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;

    return AlertDialog(
      backgroundColor: theme.colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.lg),
        side: BorderSide(
          color: theme.colors.surfaceBorder,
          width: 1,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.colors.textPrimary,
          fontSize: theme.typography.titleLargeSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: theme.colors.textSecondary,
          fontSize: theme.typography.bodyMediumSize,
        ),
      ),
      actions: [
        if (secondaryActionLabel != null)
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onSecondaryAction?.call();
              onDismiss?.call();
            },
            child: Text(secondaryActionLabel!),
          ),
        if (primaryActionLabel != null)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onPrimaryAction?.call();
              onDismiss?.call();
            },
            child: Text(primaryActionLabel!),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class AppBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showHandle;

  const AppBottomSheet({
    Key? key,
    required this.title,
    required this.child,
    this.showHandle = true,
  }) : super(key: key);

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    bool showHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AppBottomSheet(
        title: title,
        child: child,
        showHandle: showHandle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.colors.surfaceElevated,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(theme.radius.xl),
        ),
        border: Border(
          top: BorderSide(
            color: theme.colors.surfaceBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            SizedBox(height: theme.spacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
          SizedBox(height: theme.spacing.lg),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.lg),
            child: Text(
              title,
              style: TextStyle(
                color: theme.colors.textPrimary,
                fontSize: theme.typography.headlineMediumSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: theme.spacing.md),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.lg),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED BADGE/CHIP
// ─────────────────────────────────────────────────────────────────────────────
class AppBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const AppBadge({
    Key? key,
    required this.label,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    final bgColor = backgroundColor ?? theme.colors.accentLight;
    final textColor = this.textColor ?? theme.colors.accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(theme.radius.md),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: theme.typography.labelMediumSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class AppDivider extends StatelessWidget {
  final Color? color;
  final double? thickness;
  final EdgeInsets? padding;

  const AppDivider({
    Key? key,
    this.color,
    this.thickness,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    final color = this.color ?? theme.colors.surfaceBorder;
    final thickness = this.thickness ?? 1.0;
    final padding = this.padding ?? EdgeInsets.symmetric(
      vertical: theme.spacing.md,
    );

    return Padding(
      padding: padding,
      child: Divider(
        color: color,
        thickness: thickness,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// THEMED SCAFFOLD WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class AppScaffold extends StatelessWidget {
  final Widget body;
  final String? appBarTitle;
  final Widget? appBarLeading;
  final List<Widget>? appBarActions;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool extendBodyBehindAppBar;
  final EdgeInsets? padding;

  const AppScaffold({
    Key? key,
    required this.body,
    this.appBarTitle,
    this.appBarLeading,
    this.appBarActions,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.extendBodyBehindAppBar = false,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      appBar: appBar ??
          (appBarTitle != null
              ? AppBar(
            backgroundColor: theme.colors.backgroundPrimary,
            elevation: 0,
            title: Text(appBarTitle!),
            leading: appBarLeading,
            actions: appBarActions,
          )
              : null),
      body: padding != null
          ? Padding(
            padding: padding!,
            child: body,
          )
          : body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
}
