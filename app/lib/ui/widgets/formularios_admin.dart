import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dominio/modelos.dart';

Future<Zona?> mostrarFormularioZona(
  BuildContext context, {
  required int organizacionId,
  Zona? zona,
}) {
  return showModalBottomSheet<Zona>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HojaFormulario(
      titulo: zona == null ? 'Nueva zona' : 'Editar zona',
      child: _FormularioZona(organizacionId: organizacionId, zona: zona),
    ),
  );
}

Future<PuntoMuestreo?> mostrarFormularioPunto(
  BuildContext context, {
  required int organizacionId,
  required List<Zona> zonas,
  PuntoMuestreo? punto,
}) {
  return showModalBottomSheet<PuntoMuestreo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _HojaFormulario(
      titulo: punto == null ? 'Nuevo punto' : 'Editar punto',
      child: _FormularioPunto(
        organizacionId: organizacionId,
        zonas: zonas,
        punto: punto,
      ),
    ),
  );
}

class _HojaFormulario extends StatelessWidget {
  const _HojaFormulario({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _FormularioZona extends StatefulWidget {
  const _FormularioZona({required this.organizacionId, this.zona});

  final int organizacionId;
  final Zona? zona;

  @override
  State<_FormularioZona> createState() => _FormularioZonaState();
}

class _FormularioZonaState extends State<_FormularioZona> {
  final _clave = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.zona?.nombre ?? '');
  late final _descripcion =
      TextEditingController(text: widget.zona?.descripcion ?? '');
  late bool _activa = widget.zona?.activa ?? true;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_clave.currentState!.validate()) return;
    Navigator.of(context).pop(
      Zona(
        id: widget.zona?.id ?? 0,
        organizacionId: widget.organizacionId,
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        activa: _activa,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _clave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre de la zona',
              hintText: 'Plantacion 4',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Escriba un nombre'
                : null,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _descripcion,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripcion (opcional)',
              hintText: 'Ubicacion, tipo de cultivo, uso del agua...',
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: _activa,
            onChanged: (v) => setState(() => _activa = v),
            title: const Text('Zona activa', style: TextStyle(fontSize: 13.5)),
            subtitle: const Text(
              'Las zonas inactivas no aparecen en el tablero ni en captura.',
              style: TextStyle(fontSize: 11),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          if (widget.zona == null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0x14D98A0B),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: Color(0xFFB8770A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La zona no aparecera en captura ni en el tablero '
                      'hasta que le agregue al menos un punto de muestreo.',
                      style: TextStyle(fontSize: 11, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}

class _FormularioPunto extends StatefulWidget {
  const _FormularioPunto({
    required this.organizacionId,
    required this.zonas,
    this.punto,
  });

  final int organizacionId;
  final List<Zona> zonas;
  final PuntoMuestreo? punto;

  @override
  State<_FormularioPunto> createState() => _FormularioPuntoState();
}

class _FormularioPuntoState extends State<_FormularioPunto> {
  final _clave = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.punto?.nombre ?? '');
  late final _latitud = TextEditingController(
    text: widget.punto?.latitud?.toString() ?? '',
  );
  late final _longitud = TextEditingController(
    text: widget.punto?.longitud?.toString() ?? '',
  );

  late int _zonaId = widget.punto?.zonaId ?? widget.zonas.first.id;
  late TipoPunto _tipo = widget.punto?.tipo ?? TipoPunto.pozo;
  late bool _instrumentado = widget.punto?.instrumentado ?? false;

  @override
  void dispose() {
    _nombre.dispose();
    _latitud.dispose();
    _longitud.dispose();
    super.dispose();
  }

  void _guardar() {
    if (!_clave.currentState!.validate()) return;
    Navigator.of(context).pop(
      PuntoMuestreo(
        id: widget.punto?.id ?? 0,
        organizacionId: widget.organizacionId,
        zonaId: _zonaId,
        nombre: _nombre.text.trim(),
        tipo: _tipo,
        instrumentado: _instrumentado,
        latitud: double.tryParse(_latitud.text.trim().replaceAll(',', '.')),
        longitud: double.tryParse(_longitud.text.trim().replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zonaValida =
        widget.zonas.any((z) => z.id == _zonaId) ? _zonaId : widget.zonas.first.id;

    return Form(
      key: _clave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre del punto',
              hintText: 'Pozo 3',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Escriba un nombre'
                : null,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            initialValue: zonaValida,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Zona',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: [
              for (final z in widget.zonas)
                DropdownMenuItem(value: z.id, child: Text(z.nombre)),
            ],
            onChanged: (v) => setState(() => _zonaId = v ?? zonaValida),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<TipoPunto>(
            initialValue: _tipo,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Tipo de punto',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final t in TipoPunto.values)
                DropdownMenuItem(value: t, child: Text(t.etiqueta)),
            ],
            onChanged: (v) => setState(() => _tipo = v ?? _tipo),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitud,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Latitud',
                    hintText: 'opcional',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _longitud,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Longitud',
                    hintText: 'opcional',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: _instrumentado,
            onChanged: (v) => setState(() => _instrumentado = v),
            title: const Text(
              'Tiene sensor conectado',
              style: TextStyle(fontSize: 13.5),
            ),
            subtitle: const Text(
              'Habilita la lectura por Bluetooth desde la pantalla de '
              'captura.',
              style: TextStyle(fontSize: 11),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
