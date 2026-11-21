# Historial de desarrollo de NOTI ICE

Este repositorio contiene la versión consolidada del portal NOTI ICE. Lo creamos el 21 de noviembre de 2026 para la entrega del proyecto de titulación, a partir de nuestro repositorio de trabajo anterior.

## ¿Por qué un repositorio nuevo?

Fue la primera vez que trabajamos un proyecto completo con GitHub, y el repositorio anterior lo reflejaba:

- Abrimos **13 ramas** para fases, pilotos y pruebas de integración. Varias se crearon para algo puntual y después ya no se necesitaron, o quedaron con versiones intermedias del código.
- Había commits de ajustes pequeños, correcciones de errores propios y archivos de configuración local que no aportan al proyecto final.
- Tardamos en definir una sola rama de trabajo; la versión más completa terminó en `preparacion-final-despliegue` y no en `main`.

**Integrantes:** Leonardo Ariel Rangel Hernández (Leonardo) e Iván Daniel Salazar Sánchez (Iván).

## Resumen por etapas

### 1. Versión inicial, seguridad y módulo académico básico

| Fecha | Commit | Cambio |
|---|---|---|
| 11/10 | `49f8cdf` | Versión inicial unificada de NOTI ICE |
| 11/10 | `659ce5c` | Corregir la carga inicial de noticias, eventos y documentos |
| 11/10 | `96ececb` | Actualizar dependencias y corregir vulnerabilidades |
| 11/10 | `d1f8841` | Compatibilidad de identificadores entre C#, React y MySQL |
| 11/10 | `7756feb` | Secretos locales del backend fuera del repositorio |
| 11/10 | `7a52027` | Proteger la autoría de noticias y comentarios |
| 11/10 | `38c6afc` | Proteger audiencias y descargas de documentos |
| 11/10 | `238e503` | Actualizar las audiencias al cambiar de sesión |
| 11/10 | `30ac9d5` | Proteger la consulta de alumnos por grupo |
| 11/10 | `36f817a` | Consulta de las inscripciones propias del alumno |
| 11/10 | `a8ac2f7` | Integrar las inscripciones académicas en React |
| 11/10 | `40d93e7` | Validar academias y proteger materias con grupos |
| 11/10 | `d8365b5` | Validar los campos de materias en los DTO |
| 12/10 | `88d463a` | Validar y proteger la administración de academias |
| 12/10 | `a6833ba` | Validar y proteger los tipos de grupo |
| 12/10 | `acc5241` | Validar grupos e inscripciones académicas |
| 12/10 | `d2cb81b` | Pantallas de administración de academias |
| 12/10 | `9666c78` | Pantallas de materias y tipos de grupo |
| 12/10 | `953b77c` | Pantallas de grupos e inscripciones |
| 13/10 | `3ea1ecf` | Usuarios en MySQL, reactivación de cuentas y mejoras visuales |
| 13/10 | `47f43ef` | Seguridad JWT y versión de sesión persistente |
| 13/10 | `91b697a` | Seguridad de audiencias y archivos adjuntos |

### 2. Asistente conversacional y preparación para producción 

| Fecha | Commit | Cambio |
|---|---|---|
| 14/10 | `13c77ea` | Integrar Ollama con Llama 3.2 en el asistente |
| 14/10 | `ca447dd` | Límites de frecuencia y concurrencia del asistente |
| 14/10 | `7b73f44` | Configuración portable para producción |
| 14/10 | `b5c7d7e` | Almacenamiento persistente de adjuntos y respaldos |
| 14/10 | `2cb29ae` | Límites de carga de archivos y configuración de correo SMTP |
| 16/10 | `506ace6` | Integrar las funcionalidades validadas en el piloto |

### 3. Oferta académica y horarios 2027-1

| Fecha | Commit | Cambio |
|---|---|---|
| 18/10 | `d42dcec` | Oferta académica por periodo y selección de materias del alumno |
| 19/10 | `fb672ac` | Horarios de ICE 2027-1 y scripts de importación |

### 4. Cuentas, documentación y asistente académico

| Fecha | Commit | Cambio |
|---|---|---|
| 22/10 | `f77fdd5` | Validaciones de cuentas y protección de roles |
| 07/11 | `ada073a` | Modo de pruebas locales con Ollama |
| 07/11 | `91fe8b2` | Reorganizar la documentación en `docs/` por área |
| 07/11 | `3e0bde8` | Guía de arranque local y README actualizados |
| 07/11 | `2a3b3ab` | Asistente: consulta de horarios, catálogo, materias del alumno y perfil |
| 07/11 | `49b2542` | Asistente: textos y sugerencias para horarios y materias |
| 07/11 | `6054c75` | Documentar el alcance del asistente académico |

### 5. Docentes, materias del alumno y entrega a otro equipo

| Fecha | Commit | Cambio |
|---|---|---|
| 07/11 | `4f94f67` | Solicitudes de docentes para impartir materias, con aprobación del Administrador |
| 07/11 | `3e39d00` | Pantallas de solicitudes de docentes y materias como destinatarias |
| 07/11 | `b838903` | Documentar las solicitudes de docentes y su script de base de datos |
| 07/11 | `6156f26` | Los docentes publican, editan y eliminan sus propias noticias |
| 07/11 | `8c361d9` | Pantallas de noticias para docentes y sección «Mis publicaciones» |
| 07/11 | `4c4f562` | Documentar las noticias de docentes |
| 07/11 | `09f6a58` | Perfil del alumno: sección única «Mis materias y horario» |
| 07/11 | `f3945dc` | Ventana de confirmación del portal al quitar materias |
| 07/11 | `5b06864` | Agregar un grupo completo y quitar todas las materias en una operación |
| 07/11 | `e710c56` | Botones para agregar el grupo completo y quitar todas las materias |
| 07/11 | `d02f43f` | Script de base de datos limpia y guía de instalación en otro equipo |
| 07/11 | `f6b9bfb` | Opción para generar cuentas propias en la base de entrega |

### 6. Despliegue, modelo académico único y comentarios

| Fecha | Commit | Cambio |
|---|---|---|
| 10/11 | `b070c9b` | Título de la pestaña y asistente habilitado en el servidor |
| 11/11 | `5d687a5` | Modelo académico único por periodo, con academias |
| 14/11 | `37ef79f` | Noticias con vigencia y mejoras de comentarios (trabajo de Iván, integrado desde su copia) |
| 14/11 | `b48ad37` | Confirmación del borrado de comentarios con la ventana del portal |

### 7. Pruebas del capítulo 4

| Fecha | Commit | Cambio |
|---|---|---|
| 19/11 | `aabfcf3` | Resultados de las pruebas del capítulo 4 |
| 19/11 | `e93f125` | Dejar fuera de Git los borradores de la tesis |

## Ramas del repositorio anterior

| Rama | Uso |
|---|---|
| `main` | Primera versión publicada; quedó atrás de la rama de trabajo |
| `fase-a-estabilidad-seguridad` | Fase A: seguridad, módulo académico básico y preparación para producción (11 al 14 de octubre) |
| `desarrollo-materias-horarios` | Oferta académica por periodo y selección de materias del alumno |
| `preparacion-produccion-configuracion-portable` | Configuración para producción |
| `preparacion-produccion-chatbot-limites-local` | Límites del asistente |
| `preparacion-produccion-almacenamiento-respaldos` | Adjuntos y respaldos |
| `preparacion-produccion-cargas-smtp` | Carga de archivos y correo |
| `piloto-integracion-total-sin-ollama` | Piloto de integración sin el asistente |
| `preparacion-importacion-ice-2027-1` | Importación de horarios 2027-1 |
| `integracion-intervencion-1b-seguridad-cuentas-20261022` | Validaciones de cuentas |
| `integracion-consolidada-20261025` | Integración de todas las ramas anteriores |
| `preparacion-final-despliegue` | Versión final; es la base de este repositorio |

Al consolidar comprobamos que ninguna de estas ramas tenía cambios propios pendientes: todo su trabajo ya estaba integrado en `preparacion-final-despliegue`.
