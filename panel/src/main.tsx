import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import { App } from './App';
import { SesionExpirada } from './api/cliente';
import { ProveedorSesion } from './sesion/sesion';
import './estilos.css';

const cliente = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      // Reintentar un 401 no sirve de nada: el token ya no vale.
      retry: (intentos, error) =>
        !(error instanceof SesionExpirada) && intentos < 2,
    },
  },
});

createRoot(document.getElementById('raiz')!).render(
  <StrictMode>
    <QueryClientProvider client={cliente}>
      <ProveedorSesion>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </ProveedorSesion>
    </QueryClientProvider>
  </StrictMode>,
);
