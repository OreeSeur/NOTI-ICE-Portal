-- Noticias temporales (vigencia): agrega noticias.FechaExpiracion (DATE, acepta vacio).
--  * Ultimo dia en que la noticia se muestra (inclusive). Vacio = sin vencimiento.
--  * Las noticias que ya existen quedan sin vencimiento; las nuevas duran 6 meses si no se indica fecha.
-- Aditivo: no borra ni modifica datos. Idempotente: si la columna ya existe, no hace nada.
-- Debe aplicarse en cada base ANTES de desplegar el codigo que la usa: sin la columna fallan
-- todas las consultas de noticias, comentarios y el asistente.
-- Ejecutar con la base de destino:
--   mysql.exe -u root -p --default-character-set=utf8mb4 portal_noticias_pruebas < este_archivo.sql

SELECT DATABASE() AS base_seleccionada;

SET @existe := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'noticias' AND COLUMN_NAME = 'FechaExpiracion'
);

SET @sql := IF(@existe = 0,
  'ALTER TABLE `noticias` ADD COLUMN `FechaExpiracion` DATE NULL AFTER `Activo`',
  'SELECT ''La columna noticias.FechaExpiracion ya existe; no se modifico nada'' AS aviso');

PREPARE paso FROM @sql;
EXECUTE paso;
DEALLOCATE PREPARE paso;

-- Comprobacion
SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'noticias' AND COLUMN_NAME = 'FechaExpiracion';

SELECT COUNT(*) AS noticias_total,
       SUM(`FechaExpiracion` IS NULL) AS sin_vencimiento
FROM `noticias`;
