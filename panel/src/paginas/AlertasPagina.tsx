import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { api } from '../api/cliente';
import type { Alerta, Clasificacion } from '../api/tipos';
import {
  Aviso,
  Boton,
  Cargando,
  Casilla,
  Confirmacion,
  Etiqueta,
  Seleccion,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { CLASIFICACION, fecha } from '../core/formato';

type Nivel = 'todos' | Clasificacion;

export function AlertasPagina() {
  const cola = useQueryClient();
  const [soloPendientes, setSoloPendientes] = useState(true);
  const [nivel, setNivel] = useState<Nivel>('todos');
  const [confirmando, setConfirmando] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resumen, setResumen] = useState<string | null>(null);

  const alertas = useQuery({ queryKey: ['alertas'], queryFn: api.alertas });
  const puntos = useQuery({ queryKey: ['puntos'], queryFn: api.puntos });

  const atender = useMutation({
    mutationFn: api.atenderAlerta,
    onSuccess: () => cola.invalidateQueries({ queryKey: ['alertas'] }),
    onError: (e: Error) => setError(e.message),
  });

  // Una por una aunque sea mas lento: asi cada alerta deja su registro en la
  // bitacora. Uno solo del lote perderia quien atendio que.
  const atenderVarias = useMutation({
    mutationFn: async (ids: number[]) => {
      let hechas = 0;
      try {
        for (const id of ids) {
          await api.atenderAlerta(id);
          hechas++;
        }
      } catch (e) {
        // Las anteriores ya quedaron atendidas de verdad, asi que reporto
        // cuantas alcanzaron.
        return { hechas, total: ids.length, fallo: (e as Error).message };
      }
      return { hechas, total: ids.length, fallo: null };
    },
    onSuccess: (r) => {
      setConfirmando(false);
      setError(r.fallo);
      setResumen(
        r.hechas === r.total
          ? `${r.hechas} alerta(s) marcadas como atendidas.`
          : `Se marcaron ${r.hechas} de ${r.total}. Intente de nuevo con las que quedaron.`,
      );
      void cola.invalidateQueries({ queryKey: ['alertas'] });
    },
  });

  if (alertas.isPending) return <Cargando />;
  if (alertas.error) return <Aviso>{alertas.error.message}</Aviso>;

  const nombrePunto = (id: number) =>
    puntos.data?.find((p) => p.id === id)?.nombre ?? `Punto ${id}`;

  const deNivel = (a: Alerta) => nivel === 'todos' || a.tipo === nivel;

  const pendientes = alertas.data.filter((a) => !a.atendida);
  // Las pendientes del filtro, no lo que se ve: con el filtro destildado
  // aparecen las atendidas y a esas no hay nada que hacerles.
  const objetivo = pendientes.filter(deNivel);

  const visibles = (soloPendientes ? pendientes : alertas.data).filter(deNivel);

  const cuantas = (t: Clasificacion) =>
    pendientes.filter((a) => a.tipo === t).length;

  return (
    <div className="mx-auto flex h-full max-w-5xl flex-col space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">
          Alertas
          {pendientes.length > 0 && (
            <span className="text-incumplimiento ml-3 align-middle text-sm font-normal">
              {pendientes.length} sin atender
            </span>
          )}
        </h1>
        <Casilla
          etiqueta="Solo pendientes"
          marcada={soloPendientes}
          alCambiar={setSoloPendientes}
        />
      </div>

      <Seleccion
        etiqueta="Nivel"
        valor={nivel}
        alCambiar={(v) => setNivel(v as Nivel)}
        opciones={[
          { valor: 'todos', texto: `Todos los niveles (${pendientes.length})` },
          {
            valor: 'incumplimiento',
            texto: `Incumple (${cuantas('incumplimiento')})`,
          },
          { valor: 'riesgo', texto: `En riesgo (${cuantas('riesgo')})` },
        ]}
      />

      {error && <Aviso>{error}</Aviso>}
      {resumen && <Aviso tono="exito">{resumen}</Aviso>}

      {/* Arriba: abajo habria que scrollear cientos de filas. */}
      {objetivo.length > 0 && (
        <div className="bg-card flex items-center justify-between gap-4 rounded-xl border px-5 py-3">
          <p className="text-muted-foreground text-sm">
            {objetivo.length} pendiente(s)
            {nivel !== 'todos' && ` de nivel ${CLASIFICACION[nivel]}`}
          </p>
          <Boton
            variante="suave"
            disabled={atenderVarias.isPending}
            onClick={() => {
              setError(null);
              setResumen(null);
              setConfirmando(true);
            }}
          >
            Marcar {objetivo.length} como atendidas
          </Boton>
        </div>
      )}

      <Tarjeta desplazable>
        {visibles.length === 0 ? (
          <Vacio>
            {soloPendientes
              ? 'No hay alertas pendientes con este filtro.'
              : 'No hay alertas con este filtro.'}
          </Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-muted-foreground bg-card sticky top-0 z-10 text-left text-xs uppercase">
              <tr className="border-b">
                <th className="px-5 py-3 font-medium">Fecha</th>
                <th className="px-5 py-3 font-medium">Punto</th>
                <th className="px-5 py-3 font-medium">Tipo</th>
                <th className="px-5 py-3 font-medium">Detalle</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody>
              {visibles.map((a) => (
                <tr key={a.id} className="border-b last:border-0">
                  <td className="text-muted-foreground whitespace-nowrap px-5 py-3">
                    {fecha(a.fecha)}
                  </td>
                  <td className="px-5 py-3 font-medium">
                    {nombrePunto(a.punto_id)}
                  </td>
                  <td className="px-5 py-3">
                    <Etiqueta tono={a.tipo}>{CLASIFICACION[a.tipo]}</Etiqueta>
                  </td>
                  <td className="text-muted-foreground px-5 py-3">
                    {a.detalle}
                  </td>
                  <td className="whitespace-nowrap px-5 py-3 text-right">
                    {a.atendida ? (
                      <Etiqueta tono="neutro">Atendida</Etiqueta>
                    ) : (
                      <Boton
                        variante="suave"
                        disabled={atender.isPending || atenderVarias.isPending}
                        onClick={() => {
                          setError(null);
                          setResumen(null);
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

      {confirmando && (
        <Confirmacion
          titulo="Marcar como atendidas"
          textoAccion="Marcar todas"
          textoTrabajando="Marcando..."
          trabajando={atenderVarias.isPending}
          mensaje={
            <>
              Se van a marcar <strong>{objetivo.length} alerta(s)</strong> como
              atendidas a su nombre, y cada una queda registrada en la bitacora.
              <br />
              <br />
              Hagalo solo si de verdad las reviso.
            </>
          }
          alConfirmar={() => atenderVarias.mutate(objetivo.map((a) => a.id))}
          alCerrar={() => setConfirmando(false)}
        />
      )}
    </div>
  );
}
