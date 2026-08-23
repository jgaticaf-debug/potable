import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/config.dart';

class Pbkdf2 {
  static int get iteraciones => Config.pbkdf2Iteraciones;
  static const longitudSal = 16;
  static const longitudClave = 32;

  static final _azar = Random.secure();

  static String generarSal() {
    final bytes = Uint8List.fromList(
      List<int>.generate(longitudSal, (_) => _azar.nextInt(256)),
    );
    return base64Url.encode(bytes);
  }

  static String derivar(String clave, String sal, {int? vueltas}) {
    final total = vueltas ?? iteraciones;
    final hmac = Hmac(sha256, utf8.encode(clave));
    final salBytes = base64Url.decode(sal);
    final derivada = <int>[];
    var bloque = 1;

    while (derivada.length < longitudClave) {
      final entrada = <int>[...salBytes, ..._enteroBigEndian(bloque)];
      var u = hmac.convert(entrada).bytes;
      final acumulado = List<int>.from(u);

      for (var i = 1; i < total; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < acumulado.length; j++) {
          acumulado[j] ^= u[j];
        }
      }

      derivada.addAll(acumulado);
      bloque++;
    }

    return base64Url.encode(derivada.sublist(0, longitudClave));
  }

  static String hashear(String clave) {
    final sal = generarSal();
    return 'pbkdf2_sha256\$$iteraciones\$$sal\$${derivar(clave, sal)}';
  }

  static bool verificar(String clave, String almacenado) {
    final partes = almacenado.split('\$');
    if (partes.length != 4 || partes[0] != 'pbkdf2_sha256') return false;
    final vueltas = int.tryParse(partes[1]);
    if (vueltas == null) return false;
    return _igualdadConstante(
      derivar(clave, partes[2], vueltas: vueltas),
      partes[3],
    );
  }

  static bool _igualdadConstante(String a, String b) {
    if (a.length != b.length) return false;
    var diferencia = 0;
    for (var i = 0; i < a.length; i++) {
      diferencia |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diferencia == 0;
  }

  static List<int> _enteroBigEndian(int valor) => [
        (valor >> 24) & 0xFF,
        (valor >> 16) & 0xFF,
        (valor >> 8) & 0xFF,
        valor & 0xFF,
      ];
}

class TokenInvalido implements Exception {
  const TokenInvalido(this.motivo);
  final String motivo;

  @override
  String toString() => motivo;
}

class Jwt {
  static const _encabezado = {'alg': 'HS256', 'typ': 'JWT'};

  static String firmar(
    Map<String, dynamic> reclamos,
    String secreto, {
    Duration? vigencia,
  }) {
    final duracion = vigencia ?? Config.jwtVigencia;
    final ahora = DateTime.now();
    final cuerpo = <String, dynamic>{
      ...reclamos,
      'iat': ahora.millisecondsSinceEpoch ~/ 1000,
      'exp': ahora.add(duracion).millisecondsSinceEpoch ~/ 1000,
    };

    final h = _codificar(_encabezado);
    final c = _codificar(cuerpo);
    return '$h.$c.${_firma('$h.$c', secreto)}';
  }

  static Map<String, dynamic> verificar(String token, String secreto) {
    final partes = token.split('.');
    if (partes.length != 3) {
      throw const TokenInvalido('El token esta malformado.');
    }

    final esperada = _firma('${partes[0]}.${partes[1]}', secreto);
    if (!Pbkdf2._igualdadConstante(partes[2], esperada)) {
      throw const TokenInvalido('La firma del token no es valida.');
    }

    final cuerpo = _decodificar(partes[1]);
    final exp = cuerpo['exp'] as int?;
    if (exp == null) {
      throw const TokenInvalido('El token no declara vencimiento.');
    }
    final vence = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (DateTime.now().isAfter(vence)) {
      throw const TokenInvalido('La sesion expiro. Vuelva a iniciar sesion.');
    }

    return cuerpo;
  }

  static Map<String, dynamic>? leerCuerpo(String token) {
    try {
      final partes = token.split('.');
      if (partes.length != 3) return null;
      return _decodificar(partes[1]);
    } catch (_) {
      return null;
    }
  }

  static DateTime? vencimientoDe(String token) {
    try {
      final exp = _decodificar(token.split('.')[1])['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }

  static String _firma(String datos, String secreto) {
    final hmac = Hmac(sha256, utf8.encode(secreto));
    return _sinRelleno(base64Url.encode(hmac.convert(utf8.encode(datos)).bytes));
  }

  static String _codificar(Map<String, dynamic> mapa) =>
      _sinRelleno(base64Url.encode(utf8.encode(jsonEncode(mapa))));

  static Map<String, dynamic> _decodificar(String segmento) {
    final relleno = '=' * ((4 - segmento.length % 4) % 4);
    final texto = utf8.decode(base64Url.decode(segmento + relleno));
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  static String _sinRelleno(String b64) => b64.replaceAll('=', '');
}
