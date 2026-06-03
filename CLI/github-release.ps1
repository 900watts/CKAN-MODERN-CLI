# KerbClaw CLI — GitHub Release Tool
# Run this in PowerShell on your machine (not in WorkBuddy sandbox)
#
# Usage:
#   .\CLI\github-release.ps1 -Tag "v2.0.0" -BuildNumber 28

param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [Parameter(Mandatory = $false)]
    [string]$BuildNumber = ""
)

$Repo    = "900watts/CKAN-MODERN"
$SelfZip = "KerbClaw-CLI-v2.0.0-win-x64-selfcontained.zip"
$FdZip   = "KerbClaw-CLI-v2.0.0-win-x64-framework-dependent.zip"

$ReleaseName = "Build $BuildNumber" + $(if ($Tag -ne "") { " — $Tag" } else { "" })
$ReleaseBody = @"
## KerbClaw CLI v$Tag

### 📦 Downloads

| File | Size | Description |
|------|------|-------------|
| **KerbClaw-CLI-v2.0.0-win-x64-selfcontained.zip** | ~31 MB | ✅ 双击即跑，无需安装 .NET |
| **KerbClaw-CLI-v2.0.0-win-x64-framework-dependent.zip** | ~2 MB | 需要 .NET 8.0 Runtime |

### ✨ What's New
- Rebranded from CKAN-CLI → KerbClaw CLI
- AI-powered mod management with Ollama, OpenAI, Anthropic, Groq, OpenRouter
- Batch upgrade via AI: `[UPGRADE:identifier]` / `[UPGRADE_ALL]`
- Self-contained single-file executable (no .NET required)
"@

# Step 1: check if gh is available
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "❌ 'gh' CLI not found. Install it first:" -ForegroundColor Red
    Write-Host "   winget install --id GitHub.cli" -ForegroundColor Yellow
    Write-Host "   Then run: gh auth login" -ForegroundColor Yellow
    exit 1
}

# Step 2: check auth
Write-Host "🔑 Checking GitHub auth..." -ForegroundColor Cyan
gh auth status 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not authenticated. Run: gh auth login" -ForegroundColor Red
    exit 1
}

# Step 3: Delete pre-existing CLI releases (ask first)
Write-Host "`n=== Step 1/4: Removing old CLI releases ===" -ForegroundColor Cyan
$existing = gh release list --repo $Repo --json tagName,name,id 2>$null | ConvertFrom-Json
$cliReleases = $existing | Where-Object { $_.name -like "*CLI*" -or $_.name -like "*cli*" -or $_.tagName -like "*cli*" }
if ($cliReleases) {
    Write-Host "Found old CLI releases to remove:" -ForegroundColor Yellow
    $cliReleases | ForEach-Object { Write-Host "  - $($_.tagName) / $($_.name)" }
    $confirm = Read-Host "Delete these ${$cliReleases.Count} release(s)? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        foreach ($rel in $cliReleases) {
            Write-Host "  Deleting $($rel.tagName)..." -NoNewline
            gh release delete $rel.tagName --repo $Repo --yes 2>$null
            if ($LASTEXITCODE -eq 0) { Write-Host " ✅" -ForegroundColor Green }
            else { Write-Host " ❌ failed" -ForegroundColor Red }
            # Also delete the tag
            git push --delete origin $rel.tagName 2>$null
        }
    }
} else {
    Write-Host "No pre-existing CLI releases found." -ForegroundColor Green
}

# Step 4: Create new release
Write-Host "`n=== Step 2/4: Creating tag and release ===" -ForegroundColor Cyan
$tagName = if ($BuildNumber) { "build-$BuildNumber" } else { $Tag }
gh release create $tagName `
    --repo $Repo `
    --title "$ReleaseName" `
    --notes "$ReleaseBody" `
    --target main 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to create release" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Release created: $tagName" -ForegroundColor Green

# Step 5: Upload ZIP files
Write-Host "`n=== Step 3/4: Uploading ZIP files ===" -ForegroundColor Cyan
$zipDir = Split-Path -Parent $PSScriptRoot
foreach ($zip in @($SelfZip, $FdZip)) {
    $zipPath = Join-Path $zipDir $zip
    if (Test-Path $zipPath) {
        Write-Host "  Uploading $zip..." -NoNewline
        gh release upload $tagName "$zipPath" --repo $Repo --clobber 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host " ✅" -ForegroundColor Green }
        else { Write-Host " ❌" -ForegroundColor Red }
    } else {
        Write-Host "  ⚠️ $zip not found at $zipPath" -ForegroundColor Yellow
    }
}

# Step 6: Verify
Write-Host "`n=== Step 4/4: Verification ===" -ForegroundColor Cyan
gh release view $tagName --repo $Repo --json tagName,name,assets --jq '{tag: .tagName, name: .name, assets: [.assets[].name]}' | ConvertFrom-Json | Format-List

Write-Host "`n✅ Done! Release: https://github.com/$Repo/releases/tag/$tagName" -ForegroundColor Green
