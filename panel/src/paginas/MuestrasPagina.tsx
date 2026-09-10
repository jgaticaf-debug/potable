import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';

import { api } from '../api/cliente';
import type { Clasificacion, Muestra, Parametro } from '../api/tipos';
import {
  Aviso,
  Cargando,
  Etiqueta,
  Modal,
  Seleccion,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { CLASIFICACION, fecha, numero, rango } from '../core/formato';

export function MuestrasPagina() {
  const [punto, setPunto] = useState('todos');
  const [clase, setClase] = useState('todas');
  const [detalle, setDetalle] = useState<Muestra | null>(null);

  const muestras = useQuery({
    queryKey: ['muestras'],
    queryFn: () => api.muestras(),
  });
  const puntos = useQuery({ queryKey: ['puntos'], queryFn: api.puntos });
  const parametros = useQuery({
    queryKey: ['parametros'],
    queryFn: api.parametros,
  });
  const usuarios = useQuery({ queryKey: ['usuarios'], queryFn: api.usuarios });

  const filtradas = useMemo(() => {
    const todas = muestras.data ?? [];
    return todas.filter(
      (m) =>
        (punto === 'todos' || m.punto_id === Number(punto)) &&
        (clase === 'todas' || m.clasificacion_global === clase),
    );
  }, [muestras.data, punto, clase]);

  if (muestras.isPending || puntos.isPending || parametros.isPending) {
    return <Cargando />;
  }
  if (muestras.error) return <Aviso>{muestras.error.message}</Aviso>;

  const nombrePunto = (id: number) =>
    puntos.data?.find((p) => p.id === id)?.nombre ?? `Punto ${id}`;

  // usuarios solo lo puede leer un administrador, asi que para calidad la
  // columna queda con el id. Preferible eso a esconderle la muestra.
  const nombreUsuario = (id: number) =>
    usuarios.data?.find((u) => u.id === id)?.nombre ?? `Usuario ${id}`;

  const nombreParametro = (id: number | null) =>
    id === null
      ? '—'
      : (parametros.data?.find((p) => p.id === id)?.nombre ?? `#${id}`);

  return (
    <div className="mx-auto max-w-5xl space-y-4">
      <h1 className="text-2xl font-semibold text-slate-800">Muestras</h1>

      <div className="grid gap-3 sm:grid-cols-2">
        <Seleccion
          etiqueta="Punto"
          valor={punto}
          alCambiar={setPunto}
          opciones={[
            { valor: 'todos', texto: 'Todos los puntos' },
            ...(puntos.data ?? []).map((p) => ({
              valor: String(p.id),
              texto: p.nombre,
            })),
          ]}
        />
        <Seleccion
          etiqueta="Resultado"
          valor={clase}
          alCambiar={setClase}
          opciones={[
            { valor: 'todas', texto: 'Todos los resultados' },
            { valor: 'apto', texto: 'Apto' },
            { valor: 'riesgo', texto: 'En riesgo' },
            { valor: 'incumplimiento', texto: 'Incumple' },
          ]}
        />
      </div>

      <Tarjeta>
        {filtradas.length === 0 ? (
          <Vacio>
            {(muestras.data ?? []).length === 0
              ? 'Todavia no se ha sincronizado ninguna muestra.'
              : 'Ninguna muestra coincide con el filtro.'}
          </Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-left text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-100">
                <th className="px-5 py-3 font-medium">Fecha</th>
                <th className="px-5 py-3 font-medium">Punto</th>
                <th className="px-5 py-3 font-medium">Tomada por</th>
                <th className="px-5 py-3 font-medium">Resultado</th>
                <th className="px-5 py-3 font-medium">Limitante</th>
              </tr>
            </thead>
            <tbody>
              {filtradas.map((m) => (
                <tr
                  key={m.id}
                  onClick={() => setDetalle(m)}
                  className="cursor-pointer border-b border-slate-50 last:border-0 hover:bg-slate-50"
                >
                  <td className="whitespace-nowrap px-5 py-3 text-slate-600">
                    {fecha(m.fecha_hora)}
                  </td>
                  <td className="px-5 py-3 font-medium text-slate-800">
                    {nombrePunto(m.punto_id)}
                  </td>
                  <td className="px-5 py-3 text-slate-600">
                    {nombreUsuario(m.usuario_id)}
                  </td>
                  <td className="px-5 py-3">
                    <Etiqueta tono={m.clasificacion_global}>
                      {CLASIFICACION[m.clasificacion_global]}
                    </Etiqueta>
                  </td>
                  <td className="px-5 py-3 text-slate-600">
                    {nombreParametro(m.parametro_limitante_id)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Tarjeta>

      {detalle && (
        <DetalleMuestra
          muestra={detalle}
          parametros={parametros.data ?? []}
          punto={nombrePunto(detalle.punto_id)}
          alCerrar={() => setDetalle(null)}
        />
      )}
    </div>
  );
}

function DetalleMuestra({
  muestra,
  parametros,
  punto,
  alCerrar,
}: {
  muestra: Muestra;
  parametros: Parametro[];
  punto: string;
  alCerrar: () => void;
}) {
  return (
    <Modal titulo={punto} alCerrar={alCerrar}>
      <div className="space-y-4">
        <div className="flex items-center gap-3 text-sm text-slate-500">
          {fecha(muestra.fecha_hora)}
          <Etiqueta tono={muestra.clasificacion_global}>
            {CLASIFICACION[muestra.clasificacion_global]}
          </Etiqueta>
        </div>

        <div className="divide-y divide-slate-100 rounded-xl border border-slate-200">
          {muestra.mediciones.map((med) => {
            const p = parametros.find((x) => x.id === med.parametro_id);
            return (
              <div key={med.parametro_id} className="flex gap-3 px-4 py-3">
                <div className="min-w-0 flex-1">
                  <p className="font-medium text-slate-800">
                    {p?.nombre ?? `Parametro ${med.parametro_id}`}
                    {p?.critico && (
                      <span className="ml-2 text-xs font-normal text-incumplimiento">
                        critico
                      </span>
                    )}
                  </p>
                  <p className="text-xs text-slate-500">
                    {p ? rango(p) : 'Sin limite'} · {med.origen}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-semibold text-slate-800">
                    {numero(med.valor)}{' '}
                    <span className="text-xs font-normal text-slate-500">
                      {p?.unidad}
                    </span>
                  </p>
                  <Etiqueta tono={med.clasificacion as Clasificacion}>
                    {CLASIFICACION[med.clasificacion]}
                  </Etiqueta>
                </div>
              </div>
            );
          })}
        </div>

        {muestra.observaciones && (
          <div>
            <p className="mb-1 text-xs uppercase text-slate-500">
              Observaciones
            </p>
            <p className="text-sm text-slate-600">{muestra.observaciones}</p>
          </div>
        )}

        <p className="text-xs text-slate-400">
          Registrada en el dispositivo {fecha(muestra.creado_en)} · recibida en
          el servidor {fecha(muestra.recibido_en)}
        </p>
      </div>
    </Modal>
  );
}
