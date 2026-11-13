import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/money_models.dart';
import '../../theme/tokens.dart';
import '../../ui/widgets.dart';

/// Colours for the Money hub: Navy, Steel and Ice Blue in light and dark.
class MoneyPalette {
  const MoneyPalette._({
    required this.dark,
    required this.bg,
    required this.card,
    required this.cardAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.soft,
  });

  final bool dark;
  final Color bg;
  final Color card;
  final Color cardAlt;
  final Color ink;
  final Color muted;
  final Color line;

  /// Primary filled control (navy in light, ice in dark).
  final Color accent;
  final Color onAccent;

  /// Quiet fill for chips and tracks.
  final Color soft;

  Color get deposit => dark ? const Color(0xFF7FB38C) : MoneyColors.deposit;
  Color get expense => dark ? const Color(0xFFE08A76) : MoneyColors.expense;

  static const _light = MoneyPalette._(
    dark: false,
    bg: MoneyColors.ice,
    card: Colors.white,
    cardAlt: MoneyColors.paleBlue,
    ink: MoneyColors.navy,
    muted: MoneyColors.teal,
    line: MoneyColors.sky,
    accent: MoneyColors.navy,
    onAccent: MoneyColors.ice,
    soft: MoneyColors.paleBlue,
  );

  static const _dark = MoneyPalette._(
    dark: true,
    bg: MoneyColors.navy,
    card: MoneyColors.deepNavy,
    cardAlt: Color(0xFF22324A),
    ink: MoneyColors.ice,
    muted: MoneyColors.airy,
    line: Color(0xFF2A3A52),
    accent: MoneyColors.ice,
    onAccent: MoneyColors.navy,
    soft: Color(0xFF253550),
  );

  static MoneyPalette of(BuildContext context) => context.colors.isDark ? _dark : _light;
}

/// Category icon keys to icons.
IconData categoryIcon(String key) => switch (key) {
      'food' => CupertinoIcons.flame,
      'cart' => CupertinoIcons.cart,
      'car' => CupertinoIcons.car_detailed,
      'house' => CupertinoIcons.house,
      'bolt' => CupertinoIcons.bolt,
      'phone' => CupertinoIcons.device_phone_portrait,
      'bag' => CupertinoIcons.bag,
      'heart' => CupertinoIcons.heart,
      'book' => CupertinoIcons.book,
      'people' => CupertinoIcons.person_2,
      'film' => CupertinoIcons.film,
      'gift' => CupertinoIcons.gift,
      'briefcase' => CupertinoIcons.briefcase,
      'chart' => CupertinoIcons.chart_bar_alt_fill,
      'laptop' => CupertinoIcons.desktopcomputer,
      'percent' => CupertinoIcons.percent,
      'airplane' => CupertinoIcons.airplane,
      'paw' => CupertinoIcons.paw,
      'sport' => CupertinoIcons.sportscourt,
      'scissors' => CupertinoIcons.scissors,
      'wrench' => CupertinoIcons.wrench,
      _ => CupertinoIcons.tag,
    };

const categoryIconKeys = [
  'food', 'cart', 'car', 'house', 'bolt', 'phone', 'bag', 'heart', 'book', 'people', 'film', 'gift', //
  'briefcase', 'chart', 'laptop', 'percent', 'airplane', 'paw', 'sport', 'scissors', 'wrench', 'tag',
];

IconData accountIcon(AccountKind k) => switch (k) {
      AccountKind.cash => CupertinoIcons.money_dollar,
      AccountKind.bank => CupertinoIcons.building_2_fill,
      AccountKind.wallet => CupertinoIcons.device_phone_portrait,
      AccountKind.savings => CupertinoIcons.tray_arrow_down,
      AccountKind.dps => CupertinoIcons.calendar_badge_plus,
      AccountKind.fdr => CupertinoIcons.lock_shield,
      AccountKind.card => CupertinoIcons.creditcard,
      AccountKind.investment => CupertinoIcons.graph_square,
    };

class MoneyIcons {
  static const expense = CupertinoIcons.arrow_up_right;
  static const deposit = CupertinoIcons.arrow_down_left;
  static const transfer = CupertinoIcons.arrow_right_arrow_left;
  static const eye = CupertinoIcons.eye;
  static const eyeOff = CupertinoIcons.eye_slash;
  static const goal = CupertinoIcons.flag;
  static const budget = CupertinoIcons.chart_pie;
  static const accounts = CupertinoIcons.square_stack_3d_up;
  static const calendar = CupertinoIcons.calendar;
}

IconData txnIcon(TxnKind k) => switch (k) {
      TxnKind.expense => MoneyIcons.expense,
      TxnKind.deposit => MoneyIcons.deposit,
      TxnKind.transfer => MoneyIcons.transfer,
    };

/// A Money-styled bottom sheet (navy/ice instead of the warm greys).
Future<T?> showMoneySheet<T>(BuildContext context, {required WidgetBuilder builder, bool scroll = false}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final p = MoneyPalette.of(ctx);
      final body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          builder(ctx),
        ],
      );
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(Radii.xl)),
          child: SafeArea(top: false, child: scroll ? SingleChildScrollView(child: body) : body),
        ),
      );
    },
  );
}

/// Rounded content card on the Money background.
class MoneyCard extends StatelessWidget {
  const MoneyCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? p.card, borderRadius: BorderRadius.circular(Radii.l)),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.98, child: box);
  }
}

class MoneySectionTitle extends StatelessWidget {
  const MoneySectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Expanded(child: Text(text, style: AppText.sans(13, weight: FontWeight.w600, color: p.muted))),
        if (action != null)
          Pressable(
            onTap: onAction,
            label: action,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(action!, style: AppText.sans(13, weight: FontWeight.w600, color: p.ink)),
            ),
          ),
      ]),
    );
  }
}

/// Round icon tile used for categories and accounts.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 40, this.background, this.foreground});

  final IconData icon;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? p.soft, borderRadius: BorderRadius.circular(size * 0.34)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.46, color: foreground ?? p.ink),
    );
  }
}

/// Selectable chip in the Money palette.
class MoneyChip extends StatelessWidget {
  const MoneyChip({super.key, required this.label, required this.selected, this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final fg = selected ? p.onAccent : p.ink;
    return Pressable(
      onTap: onTap,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(color: selected ? p.accent : p.soft, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
          Text(label, maxLines: 1, style: AppText.sans(13.5, weight: FontWeight.w500, color: fg)),
        ]),
      ),
    );
  }
}

/// Wide filled button in the Money palette.
class MoneyButton extends StatelessWidget {
  const MoneyButton({super.key, required this.label, this.icon, this.onTap, this.filled = true, this.color, this.height = 52});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final bg = color ?? (filled ? p.accent : p.soft);
    final fg = color != null ? Colors.white : (filled ? p.onAccent : p.ink);
    return Pressable(
      onTap: onTap,
      label: label,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.sans(15.5, weight: FontWeight.w600, color: fg))),
          ]),
        ),
      ),
    );
  }
}

/// Thin progress track.
class MoneyBar extends StatelessWidget {
  const MoneyBar({super.key, required this.value, this.color, this.height = 6});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: p.soft)),
          FractionallySizedBox(widthFactor: v, child: ColoredBox(color: color ?? p.accent)),
        ]),
      ),
    );
  }
}

/// Plain text field in the Money palette.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboard,
    this.autofocus = false,
    this.prefix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool autofocus;
  final String? prefix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: p.soft, borderRadius: BorderRadius.circular(Radii.s)),
      alignment: Alignment.center,
      child: Row(children: [
        if (prefix != null) ...[Text(prefix!, style: AppText.sans(16, weight: FontWeight.w600, color: p.muted)), const SizedBox(width: 6)],
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboard,
            onSubmitted: onSubmitted,
            cursorColor: p.ink,
            style: AppText.sans(16, color: p.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppText.sans(16, color: p.muted.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Label above a field in a sheet.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(text.toUpperCase(), style: AppText.label(10.5, color: p.muted)),
    );
  }
}

/// Header row for pushed Money pages.
class MoneyPageHeader extends StatelessWidget {
  const MoneyPageHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = MoneyPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        RoundIconButton(icon: AppIcons.back, label: 'Back', background: p.card, foreground: p.ink, onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppText.sans(20, weight: FontWeight.w700, color: p.ink, letterSpacing: -0.4))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Confirmation sheet; resolves true when confirmed.
Future<bool> confirmMoney(BuildContext context, {required String title, required String message, required String confirm}) async {
  final ok = await showMoneySheet<bool>(
    context,
    builder: (ctx) {
      final p = MoneyPalette.of(ctx);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: AppText.sans(18, weight: FontWeight.w700, color: p.ink)),
        const SizedBox(height: 6),
        Text(message, style: AppText.sans(14.5, color: p.muted, height: 1.4)),
        const SizedBox(height: 18),
        MoneyButton(label: confirm, color: p.expense, onTap: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 8),
        MoneyButton(label: 'Cancel', filled: false, onTap: () => Navigator.of(ctx).pop(false)),
      ]);
    },
  );
  return ok == true;
}
