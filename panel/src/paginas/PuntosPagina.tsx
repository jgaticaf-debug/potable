import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';

import { api } from '../api/cliente';
import type { Punto, TipoPunto, Zona } from '../api/tipos';
import {
  Aviso,
  Boton,
  Campo,
  Cargando,
  Casilla,
  Confirmacion,
  Etiqueta,
  Modal,
  Seleccion,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { useSesion } from '../sesion/sesion';

const TIPOS = [
  { valor: 'pozo', texto: 'Pozo' },
  { valor: 'tanque', texto: 'Tanque de almacenamiento' },
  { valor: 'linea', texto: 'Linea de distribucion' },
  { valor: 'tratamiento', texto: 'Equipo de tratamiento' },
  { valor: 'consumo', texto: 'Punto de consumo' },
];

const nombreTipo = (t: TipoPunto) =>
  TIPOS.find((x) => x.valor === t)?.texto ?? t;

export function PuntosPagina() {
  const cola = useQueryClient();
  const { esAdministrador } = useSesion();
  const [editando, setEditando] = useState<Punto | 'nuevo' | null>(null);
  const [borrando, setBorrando] = useState<Punto | null>(null);
  const [error, setError] = useState<string | null>(null);

  const puntos = useQuery({ queryKey: ['puntos'], queryFn: api.puntos });
  const zonas = useQuery({ queryKey: ['zonas'], queryFn: api.zonas });

  const borrar = useMutation({
    mutationFn: api.eliminarPunto,
    onSuccess: () => {
      cola.invalidateQueries({ queryKey: ['puntos'] });
      setBorrando(null);
    },
    onError: (e: Error) => {
      setError(e.message);
      setBorrando(null);
    },
  });

  if (puntos.isPending || zonas.isPending) return <Cargando />;
  if (puntos.error) return <Aviso>{puntos.error.message}</Aviso>;
  if (zonas.error) return <Aviso>{zonas.error.message}</Aviso>;

  const nombreZona = (id: number) =>
    zonas.data.find((z) => z.id === id)?.nombre ?? 'Sin zona';

  return (
    <div className="mx-auto flex h-full max-w-5xl flex-col space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-slate-800">
          Puntos de muestreo
        </h1>
        {esAdministrador && (
          <Boton
            disabled={zonas.data.length === 0}
            onClick={() => setEditando('nuevo')}
          >
            Nuevo punto
          </Boton>
        )}
      </div>

      {error && <Aviso>{error}</Aviso>}

      {zonas.data.length === 0 && (
        <Aviso tono="nota">
          Cree primero una zona: todo punto tiene que colgar de una.
        </Aviso>
      )}

      <Tarjeta desplazable>
        {puntos.data.length === 0 ? (
          <Vacio>Todavia no hay puntos registrados.</Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="sticky top-0 z-10 bg-white text-left text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-100">
                <th className="px-5 py-3 font-medium">Nombre</th>
                <th className="px-5 py-3 font-medium">Zona</th>
                <th className="px-5 py-3 font-medium">Tipo</th>
                <th className="px-5 py-3 font-medium">Sensor</th>
                <th className="px-5 py-3 font-medium">Coordenadas</th>
                {esAdministrador && <th className="px-5 py-3" />}
              </tr>
            </thead>
            <tbody>
              {puntos.data.map((p) => (
                <tr key={p.id} className="border-b border-slate-50 last:border-0">
                  <td className="px-5 py-3 font-medium text-slate-800">
                    {p.nombre}
                  </td>
                  <td className="px-5 py-3 text-slate-600">
                    {nombreZona(p.zona_id)}
                  </td>
                  <td className="px-5 py-3 text-slate-600">
                    {nombreTipo(p.tipo)}
                  </td>
                  <td className="px-5 py-3">
                    <Etiqueta tono={p.instrumentado ? 'apto' : 'neutro'}>
                      {p.instrumentado ? 'Instrumentado' : 'Manual'}
                    </Etiqueta>
                  </td>
                  <td className="px-5 py-3 text-slate-500">
                    {p.latitud !== null && p.longitud !== null
                      ? `${p.latitud}, ${p.longitud}`
                      : '—'}
                  </td>
                  {esAdministrador && (
                    <td className="whitespace-nowrap px-5 py-3 text-right">
                      <Boton variante="suave" onClick={() => setEditando(p)}>
                        Editar
                      </Boton>
                      <Boton
                        variante="peligro"
                        className="ml-2"
                        onClick={() => {
                          setError(null);
                          setBorrando(p);
                        }}
                      >
                        Eliminar
                      </Boton>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Tarjeta>

      {editando && (
        <FormularioPunto
          punto={editando === 'nuevo' ? null : editando}
          zonas={zonas.data}
          alCerrar={() => setEditando(null)}
        />
      )}

      {borrando && (
        <Confirmacion
          titulo="Eliminar punto"
          mensaje={
            <>
              Se eliminara el punto{' '}
              <strong className="text-slate-800">{borrando.nombre}</strong>. Si
              ya tiene muestras registradas el servidor no lo va a permitir.
            </>
          }
          trabajando={borrar.isPending}
          alConfirmar={() => borrar.mutate(borrando.id)}
          alCerrar={() => setBorrando(null)}
        />
      )}
    </div>
  );
}

function FormularioPunto({
  punto,
  zonas,
  alCerrar,
}: {
  punto: Punto | null;
  zonas: Zona[];
  alCerrar: () => void;
}) {
  const cola = useQueryClient();
  const [zonaId, setZonaId] = useState(String(punto?.zona_id ?? zonas[0]?.id));
  const [nombre, setNombre] = useState(punto?.nombre ?? '');
  const [tipo, setTipo] = useState<TipoPunto>(punto?.tipo ?? 'pozo');
  const [instrumentado, setInstrumentado] = useState(
    punto?.instrumentado ?? false,
  );
  const [latitud, setLatitud] = useState(punto?.latitud?.toString() ?? '');
  const [longitud, setLongitud] = useState(punto?.longitud?.toString() ?? '');
  const [error, setError] = useState<string | null>(null);

  const guardar = useMutation({
    mutationFn: () => {
      // Coordenada vacia va como null, no como 0: no es lo mismo "no la
      // tomamos" que "esta en el meridiano cero".
      const datos = {
        zona_id: Number(zonaId),
        nombre: nombre.trim(),
        tipo,
        instrumentado,
        latitud: latitud.trim() === '' ? null : Number(latitud),
        longitud: longitud.trim() === '' ? null : Number(longitud),
      };
      return punto ? api.editarPunto(punto.id, datos) : api.crearPunto(datos);
    },
    onSuccess: () => {
      cola.invalidateQueries({ queryKey: ['puntos'] });
      alCerrar();
    },
    onError: (e: Error) => setError(e.message),
  });

  function enviar(e: FormEvent) {
    e.preventDefault();
    setError(null);
    guardar.mutate();
  }

  return (
    <Modal titulo={punto ? 'Editar punto' : 'Nuevo punto'} alCerrar={alCerrar}>
      <form onSubmit={enviar} className="space-y-4">
        {error && <Aviso>{error}</Aviso>}

        <Campo
          etiqueta="Nombre"
          required
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
        />
        <Seleccion
          etiqueta="Zona"
          valor={zonaId}
          opciones={zonas.map((z) => ({
            valor: String(z.id),
            texto: z.nombre,
          }))}
          alCambiar={setZonaId}
        />
        <Seleccion
          etiqueta="Tipo"
          valor={tipo}
          opciones={TIPOS}
          alCambiar={(v) => setTipo(v as TipoPunto)}
        />

        <div className="grid grid-cols-2 gap-3">
          <Campo
            etiqueta="Latitud"
            type="number"
            step="any"
            value={latitud}
            onChange={(e) => setLatitud(e.target.value)}
          />
          <Campo
            etiqueta="Longitud"
            type="number"
            step="any"
            value={longitud}
            onChange={(e) => setLongitud(e.target.value)}
          />
        </div>

        <Casilla
          etiqueta="Tiene sensor instalado"
          marcada={instrumentado}
          alCambiar={setInstrumentado}
        />

        <div className="flex justify-end gap-2 pt-2">
          <Boton type="button" variante="suave" onClick={alCerrar}>
            Cancelar
          </Boton>
          <Boton type="submit" disabled={guardar.isPending}>
            {guardar.isPending ? 'Guardando...' : 'Guardar'}
          </Boton>
        </div>
      </form>
    </Modal>
  );
}
