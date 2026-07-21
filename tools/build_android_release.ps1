param(
    [ValidateSet("apk", "appbundle", "both")]
    [string]$Target = "both",
    [string]$BuildName = "1.0.0",
    [int]$BuildNumber = 1
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Read-DotEnvValue {
    param(
        [string]$FilePath,
        [string]$Key
    )

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    foreach ($line in Get-Content $FilePath) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith("#")) {
            continue
        }

        $parts = $line -split "=", 2
        if ($parts.Length -eq 2 -and $parts[0].Trim() -eq $Key) {
            return $parts[1].Trim()
        }
    }

    return $null
}

$envFile = Join-Path $projectRoot ".env"
$supabaseUrl = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { Read-DotEnvValue -FilePath $envFile -Key "SUPABASE_URL" }
$supabaseAnonKey = if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { Read-DotEnvValue -FilePath $envFile -Key "SUPABASE_ANON_KEY" }

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or [string]::IsNullOrWhiteSpace($supabaseAnonKey)) {
    throw "SUPABASE_URL atau SUPABASE_ANON_KEY belum tersedia. Isi file .env lokal atau export environment variable terlebih dahulu."
}

$dartDefineArgs = @(
    "--dart-define=SUPABASE_URL=$supabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey",
    "--build-name=$BuildName",
    "--build-number=$BuildNumber",
    "--release"
)

if ($Target -in @("apk", "both")) {
    & flutter build apk @dartDefineArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk gagal."
    }
}

if ($Target -in @("appbundle", "both")) {
    & flutter build appbundle @dartDefineArgs
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build appbundle gagal."
    }
}

Write-Host "Build Android selesai." -ForegroundColor Green
