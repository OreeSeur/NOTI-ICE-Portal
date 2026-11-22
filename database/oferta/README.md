# Importación de la oferta académica

Herramientas para cargar los grupos, materias, laboratorios, horarios y docentes publicados en el sistema de horarios de la ESIME Zacatenco. El procedimiento completo, con sus validaciones y resultados del periodo 2027-1, está en [docs/desarrollo/Importacion_oferta_academica.pdf](../../docs/desarrollo/Importacion_oferta_academica.pdf).

| Archivo | Etapa | Qué hace |
|---|---|---|
| `Recopilar-Horarios-ICE.ps1` | 1. Recopilación | Consulta el sistema público de horarios (solo lectura, con pausa de 1.25 s entre solicitudes), descarga la página de cada grupo de ICE de ambos planes y la guarda en una carpeta de Descargas con un ZIP. |
| `Procesar-Horarios-ICE.ps1` | 2. Procesamiento | Lee esas páginas y genera `grupos.csv`, `unidades.csv`, `sesiones.csv`, `docentes.csv` y `catalogo.csv`, más `errores.csv` y `resumen.txt`. No consulta internet ni escribe en MySQL. |
| `backend/NoiceBack/Sql/00_PREVALIDACION_SOLO_LECTURA.sql` | 3. Importación | Consulta de solo lectura previa a la carga. |
| `backend/NoiceBack/Sql/01_IMPORTAR_ICE_2027-1_SOLO_PRUEBAS_NO_EJECUTAR.sql` | 3. Importación | Modelo del script de carga: tablas temporales, verificaciones y una sola transacción. |

## Uso para un periodo nuevo

```powershell
# 1. Recopilar (requiere internet)
powershell -ExecutionPolicy Bypass -File database\oferta\Recopilar-Horarios-ICE.ps1 -Periodo 2027-2

# 2. Procesar la carpeta que indique el paso anterior
powershell -ExecutionPolicy Bypass -File database\oferta\Procesar-Horarios-ICE.ps1 -Origen "$HOME\Downloads\NOTI_ICE_ICE_Ambos_Planes_2027-2_<fecha>" -Destino .\oferta_2027-2 -Periodo 2027-2
```

3. Revisar `errores.csv` y `resumen.txt` antes de continuar.
4. Respaldar la base de datos y generar el script de importación del periodo a partir del modelo `01_IMPORTAR_...sql`, con las cantidades esperadas del resumen.

No se deben reutilizar los grupos, docentes, aulas ni horarios de un periodo anterior: cada periodo se recopila de nuevo desde la fuente. La información cargada es una referencia y no sustituye los canales oficiales del IPN.
