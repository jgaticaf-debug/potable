import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../datos/api/mock_api.dart';
import '../datos/estado_app.dart';
import '../datos/semilla.dart';
import '../dominio/modelos.dart';

class LoginPagina extends StatefulWidget {
  const LoginPagina({super.key, required this.estado});

  final EstadoApp estado;

  @override
  State<LoginPagina> createState() => _LoginPaginaState();
}

class _LoginPaginaState extends State<LoginPagina> {
  final _correo = TextEditingController(text: Semilla.usuarios.first.correo);
  final _clave = TextEditingController(text: MockApi.claveDemo);
  final _formulario = GlobalKey<FormState>();

  bool _ocultarClave = true;
  bool _enviando = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _error ??= widget.estado.sesionExpirada;
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final error =
        await widget.estado.iniciarSesion(_correo.text, _clave.text);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = error;
    });
  }

  void _usarCuenta(Usuario u) {
    setState(() {
      _correo.text = u.correo;
      _clave.text = MockApi.claveDemo;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Tema.azulOscuro, Tema.azul, Tema.cian],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 60, color: Colors.white),
                    const SizedBox(height: 14),
                    const Text(
                      'Potable',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Monitoreo de calidad del agua potable\n'
                      'COGUANOR NTG 29001',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formulario,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _correo,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo institucional',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: (v) =>
                                    (v == null || !v.contains('@'))
                                        ? 'Ingrese un correo valido'
                                        : null,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _clave,
                                obscureText: _ocultarClave,
                                decoration: InputDecoration(
                                  labelText: 'Contrasena',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _ocultarClave
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _ocultarClave = !_ocultarClave,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Ingrese su contrasena'
                                    : null,
                                onFieldSubmitted: (_) => _entrar(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Tema.rojo.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          size: 17, color: Tema.rojo),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Tema.rojo,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: _enviando ? null : _entrar,
                                child: _enviando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Iniciar sesion'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Cuentas de demostracion',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final u in Semilla.usuarios)
                          ActionChip(
                            avatar: CircleAvatar(
                              backgroundColor: Tema.azulOscuro,
                              child: Text(
                                u.iniciales,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            label: Text(
                              u.rol.etiqueta,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.white,
                            onPressed: () => _usarCuenta(u),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Contrasena para todas: ${MockApi.claveDemo}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
