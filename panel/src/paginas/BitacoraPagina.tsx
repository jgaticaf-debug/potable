import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';

import { api } from '../api/cliente';
import {
  Aviso,
  Cargando,
  Seleccion,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { accion, fecha } from '../core/formato';

export function BitacoraPagina() {
  const [filtro, setFiltro] = useState('todas');

  const registros = useQuery({
    queryKey: ['auditoria'],
    queryFn: () => api.auditoria(),
  });

  const acciones = useMemo(() => {
    const unicas = [...new Set((registros.data ?? []).map((r) => r.accion))];
    return unicas.sort().map((a) => ({ valor: a, texto: accion(a) }));
  }, [registros.data]);

  if (registros.isPending) return <Cargando />;
  if (registros.error) return <Aviso>{registros.error.message}</Aviso>;

  const visibles =
    filtro === 'todas'
      ? registros.data
      : registros.data.filter((r) => r.accion === filtro);

  return (
    <div className="mx-auto max-w-5xl space-y-4">
      <div>
        <h1 className="text-2xl font-semibold text-slate-800">Bitacora</h1>
        <p className="text-sm text-slate-500">
          Registro de auditoria. No se edita ni se borra.
        </p>
      </div>

      <Seleccion
        etiqueta="Accion"
        valor={filtro}
        alCambiar={setFiltro}
        opciones={[{ valor: 'todas', texto: 'Todas las acciones' }, ...acciones]}
      />

      <Tarjeta>
        {visibles.length === 0 ? (
          <Vacio>No hay registros para ese filtro.</Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-left text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-100">
                <th className="px-5 py-3 font-medium">Fecha</th>
                <th className="px-5 py-3 font-medium">Usuario</th>
                <th className="px-5 py-3 font-medium">Rol</th>
                <th className="px-5 py-3 font-medium">Accion</th>
                <th className="px-5 py-3 font-medium">Detalle</th>
              </tr>
            </thead>
            <tbody>
              {visibles.map((r) => (
                <tr key={r.id} className="border-b border-slate-50 last:border-0">
                  <td className="whitespace-nowrap px-5 py-3 text-slate-600">
                    {fecha(r.fecha)}
                  </td>
                  {/* El nombre y el rol son los del momento del hecho, no los
                      actuales. Por eso la bitacora los guarda copiados. */}
                  <td className="px-5 py-3 font-medium text-slate-800">
                    {r.usuario_nombre}
                  </td>
                  <td className="px-5 py-3 text-slate-600">{r.rol}</td>
                  <td className="px-5 py-3 text-slate-600">
                    {accion(r.accion)}
                  </td>
                  <td className="px-5 py-3 text-slate-500">{r.detalle || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Tarjeta>
    </div>
  );
}
