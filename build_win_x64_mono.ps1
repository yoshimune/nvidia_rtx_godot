<#
.SYNOPSIS
    Godot 4 .NET (C#) Build Script for Windows (x64)
.DESCRIPTION
    Godot リポジトリルートで実行し、エディタ本体、Mono Glue、マネージドアセンブリを順次ビルドします。
#>

[CmdletBinding()]
param (
    [int]$Threads = [System.Environment]::ProcessorCount
)

$ErrorActionPreference = "Stop"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Godot 4 .NET (C#) Build Script for Windows (x64)  " -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. 実行パスの確認（SConstruct の存在チェック）
if (-not (Test-Path "SConstruct")) {
    Write-Error "[ERROR] SConstruct が見つかりません。Godot のリポジトリルートで実行してください。"
    exit 1
}

Write-Host "[INFO] 使用スレッド数: $Threads" -ForegroundColor Gray
Write-Host ""

# 外部コマンド実行と終了コードのチェック用関数
function Invoke-BuildStep {
    param (
        [string]$StepTitle,
        [scriptblock]$Command
    )
    Write-Host $StepTitle -ForegroundColor Yellow
    & $Command
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[FAIL] $StepTitle に失敗しました (Exit Code: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    Write-Host "[SUCCESS] 完了`n" -ForegroundColor Green
}

# ----------------------------------------------------
# ステップ 1: エディタ本体のコンパイル
# ----------------------------------------------------
Invoke-BuildStep -StepTitle "[STEP 1/3] Compiling Godot Editor with .NET module..." -Command {
    scons platform=windows arch=x86_64 target=editor module_mono_enabled=yes -j $Threads
}

# ----------------------------------------------------
# 実行ファイルパスの確認
# ----------------------------------------------------
$GodotBin = "bin\godot.windows.editor.x86_64.mono.exe"
if (-not (Test-Path $GodotBin)) {
    Write-Error "[ERROR] 生成されたエディタバイナリが見つかりません: $GodotBin"
    exit 1
}

# ----------------------------------------------------
# ステップ 2: C++/C# Glueコードの生成
# ----------------------------------------------------
Invoke-BuildStep -StepTitle "[STEP 2/3] Generating Mono Glue..." -Command {
    & ".\$GodotBin" --headless --generate-mono-glue modules/mono/glue
}

# ----------------------------------------------------
# ステップ 3: マネージドアセンブリ (.NETライブラリ) のビルド
# ----------------------------------------------------
Invoke-BuildStep -StepTitle "[STEP 3/3] Building Managed Assemblies..." -Command {
    python modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --godot-platform=windows
}

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " All build steps completed successfully!" -ForegroundColor Green
Write-Host " Binary location: $((Get-Item $GodotBin).FullName)" -ForegroundColor White
Write-Host "===================================================" -ForegroundColor Cyan