import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';

import { api } from '../api/cliente';
import type { Zona } from '../api/tipos';
import {
  Aviso,
  Boton,
  Campo,
  Cargando,
  Confirmacion,
  Etiqueta,
  Modal,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { useSesion } from '../sesion/sesion';

export function ZonasPagina() {
  const cola = useQueryClient();
  const { esAdministrador } = useSesion();
  const [editando, setEditando] = useState<Zona | 'nueva' | null>(null);
  const [borrando, setBorrando] = useState<Zona | null>(null);
  const [error, setError] = useState<string | null>(null);

  const zonas = useQuery({ queryKey: ['zonas'], queryFn: api.zonas });
  const puntos = useQuery({ queryKey: ['puntos'], queryFn: api.puntos });

  const borrar = useMutation({
    mutationFn: api.eliminarZona,
    onSuccess: () => {
      cola.invalidateQueries({ queryKey: ['zonas'] });
      setBorrando(null);
    },
    onError: (e: Error) => {
      setError(e.message);
      setBorrando(null);
    },
  });

  if (zonas.isPending) return <Cargando />;
  if (zonas.error) return <Aviso>{zonas.error.message}</Aviso>;

  const cuantosPuntos = (zonaId: number) =>
    puntos.data?.filter((p) => p.zona_id === zonaId).length ?? 0;

  return (
    <div className="mx-auto max-w-4xl space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-slate-800">Zonas</h1>
        {esAdministrador && (
          <Boton onClick={() => setEditando('nueva')}>Nueva zona</Boton>
        )}
      </div>

      {error && <Aviso>{error}</Aviso>}

      <Tarjeta>
        {zonas.data.length === 0 ? (
          <Vacio>Todavia no hay zonas registradas.</Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-left text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-100">
                <th className="px-5 py-3 font-medium">Nombre</th>
                <th className="px-5 py-3 font-medium">Descripcion</th>
                <th className="px-5 py-3 font-medium">Puntos</th>
                <th className="px-5 py-3 font-medium">Estado</th>
                {esAdministrador && <th className="px-5 py-3" />}
              </tr>
            </thead>
            <tbody>
              {zonas.data.map((z) => (
                <tr key={z.id} className="border-b border-slate-50 last:border-0">
                  <td className="px-5 py-3 font-medium text-slate-800">
                    {z.nombre}
                  </td>
                  <td className="px-5 py-3 text-slate-600">
                    {z.descripcion || '—'}
                  </td>
                  <td className="px-5 py-3 text-slate-600">
                    {cuantosPuntos(z.id)}
                  </td>
                  <td className="px-5 py-3">
                    <Etiqueta tono={z.activa ? 'apto' : 'neutro'}>
                      {z.activa ? 'Activa' : 'Inactiva'}
                    </Etiqueta>
                  </td>
                  {esAdministrador && (
                    <td className="whitespace-nowrap px-5 py-3 text-right">
                      <Boton variante="suave" onClick={() => setEditando(z)}>
                        Editar
                      </Boton>
                      <Boton
                        variante="peligro"
                        className="ml-2"
                        onClick={() => {
                          setError(null);
                          setBorrando(z);
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
        <FormularioZona
          zona={editando === 'nueva' ? null : editando}
          alCerrar={() => setEditando(null)}
        />
      )}

      {borrando && (
        <Confirmacion
          titulo="Eliminar zona"
          mensaje={
            <>
              Se eliminara la zona{' '}
              <strong className="text-slate-800">{borrando.nombre}</strong>.
              {cuantosPuntos(borrando.id) > 0 && (
                <> Tiene puntos asignados, asi que el servidor lo va a impedir.</>
              )}
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

function FormularioZona({
  zona,
  alCerrar,
}: {
  zona: Zona | null;
  alCerrar: () => void;
}) {
  const cola = useQueryClient();
  const [nombre, setNombre] = useState(zona?.nombre ?? '');
  const [descripcion, setDescripcion] = useState(zona?.descripcion ?? '');
  const [activa, setActiva] = useState(zona?.activa ?? true);
  const [error, setError] = useState<string | null>(null);

  const guardar = useMutation({
    mutationFn: () => {
      const datos = {
        nombre: nombre.trim(),
        descripcion: descripcion.trim(),
        activa,
      };
      return zona ? api.editarZona(zona.id, datos) : api.crearZona(datos);
    },
    onSuccess: () => {
      cola.invalidateQueries({ queryKey: ['zonas'] });
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
    <Modal titulo={zona ? 'Editar zona' : 'Nueva zona'} alCerrar={alCerrar}>
      <form onSubmit={enviar} className="space-y-4">
        {error && <Aviso>{error}</Aviso>}

        <Campo
          etiqueta="Nombre"
          required
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
          ayuda="No se puede repetir dentro de la organizacion."
        />
        <Campo
          etiqueta="Descripcion"
          value={descripcion}
          onChange={(e) => setDescripcion(e.target.value)}
        />

        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={activa}
            onChange={(e) => setActiva(e.target.checked)}
          />
          Zona activa
        </label>

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
