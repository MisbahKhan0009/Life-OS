/// Taka formatting with South Asian (lakh and crore) digit grouping,
/// and the little calculator behind the amount keypad.

const taka = '৳';

/// 1234567 -> "12,34,567".
String groupLakh(int n) {
  final neg = n < 0;
  var s = n.abs().toString();
  if (s.length > 3) {
    final last = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last';
  }
  return neg ? '-$s' : s;
}

/// Paisa to "৳12,34,567" or "৳1,250.50". Decimals only when there are paisa.
/// [sign] puts a + in front of positive amounts.
String money(int paisa, {bool symbol = true, bool sign = false, bool hidden = false}) {
  final prefix = symbol ? taka : '';
  if (hidden) return '$prefix••••';
  final neg = paisa < 0;
  final abs = paisa.abs();
  final whole = groupLakh(abs ~/ 100);
  final frac = abs % 100;
  final body = frac == 0 ? whole : '$whole.${frac.toString().padLeft(2, '0')}';
  final s = neg ? '-' : (sign && paisa > 0 ? '+' : '');
  return '$s$prefix$body';
}

/// Short form for tight spaces: "৳950", "৳12.5K", "৳3.4L", "৳1.2Cr".
String moneyShort(int paisa, {bool hidden = false}) {
  if (hidden) return '$taka••';
  final neg = paisa < 0;
  final t = paisa.abs() / 100;
  String body;
  if (t >= 10000000) {
    body = '${_trim(t / 10000000)}Cr';
  } else if (t >= 100000) {
    body = '${_trim(t / 100000)}L';
  } else if (t >= 1000) {
    body = '${_trim(t / 1000)}K';
  } else {
    body = t.round().toString();
  }
  return '${neg ? '-' : ''}$taka$body';
}

String _trim(double v) {
  final s = v.toStringAsFixed(v >= 100 ? 0 : 1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Parses typed text such as "1,250.5" into paisa. Returns null if it is not a number.
int? parseAmount(String text) {
  final clean = text.replaceAll(',', '').replaceAll(taka, '').trim();
  if (clean.isEmpty) return null;
  final v = double.tryParse(clean);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return (v * 100).round();
}

const calcOps = {'+', '−', '×', '÷'};

/// Evaluates a keypad expression like "120+45×2" into paisa (× and ÷ first).
/// A trailing operator is ignored. Returns null for an empty or invalid expression.
int? evalAmount(String expr) {
  var e = expr.replaceAll('-', '−').replaceAll('*', '×').replaceAll('/', '÷').replaceAll(' ', '');
  while (e.isNotEmpty && calcOps.contains(e[e.length - 1])) {
    e = e.substring(0, e.length - 1);
  }
  if (e.isEmpty) return null;

  final nums = <double>[];
  final ops = <String>[];
  var buf = '';
  for (var i = 0; i < e.length; i++) {
    final ch = e[i];
    if (calcOps.contains(ch)) {
      if (buf.isEmpty) return null;
      final v = double.tryParse(buf);
      if (v == null) return null;
      nums.add(v);
      ops.add(ch);
      buf = '';
    } else {
      buf += ch;
    }
  }
  final last = double.tryParse(buf);
  if (last == null) return null;
  nums.add(last);

  // First pass: × and ÷.
  final n2 = <double>[nums.first];
  final o2 = <String>[];
  for (var i = 0; i < ops.length; i++) {
    final op = ops[i];
    final b = nums[i + 1];
    if (op == '×') {
      n2[n2.length - 1] = n2.last * b;
    } else if (op == '÷') {
      if (b == 0) return null;
      n2[n2.length - 1] = n2.last / b;
    } else {
      n2.add(b);
      o2.add(op);
    }
  }
  // Second pass: + and −.
  var total = n2.first;
  for (var i = 0; i < o2.length; i++) {
    total = o2[i] == '+' ? total + n2[i + 1] : total - n2[i + 1];
  }
  if (total.isNaN || total.isInfinite) return null;
  return (total * 100).round();
}

/// True when the expression contains an operator that still needs evaluating.
bool hasOperator(String expr) => expr.split('').skip(1).any(calcOps.contains);

/// Applies one keypad press to an expression and returns the new expression.
/// Keys: digits, ".", the four operators, "⌫" and "C".
String keypadPress(String expr, String key) {
  if (key == 'C') return '';
  if (key == '⌫') return expr.isEmpty ? '' : expr.substring(0, expr.length - 1);
  final lastChar = expr.isEmpty ? '' : expr[expr.length - 1];
  if (calcOps.contains(key)) {
    if (expr.isEmpty) return '';
    if (calcOps.contains(lastChar)) return expr.substring(0, expr.length - 1) + key;
    if (lastChar == '.') return expr.substring(0, expr.length - 1) + key;
    return expr + key;
  }
  // Current number is everything after the last operator.
  var start = 0;
  for (var i = expr.length - 1; i >= 0; i--) {
    if (calcOps.contains(expr[i])) {
      start = i + 1;
      break;
    }
  }
  final current = expr.substring(start);
  if (key == '.') {
    if (current.contains('.')) return expr;
    return expr + (current.isEmpty ? '0.' : '.');
  }
  // Digits: at most two decimals, at most 10 whole digits, no leading zeros.
  final dot = current.indexOf('.');
  if (dot >= 0 && current.length - dot > 2) return expr;
  if (dot < 0 && current.length >= 10) return expr;
  if (current == '0') return expr.substring(0, expr.length - 1) + key;
  return expr + key;
}

/// Turns an amount back into keypad text: 125050 -> "1250.5".
String amountToExpr(int paisa) {
  if (paisa % 100 == 0) return (paisa ~/ 100).toString();
  final s = (paisa / 100).toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// Pretty version of an expression for display: "1250+300" -> "1,250 + 300".
String prettyExpr(String expr) {
  final out = StringBuffer();
  var buf = '';
  void flush() {
    if (buf.isEmpty) return;
    final dot = buf.indexOf('.');
    final whole = dot < 0 ? buf : buf.substring(0, dot);
    final rest = dot < 0 ? '' : buf.substring(dot);
    final n = int.tryParse(whole);
    out.write(n == null ? whole : groupLakh(n));
    out.write(rest);
    buf = '';
  }

  for (var i = 0; i < expr.length; i++) {
    final ch = expr[i];
    if (calcOps.contains(ch)) {
      flush();
      out.write(' $ch ');
    } else {
      buf += ch;
    }
  }
  flush();
  return out.toString().trimRight();
}
