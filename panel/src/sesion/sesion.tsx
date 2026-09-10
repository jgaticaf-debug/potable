import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { alPerderSesion, api, hayToken } from '../api/cliente';
import type { Usuario } from '../api/tipos';

interface Sesion {
  usuario: Usuario | null;
  cargando: boolean;
  entrar: (correo: string, clave: string) => Promise<void>;
  salir: () => Promise<void>;
  esAdministrador: boolean;
}

const Contexto = createContext<Sesion | null>(null);

export function ProveedorSesion({ children }: { children: ReactNode }) {
  const [usuario, setUsuario] = useState<Usuario | null>(null);
  const [cargando, setCargando] = useState(hayToken());

  // El token guardado puede estar vencido o revocado desde otro dispositivo.
  // Lo unico que lo confirma es preguntarle al servidor.
  useEffect(() => {
    if (!hayToken()) return;

    let vigente = true;
    api
      .perfil()
      .then((u) => vigente && setUsuario(u))
      .catch(() => vigente && setUsuario(null))
      .finally(() => vigente && setCargando(false));

    return () => {
      vigente = false;
    };
  }, []);

  useEffect(() => alPerderSesion(() => setUsuario(null)), []);

  const entrar = useCallback(async (correo: string, clave: string) => {
    const { usuario } = await api.login(correo, clave);
    setUsuario(usuario);
  }, []);

  const salir = useCallback(async () => {
    await api.logout();
    setUsuario(null);
  }, []);

  const valor = useMemo<Sesion>(
    () => ({
      usuario,
      cargando,
      entrar,
      salir,
      esAdministrador: usuario?.rol === 'administrador',
    }),
    [usuario, cargando, entrar, salir],
  );

  return <Contexto.Provider value={valor}>{children}</Contexto.Provider>;
}

export function useSesion(): Sesion {
  const valor = useContext(Contexto);
  if (!valor) throw new Error('useSesion va dentro de ProveedorSesion.');
  return valor;
}
