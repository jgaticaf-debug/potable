# Respaldos del ESP32

## Que hay aqui

**`nvs_AAAAMMDD.bin`** — la particion NVS, donde el firmware guarda la
calibracion del pH (`phPendiente` y `phOffset`). Son 20 KB y **si van al
repositorio**: perderlos significa repetir una sesion completa de calibracion
con patrones, enjuagues y esperas.

**`flash_completo_AAAAMMDD.bin`** — los 4 MB enteros. **No van al
repositorio**, y por eso estan en el `.gitignore`. Contienen el programa, que
ya vive aqui como codigo fuente, mas la NVS, que ya esta respaldada aparte. Es
reproducible, asi que no vale la pena cargar 4 MB en el historial cada vez.

## Calibracion guardada en `nvs_20260912.bin`

```
phPendiente = -5.5897
phOffset    = 15.0135
```

Verificada el 11 de septiembre de 2026: lee 6.95 a 7.00 en el patron de 7.00
y 4.04 a 4.06 en el de 4.00.

## Como hacer un respaldo nuevo

La placa necesita estar en modo descarga: mantener **BOOT** presionado
mientras arranca el comando, y soltarlo cuando empiece a leer. El Monitor
Serie del IDE tiene que estar cerrado o el puerto sale ocupado.

```bash
ESPTOOL="C:/Users/jason/AppData/Local/Arduino15/packages/esp32/tools/esptool_py/5.3.1/esptool.exe"

# Solo la calibracion
"$ESPTOOL" --port COM5 read-flash 0x9000 0x5000 nvs_$(date +%Y%m%d).bin

# Todo el flash
"$ESPTOOL" --port COM5 read-flash 0 0x400000 flash_completo_$(date +%Y%m%d).bin
```

## Como restaurar la calibracion

Mismo baile del boton BOOT:

```bash
"$ESPTOOL" --port COM5 write-flash 0x9000 nvs_20260912.bin
```

## Por que se pierde la calibracion

Reflashear el sketch **no** la borra. Lo que si la borra es tener habilitado
**Herramientas -> Erase All Flash Before Sketch Upload** en el Arduino IDE.
Debe estar en **Disabled**.

## Nota

La calibracion es del **electrodo**, no de la placa. Si algun dia se usa este
respaldo en un segundo ESP32 con otro electrodo, hay que recalibrar: los
numeros de aqui describen el comportamiento de esta sonda en particular.
