import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { api } from '../api/cliente';
import {
  Aviso,
  Boton,
  Cargando,
  Etiqueta,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { CLASIFICACION, fecha } from '../core/formato';

export function AlertasPagina() {
  const cola = useQueryClient();
  const [soloPendientes, setSoloPendientes] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const alertas = useQuery({ queryKey: ['alertas'], queryFn: api.alertas });
  const puntos = useQuery({ queryKey: ['puntos'], queryFn: api.puntos });

  const atender = useMutation({
    mutationFn: api.atenderAlerta,
    onSuccess: () => cola.invalidateQueries({ queryKey: ['alertas'] }),
    onError: (e: Error) => setError(e.message),
  });

  if (alertas.isPending) return <Cargando />;
  if (alertas.error) return <Aviso>{alertas.error.message}</Aviso>;

  const nombrePunto = (id: number) =>
    puntos.data?.find((p) => p.id === id)?.nombre ?? `Punto ${id}`;

  const visibles = soloPendientes
    ? alertas.data.filter((a) => !a.atendida)
    : alertas.data;

  const pendientes = alertas.data.filter((a) => !a.atendida).length;

  return (
    <div className="mx-auto max-w-5xl space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-slate-800">
          Alertas
          {pendientes > 0 && (
            <span className="ml-3 align-middle text-sm font-normal text-incumplimiento">
              {pendientes} sin atender
            </span>
          )}
        </h1>
        <label className="flex items-center gap-2 text-sm text-slate-600">
          <input
            type="checkbox"
            checked={soloPendientes}
            onChange={(e) => setSoloPendientes(e.target.checked)}
          />
          Solo pendientes
        </label>
      </div>

      {error && <Aviso>{error}</Aviso>}

      <Tarjeta>
        {visibles.length === 0 ? (
          <Vacio>
            {soloPendientes
              ? 'No hay alertas pendientes.'
              : 'Todavia no se ha generado ninguna alerta.'}
          </Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-left text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-100">
                <th className="px-5 py-3 font-medium">Fecha</th>
                <th className="px-5 py-3 font-medium">Punto</th>
                <th className="px-5 py-3 font-medium">Tipo</th>
                <th className="px-5 py-3 font-medium">Detalle</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody>
              {visibles.map((a) => (
                <tr key={a.id} className="border-b border-slate-50 last:border-0">
                  <td className="whitespace-nowrap px-5 py-3 text-slate-600">
                    {fecha(a.fecha)}
                  </td>
                  <td className="px-5 py-3 font-medium text-slate-800">
                    {nombrePunto(a.punto_id)}
                  </td>
                  <td className="px-5 py-3">
                    <Etiqueta tono={a.tipo}>{CLASIFICACION[a.tipo]}</Etiqueta>
                  </td>
                  <td className="px-5 py-3 text-slate-600">{a.detalle}</td>
                  <td className="whitespace-nowrap px-5 py-3 text-right">
                    {a.atendida ? (
                      <Etiqueta tono="neutro">Atendida</Etiqueta>
                    ) : (
                      <Boton
                        variante="suave"
                        disabled={atender.isPending}
                        onClick={() => {
                          setError(null);
                          atender.mutate(a.id);
                        }}
                      >
                        Marcar atendida
                      </Boton>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Tarjeta>
    </div>
  );
}
