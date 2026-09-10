import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState, type FormEvent } from 'react';

import { api } from '../api/cliente';
import type { Rol, Usuario } from '../api/tipos';
import {
  Aviso,
  Boton,
  Campo,
  Cargando,
  Confirmacion,
  Etiqueta,
  Modal,
  Seleccion,
  Tarjeta,
  Vacio,
} from '../componentes/comunes';
import { useSesion } from '../sesion/sesion';

const ROLES = [
  { valor: 'operario', texto: 'Operario' },
  { valor: 'calidad', texto: 'Control de calidad' },
  { valor: 'administrador', texto: 'Administrador' },
];

export function UsuariosPagina() {
  const cola = useQueryClient();
  const { usuario: yo } = useSesion();
  const [editando, setEditando] = useState<Usuario | 'nuevo' | null>(null);
  const [borrando, setBorrando] = useState<Usuario | null>(null);
  const [error, setError] = useState<string | null>(null);

  const lista = useQuery({ queryKey: ['usuarios'], queryFn: api.usuarios });

  const borrar = useMutation({
    mutationFn: api.eliminarUsuario,
    onSuccess: () => {
      cola.invalidateQueries({ queryKey: ['usuarios'] });
      setBorrando(null);
    },
    // El servidor se niega a borrar cuentas con muestras y explica por que.
    // Ese mensaje vale mas que un "no se pudo", asi que lo muestro tal cual.
    onError: (e: Error) => {
      setError(e.message);
      setBorrando(null);
    },
  });

  if (lista.isPending) return <Cargando />;
  if (lista.error) return <Aviso>{lista.error.message}</Aviso>;

  return (
    <div className="mx-auto max-w-4xl space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-slate-800">Usuarios</h1>
        <Boton onClick={() => setEditando('nuevo')}>Nuevo usuario</Boton>
      </div>

      {error && <Aviso>{error}</Aviso>}

      <Tarjeta>
        {lista.data.length === 0 ? (
          <Vacio>Todavia no hay cuentas registradas.</Vacio>
        ) : (
          <table className="w-full text-sm">
            <thead className="text-left text-xs uppercase text-slate-500">
              <tr className="border-b border-slate-100">
                <th className="px-5 py-3 font-medium">Nombre</th>
                <th className="px-5 py-3 font-medium">Correo</th>
                <th className="px-5 py-3 font-medium">Rol</th>
                <th className="px-5 py-3 font-medium">Estado</th>
                <th className="px-5 py-3" />
              </tr>
            </thead>
            <tbody>
              {lista.data.map((u) => (
                <tr key={u.id} className="border-b border-slate-50 last:border-0">
                  <td className="px-5 py-3 font-medium text-slate-800">
                    {u.nombre}
                    {u.id === yo?.id && (
                      <span className="ml-2 text-xs text-slate-400">(usted)</span>
                    )}
                  </td>
                  <td className="px-5 py-3 text-slate-600">{u.correo}</td>
                  <td className="px-5 py-3 text-slate-600">{u.rol}</td>
                  <td className="px-5 py-3">
                    <Etiqueta tono={u.activo ? 'apto' : 'neutro'}>
                      {u.activo ? 'Activa' : 'Desactivada'}
                    </Etiqueta>
                  </td>
                  <td className="whitespace-nowrap px-5 py-3 text-right">
                    <Boton variante="suave" onClick={() => setEditando(u)}>
                      Editar
                    </Boton>
                    <Boton
                      variante="peligro"
                      className="ml-2"
                      disabled={u.id === yo?.id}
                      onClick={() => {
                        setError(null);
                        setBorrando(u);
                      }}
                    >
                      Eliminar
                    </Boton>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Tarjeta>

      {editando && (
        <FormularioUsuario
          usuario={editando === 'nuevo' ? null : editando}
          alCerrar={() => setEditando(null)}
        />
      )}

      {borrando && (
        <Confirmacion
          titulo="Eliminar usuario"
          mensaje={
            <>
              Se eliminara la cuenta de{' '}
              <strong className="text-slate-800">{borrando.nombre}</strong>. Si
              ya registro muestras, desactivela en vez de borrarla para no
              perder la trazabilidad.
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

function FormularioUsuario({
  usuario,
  alCerrar,
}: {
  usuario: Usuario | null;
  alCerrar: () => void;
}) {
  const cola = useQueryClient();
  const [nombre, setNombre] = useState(usuario?.nombre ?? '');
  const [correo, setCorreo] = useState(usuario?.correo ?? '');
  const [rol, setRol] = useState<Rol>(usuario?.rol ?? 'operario');
  const [activo, setActivo] = useState(usuario?.activo ?? true);
  const [clave, setClave] = useState('');
  const [error, setError] = useState<string | null>(null);

  const guardar = useMutation({
    mutationFn: () => {
      const datos = { nombre: nombre.trim(), correo: correo.trim(), rol, activo };
      // En edicion la contrasena vacia significa "dejala como esta", asi que
      // ni siquiera viaja en el cuerpo.
      return usuario
        ? api.editarUsuario(usuario.id, {
            ...datos,
            ...(clave ? { clave } : {}),
          })
        : api.crearUsuario({ ...datos, clave });
    },
    onSuccess: () => {
      cola.invalidateQueries({ queryKey: ['usuarios'] });
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
    <Modal
      titulo={usuario ? 'Editar usuario' : 'Nuevo usuario'}
      alCerrar={alCerrar}
    >
      <form onSubmit={enviar} className="space-y-4">
        {error && <Aviso>{error}</Aviso>}

        <Campo
          etiqueta="Nombre"
          required
          value={nombre}
          onChange={(e) => setNombre(e.target.value)}
        />
        <Campo
          etiqueta="Correo"
          type="email"
          required
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
        />
        <Seleccion
          etiqueta="Rol"
          valor={rol}
          opciones={ROLES}
          alCambiar={(v) => setRol(v as Rol)}
        />
        <Campo
          etiqueta="Contrasena"
          type="password"
          autoComplete="new-password"
          required={!usuario}
          minLength={8}
          value={clave}
          onChange={(e) => setClave(e.target.value)}
          ayuda={
            usuario
              ? 'Dejela vacia para conservar la actual.'
              : 'Minimo ocho caracteres.'
          }
        />

        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={activo}
            onChange={(e) => setActivo(e.target.checked)}
          />
          Cuenta activa
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
