/*
  Potable - nodo de medicion ESP32

  CONEXIONES
  ----------------------------------------------------------------------
  Sensor                    Modelo          Pin ESP32   Alimentacion
  pH                        SEN0161-V2      GPIO 34     3.3 V
  Turbidez                  SEN0189         GPIO 35     5 V  (ver aviso)
  TDS / conductividad       SEN0244         GPIO 32     3.3 V
  Temperatura               DS18B20         GPIO 4      3.3 V
  LED de estado             interno         GPIO 2      -

  AVISO 1: el SEN0189 entrega hasta 4.5 V y el ADC del ESP32 tolera 3.3 V.
  Va con divisor de voltaje R1 = 10 kohm (senal a GPIO 35) y R2 = 20 kohm
  (GPIO 35 a GND). Eso da 4.5 V -> 3.0 V. Sin el divisor se danan el pin.

  AVISO 2: el DS18B20 necesita 4.7 kohm entre su linea de datos y 3.3 V.

  AVISO 3: los electrodos de pH y TDS se interfieren si estan en el agua
  al mismo tiempo. El firmware los lee alternadamente, nunca juntos.

  BIBLIOTECAS
  ----------------------------------------------------------------------
  OneWire, DallasTemperature, ArduinoJson.
  El soporte BLE viene con el nucleo ESP32 de Arduino.
*/

#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <DallasTemperature.h>
#include <OneWire.h>  
#include <Preferences.h>

#define MODO_SIMULACION 0

// Que sensores estan conectados de verdad. Un pin ADC sin nada no da cero:
// flota y devuelve basura que parece una medicion. Los que esten en 0 no se
// leen y no viajan en el JSON, asi que la app los deja en captura manual.
#define TIENE_PH            1
#define TIENE_TURBIDEZ      1
#define TIENE_CONDUCTIVIDAD 0
#define TIENE_TEMPERATURA   0

static const char* IDENTIFICADOR = "ESP32-POZO1";

static const char* UUID_SERVICIO = "6f2a1000-8b41-4c8e-9d5a-1f7c3e0a9b21";
static const char* UUID_LECTURA  = "6f2a1001-8b41-4c8e-9d5a-1f7c3e0a9b21";
static const char* UUID_COMANDO  = "6f2a1002-8b41-4c8e-9d5a-1f7c3e0a9b21";
static const char* UUID_ESTADO   = "6f2a1003-8b41-4c8e-9d5a-1f7c3e0a9b21";

static const uint8_t PIN_PH          = 34;
static const uint8_t PIN_TURBIDEZ    = 35;
static const uint8_t PIN_TDS         = 32;
static const uint8_t PIN_TEMPERATURA = 4;
static const uint8_t PIN_LED         = 2;

static const uint8_t MUESTRAS_POR_LECTURA = 21;
static const uint16_t ADC_MAXIMO = 4095;
static const float VOLTAJE_REFERENCIA = 3.3f;

static const float DIVISOR_TURBIDEZ = 1.5f;

// El divisor en papel es 1.5 pero la cadena no lo cumple: resistores al +-5%,
// alimentacion de VIN (4.8 V, no 5.0) y el ADC leyendo por lo bajo. Sale de
// calibrar a un punto, 2.545 V crudos en agua limpia contra el cero en 4.20.
// Medido con el vaso TAPADO: la luz del cuarto mete 48 mV de ruido.
static const float AJUSTE_TURBIDEZ = 1.100f;

// Arriba de V_LIMPIA es agua limpia; abajo del vertice la lectura satura.
static const float TURBIDEZ_V_LIMPIA = 4.2f;
static const float TURBIDEZ_V_VERTICE = 2.56f;
static const float TURBIDEZ_NTU_MAXIMA = 3000.0f;

static const float TEMPERATURA_REFERENCIA = 25.0f;

static const float PH_PENDIENTE_POR_DEFECTO = -5.70f;
static const float PH_OFFSET_POR_DEFECTO = 21.34f;

static const float FACTOR_TDS_A_EC = 2.0f;

OneWire cableUnico(PIN_TEMPERATURA);
DallasTemperature sensorTemperatura(&cableUnico);
Preferences memoria;

BLECharacteristic* caracteristicaLectura = nullptr;
BLECharacteristic* caracteristicaEstado = nullptr;
bool hayCentralConectada = false;

float phPendiente = PH_PENDIENTE_POR_DEFECTO;
float phOffset = PH_OFFSET_POR_DEFECTO;

// Calibracion de dos puntos. El primer patron se guarda aqui esperando al
// segundo; con los dos se calcula la pendiente, que es lo que se degrada con
// el uso del electrodo. Con un solo punto quedaria exacto en ese pH y cada
// vez mas equivocado al alejarse, justo donde la norma decide apto o riesgo.
bool hayPrimerPunto = false;
float primerPuntoPh = 0.0f;
float primerPuntoV = 0.0f;

// Lectura continua por el serial. Sirve para ver el electrodo asentarse antes
// de fijar un punto, en vez de adivinar cuando dejo de moverse.
bool monitorContinuo = false;

struct Lectura {
  float ph;
  float turbidez;
  float conductividad;
  float temperatura;
  bool valida;
};

static int comparar(const void* a, const void* b) {
  return (*(const uint16_t*)a) - (*(const uint16_t*)b);
}

static uint16_t leerCrudoFiltrado(uint8_t pin) {
  uint16_t muestras[MUESTRAS_POR_LECTURA];
  for (uint8_t i = 0; i < MUESTRAS_POR_LECTURA; i++) {
    muestras[i] = analogRead(pin);
    delay(4);
  }
  qsort(muestras, MUESTRAS_POR_LECTURA, sizeof(uint16_t), comparar);
  return muestras[MUESTRAS_POR_LECTURA / 2];
}

static float aVoltios(uint16_t crudo) {
  return (crudo * VOLTAJE_REFERENCIA) / ADC_MAXIMO;
}

static float leerTemperatura() {
  sensorTemperatura.requestTemperatures();
  float grados = sensorTemperatura.getTempCByIndex(0);
  return (grados == DEVICE_DISCONNECTED_C) ? NAN : grados;
}

// Conversion aparte de la lectura: el monitor imprime el valor y el voltaje
// del que salio, y con dos llamadas al ADC salian de momentos distintos.
static float phDeVoltios(float voltios, float temperatura) {
  float ph = phPendiente * voltios + phOffset;

  if (!isnan(temperatura)) {
    ph += (temperatura - TEMPERATURA_REFERENCIA) * 0.03f;
  }
  return constrain(ph, 0.0f, 14.0f);
}

static float leerPh(float temperatura) {
  return phDeVoltios(aVoltios(leerCrudoFiltrado(PIN_PH)), temperatura);
}

static float voltiosTurbidez() {
  return aVoltios(leerCrudoFiltrado(PIN_TURBIDEZ)) * DIVISOR_TURBIDEZ *
         AJUSTE_TURBIDEZ;
}

static float turbidezDeVoltios(float voltios) {
  if (voltios > TURBIDEZ_V_LIMPIA) return 0.0f;

  // La curva es una parabola: pasado el vertice se devuelve y el agua mas
  // sucia daria menos. Con leche daba 0.0 NTU y el vaso casi blanco.
  if (voltios < TURBIDEZ_V_VERTICE) return TURBIDEZ_NTU_MAXIMA;

  float ntu = -1120.4f * voltios * voltios + 5742.3f * voltios - 4352.9f;
  return constrain(ntu, 0.0f, TURBIDEZ_NTU_MAXIMA);
}

static float leerTurbidez() { return turbidezDeVoltios(voltiosTurbidez()); }

static float leerConductividad(float temperatura) {
  float voltios = aVoltios(leerCrudoFiltrado(PIN_TDS));

  float grados = isnan(temperatura) ? TEMPERATURA_REFERENCIA : temperatura;
  float compensacion = 1.0f + 0.02f * (grados - TEMPERATURA_REFERENCIA);
  float voltiosCompensados = voltios / compensacion;

  float ppm = (133.42f * voltiosCompensados * voltiosCompensados *
                   voltiosCompensados -
               255.86f * voltiosCompensados * voltiosCompensados +
               857.39f * voltiosCompensados) *
              0.5f;

  return constrain(ppm * FACTOR_TDS_A_EC, 0.0f, 5000.0f);
}

#if MODO_SIMULACION
static float ruido(float amplitud) {
  return ((random(0, 1000) / 1000.0f) - 0.5f) * amplitud;
}

static Lectura tomarLectura() {
  Lectura l;
  l.temperatura = 22.0f + ruido(6.0f);
  l.ph = 7.2f + ruido(0.9f);
  l.turbidez = max(0.0f, 0.8f + ruido(1.6f));
  l.conductividad = max(0.0f, 320.0f + ruido(190.0f));
  l.valida = true;
  return l;
}
#else
static Lectura tomarLectura() {
  Lectura l;

  l.temperatura = TIENE_TEMPERATURA ? leerTemperatura() : NAN;

  // pH y TDS se leen alternados con una pausa: los electrodos se interfieren
  // si se muestrean al mismo tiempo.
  l.ph = TIENE_PH ? leerPh(l.temperatura) : NAN;

  if (TIENE_PH && TIENE_CONDUCTIVIDAD) delay(500);
  l.conductividad =
      TIENE_CONDUCTIVIDAD ? leerConductividad(l.temperatura) : NAN;

  if (TIENE_CONDUCTIVIDAD && TIENE_TURBIDEZ) delay(200);
  l.turbidez = TIENE_TURBIDEZ ? leerTurbidez() : NAN;

  l.valida = !isnan(l.ph) || !isnan(l.turbidez) ||
             !isnan(l.conductividad) || !isnan(l.temperatura);
  return l;
}
#endif

static String comoJson(const Lectura& l) {
  JsonDocument doc;
  doc["equipo"] = IDENTIFICADOR;
  doc["simulado"] = MODO_SIMULACION == 1;
  doc["ms"] = millis();

  // Lo que no se midio simplemente no va. Mandar un cero seria peor: la app
  // lo tomaria como una medicion valida y lo evaluaria contra la norma.
  JsonObject valores = doc["valores"].to<JsonObject>();
  if (!isnan(l.ph)) valores["ph"] = round(l.ph * 100) / 100.0;
  if (!isnan(l.turbidez)) {
    valores["turbidez"] = round(l.turbidez * 100) / 100.0;
  }
  if (!isnan(l.conductividad)) {
    valores["conductividad"] = round(l.conductividad);
  }
  if (!isnan(l.temperatura)) {
    valores["temperatura"] = round(l.temperatura * 10) / 10.0;
  }

  String salida;
  serializeJson(doc, salida);
  return salida;
}

static void publicarLectura() {
  Lectura l = tomarLectura();
  String json = comoJson(l);

  caracteristicaLectura->setValue((uint8_t*)json.c_str(), json.length());
  if (hayCentralConectada) caracteristicaLectura->notify();

  Serial.println(json);
}

static void publicarEstado(const char* estado) {
  caracteristicaEstado->setValue((uint8_t*)estado, strlen(estado));
  if (hayCentralConectada) caracteristicaEstado->notify();
}

static void guardarCalibracion() {
  memoria.begin("potable", false);
  memoria.putFloat("phPendiente", phPendiente);
  memoria.putFloat("phOffset", phOffset);
  memoria.end();
}

// Reflashear no borra la NVS; "Erase All Flash" si. Esto lo dice sin sacar
// la sonda.
static void imprimirCalibracion() {
  float salud = fabs(phPendiente / PH_PENDIENTE_POR_DEFECTO) * 100.0f;
  bool deFabrica = phPendiente == PH_PENDIENTE_POR_DEFECTO &&
                   phOffset == PH_OFFSET_POR_DEFECTO;

  Serial.printf("calibracion pH: pendiente %.4f, offset %.4f (%.0f%% de la "
                "nominal)\n", phPendiente, phOffset, salud);

  if (deFabrica) {
    Serial.println("OJO: son los valores por defecto. O nunca se calibro, o "
                   "se borro la NVS y hay que restaurar el respaldo.");
  }
}

// Primer patron: se guarda y se espera el segundo. Segundo patron: con los
// dos puntos sale la recta completa.
static void calibrar(float phPatron) {
  if (phPatron < 0.0f || phPatron > 14.0f) {
    publicarEstado("patron fuera de rango");
    Serial.printf("patron invalido: %.2f\n", phPatron);
    return;
  }

  float voltios = aVoltios(leerCrudoFiltrado(PIN_PH));

  if (!hayPrimerPunto) {
    hayPrimerPunto = true;
    primerPuntoPh = phPatron;
    primerPuntoV = voltios;

    publicarEstado("primer punto listo");
    Serial.printf("punto 1: pH %.2f a %.4f V. Enjuague y meta el otro patron\n",
                  phPatron, voltios);
    return;
  }

  // Si los dos patrones dan casi el mismo voltaje es que se midio el mismo
  // dos veces, o el electrodo no esta respondiendo. Dividir ahi da un
  // disparate y lo guardaria como si fuera bueno.
  float saltoV = voltios - primerPuntoV;
  if (fabs(saltoV) < 0.05f) {
    publicarEstado("patrones demasiado parecidos");
    Serial.printf("punto 2 a %.4f V, casi igual al punto 1 (%.4f V). "
                  "Revise que sean patrones distintos y que el electrodo "
                  "responda\n", voltios, primerPuntoV);
    return;
  }

  phPendiente = (phPatron - primerPuntoPh) / saltoV;
  phOffset = phPatron - phPendiente * voltios;
  hayPrimerPunto = false;
  guardarCalibracion();

  // La pendiente contra la de fabrica dice como anda el electrodo: se
  // degrada con el uso y es el primer sintoma de que hay que reemplazarlo.
  float salud = fabs(phPendiente / PH_PENDIENTE_POR_DEFECTO) * 100.0f;

  publicarEstado(salud < 70.0f || salud > 130.0f ? "calibrado, revise el electrodo"
                                                 : "calibrado");
  Serial.printf("calibrado con pH %.2f y %.2f: pendiente %.3f, offset %.3f "
                "(%.0f%% de la nominal)\n",
                primerPuntoPh, phPatron, phPendiente, phOffset, salud);

  if (salud < 70.0f || salud > 130.0f) {
    Serial.println("ADVERTENCIA: la pendiente se alejo mucho de la de "
                   "fabrica. Electrodo gastado, mal enjuagado, o patrones "
                   "vencidos.");
  }
}

class ManejadorServidor : public BLEServerCallbacks {
  void onConnect(BLEServer* servidor) override {
    hayCentralConectada = true;
    digitalWrite(PIN_LED, HIGH);
    Serial.println("central conectada");
  }

  void onDisconnect(BLEServer* servidor) override {
    hayCentralConectada = false;
    digitalWrite(PIN_LED, LOW);
    Serial.println("central desconectada");
    servidor->startAdvertising();
  }
};

// Los mismos comandos entran por Bluetooth y por el monitor serie. Calibrar
// desde el IDE es mucho mas comodo: el cable ya esta puesto y se ve lo que
// imprime sin tener que ir al telefono.
static void ejecutarComando(String comando) {
  comando.trim();

  if (comando == "leer") {
    publicarEstado("midiendo");
    publicarLectura();
    publicarEstado("listo");
    return;
  }

  if (comando == "monitor") {
    monitorContinuo = !monitorContinuo;
    Serial.println(monitorContinuo
                       ? "monitor encendido, 'monitor' otra vez para apagarlo"
                       : "monitor apagado");
    return;
  }

  if (comando == "calibrar:reset") {
    hayPrimerPunto = false;
    publicarEstado("calibracion reiniciada");
    Serial.println("calibracion reiniciada, mande el primer patron");
    return;
  }

  if (comando.startsWith("calibrar:")) {
    calibrar(comando.substring(9).toFloat());
    return;
  }

  if (comando == "calibracion") {
    imprimirCalibracion();
    return;
  }

  if (comando == "ayuda" || comando == "?") {
    Serial.println("leer            una lectura");
    Serial.println("monitor         enciende o apaga la lectura continua");
    Serial.println("calibracion     muestra la calibracion guardada del pH");
    Serial.println("calibrar:7.00   fija un punto con ese patron");
    Serial.println("calibrar:reset  olvida el primer punto");
    return;
  }

  publicarEstado("comando desconocido");
  Serial.printf("no entiendo '%s'. Escriba 'ayuda'\n", comando.c_str());
}

class ManejadorComando : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* caracteristica) override {
    ejecutarComando(String(caracteristica->getValue().c_str()));
  }
};

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);

  sensorTemperatura.begin();
  randomSeed(esp_random());

  memoria.begin("potable", true);
  phPendiente = memoria.getFloat("phPendiente", PH_PENDIENTE_POR_DEFECTO);
  phOffset = memoria.getFloat("phOffset", PH_OFFSET_POR_DEFECTO);
  memoria.end();
  imprimirCalibracion();

  BLEDevice::init(IDENTIFICADOR);
  BLEServer* servidor = BLEDevice::createServer();
  servidor->setCallbacks(new ManejadorServidor());

  BLEService* servicio = servidor->createService(UUID_SERVICIO);

  caracteristicaLectura = servicio->createCharacteristic(
      UUID_LECTURA,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  caracteristicaLectura->addDescriptor(new BLE2902());

  BLECharacteristic* caracteristicaComando = servicio->createCharacteristic(
      UUID_COMANDO, BLECharacteristic::PROPERTY_WRITE);
  caracteristicaComando->setCallbacks(new ManejadorComando());

  caracteristicaEstado = servicio->createCharacteristic(
      UUID_ESTADO,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  caracteristicaEstado->addDescriptor(new BLE2902());
  publicarEstado("listo");

  servicio->start();

  BLEAdvertising* anuncio = BLEDevice::getAdvertising();
  anuncio->addServiceUUID(UUID_SERVICIO);
  anuncio->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.printf("%s anunciando%s\n", IDENTIFICADOR,
                MODO_SIMULACION ? " (simulado)" : "");
}

void loop() {
  static uint32_t ultimoLatido = 0;
  static uint32_t ultimoMonitor = 0;

  if (Serial.available()) {
    ejecutarComando(Serial.readStringUntil('\n'));
  }

  // Con el voltaje crudo al lado: si salta sin que pase nada, es el cable.
  if (monitorContinuo && millis() - ultimoMonitor > 1000) {
    ultimoMonitor = millis();

#if MODO_SIMULACION
    Serial.println("monitor no aplica en modo simulacion");
    monitorContinuo = false;
#else
#if TIENE_PH
    float voltiosPh = aVoltios(leerCrudoFiltrado(PIN_PH));
    Serial.printf("pH %.2f   (%.4f V)\n", phDeVoltios(voltiosPh, NAN),
                  voltiosPh);
#endif
#if TIENE_TURBIDEZ
    float voltiosTurb = voltiosTurbidez();
    Serial.printf("turbidez %.1f NTU   (%.4f V)\n",
                  turbidezDeVoltios(voltiosTurb), voltiosTurb);
#endif
#if TIENE_CONDUCTIVIDAD
    Serial.printf("conductividad %.0f uS/cm   (%.4f V)\n",
                  leerConductividad(NAN), aVoltios(leerCrudoFiltrado(PIN_TDS)));
#endif
#if TIENE_TEMPERATURA
    Serial.printf("temperatura %.1f C\n", leerTemperatura());
#endif
#endif
  }

  if (!hayCentralConectada && millis() - ultimoLatido > 2000) {
    ultimoLatido = millis();
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
  }

  delay(100);
}
