<#
.SYNOPSIS
    NOTI ICE - Recopila las paginas publicas de horarios de ICE (ambos planes) del sistema de horarios de ESIME Zacatenco.

.DESCRIPTION
    Solo consulta paginas publicas (HTTP GET) de https://horarios.esimez.ipn.mx; no modifica bases de datos ni servidores.
    Recorre los indices por carrera, semestre y turno, descarga la pagina de horario de cada grupo y guarda todo en una
    carpeta de Descargas junto con un ZIP. La fuente rotula el plan antiguo como 2009; en NOTI ICE se registra como 2003.
    El resultado se procesa despues con Procesar-Horarios-ICE.ps1. Compatible con Windows PowerShell 5.1.

.PARAMETER Periodo
    Periodo esperado en las paginas de horario, por ejemplo 2027-1.
#>
param([ValidatePattern('^20\d{2}-[12]$')][string]$Periodo = '2027-1')

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $sitio = 'https://horarios.esimez.ipn.mx'
    $descargas = Join-Path $HOME 'Downloads'
    $marca = Get-Date -Format 'yyyyMMdd-HHmmss'
    $destino = Join-Path $descargas "NOTI_ICE_ICE_Ambos_Planes_${periodo}_$marca"
    $dirIndices = Join-Path $destino 'indices'
    $dirHorarios = Join-Path $destino 'horarios'
    New-Item -ItemType Directory -Force -Path $dirIndices, $dirHorarios | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $resultadosIndices = New-Object 'System.Collections.Generic.List[object]'
    $resultadosHorarios = New-Object 'System.Collections.Generic.List[object]'
    $errores = New-Object 'System.Collections.Generic.List[object]'
    $grupos = @{}
    $linksRegex = '(?is)\bhref\s*=\s*["''](?<url>[^"'']+)["'']'

    function Obtener-Html([string]$url) {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 40 -MaximumRedirection 3 -Headers @{Accept='text/html'}
        if ($r.BaseResponse.ResponseUri.Host -ne 'horarios.esimez.ipn.mx') { throw "Redireccion ajena al sitio: $url" }
        $html = [string]$r.Content
        if ([string]::IsNullOrWhiteSpace($html) -or $html.Length -lt 100) { throw "HTML vacio: $url" }
        return $html
    }
    function Publicar-Html([string]$html, [string]$archivo) {
        # Remover scripts y campos ocultos de las paginas compartidas.
        $limpio = [regex]::Replace($html, '(?is)<script\b[^>]*>.*?</script\s*>', '')
        $limpio = [regex]::Replace($limpio, '(?is)<input\b(?=[^>]*\btype\s*=\s*["'']?hidden\b)[^>]*>', '')
        [IO.File]::WriteAllText($archivo, $limpio, $utf8)
        return $limpio
    }
    function Texto-Visible([string]$html) {
        $s = [regex]::Replace($html, '(?is)<script\b[^>]*>.*?</script\s*>', ' ')
        $s = [regex]::Replace($s, '(?is)<style\b[^>]*>.*?</style\s*>', ' ')
        $s = [Net.WebUtility]::HtmlDecode([regex]::Replace($s, '(?s)<[^>]*>', ' '))
        return ([regex]::Replace($s, '\s+', ' ')).Trim()
    }
    function Valor-Plan([string]$html) {
        $texto = Texto-Visible $html
        $m = [regex]::Match($texto, '(?i)\bPLAN\s*(?:DE\s+ESTUDIOS\s*)?(2004|2009|2024)\b')
        if ($m.Success) { return $m.Groups[1].Value }
        return 'SIN_IDENTIFICAR'
    }

    Write-Host '=== PROGRAMAS PUBLICADOS EN EL SELECTOR INSTITUCIONAL ==='
    try { $inicio = Obtener-Html "$sitio/alumnos" }
    catch { throw "No se pudo abrir el selector oficial: $($_.Exception.Message)" }
    $todosProgramas = New-Object 'System.Collections.Generic.List[object]'
    $selecciones = [regex]::Matches($inicio, '(?is)<select\b(?<attr>[^>]*)>(?<body>.*?)</select\s*>')
    foreach ($sel in $selecciones) {
        if ($sel.Groups['attr'].Value -notmatch '(?i)Programa|Carrera') { continue }
        foreach ($opt in [regex]::Matches($sel.Groups['body'].Value, '(?is)<option\b(?<attr>[^>]*)>(?<label>.*?)</option\s*>')) {
            $v = [regex]::Match($opt.Groups['attr'].Value, '(?i)\bvalue\s*=\s*(?:"(?<a>\d+)"|''(?<b>\d+)''|(?<c>\d+))')
            if (-not $v.Success) { continue }
            $id = $v.Groups['a'].Value + $v.Groups['b'].Value + $v.Groups['c'].Value
            $nombre = Texto-Visible $opt.Groups['label'].Value
            $todosProgramas.Add([pscustomobject]@{ProgramaId=[int]$id; Nombre=$nombre})
        }
    }
    if ($todosProgramas.Count -eq 0) {
        # Segundo intento si el select carece de atributos id/name.
        foreach ($opt in [regex]::Matches($inicio, '(?is)<option\b(?<attr>[^>]*)>(?<label>.*?)</option\s*>')) {
            $v = [regex]::Match($opt.Groups['attr'].Value, '(?i)\bvalue\s*=\s*(?:"(?<a>\d+)"|''(?<b>\d+)''|(?<c>\d+))')
            if (-not $v.Success) { continue }
            $id = $v.Groups['a'].Value + $v.Groups['b'].Value + $v.Groups['c'].Value
            $nombre = Texto-Visible $opt.Groups['label'].Value
            $todosProgramas.Add([pscustomobject]@{ProgramaId=[int]$id; Nombre=$nombre})
        }
    }
    $todosProgramas | Sort-Object ProgramaId -Unique | Export-Csv -LiteralPath (Join-Path $destino 'opciones_programa.csv') -NoTypeInformation -Encoding UTF8
    $programasICE = @($todosProgramas | Where-Object { $_.Nombre -match '(?i)Comunicaciones\s+y\s+Electr.nica|\bICE\b' } | Sort-Object ProgramaId -Unique)
    foreach ($p in $programasICE) { Write-Host "Opcion ICE: ProgramaId=$($p.ProgramaId); $($p.Nombre)" }
    if ($programasICE.Count -lt 2) {
        Write-Warning "Solo se identificaron $($programasICE.Count) opciones ICE. Para evitar una recopilacion incompleta, NO se descargan mas grupos."
        Write-Host 'Revise opciones_programa.csv para identificar los ProgramaId correctos de ICE.'
        Write-Host "Carpeta diagnostica: $destino"
        return
    }

    # Reutiliza las paginas de ProgramaId=4 de una captura previa del mismo periodo, si existe, para no repetir consultas.
    $anterior = $null
    $carpetasPrevias = @(Get-ChildItem -LiteralPath $descargas -Directory -Filter "NOTI_ICE_Fuentes_ICE_${periodo}_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    foreach ($carpeta in $carpetasPrevias) {
        $leeme = Join-Path $carpeta.FullName 'LEEME.txt'
        if ((Test-Path -LiteralPath $leeme) -and (Test-Path -LiteralPath (Join-Path $carpeta.FullName 'indices')) -and ((Get-Content -LiteralPath $leeme -Raw) -match 'ProgramaId=4')) {
            $anterior = $carpeta.FullName
            break
        }
    }
    if ($null -ne $anterior) { Write-Host "Se reutilizaran los archivos de ProgramaId=4: $anterior" }

    Write-Host "`n=== INDICES DE ICE, AMBOS PLANES, $periodo ==="
    foreach ($programa in $programasICE) {
        $id = $programa.ProgramaId
        foreach ($semestre in 1..9) {
            foreach ($turno in 1..2) {
                $url = "$sitio/alumnos?ProgramaId=$id&Semestre=$semestre&TurnoId=$turno"
                $archivo = Join-Path $dirIndices "programa_${id}_semestre_${semestre}_turno_${turno}.html"
                $origen = if ($id -eq 4 -and $null -ne $anterior) { Join-Path $anterior "indices\semestre_${semestre}_turno_${turno}.html" } else { '' }
                try {
                    if ($origen -and (Test-Path -LiteralPath $origen)) {
                        Copy-Item -LiteralPath $origen -Destination $archivo
                        $html = [IO.File]::ReadAllText($archivo)
                        $origenDato = 'CACHE'
                    } else {
                        $html = Publicar-Html (Obtener-Html $url) $archivo
                        $origenDato = 'WEB'
                        Start-Sleep -Milliseconds 1250
                    }
                    $vistos = @{}
                    foreach ($enlace in [regex]::Matches($html, $linksRegex)) {
                        $href = [Net.WebUtility]::HtmlDecode($enlace.Groups['url'].Value)
                        if ($href -notmatch '(?i)(?:^|/)Alumnos/Horario/([^/?#]+)') { continue }
                        $codigo = [Uri]::UnescapeDataString($Matches[1]).Trim()
                        if ($codigo -notmatch '^[A-Za-z0-9_-]{2,30}$') { continue }
                        $uri = [Uri]::new(([Uri]$sitio), [string]$href)
                        if ($uri.Host -ne 'horarios.esimez.ipn.mx' -or $uri.Scheme -ne 'https') { continue }
                        if ($vistos.ContainsKey($codigo)) { continue }
                        $vistos[$codigo] = $true
                        $clave = "${id}|${codigo}"
                        if (-not $grupos.ContainsKey($clave)) {
                            $grupos[$clave] = [pscustomobject]@{ ProgramaId=$id; CodigoGrupo=$codigo; SemestreIndice=$semestre; TurnoIndice=$turno; Url=$uri.AbsoluteUri }
                        }
                    }
                    $resultadosIndices.Add([pscustomobject]@{ProgramaId=$id;Programa=$programa.Nombre;Semestre=$semestre;TurnoId=$turno;Grupos=$vistos.Count;Estado='OK';Origen=$origenDato;Url=$url})
                    Write-Host "Programa $id, semestre $semestre, turno $turno : $($vistos.Count) grupos ($origenDato)"
                } catch {
                    $msg = $_.Exception.Message -replace '[\r\n]+',' '
                    $resultadosIndices.Add([pscustomobject]@{ProgramaId=$id;Programa=$programa.Nombre;Semestre=$semestre;TurnoId=$turno;Grupos=0;Estado='ERROR';Origen='';Url=$url})
                    $errores.Add([pscustomobject]@{Etapa='indice';Identificador="$id/$semestre/$turno";Url=$url;Error=$msg})
                    Write-Warning "Indice $id/$semestre/$turno : $msg"
                }
            }
        }
    }

    $lista = @($grupos.Values | Sort-Object ProgramaId, CodigoGrupo)
    Write-Host "`nReferencias programa-grupo encontradas: $($lista.Count)"
    if ($lista.Count -gt 800) { throw 'Se encontraron mas de 800 referencias; se detiene la captura para revision.' }
    Write-Host '=== DETALLES Y IDENTIFICACION DEL PLAN POR CADA GRUPO ==='
    $n = 0
    foreach ($grupo in $lista) {
        $n++
        $cod = $grupo.CodigoGrupo
        $id = $grupo.ProgramaId
        $archivo = Join-Path $dirHorarios "programa_${id}_${cod}.html"
        $origen = if ($id -eq 4 -and $null -ne $anterior) { Join-Path $anterior "horarios\${cod}.html" } else { '' }
        try {
            if ($origen -and (Test-Path -LiteralPath $origen)) {
                Copy-Item -LiteralPath $origen -Destination $archivo
                $html = [IO.File]::ReadAllText($archivo)
                $fuente = 'CACHE'
            } else {
                $html = Publicar-Html (Obtener-Html $grupo.Url) $archivo
                $fuente = 'WEB'
                Start-Sleep -Milliseconds 1250
            }
            $planOriginal = Valor-Plan $html
            $textoFuente = Texto-Visible $html
            $mPeriodo = [regex]::Match($textoFuente, '(?i)\bPERIODO\s*(20\d{2}-[12])\b')
            $periodoFuente = if ($mPeriodo.Success) { $mPeriodo.Groups[1].Value } else { 'SIN_IDENTIFICAR' }
            if ($periodoFuente -ne $periodo) {
                $errores.Add([pscustomobject]@{Etapa='periodo';Identificador="$id/$cod";Url=$grupo.Url;Error="Periodo distinto o sin identificar: $periodoFuente"})
            }
            $planNoti = switch ($planOriginal) {'2009' {'2003'} '2004' {'2003'} '2024' {'2024'} default {'SIN_IDENTIFICAR'}}
            if ($planNoti -eq 'SIN_IDENTIFICAR') {
                $errores.Add([pscustomobject]@{Etapa='plan';Identificador="$id/$cod";Url=$grupo.Url;Error='Plan no identificado en la pagina de horario'})
            }
            $resultadosHorarios.Add([pscustomobject]@{ProgramaId=$id;CodigoGrupo=$cod;SemestreIndice=$grupo.SemestreIndice;TurnoIndice=$grupo.TurnoIndice;PlanFuente=$planOriginal;PlanNotiIce=$planNoti;PeriodoFuente=$periodoFuente;Estado='OK';Origen=$fuente;Archivo="horarios/programa_${id}_${cod}.html";Url=$grupo.Url})
        } catch {
            $msg = $_.Exception.Message -replace '[\r\n]+',' '
            $errores.Add([pscustomobject]@{Etapa='horario';Identificador="$id/$cod";Url=$grupo.Url;Error=$msg})
            $resultadosHorarios.Add([pscustomobject]@{ProgramaId=$id;CodigoGrupo=$cod;SemestreIndice=$grupo.SemestreIndice;TurnoIndice=$grupo.TurnoIndice;PlanFuente='';PlanNotiIce='';PeriodoFuente='';Estado='ERROR';Origen='';Archivo='';Url=$grupo.Url})
            Write-Warning "Grupo $id/$cod : $msg"
        }
        if ($n % 25 -eq 0 -or $n -eq $lista.Count) { Write-Host "Detalles revisados: $n/$($lista.Count)" }
    }
    $resultadosIndices | Export-Csv -LiteralPath (Join-Path $destino 'indices.csv') -NoTypeInformation -Encoding UTF8
    $resultadosHorarios | Export-Csv -LiteralPath (Join-Path $destino 'grupos_por_plan.csv') -NoTypeInformation -Encoding UTF8
    if ($errores.Count) { $errores | Export-Csv -LiteralPath (Join-Path $destino 'errores.csv') -NoTypeInformation -Encoding UTF8 }
    $colisiones = @($resultadosHorarios | Group-Object CodigoGrupo | Where-Object { $_.Count -gt 1 })
    if ($colisiones.Count -gt 0) {
        $colisiones | ForEach-Object { [pscustomobject]@{CodigoGrupo=$_.Name; Referencias=$_.Count} } | Export-Csv -LiteralPath (Join-Path $destino 'grupos_repetidos_entre_programas.csv') -NoTypeInformation -Encoding UTF8
        Write-Warning "Se encontraron $($colisiones.Count) codigos de grupo en multiples ProgramaId. Requieren revision antes de importar."
    }
    $totales = @($resultadosHorarios | Group-Object PlanNotiIce | Sort-Object Name | ForEach-Object { [pscustomobject]@{PlanNotiIce=$_.Name;Grupos=$_.Count} })
    $totales | Export-Csv -LiteralPath (Join-Path $destino 'totales_por_plan.csv') -NoTypeInformation -Encoding UTF8
    $leeme = @(
        "NOTI ICE | Consulta publica ICE $periodo | Solo captura documental",
        'El plan 2009 de la fuente se registra como plan 2003 en NOTI ICE.',
        'El plan se identifica por el texto de CADA pagina de horario; no se infiere por semestre.',
        "Programas ICE detectados: $($programasICE.Count)",
        "Referencias programa-grupo: $($lista.Count)",
        "Errores o planes no identificados: $($errores.Count)",
        'NO es migracion SQL. Revisar coincidencias de CodigoGrupo entre programas y datos de origen.',
        'Solo se consultaron paginas publicas; no se modifico ninguna base de datos ni servidor.'
    )
    [IO.File]::WriteAllLines((Join-Path $destino 'LEEME.txt'), [string[]]$leeme, $utf8)
    $zip = "$destino.zip"
    Compress-Archive -Path (Join-Path $destino '*') -DestinationPath $zip -Force
    Write-Host "`n=== RESULTADOS ==="
    $totales | Format-Table -AutoSize
    Write-Host "Referencias programa-grupo: $($lista.Count)"
    Write-Host "Errores: $($errores.Count)"
    Write-Host "Carpeta: $destino"
    Write-Host "Archivo comprimido: $zip"
    Write-Host 'Siguiente paso: procesar la carpeta con Procesar-Horarios-ICE.ps1.'
}
