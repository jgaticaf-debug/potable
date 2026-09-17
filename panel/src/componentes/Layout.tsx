import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';

import { useSesion } from '../sesion/sesion';
import { Boton } from './comunes';
import { seccionesDe } from './secciones';

const LLAVE_MENU = 'potable.menu';

// En angosto siempre cerrado: ahi flota encima y taparia todo.
function estadoInicial(): boolean {
  if (window.innerWidth < 768) return false;
  try {
    const guardado = localStorage.getItem(LLAVE_MENU);
    if (guardado) return guardado === 'abierto';
  } catch {
    // Ventana privada o cookies bloqueadas.
  }
  return true;
}

export function Layout() {
  const { usuario, salir } = useSesion();
  const [abierta, setAbierta] = useState(estadoInicial);

  const cambiar = (valor: boolean) => {
    setAbierta(valor);
    try {
      localStorage.setItem(LLAVE_MENU, valor ? 'abierto' : 'cerrado');
    } catch {
      // Se pierde la preferencia, pero el menu sigue.
    }
  };

  // Alto fijo y scroll adentro del contenido: si scrollea la pagina, en la
  // bitacora el boton de salir se va cientos de pixeles abajo.
  //
  // El azul del contenedor tapa el medio pixel que deja el ancho al animarse.
  return (
    <div className="bg-sidebar flex h-dvh overflow-hidden">
      {/* Montado siempre, si no al cerrar desaparece de golpe. */}
      <div
        onClick={() => cambiar(false)}
        aria-hidden="true"
        className={`fixed inset-0 z-30 bg-slate-900/40 transition-opacity duration-300 motion-reduce:transition-none md:hidden ${
          abierta ? 'opacity-100' : 'pointer-events-none opacity-0'
        }`}
      />

      {/* En angosto desliza encima; en escritorio se anima el ancho para que
          el contenido se corra solo. */}
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-60 shrink-0 overflow-hidden bg-azul-oscuro text-white transition-transform duration-300 ease-out motion-reduce:transition-none md:static md:translate-x-0 md:transition-[width] ${
          abierta ? 'translate-x-0 md:w-60' : '-translate-x-full md:w-0'
        }`}
      >
        {/* Ancho fijo para que el texto no se reacomode mientras se recorta, y
            se desvanece antes de que el recorte llegue a las pastillas. */}
        <div
          className={`flex h-full w-60 flex-col transition-opacity duration-[180ms] motion-reduce:transition-none ${
            abierta ? 'opacity-100' : 'opacity-0'
          }`}
        >
          <div className="px-5 py-6">
            <p className="text-lg font-semibold">Potable</p>
            <p className="text-xs text-white/60">Administracion</p>
          </div>

          <nav className="flex-1 overflow-y-auto px-3">
            {seccionesDe(usuario?.rol).map((s) => (
              <NavLink
                key={s.ruta}
                to={s.ruta}
                // En angosto tapa el contenido, asi que se cierra solo.
                onClick={() => {
                  if (window.innerWidth < 768) cambiar(false);
                }}
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
            {/* La variante suave sola queda como un bloque claro sobre la barra. */}
            <Boton
              variante="suave"
              className="w-full border-white/25 bg-transparent text-white hover:bg-white/10 hover:text-white"
              onClick={() => void salir()}
            >
              Cerrar sesion
            </Boton>
          </div>
        </div>
      </aside>

      <div className="bg-background flex min-w-0 flex-1 flex-col overflow-hidden">
        <div className="shrink-0 px-6 pt-4">
          <button
            type="button"
            onClick={() => cambiar(!abierta)}
            aria-label={abierta ? 'Ocultar el menu' : 'Mostrar el menu'}
            aria-expanded={abierta}
            className="rounded-lg p-2 text-slate-500 transition hover:bg-slate-200 hover:text-slate-700 active:scale-95"
          >
            {/* Transform a mano: hay que girar y despues correr, y Tailwind
                compone al reves. */}
            <svg
              width="20"
              height="20"
              viewBox="0 0 20 20"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              aria-hidden="true"
            >
              <line
                x1="3"
                y1="5"
                x2="17"
                y2="5"
                className={`origin-center transition-transform duration-300 motion-reduce:transition-none ${
                  abierta ? '[transform:rotate(45deg)_translateY(5px)]' : ''
                }`}
              />
              <line
                x1="3"
                y1="10"
                x2="17"
                y2="10"
                className={`transition-opacity duration-200 motion-reduce:transition-none ${
                  abierta ? 'opacity-0' : 'opacity-100'
                }`}
              />
              <line
                x1="3"
                y1="15"
                x2="17"
                y2="15"
                className={`origin-center transition-transform duration-300 motion-reduce:transition-none ${
                  abierta ? '[transform:rotate(-45deg)_translateY(-5px)]' : ''
                }`}
              />
            </svg>
          </button>
        </div>

        <main className="min-h-0 flex-1 overflow-hidden px-6 pb-6 pt-2">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
