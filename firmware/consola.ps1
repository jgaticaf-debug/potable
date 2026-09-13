param(
  [string]$Puerto = "COM5",
  [string]$Comando = "",
  [int]$Segundos = 6
)

# El monitor del Arduino IDE se cuelga seguido. Esto hace lo mismo: abre el
# puerto, manda un comando si se lo doy, e imprime lo que conteste la placa.
# El IDE tiene que estar sin el monitor abierto o el puerto sale ocupado.

$puertoSerie = New-Object System.IO.Ports.SerialPort $Puerto, 115200, None, 8, one
$puertoSerie.ReadTimeout = 500

try {
  $puertoSerie.Open()
} catch {
  Write-Host "No se pudo abrir $Puerto. Cerra el Monitor Serie del IDE." -ForegroundColor Red
  exit 1
}

if ($Comando -ne "") {
  Start-Sleep -Milliseconds 400
  $puertoSerie.WriteLine($Comando)
}

$fin = (Get-Date).AddSeconds($Segundos)
while ((Get-Date) -lt $fin) {
  if ($puertoSerie.BytesToRead -gt 0) {
    Write-Host -NoNewline $puertoSerie.ReadExisting()
  }
  Start-Sleep -Milliseconds 100
}

$puertoSerie.Close()
