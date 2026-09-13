-- Parametros que se miden y se guardan, pero que no alcanzan para declarar
-- cumplimiento contra la norma. Si la columna esta llena, aqui va el porque, y
-- eso es lo que la app le muestra al operario. Van juntos a proposito: un
-- parametro no puede quedar marcado como indicativo sin decir la razon.
ALTER TABLE parametros ADD COLUMN IF NOT EXISTS nota_indicativa TEXT;

-- La turbidez pasa a indicativa. El SEN0189 mide luz transmitida, que entre
-- 0 y 5 UNT casi no cambia: midiendo la misma muestra dio entre 4 y 48 UNT,
-- cuatro veces mas incertidumbre que el limite de 5 que pide COGUANOR. No es
-- calibracion, es el alcance del aparato, y por eso no puede decidir.
UPDATE parametros
SET nota_indicativa =
  'El sensor mide cuanta luz atraviesa el agua, y entre 0 y 5 UNT casi no ' ||
  'cambia nada. Midiendo la misma muestra quince veces seguidas dio entre 4 ' ||
  'y 48 UNT: cuatro veces mas incertidumbre que el limite de 5 que pide la ' ||
  'norma. No es falta de calibracion, es el alcance del aparato.' ||
  E'\n\n' ||
  'Por eso el valor se registra pero no decide si la muestra cumple. Para ' ||
  'eso hace falta laboratorio.' ||
  E'\n\n' ||
  'Donde si sirve: para ver que tan turbia esta el agua y como cambia con el ' ||
  'tiempo en un mismo punto. La contaminacion gruesa la detecta sin problema.' ||
  E'\n\n' ||
  'Al medir, protega la muestra de la luz y no mueva nada durante la ' ||
  'lectura: la luz del ambiente es el error mas grande y hace que el agua se ' ||
  'vea mas sucia de lo que esta.'
WHERE nombre = 'Turbidez';
