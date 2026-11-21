<#
.SYNOPSIS
    NOTI ICE - Procesa las paginas de horarios de ESIME Zacatenco y genera los CSV de la oferta academica.

.DESCRIPTION
    Lee las paginas HTML de horario por grupo (https://horarios.esimez.ipn.mx/Alumnos/Horario/<grupo>)
    que guarda el recopilador y las convierte en cinco archivos CSV con la misma estructura que
    las tablas temporales del script de importacion:

        grupos.csv     -> ofertagrupos
        unidades.csv   -> ofertaunidades           (materias y laboratorios)
        sesiones.csv   -> ofertasesiones           (dia, hora de inicio, hora de fin, aula)
        docentes.csv   -> ofertadocentesunidad     (DOCENTE o VACANTE)
        catalogo.csv   -> catalogomateriasplanes   (nombres de materia por plan y semestre)

    Ademas genera errores.csv (grupos o filas que no superaron las validaciones) y resumen.txt.

    Solo lee archivos locales: no consulta internet ni escribe en MySQL.

    Reglas de transformacion:
      - Plan: la fuente publica el plan antiguo como 2009; en NOTI ICE se registra como 2003.
      - Cada fila de la tabla es una unidad; su orden en la tabla es OrdenFuente.
      - Es laboratorio si el nombre contiene "Laboratorio" o "Laboratorios".
      - Cada celda de dia con "HH:MM<br/>HH:MM" es una sesion (LUN=1 ... VIE=5).
      - Salon vacio se registra como "—".
      - Los profesores vienen separados por <br/>; "Vacante" se registra como VACANTE sin nombre.
      - IdOrigen del catalogo: ICE-HOR-<periodo>-<plan>-<semestre>-<30 primeros hex de SHA-256("plan|semestre|nombre")>.
      - ChecksumFuente: SHA-256 del archivo HTML procesado.
      - FechaActualizacionFuente: la fecha "Actualizado al ..." del pie de la pagina.

.PARAMETER Origen
    Carpeta con las paginas HTML. Se buscan archivos programa_<ProgramaId>_<grupo>.html
    (formato del recopilador) en la carpeta y sus subcarpetas.

.PARAMETER Destino
    Carpeta donde se escriben los CSV. Se crea si no existe.

.PARAMETER Periodo
    Periodo esperado, por ejemplo 2027-1. Los grupos de otro periodo se registran como error y no se procesan.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Procesar-Horarios-ICE.ps1 -Origen .\NOTI_ICE_ICE_Ambos_Planes_2027-1_20261019-001258 -Destino .\oferta_2027-1 -Periodo 2027-1
#>
param(
    [Parameter(Mandatory = $true)][string]$Origen,
    [Parameter(Mandatory = $true)][string]$Destino,
    [Parameter(Mandatory = $true)][ValidatePattern('^20\d{2}-[12]$')][string]$Periodo
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$sha = [System.Security.Cryptography.SHA256]::Create()
$sitio = 'https://horarios.esimez.ipn.mx'
$meses = @{ enero=1; febrero=2; marzo=3; abril=4; mayo=5; junio=6; julio=7; agosto=8; septiembre=9; setiembre=9; octubre=10; noviembre=11; diciembre=12 }
$planes = @{ '2009' = '2003'; '2004' = '2003'; '2003' = '2003'; '2024' = '2024' }
$dias = @('LUN', 'MAR', 'MIÉ', 'JUE', 'VIE')

function Get-Hex([byte[]]$bytes) { -join ($bytes | ForEach-Object { $_.ToString('x2') }) }

function Get-Texto([string]$html) {
    # Quita etiquetas, decodifica entidades HTML y normaliza espacios.
    $s = [regex]::Replace($html, '(?s)<[^>]*>', ' ')
    $s = [Net.WebUtility]::HtmlDecode($s)
    return ([regex]::Replace($s, '\s+', ' ')).Trim().Normalize([Text.NormalizationForm]::FormC)
}

function Get-Dato([string]$html, [string]$titulo) {
    # Valor de un recuadro <span class="tituloDato">TITULO</span><span class="valorDato">valor</span>.
    $patron = '(?is)<span[^>]*class="tituloDato"[^>]*>\s*' + [regex]::Escape($titulo) + '\s*</span>\s*<span[^>]*class="valorDato"[^>]*>(?<v>.*?)</span>'
    $m = [regex]::Match($html, $patron)
    if ($m.Success) { return Get-Texto $m.Groups['v'].Value }
    return $null
}

function Get-Partes([string]$celda) {
    # Separa el contenido de una celda por <br/> y devuelve los textos no vacios.
    return @([regex]::Split($celda, '(?i)<br\s*/?>') | ForEach-Object { Get-Texto $_ } | Where-Object { $_ -ne '' })
}

if (-not (Test-Path -LiteralPath $Origen -PathType Container)) { throw "No existe la carpeta de origen: $Origen" }
New-Item -ItemType Directory -Force -Path $Destino | Out-Null

$grupos = New-Object 'System.Collections.Generic.List[object]'
$unidades = New-Object 'System.Collections.Generic.List[object]'
$sesiones = New-Object 'System.Collections.Generic.List[object]'
$docentes = New-Object 'System.Collections.Generic.List[object]'
$catalogo = [ordered]@{}
$errores = New-Object 'System.Collections.Generic.List[object]'

$archivos = @(Get-ChildItem -LiteralPath $Origen -Recurse -File -Filter 'programa_*_*.html' |
    Where-Object { $_.Name -match '^programa_(\d+)_([A-Za-z0-9_-]{2,30})\.html$' } | Sort-Object Name)
if ($archivos.Count -eq 0) { throw "No se encontraron archivos programa_<ProgramaId>_<grupo>.html en $Origen" }

foreach ($archivo in $archivos) {
    $null = $archivo.Name -match '^programa_(\d+)_([A-Za-z0-9_-]{2,30})\.html$'
    $programaId = $Matches[1]
    $codigoArchivo = $Matches[2]
    $bytes = [IO.File]::ReadAllBytes($archivo.FullName)
    $html = $utf8.GetString($bytes)
    $idGrupo = "$programaId|$codigoArchivo"

    try {
        # --- Datos generales del grupo ---
        $mGrupo = [regex]::Match($html, '(?is)<div[^>]*class="grupoBox"[^>]*>(?<v>.*?)</div>')
        $codigo = if ($mGrupo.Success) { Get-Texto $mGrupo.Groups['v'].Value } else { '' }
        if ($codigo -ne $codigoArchivo) { throw "El grupo de la pagina ($codigo) no coincide con el archivo ($codigoArchivo)" }

        $periodoFuente = Get-Dato $html 'PERIODO'
        if ($periodoFuente -ne $Periodo) { throw "Periodo distinto o sin identificar: $periodoFuente" }

        $planFuente = Get-Dato $html 'PLAN'
        if (-not $planes.ContainsKey([string]$planFuente)) { throw "Plan no reconocido: $planFuente" }
        $plan = $planes[[string]$planFuente]

        $semestreTexto = Get-Dato $html 'SEMESTRE'
        if ($semestreTexto -notmatch '^\d{1,2}$' -or [int]$semestreTexto -lt 1 -or [int]$semestreTexto -gt 12) { throw "Semestre invalido: $semestreTexto" }
        $semestre = [int]$semestreTexto

        $programa = Get-Dato $html 'PROGRAMA ACADÉMICO'
        if (-not $programa) { throw 'Programa academico no identificado' }

        $fecha = $null
        $mFecha = [regex]::Match((Get-Texto $html), '(?i)Actualizado al (\d{1,2}) de (\p{L}+) de (\d{4})')
        if ($mFecha.Success -and $meses.ContainsKey($mFecha.Groups[2].Value.ToLower())) {
            $fecha = '{0:0000}-{1:00}-{2:00}' -f [int]$mFecha.Groups[3].Value, $meses[$mFecha.Groups[2].Value.ToLower()], [int]$mFecha.Groups[1].Value
        }

        # --- Tabla de horario ---
        $mTabla = [regex]::Match($html, '(?is)<table[^>]*class="tablaHorario"[^>]*>(?<t>.*?)</table>')
        if (-not $mTabla.Success) { throw 'No se encontro la tabla de horario' }
        $encabezado = [regex]::Match($mTabla.Groups['t'].Value, '(?is)<tr[^>]*class="encabezadoHorario"[^>]*>(?<f>.*?)</tr>')
        $titulos = @([regex]::Matches($encabezado.Groups['f'].Value, '(?is)<td[^>]*>(?<c>.*?)</td>') | ForEach-Object { Get-Texto $_.Groups['c'].Value })
        $esperado = @('UNIDAD DE APRENDIZAJE', 'SALÓN') + $dias + @('PROFESOR')
        if (($titulos -join '|') -ne ($esperado -join '|')) { throw "Encabezado inesperado: $($titulos -join ', ')" }

        $filas = @([regex]::Matches($mTabla.Groups['t'].Value, '(?is)<tr[^>]*class="filaHorario"[^>]*>(?<f>.*?)</tr>'))
        if ($filas.Count -eq 0) { throw 'El grupo no tiene materias publicadas' }

        $unidadesGrupo = New-Object 'System.Collections.Generic.List[object]'
        $sesionesGrupo = New-Object 'System.Collections.Generic.List[object]'
        $docentesGrupo = New-Object 'System.Collections.Generic.List[object]'
        $orden = 0
        foreach ($fila in $filas) {
            $orden++
            $celdas = @([regex]::Matches($fila.Groups['f'].Value, '(?is)<td[^>]*>(?<c>.*?)</td>') | ForEach-Object { $_.Groups['c'].Value })
            if ($celdas.Count -ne 8) { throw "La fila $orden tiene $($celdas.Count) celdas; se esperaban 8" }

            $nombre = Get-Texto $celdas[0]
            if (-not $nombre) { throw "La fila $orden no tiene nombre de unidad" }
            $aula = Get-Texto $celdas[1]
            if (-not $aula) { $aula = '—' }
            $idUnidad = "$idGrupo|$orden"
            $esLab = if ($nombre -match '(?i)\blaboratorios?\b') { 1 } else { 0 }
            $unidadesGrupo.Add([pscustomobject]@{ SourceId = $idUnidad; SourceGrupoId = $idGrupo; OrdenFuente = $orden; NombrePublicado = $nombre; EsLaboratorio = $esLab; AulaPublicada = $aula })

            for ($d = 0; $d -lt 5; $d++) {
                $partes = @(Get-Partes $celdas[2 + $d])
                if ($partes.Count -eq 0) { continue }
                if ($partes.Count -ne 2 -or $partes[0] -notmatch '^([01]\d|2[0-3]):[0-5]\d$' -or $partes[1] -notmatch '^([01]\d|2[0-3]):[0-5]\d$') {
                    throw "Horario invalido en la fila $orden, dia $($dias[$d]): $($partes -join ' ')"
                }
                if ($partes[1] -le $partes[0]) { throw "La hora de fin no es posterior a la de inicio en la fila $orden, dia $($dias[$d])" }
                $sesionesGrupo.Add([pscustomobject]@{ SourceUnidadId = $idUnidad; DiaSemana = $d + 1; HoraInicio = "$($partes[0]):00"; HoraFin = "$($partes[1]):00"; Aula = $aula })
            }

            $profes = @(Get-Partes $celdas[7])
            if ($profes.Count -eq 0) { $profes = @('Vacante') }
            $n = 0
            foreach ($p in $profes) {
                $n++
                if ($p -match '^(?i)vacante$') {
                    $docentesGrupo.Add([pscustomobject]@{ SourceUnidadId = $idUnidad; Orden = $n; NombrePublicado = $null; Tipo = 'VACANTE' })
                } else {
                    $docentesGrupo.Add([pscustomobject]@{ SourceUnidadId = $idUnidad; Orden = $n; NombrePublicado = $p; Tipo = 'DOCENTE' })
                }
            }

            $claveCatalogo = "$plan|$semestre|$nombre"
            if (-not $catalogo.Contains($claveCatalogo)) {
                $hash = (Get-Hex $sha.ComputeHash($utf8.GetBytes($claveCatalogo))).Substring(0, 30)
                $catalogo[$claveCatalogo] = [pscustomobject]@{ IdOrigen = "ICE-HOR-$Periodo-$plan-$semestre-$hash"; Plan = $plan; Semestre = $semestre; NombrePublicado = $nombre }
            }
        }

        # El grupo se agrega solo si todas sus filas fueron validas.
        $grupos.Add([pscustomobject]@{
            SourceId = $idGrupo; CodigoGrupo = $codigo; Programa = $programa; Plan = $plan; Semestre = $semestre
            Turno = Get-Dato $html 'TURNO'; Modalidad = Get-Dato $html 'MODALIDAD'; Especialidad = Get-Dato $html 'ESPECIALIDAD'
            UrlFuente = "$sitio/Alumnos/Horario/$codigo"; FechaActualizacionFuente = $fecha; ChecksumFuente = Get-Hex $sha.ComputeHash($bytes)
        })
        $unidades.AddRange($unidadesGrupo)
        $sesiones.AddRange($sesionesGrupo)
        $docentes.AddRange($docentesGrupo)
    } catch {
        $errores.Add([pscustomobject]@{ Grupo = $idGrupo; Archivo = $archivo.Name; Error = $_.Exception.Message })
    }
}

# Un mismo grupo no puede aparecer dos veces en el mismo programa y plan.
$repetidos = @($grupos | Group-Object Programa, Plan, CodigoGrupo | Where-Object { $_.Count -gt 1 })
foreach ($r in $repetidos) { $errores.Add([pscustomobject]@{ Grupo = $r.Name; Archivo = ''; Error = 'Grupo repetido en el mismo programa y plan' }) }

$grupos | Export-Csv -LiteralPath (Join-Path $Destino 'grupos.csv') -NoTypeInformation -Encoding UTF8
$unidades | Export-Csv -LiteralPath (Join-Path $Destino 'unidades.csv') -NoTypeInformation -Encoding UTF8
$sesiones | Export-Csv -LiteralPath (Join-Path $Destino 'sesiones.csv') -NoTypeInformation -Encoding UTF8
$docentes | Export-Csv -LiteralPath (Join-Path $Destino 'docentes.csv') -NoTypeInformation -Encoding UTF8
@($catalogo.Values) | Export-Csv -LiteralPath (Join-Path $Destino 'catalogo.csv') -NoTypeInformation -Encoding UTF8
if ($errores.Count) { $errores | Export-Csv -LiteralPath (Join-Path $Destino 'errores.csv') -NoTypeInformation -Encoding UTF8 }

$resumen = @(
    "NOTI ICE | Procesamiento de horarios | Periodo $Periodo",
    "Archivos leidos: $($archivos.Count)",
    "Grupos procesados: $($grupos.Count)",
    "Unidades (materias y laboratorios): $($unidades.Count)",
    "Sesiones: $($sesiones.Count)",
    "Asignaciones docentes: $($docentes.Count) ($(@($docentes | Where-Object Tipo -eq 'VACANTE').Count) vacantes)",
    "Materias distintas en el catalogo: $($catalogo.Count)",
    "Errores: $($errores.Count)"
)
[IO.File]::WriteAllLines((Join-Path $Destino 'resumen.txt'), [string[]]$resumen, $utf8)
$resumen | ForEach-Object { Write-Host $_ }
if ($errores.Count) { Write-Warning "Revise errores.csv antes de importar." }
