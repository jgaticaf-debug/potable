class Formato {
  static const _meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String _dosDigitos(int v) => v.toString().padLeft(2, '0');

  static String fechaHora(DateTime d) =>
      '${d.day} ${_meses[d.month - 1]} ${d.year}, '
      '${_dosDigitos(d.hour)}:${_dosDigitos(d.minute)}';

  static String fecha(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

  static String hora(DateTime d) =>
      '${_dosDigitos(d.hour)}:${_dosDigitos(d.minute)}';

  static String relativo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 30) return 'hace ${diff.inDays} d';
    return fecha(d);
  }

  static String numero(double v, {int maxDecimales = 2}) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final texto = v.toStringAsFixed(maxDecimales);
    return texto.contains('.')
        ? texto.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : texto;
  }

  static String porcentaje(double v) => '${v.toStringAsFixed(1)} %';

  static String coordenada(double lat, double lon) =>
      '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
}
