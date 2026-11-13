import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/widgets.dart';

/// Focus is always dark: near-black ground, a light card for controls and the one red action.
class FocusColors {
  static const ground = Color(0xFF070707);
  static const panel = Color(0xFF151516);
  static const panelHigh = Color(0xFF1F1F21);
  static const line = Color(0xFF2E2E30);
  static const ink = Color(0xFFEDEDEA);
  static const muted = Color(0xFF8D8C88);
  static const dim = Color(0xFF5F5E5A);
  static const card = Color(0xFFECEBE7);
  static const cardSoft = Color(0xFFDCDBD5);
  static const cardInk = Color(0xFF151515);
  static const cardMuted = Color(0xFF6F6E6A);
  static const red = Color(0xFFE5262E);
  static const sage = Color(0xFF8FA591);
}

class FocusIcons {
  static const stats = CupertinoIcons.chart_bar_alt_fill;
  static const settings = CupertinoIcons.slider_horizontal_3;
  static const sound = CupertinoIcons.waveform;
  static const soundOff = CupertinoIcons.speaker_slash;
  static const note = CupertinoIcons.doc_text;
  static const link = CupertinoIcons.link;
  static const distract = CupertinoIcons.bolt;
  static const quickNote = CupertinoIcons.pencil;
  static const plusFive = CupertinoIcons.goforward_plus;
  static const skip = CupertinoIcons.forward_end;
  static const stop = CupertinoIcons.stop;
  static const expand = CupertinoIcons.fullscreen;
  static const collapse = CupertinoIcons.fullscreen_exit;
  static const flame = CupertinoIcons.flame;
  static const breathe = CupertinoIcons.wind;
  static const check = CupertinoIcons.checkmark_alt;
  static const copy = CupertinoIcons.doc_on_clipboard;
  static const edit = CupertinoIcons.pencil;
}

/// A dark bottom sheet for Focus.
Future<T?> showFocusSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scroll = true}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: FocusColors.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          builder(ctx),
        ],
      );
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: FocusColors.panel,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: FocusColors.line),
          ),
          child: SafeArea(top: false, child: scroll ? SingleChildScrollView(child: body) : body),
        ),
      );
    },
  );
}

class FocusSheetTitle extends StatelessWidget {
  const FocusSheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppText.sans(20, weight: FontWeight.w700, color: FocusColors.ink)),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: AppText.sans(13.5, color: FocusColors.muted, height: 1.4)),
      ],
    ]);
  }
}

class FocusLabel extends StatelessWidget {
  const FocusLabel(this.text, {super.key, this.top = 16});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(2, top, 2, 8),
        child: Text(text.toUpperCase(), style: AppText.label(10.5, color: FocusColors.muted)),
      );
}

/// Wide button for dark sheets. [red] is the one strong action.
class FocusButton extends StatelessWidget {
  const FocusButton({super.key, required this.label, this.onTap, this.red = false, this.quiet = false, this.icon, this.height = 52});

  final String label;
  final VoidCallback? onTap;
  final bool red;
  final bool quiet;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = red ? FocusColors.red : (quiet ? FocusColors.panelHigh : FocusColors.ink);
    final fg = red ? Colors.white : (quiet ? FocusColors.ink : FocusColors.ground);
    return Pressable(
      onTap: onTap,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 17, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15.5, weight: FontWeight.w600, color: fg))),
          ]),
        ),
      ),
    );
  }
}

/// Dark text field.
class FocusField extends StatelessWidget {
  const FocusField({super.key, required this.controller, required this.hint, this.autofocus = false, this.maxLines = 1, this.keyboard, this.onSubmitted});

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboard;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: FocusColors.panelHigh, borderRadius: BorderRadius.circular(Radii.s)),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: 1,
        keyboardType: keyboard,
        onSubmitted: onSubmitted,
        cursorColor: FocusColors.ink,
        style: AppText.sans(16, color: FocusColors.ink),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppText.sans(16, color: FocusColors.dim),
        ),
      ),
    );
  }
}

/// Setting row with a switch.
class FocusToggle extends StatelessWidget {
  const FocusToggle({super.key, required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.sans(15, weight: FontWeight.w500, color: FocusColors.ink)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: AppText.sans(12.5, color: FocusColors.muted, height: 1.35)),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        CupertinoSwitch(value: value, activeTrackColor: FocusColors.red, onChanged: onChanged),
      ]),
    );
  }
}

/// Minus / value / plus control.
class FocusStepper extends StatelessWidget {
  const FocusStepper({super.key, required this.title, required this.value, required this.onChanged, this.step = 1, this.min = 1, this.max = 999, this.unit = ''});

  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final int min;
  final int max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String label, int next) => RoundIconButton(
          icon: icon,
          label: label,
          size: 36,
          background: FocusColors.panelHigh,
          foreground: next < min || next > max ? FocusColors.dim : FocusColors.ink,
          onTap: next < min || next > max ? null : () => onChanged(next),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(title, style: AppText.sans(15, weight: FontWeight.w500, color: FocusColors.ink))),
        btn(CupertinoIcons.minus, 'Less', value - step),
        SizedBox(
          width: 74,
          child: Text('$value$unit', textAlign: TextAlign.center, style: AppText.dot(20, color: FocusColors.ink)),
        ),
        btn(CupertinoIcons.plus, 'More', value + step),
      ]),
    );
  }
}

/// Five dots to pick a score from 1 to 5 (tap the same one again to clear).
class ScoreDots extends StatelessWidget {
  const ScoreDots({super.key, required this.value, required this.onChanged, required this.low, required this.high});

  final int value;
  final ValueChanged<int> onChanged;
  final String low;
  final String high;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              label: '$i of 5',
              onTap: () => onChanged(value == i ? 0 : i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i <= value ? FocusColors.ink : FocusColors.panelHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('$i', style: AppText.dot(20, color: i <= value ? FocusColors.ground : FocusColors.muted)),
              ),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Text(low, style: AppText.label(10, color: FocusColors.dim)),
        const Spacer(),
        Text(high, style: AppText.label(10, color: FocusColors.dim)),
      ]),
    ]);
  }
}

/// Header for pushed Focus pages.
class FocusPageHeader extends StatelessWidget {
  const FocusPageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        RoundIconButton(
          icon: AppIcons.back,
          label: 'Back',
          background: FocusColors.panelHigh,
          foreground: FocusColors.ink,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppText.sans(20, weight: FontWeight.w700, color: FocusColors.ink, letterSpacing: -0.4))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// "9:40 AM" style time.
String focusClock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}
