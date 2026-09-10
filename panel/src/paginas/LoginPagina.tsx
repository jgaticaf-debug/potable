import { useState, type FormEvent } from 'react';

import { Aviso, Boton, Campo } from '../componentes/comunes';
import { useSesion } from '../sesion/sesion';

export function LoginPagina() {
  const { entrar } = useSesion();
  const [correo, setCorreo] = useState('');
  const [clave, setClave] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setEnviando(true);
    try {
      await entrar(correo.trim(), clave);
    } catch (fallo) {
      setError(fallo instanceof Error ? fallo.message : 'No se pudo entrar.');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <form
        onSubmit={enviar}
        className="w-full max-w-sm space-y-4 rounded-2xl border border-slate-200 bg-white p-8"
      >
        <div>
          <h1 className="text-xl font-semibold text-azul-oscuro">Potable</h1>
          <p className="text-sm text-slate-500">Panel de administracion</p>
        </div>

        {error && <Aviso>{error}</Aviso>}

        <Campo
          etiqueta="Correo"
          type="email"
          autoComplete="username"
          required
          value={correo}
          onChange={(e) => setCorreo(e.target.value)}
        />
        <Campo
          etiqueta="Contrasena"
          type="password"
          autoComplete="current-password"
          required
          value={clave}
          onChange={(e) => setClave(e.target.value)}
        />

        <Boton type="submit" className="w-full" disabled={enviando}>
          {enviando ? 'Entrando...' : 'Entrar'}
        </Boton>
      </form>
    </div>
  );
}
