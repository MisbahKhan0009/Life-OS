import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// A tap target with a gentle press-down scale instead of a ripple.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.label, this.scale = 0.96, this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? label;
  final double scale;

  /// A light tick on tap, like iOS controls.
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null
              ? null
              : () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onLongPress!();
                },
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: () => _set(false),
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: Duration(milliseconds: _down ? 90 : 260),
            curve: _down ? Curves.easeOut : Curves.easeOutBack,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Frosted Liquid Glass surface for bars, menus and sheets. Never for content cards.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = Radii.l, this.padding, this.blur = 24, this.tint});

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? c.glass,
              borderRadius: r,
              border: Border.all(color: c.glassEdge),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Round icon button.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, this.onTap, this.size = 40, this.background, this.foreground});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background ?? c.surface, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.45, color: foreground ?? c.ink),
      ),
    );
  }
}

/// Pill button. [primary] is ink-filled, [action] is the red one-per-screen button.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.icon, this.onTap, this.style = PillStyle.primary, this.height = 48, this.mono = false, this.expand = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final PillStyle style;
  final double height;
  final bool mono;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (style) {
      PillStyle.primary => (c.ink, c.inverseInk),
      PillStyle.secondary => (c.surface, c.ink),
      PillStyle.action => (c.action, Colors.white),
      PillStyle.quiet => (c.chip, c.ink),
    };
    final text = mono ? AppText.label(13, color: fg, tracking: 0.2) : AppText.sans(15, weight: FontWeight.w600, color: fg);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
            Text(label, style: text),
          ],
        ),
      ),
    );
  }
}

enum PillStyle { primary, secondary, action, quiet }

/// Filter chip.
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? c.ink : c.chip, borderRadius: BorderRadius.circular(17)),
        child: Text(label, style: AppText.sans(13.5, weight: FontWeight.w500, color: selected ? c.inverseInk : c.ink)),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.sans(13, weight: FontWeight.w600, color: c.muted))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Bottom sheet in the app's own style.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final c = ctx.colors;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.xl)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 12),
                builder(ctx),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A row in a sheet or menu: label on the left, icon on the right.
class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.label, required this.icon, this.onTap, this.destructive = false, this.selected = false});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = destructive ? c.action : c.ink;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? c.ink.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.sans(15, color: color))),
            Icon(icon, size: 19, color: color),
          ],
        ),
      ),
    );
  }
}

/// Small transient message at the bottom of the screen.
void showToast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final c = context.colors;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: c.ink,
    elevation: 0,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    content: Text(message, style: AppText.sans(14, color: c.inverseInk)),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, textColor: c.inverseInk, onPressed: onAction ?? () {}),
  ));
}

/// Shared icon set (Cupertino outlines keep the app away from the Material look).
class AppIcons {
  static const notes = CupertinoIcons.doc_text;
  static const folder = CupertinoIcons.folder;
  static const focus = CupertinoIcons.timer;
  static const money = CupertinoIcons.creditcard;
  static const add = CupertinoIcons.plus;
  static const search = CupertinoIcons.search;
  static const more = CupertinoIcons.ellipsis;
  static const moreVertical = CupertinoIcons.ellipsis_vertical;
  static const pin = CupertinoIcons.pin;
  static const pinFill = CupertinoIcons.pin_fill;
  static const lock = CupertinoIcons.lock;
  static const unlock = CupertinoIcons.lock_open;
  static const checklist = CupertinoIcons.checkmark_square;
  static const image = CupertinoIcons.photo;
  static const trash = CupertinoIcons.trash;
  static const restore = CupertinoIcons.arrow_uturn_left;
  static const back = CupertinoIcons.chevron_left;
  static const forward = CupertinoIcons.chevron_right;
  static const close = CupertinoIcons.xmark;
  static const text = CupertinoIcons.textformat;
  static const bullet = CupertinoIcons.list_bullet;
  static const numbered = CupertinoIcons.list_number;
  static const quote = CupertinoIcons.quote_bubble;
  static const divider = CupertinoIcons.minus;
  static const code = CupertinoIcons.chevron_left_slash_chevron_right;
  static const archive = CupertinoIcons.archivebox;
  static const settings = CupertinoIcons.gear;
  static const copy = CupertinoIcons.doc_on_doc;
  static const sun = CupertinoIcons.sun_max;
  static const moon = CupertinoIcons.moon;
  static const check = CupertinoIcons.checkmark;
  static const edit = CupertinoIcons.pencil;
  static const ask = CupertinoIcons.sparkles;
  static const send = CupertinoIcons.arrow_up;
  static const standby = CupertinoIcons.device_phone_landscape;
}
