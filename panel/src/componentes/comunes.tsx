import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';

export function Cargando({ texto = 'Cargando...' }: { texto?: string }) {
  return (
    <div className="flex items-center gap-3 p-8 text-sm text-slate-500">
      <span className="size-4 animate-spin rounded-full border-2 border-slate-300 border-t-azul" />
      {texto}
    </div>
  );
}

export function Aviso({
  tono = 'error',
  children,
}: {
  tono?: 'error' | 'exito' | 'nota';
  children: ReactNode;
}) {
  const estilos = {
    error: 'bg-red-50 text-incumplimiento border-red-200',
    exito: 'bg-emerald-50 text-apto border-emerald-200',
    nota: 'bg-slate-50 text-slate-600 border-slate-200',
  }[tono];

  return (
    <div className={`rounded-xl border px-4 py-3 text-sm ${estilos}`}>
      {children}
    </div>
  );
}

type VarianteBoton = 'principal' | 'suave' | 'peligro';

export function Boton({
  variante = 'principal',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variante?: VarianteBoton }) {
  const estilos = {
    principal: 'bg-azul text-white hover:bg-azul-oscuro',
    suave: 'bg-white text-slate-700 border border-slate-300 hover:bg-slate-50',
    peligro: 'bg-white text-incumplimiento border border-red-200 hover:bg-red-50',
  }[variante];

  return (
    <button
      {...props}
      className={`rounded-lg px-4 py-2 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-50 ${estilos} ${className}`}
    />
  );
}

export function Campo({
  etiqueta,
  ayuda,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & {
  etiqueta: string;
  ayuda?: string;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium text-slate-700">
        {etiqueta}
      </span>
      <input
        {...props}
        className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-azul focus:ring-2 focus:ring-azul/20"
      />
      {ayuda && <span className="mt-1 block text-xs text-slate-500">{ayuda}</span>}
    </label>
  );
}

export function Seleccion({
  etiqueta,
  valor,
  opciones,
  alCambiar,
}: {
  etiqueta: string;
  valor: string;
  opciones: { valor: string; texto: string }[];
  alCambiar: (v: string) => void;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium text-slate-700">
        {etiqueta}
      </span>
      <select
        value={valor}
        onChange={(e) => alCambiar(e.target.value)}
        className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-azul"
      >
        {opciones.map((o) => (
          <option key={o.valor} value={o.valor}>
            {o.texto}
          </option>
        ))}
      </select>
    </label>
  );
}

export function Tarjeta({
  titulo,
  acciones,
  children,
}: {
  titulo?: string;
  acciones?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white">
      {(titulo || acciones) && (
        <header className="flex items-center justify-between gap-4 border-b border-slate-100 px-5 py-4">
          <h2 className="font-semibold text-slate-800">{titulo}</h2>
          {acciones}
        </header>
      )}
      {children}
    </section>
  );
}

export function Vacio({ children }: { children: ReactNode }) {
  return <p className="p-8 text-center text-sm text-slate-500">{children}</p>;
}

export function Modal({
  titulo,
  alCerrar,
  children,
}: {
  titulo: string;
  alCerrar: () => void;
  children: ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4"
      onMouseDown={alCerrar}
    >
      <div
        className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-2xl bg-white p-6"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <h2 className="mb-4 text-lg font-semibold text-slate-800">{titulo}</h2>
        {children}
      </div>
    </div>
  );
}

export function Confirmacion({
  titulo,
  mensaje,
  textoAccion = 'Eliminar',
  trabajando = false,
  alConfirmar,
  alCerrar,
}: {
  titulo: string;
  mensaje: ReactNode;
  textoAccion?: string;
  trabajando?: boolean;
  alConfirmar: () => void;
  alCerrar: () => void;
}) {
  return (
    <Modal titulo={titulo} alCerrar={alCerrar}>
      <div className="space-y-5 text-sm text-slate-600">
        <div>{mensaje}</div>
        <div className="flex justify-end gap-2">
          <Boton variante="suave" onClick={alCerrar}>
            Cancelar
          </Boton>
          <Boton variante="peligro" disabled={trabajando} onClick={alConfirmar}>
            {trabajando ? 'Eliminando...' : textoAccion}
          </Boton>
        </div>
      </div>
    </Modal>
  );
}

export function Etiqueta({
  tono,
  children,
}: {
  tono: 'apto' | 'riesgo' | 'incumplimiento' | 'neutro';
  children: ReactNode;
}) {
  const estilos = {
    apto: 'bg-emerald-50 text-apto',
    riesgo: 'bg-amber-50 text-riesgo',
    incumplimiento: 'bg-red-50 text-incumplimiento',
    neutro: 'bg-slate-100 text-slate-600',
  }[tono];

  return (
    <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${estilos}`}>
      {children}
    </span>
  );
}
