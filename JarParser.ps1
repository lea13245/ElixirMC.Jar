Clear-Host
$SS = @"

██╗░░░░░██╗░░░██╗██╗░░░██╗██╗░░░░░░███████╗██╗░░░░░██╗░░██╗██████╗░
██║░░░░░██║░░░██║██║░░░██║██║░░░░░░██╔════╝██║░░░░░╚██╗██╔╝██╔══██╗
██║░░░░░██║░░░██║╚██╗░██╔╝██║█████╗█████╗░░██║░░░░░░╚███╔╝░██████╔╝
██║░░░░░██║░░░██║░╚████╔╝░██║╚════╝██╔══╝░░██║░░░░░░██╔██╗░██╔══██╗
███████╗╚██████╔╝░░╚██╔╝░░██║░░░░░░███████╗███████╗██╔╝╚██╗██║░░██║
╚══════╝░╚═════╝░░░░╚═╝░░░╚═╝░░░░░░╚══════╝╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝
"@
Write-Host $SS -ForegroundColor Magenta

$pecmdUrl = "https://github.com/NoDiff-del/JARs/releases/download/Jar/PECmd.exe"
$pecmdPath = "$env:TEMP\PECmd.exe"

Invoke-WebRequest -Uri $pecmdUrl -OutFile $pecmdPath -UseBasicParsing

$logonTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$prefetchFolder = "C:\\Windows\\Prefetch"
$files = Get-ChildItem -Path $prefetchFolder -Filter *.pf | Where-Object {
    ($_.Name -match "java|javaw") -and ($_.LastWriteTime -gt $logonTime)
} | Sort-Object LastWriteTime -Descending

if ($files.Count -gt 0) {
    Write-Host "PF files found after logon time (sorted by LastWriteTime).." -ForegroundColor Gray
    $files | ForEach-Object {
        Write-Host " "
        Write-Host "Analizando: $($_.Name)" -ForegroundColor DarkCyan
        Write-Host "Última modificación del .pf: $($_.LastWriteTime)" -ForegroundColor Cyan

        try {
            $pecmdOutput = & $pecmdPath -f $_.FullName
        } catch {
            Write-Warning "Error ejecutando PECmd.exe en $($_.Name): $_"
            return
        }

        $filteredImports = $pecmdOutput

        if ($filteredImports.Count -gt 0) {
            Write-Host "Imports encontrados:" -ForegroundColor DarkYellow
            foreach ($lineRaw in $filteredImports) {
                if ($lineRaw -notmatch '\\VOLUME|:\\\\') {
                    continue
                }

                $line = $lineRaw
                if ($line -match '\\VOLUME{(.+?)}') {
                    $line = $line -replace '\\VOLUME{(.+?)}', 'C:'
                }
                $line = $line -replace '^\d+: ', ''
                $line = $line.Trim()

                if ($line -match '\\[^\\]+\.[^\\]+$' -and (Test-Path $line)) {
                    $sig = Get-AuthenticodeSignature -FilePath $line -ErrorAction SilentlyContinue
                    if ($sig.Status -ne 'Valid') {
                        Write-Host "[SIN FIRMA] $line" -ForegroundColor Red
                    }
                } elseif ($line -match '\\[^\\]+\.[^\\]+$') {
                    Write-Host "[NO EXISTE] $line" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "No imports found for the file $($_.Name)." -ForegroundColor Red
        }
    }
} else {
    Write-Host "No PF files para java.exe o javaw.exe modificados tras el logon." -ForegroundColor Red
}
