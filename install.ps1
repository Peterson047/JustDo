<#
.SYNOPSIS
  Installs (or removes) the JustDo! directive and skill across supported tools.

.DESCRIPTION
  Works on Windows PowerShell 5.1 and PowerShell 7+.
  Never overwrites existing configs:
  - Instructions: injects a marker-delimited block and refreshes it on each run.
  - Skills: copies SKILL.md into the skills folder of detected tools.

.PARAMETER Update
  Install or refresh (default).

.PARAMETER Remove
  Remove what this script installed.

.PARAMETER NoSkill
  Handle only the global instructions; skip the skills section.

.EXAMPLE
  .\install.ps1

.EXAMPLE
  .\install.ps1 -Remove

.EXAMPLE
  .\install.ps1 -NoSkill
#>
[CmdletBinding()]
param(
    [switch]$Update,
    [switch]$Remove,
    [switch]$NoSkill
)

$ErrorActionPreference = 'Stop'

$RootDir   = $PSScriptRoot
$SrcAgents = Join-Path $RootDir 'AGENTS.md'
$SrcSkill  = Join-Path $RootDir 'SKILL.md'
$Start     = '<!-- just-do:start -->'
$End       = '<!-- just-do:end -->'
$Utf8      = New-Object System.Text.UTF8Encoding($false)   # UTF-8 without BOM

function Get-HomePath([string]$Relative) {
    [IO.Path]::GetFullPath((Join-Path $HOME $Relative))
}

# 1. Global instructions (marker-delimited block injection)
$InstructionTargets = @(
    (Get-HomePath '.codex/AGENTS.md')
    (Get-HomePath '.claude/CLAUDE.md')
    (Get-HomePath '.gemini/GEMINI.md')
)

# 2. Global skills (copies SKILL.md into Dir)
# Base = tool folder that must already exist; Dir = skill folder created inside it
$SkillTargets = @(
    @{ Base = (Get-HomePath '.claude');                 Dir = (Get-HomePath '.claude/skills/just-do') }
    @{ Base = (Get-HomePath '.gemini/antigravity-cli'); Dir = (Get-HomePath '.gemini/antigravity-cli/skills/just-do') }
    @{ Base = (Get-HomePath '.agents');                 Dir = (Get-HomePath '.agents/skills/just-do') }
    # Unverified path: uncomment after checking the Codex docs.
    # @{ Base = (Get-HomePath '.codex');                Dir = (Get-HomePath '.codex/skills/just-do') }
)

# --- Helpers -----------------------------------------------------------------
function Read-Text([string]$Path) { [IO.File]::ReadAllText($Path, $Utf8) }

function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllText($Path, $Text, $Utf8) }

# True when the file exists and contains the literal marker
function Test-Marker([string]$Path, [string]$Marker) {
    (Test-Path -LiteralPath $Path -PathType Leaf) -and (Read-Text $Path).Contains($Marker)
}

function Write-Status([string]$Label, [string]$Message) {
    Write-Host ('{0,-8}{1}' -f $Label, $Message)
}

# True when a link (symlink/junction) points to this repo folder
function Test-PointsToSource($Item) {
    $prop = $Item.PSObject.Properties['Target']
    if (-not $prop -or -not $prop.Value) { return $false }
    foreach ($t in @($prop.Value)) {
        $full = [IO.Path]::GetFullPath($t).TrimEnd('\', '/')
        if ($full -eq $RootDir.TrimEnd('\', '/')) { return $true }
    }
    return $false
}

# --- Arguments ---------------------------------------------------------------
if ($Update -and $Remove) { throw 'Use only one of -Update or -Remove.' }
$Action = if ($Remove) { 'remove' } elseif ($Update) { 'update' } else { '' }
$InstallSkill = -not $NoSkill

# --- Detect an existing installation -------------------------------------------
$isInstalled = $false
foreach ($f in $InstructionTargets) {
    if (Test-Marker $f $Start) { $isInstalled = $true; break }
}
if (-not $isInstalled -and $InstallSkill) {
    foreach ($t in $SkillTargets) {
        if (Test-Path -LiteralPath (Join-Path $t.Dir 'SKILL.md') -PathType Leaf) { $isInstalled = $true; break }
    }
}

# Interactive wizard if already installed and no action was given
if ($isInstalled -and -not $Action -and -not [Console]::IsInputRedirected) {
    Write-Host 'JustDo! is already installed in one or more tools.'
    Write-Host ''
    Write-Host 'What would you like to do?'
    Write-Host '  1) Update / Reinstall'
    Write-Host '  2) Remove / Uninstall'
    Write-Host '  3) Cancel'
    Write-Host ''
    switch (Read-Host 'Select an option [1-3]') {
        '1'     { $Action = 'update' }
        '2'     { $Action = 'remove' }
        default { Write-Host 'Canceled.'; exit 0 }
    }
}
if (-not $Action) { $Action = 'update' }

# --- Validate sources before touching anything --------------------------------
if ($Action -eq 'update') {
    if (-not (Test-Path -LiteralPath $SrcAgents -PathType Leaf)) { throw "error: $SrcAgents not found" }
    if ($InstallSkill -and -not (Test-Path -LiteralPath $SrcSkill -PathType Leaf)) { throw "error: $SrcSkill not found" }
}

# --- 1. Global instructions ----------------------------------------------------
Write-Host '==> Global instructions'
foreach ($f in $InstructionTargets) {
    if (-not (Test-Path -LiteralPath (Split-Path $f -Parent) -PathType Container)) {
        Write-Status 'skip' "$f (tool not found)"
        continue
    }

    $text = if (Test-Path -LiteralPath $f -PathType Leaf) { Read-Text $f } else { '' }
    $hasStart = $text.Contains($Start)
    $hasEnd   = $text.Contains($End)
    $hadBlock = $false

    if ($hasStart -or $hasEnd) {
        $pattern  = '(?s)' + [regex]::Escape($Start) + '.*?' + [regex]::Escape($End) + '(\r?\n)?'
        $stripped = [regex]::Replace($text, $pattern, '')
        # A lone (or reversed) marker is never touched automatically
        if (-not ($hasStart -and $hasEnd) -or $stripped -eq $text) {
            Write-Status 'warn' "$f (orphan marker found; fix manually)"
            continue
        }
        $hadBlock = $true
        $text = $stripped
    }

    if ($Action -eq 'remove') {
        if (-not $hadBlock) { Write-Status 'none' $f; continue }
        # If the file is now empty or only whitespace, delete it completely
        if ($text.Trim().Length -eq 0) {
            Remove-Item -LiteralPath $f -Force
            Write-Status 'deleted' $f
        } else {
            Write-Text $f $text
            Write-Status 'removed' "block from $f"
        }
        continue
    }

    # Keep the file's own line endings; make sure it ends with a newline before appending
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    if ($text.Length -gt 0 -and -not $text.EndsWith("`n", [StringComparison]::Ordinal)) { $text += $nl }
    $body = ([regex]::Replace((Read-Text $SrcAgents), '\r?\n', $nl)).TrimEnd([char[]]@(13, 10))
    $text += $Start + $nl + $body + $nl + $End + $nl
    Write-Text $f $text
    Write-Status 'ok' $f
}

# --- 2. Global skills ------------------------------------------------------------
if ($InstallSkill) {
    Write-Host ''
    Write-Host '==> Global skills'
    foreach ($t in $SkillTargets) {
        $dir        = $t.Dir
        $targetFile = Join-Path $dir 'SKILL.md'

        if (-not (Test-Path -LiteralPath $t.Base -PathType Container)) {
            Write-Status 'skip' "$targetFile (tool not found)"
            continue
        }

        $item   = Get-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
        $isLink = $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)

        if ($Action -eq 'remove') {
            if ($item) {
                # Delete a link without following it, so the target is never touched
                if ($isLink) { [IO.Directory]::Delete($dir) }
                else { Remove-Item -LiteralPath $dir -Recurse -Force }
                Write-Status 'deleted' $dir
            } else {
                Write-Status 'none' $dir
            }
            continue
        }

        # Skip when the folder is a link back to this repo
        if ($isLink -and (Test-PointsToSource $item)) {
            Write-Status 'same' "$targetFile (already points to the source)"
            continue
        }

        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Copy-Item -LiteralPath $SrcSkill -Destination $targetFile -Force
        Write-Status 'ok' $targetFile
    }
}