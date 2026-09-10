import { NavLink, Outlet } from 'react-router-dom';

import { useSesion } from '../sesion/sesion';
import { Boton } from './comunes';
import { seccionesDe } from './secciones';

export function Layout() {
  const { usuario, salir } = useSesion();

  return (
    <div className="flex min-h-screen">
      <aside className="hidden w-60 shrink-0 flex-col bg-azul-oscuro text-white md:flex">
        <div className="px-5 py-6">
          <p className="text-lg font-semibold">Potable</p>
          <p className="text-xs text-white/60">Administracion</p>
        </div>

        <nav className="flex-1 px-3">
          {seccionesDe(usuario?.rol).map((s) => (
            <NavLink
              key={s.ruta}
              to={s.ruta}
              className={({ isActive }) =>
                `mb-1 block rounded-lg px-3 py-2 text-sm transition ${
                  isActive
                    ? 'bg-white/15 font-medium'
                    : 'text-white/75 hover:bg-white/10'
                }`
              }
            >
              {s.texto}
            </NavLink>
          ))}
        </nav>

        <div className="border-t border-white/10 px-5 py-4">
          <p className="truncate text-sm">{usuario?.nombre}</p>
          <p className="mb-3 truncate text-xs text-white/60">{usuario?.rol}</p>
          <Boton
            variante="suave"
            className="w-full"
            onClick={() => void salir()}
          >
            Cerrar sesion
          </Boton>
        </div>
      </aside>

      <main className="flex-1 overflow-x-auto p-6">
        <Outlet />
      </main>
    </div>
  );
}
