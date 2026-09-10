import type { ReactElement } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { Aviso, Cargando } from './componentes/comunes';
import { Layout } from './componentes/Layout';
import { seccionesDe } from './componentes/secciones';
import { AlertasPagina } from './paginas/AlertasPagina';
import { BitacoraPagina } from './paginas/BitacoraPagina';
import { LoginPagina } from './paginas/LoginPagina';
import { MuestrasPagina } from './paginas/MuestrasPagina';
import { PuntosPagina } from './paginas/PuntosPagina';
import { UsuariosPagina } from './paginas/UsuariosPagina';
import { ZonasPagina } from './paginas/ZonasPagina';
import { useSesion } from './sesion/sesion';

const PANTALLAS: Record<string, ReactElement> = {
  '/muestras': <MuestrasPagina />,
  '/alertas': <AlertasPagina />,
  '/zonas': <ZonasPagina />,
  '/puntos': <PuntosPagina />,
  '/usuarios': <UsuariosPagina />,
  '/bitacora': <BitacoraPagina />,
};

export function App() {
  const { usuario, cargando } = useSesion();

  if (cargando) return <Cargando texto="Restaurando sesion..." />;
  if (!usuario) return <LoginPagina />;

  const visibles = seccionesDe(usuario.rol);
  const inicio = visibles[0]?.ruta;

  return (
    <Routes>
      <Route element={<Layout />}>
        {visibles.map((s) => (
          <Route key={s.ruta} path={s.ruta} element={PANTALLAS[s.ruta]} />
        ))}
        <Route
          path="*"
          element={
            inicio ? (
              <Navigate to={inicio} replace />
            ) : (
              <Aviso tono="nota">
                Su rol no tiene secciones habilitadas en el panel todavia.
              </Aviso>
            )
          }
        />
      </Route>
    </Routes>
  );
}
