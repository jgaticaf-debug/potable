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

#define MODO_SIMULACION 1

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

static float leerPh(float temperatura) {
  float voltios = aVoltios(leerCrudoFiltrado(PIN_PH));
  float ph = phPendiente * voltios + phOffset;

  if (!isnan(temperatura)) {
    ph += (temperatura - TEMPERATURA_REFERENCIA) * 0.03f;
  }
  return constrain(ph, 0.0f, 14.0f);
}

static float leerTurbidez() {
  float voltios = aVoltios(leerCrudoFiltrado(PIN_TURBIDEZ)) * DIVISOR_TURBIDEZ;

  if (voltios > 4.2f) return 0.0f;
  float ntu = -1120.4f * voltios * voltios + 5742.3f * voltios - 4352.9f;
  return constrain(ntu, 0.0f, 4000.0f);
}

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
  l.temperatura = leerTemperatura();

  l.ph = leerPh(l.temperatura);
  delay(500);
  l.conductividad = leerConductividad(l.temperatura);
  delay(200);
  l.turbidez = leerTurbidez();

  l.valida = !isnan(l.temperatura);
  return l;
}
#endif

static String comoJson(const Lectura& l) {
  JsonDocument doc;
  doc["equipo"] = IDENTIFICADOR;
  doc["simulado"] = MODO_SIMULACION == 1;
  doc["ms"] = millis();

  JsonObject valores = doc["valores"].to<JsonObject>();
  valores["ph"] = round(l.ph * 100) / 100.0;
  valores["turbidez"] = round(l.turbidez * 100) / 100.0;
  valores["conductividad"] = round(l.conductividad);
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

class ManejadorComando : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* caracteristica) override {
    String comando = String(caracteristica->getValue().c_str());
    comando.trim();

    if (comando == "leer") {
      publicarEstado("midiendo");
      publicarLectura();
      publicarEstado("listo");
      return;
    }

    if (comando.startsWith("calibrar:")) {
      float phConocido = comando.substring(9).toFloat();
      float voltios = aVoltios(leerCrudoFiltrado(PIN_PH));
      phOffset = phConocido - phPendiente * voltios;

      memoria.begin("potable", false);
      memoria.putFloat("phOffset", phOffset);
      memoria.end();

      publicarEstado("calibrado");
      Serial.printf("calibrado en pH %.2f, offset %.3f\n", phConocido, phOffset);
      return;
    }

    publicarEstado("comando desconocido");
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

  if (!hayCentralConectada && millis() - ultimoLatido > 2000) {
    ultimoLatido = millis();
    digitalWrite(PIN_LED, !digitalRead(PIN_LED));
  }

  delay(100);
}
