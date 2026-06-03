# KerbClaw CLI — Self-contained single-file publish script
# Run this in PowerShell to produce a portable .exe for GitHub release.

param(
    [string]$OutputPath = "$PSScriptRoot\bin\Published"
)

$Project = "$PSScriptRoot\CKAN-CLI.csproj"
$Rid     = "win-x64"
$Config  = "Release"

Write-Host "=== KerbClaw CLI Self-contained Publish ===" -ForegroundColor Cyan
Write-Host "Target : $Rid / $Config"
Write-Host "Output : $OutputPath"
Write-Host ""

# Step 1 — Build with RID so restore knows the target
Write-Host "[1/3] Restoring packages for $Rid..." -ForegroundColor Yellow
dotnet restore $Project -r $Rid
if ($LASTEXITCODE -ne 0) { Write-Host "Restore failed!" -ForegroundColor Red; exit 1 }

# Step 2 — Publish self-contained single-file
Write-Host "[2/3] Publishing self-contained single-file EXE..." -ForegroundColor Yellow
dotnet publish $Project `
    -c $Config `
    -r $Rid `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:DebugType=none `
    -p:DebugSymbols=false `
    -p:PublishDir="$OutputPath"
if ($LASTEXITCODE -ne 0) { Write-Host "Publish failed!" -ForegroundColor Red; exit 1 }

# Step 3 — Verify
$ExePath = "$OutputPath\KerbClaw-CLI.exe"
if (Test-Path $ExePath) {
    $Size = (Get-Item $ExePath).Length / 1MB
    Write-Host "[3/3] Done!" -ForegroundColor Green
    Write-Host "Output: $ExePath ($([math]::Round($Size, 1)) MB)" -ForegroundColor Green
    Write-Host "This single .exe runs on ANY Windows x64 machine — no .NET needed." -ForegroundColor Green
} else {
    Write-Host "ERROR: $ExePath not found!" -ForegroundColor Red
    exit 1
}
