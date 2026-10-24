/// Indonesian number/time formatting without pulling locale data at startup.
abstract final class Fmt {
  /// 72000 -> "72.000"
  static String group(num v) {
    final neg = v < 0;
    final s = v.abs().round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '${neg ? '−' : ''}$b';
  }

  /// 72000 -> "Rp72.000"
  static String rp(num v) => '${v < 0 ? '−' : ''}Rp${group(v.abs())}';

  /// 35000 -> "Rp35rb"
  static String rpShort(num v) => 'Rp${(v / 1000).round()}rb';

  /// 5.24 -> "5,24"
  static String dec(double v, [int digits = 2]) => v.toStringAsFixed(digits).replaceAll('.', ',');

  /// 1930s -> "32:10", 4000s -> "1:06:40"
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }

  /// Pace in min/km -> 6'08"
  static String pace(Duration elapsed, double km) {
    if (km < .05) return "0'00\"";
    final secPerKm = elapsed.inSeconds / km;
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round().toString().padLeft(2, '0');
    return "$m'$s\"";
  }

  /// 90 min -> "1 j 30 m"
  static String hm(Duration d) => '${d.inHours} j ${d.inMinutes.remainder(60)} m';

  static const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const daysLong = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  static const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  static const monthsLong = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];

  static String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

  /// "Rab, 29 Okt · 19.00"
  static String dayDate(DateTime t) => '${days[t.weekday - 1]}, ${t.day} ${months[t.month - 1]} · ${hhmm(t)}';
}
