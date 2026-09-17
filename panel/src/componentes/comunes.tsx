import { useId } from 'react';
import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode } from 'react';

import { Alert, AlertDescription } from '@/components/ui/alert';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { cn } from '@/lib/utils';

// Capa sobre shadcn: las pantallas llaman Boton, Campo y Seleccion sin
// saber que hay debajo. Si se cambia de libreria, se cambia aqui.

export function Cargando({ texto = 'Cargando...' }: { texto?: string }) {
  return (
    // Tarda 200 ms en salir: si la consulta contesta rapido, mostrarla y
    // quitarla es un parpadeo.
    <div
      role="status"
      className="text-muted-foreground flex animate-aparecer items-center gap-3 p-8 text-sm [animation-delay:200ms] motion-reduce:animate-none"
    >
      <span className="border-muted border-t-primary size-4 animate-spin rounded-full border-2" />
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
    <Alert className={cn('animate-aparecer motion-reduce:animate-none', estilos)}>
      <AlertDescription className="text-inherit">{children}</AlertDescription>
    </Alert>
  );
}

type VarianteBoton = 'principal' | 'suave' | 'peligro';

export function Boton({
  variante = 'principal',
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variante?: VarianteBoton }) {
  // Los nombres de afuera son los de siempre; aqui se traducen.
  const equivalente = {
    principal: 'default',
    suave: 'outline',
    peligro: 'outline',
  }[variante] as 'default' | 'outline';

  return (
    <Button
      {...props}
      variant={equivalente}
      className={cn(
        // outline no fija color de texto: en la barra oscura salia blanco
        // sobre blanco.
        variante === 'suave' && 'text-foreground',
        variante === 'peligro' &&
          'text-incumplimiento border-red-200 hover:bg-red-50 hover:text-incumplimiento',
        className,
      )}
    />
  );
}

export function Campo({
  etiqueta,
  ayuda,
  className,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & {
  etiqueta: string;
  ayuda?: string;
}) {
  // El label ya no envuelve al input, hay que unirlos con id. useId lo hace
  // unico por instancia: uno fijo chocaria entre campos del mismo formulario.
  const generado = useId();
  const id = props.id ?? generado;

  return (
    <div className="grid gap-2">
      <Label htmlFor={id}>{etiqueta}</Label>
      <Input id={id} className={className} {...props} />
      {ayuda && <p className="text-muted-foreground text-xs">{ayuda}</p>}
    </div>
  );
}

export function Casilla({
  etiqueta,
  marcada,
  alCambiar,
}: {
  etiqueta: string;
  marcada: boolean;
  alCambiar: (v: boolean) => void;
}) {
  const id = useId();

  return (
    <div className="flex items-center gap-2">
      <Checkbox
        id={id}
        checked={marcada}
        onCheckedChange={(v) => alCambiar(v === true)}
      />
      <Label htmlFor={id} className="font-normal">
        {etiqueta}
      </Label>
    </div>
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
    <div className="grid gap-2">
      <Label>{etiqueta}</Label>
      <Select value={valor} onValueChange={alCambiar}>
        <SelectTrigger className="w-full">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {opciones.map((o) => (
            <SelectItem key={o.valor} value={o.valor}>
              {o.texto}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}

// Con `desplazable` la tarjeta ocupa el alto que le sobra a la pagina y el
// scroll queda adentro de ella. Asi el titulo, los filtros y el encabezado de
// la tabla se quedan arriba, y solo corren las filas.
export function Tarjeta({
  titulo,
  acciones,
  desplazable = false,
  children,
}: {
  titulo?: string;
  acciones?: ReactNode;
  desplazable?: boolean;
  children: ReactNode;
}) {
  return (
    <section
      className={cn(
        'bg-card animate-aparecer rounded-xl border shadow-sm motion-reduce:animate-none',
        desplazable && 'flex min-h-0 flex-1 flex-col overflow-hidden',
      )}
    >
      {(titulo || acciones) && (
        <header className="flex shrink-0 items-center justify-between gap-4 border-b px-5 py-4">
          <h2 className="font-semibold">{titulo}</h2>
          {acciones}
        </header>
      )}
      {desplazable ? (
        <div className="min-h-0 flex-1 overflow-auto">{children}</div>
      ) : (
        children
      )}
    </section>
  );
}

export function Vacio({ children }: { children: ReactNode }) {
  return (
    <p className="text-muted-foreground p-8 text-center text-sm">{children}</p>
  );
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
  // Radix trae lo que el modal de antes no tenia: Escape, trampa de foco y
  // rol de dialogo.
  return (
    <Dialog open onOpenChange={(abierto) => !abierto && alCerrar()}>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{titulo}</DialogTitle>
        </DialogHeader>
        {children}
      </DialogContent>
    </Dialog>
  );
}

export function Confirmacion({
  titulo,
  mensaje,
  textoAccion = 'Eliminar',
  textoTrabajando = 'Eliminando...',
  trabajando = false,
  alConfirmar,
  alCerrar,
}: {
  titulo: string;
  mensaje: ReactNode;
  textoAccion?: string;
  textoTrabajando?: string;
  trabajando?: boolean;
  alConfirmar: () => void;
  alCerrar: () => void;
}) {
  return (
    <Dialog open onOpenChange={(abierto) => !abierto && alCerrar()}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{titulo}</DialogTitle>
          <DialogDescription asChild>
            <div>{mensaje}</div>
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Boton variante="suave" onClick={alCerrar}>
            Cancelar
          </Boton>
          <Boton variante="peligro" disabled={trabajando} onClick={alConfirmar}>
            {trabajando ? textoTrabajando : textoAccion}
          </Boton>
        </DialogFooter>
      </DialogContent>
    </Dialog>
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
    apto: 'bg-emerald-50 text-apto border-emerald-200',
    riesgo: 'bg-amber-50 text-riesgo border-amber-200',
    incumplimiento: 'bg-red-50 text-incumplimiento border-red-200',
    neutro: 'bg-slate-100 text-slate-600 border-slate-200',
  }[tono];

  return (
    <Badge variant="outline" className={cn('rounded-full', estilos)}>
      {children}
    </Badge>
  );
}
