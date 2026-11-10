param([switch]$Playground, [switch]$Controller, [switch]$Swat, [switch]$Viewer, [switch]$Showcase, [string]$Godot = "")
$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
if (-not $Godot) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $Godot = $installed.Source }
}
if (-not $Godot) {
    $primaryLine = git -C $repoRoot worktree list --porcelain | Select-Object -First 1
    $primaryRoot = $primaryLine -replace '^worktree ', ''
    $binary = Get-ChildItem -LiteralPath (Join-Path $primaryRoot "build/tools/godot") -Filter '*_console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($binary) { $Godot = $binary.FullName }
}
if (-not $Godot) { throw "Pass -Godot with the path to Godot 4.7.2 console executable." }
$characterArgs = @()
if ($Swat) { $characterArgs += "--swat-units" }
if ($Playground) {
    & $Godot --path $repoRoot tests/mocap/playground.tscn -- --swat-units
} elseif ($Controller) {
    & $Godot --path $repoRoot tests/mocap/controller.tscn -- @characterArgs
} elseif ($Viewer) {
    & $Godot --path $repoRoot tests/mocap/viewer.tscn -- @characterArgs
} elseif ($Showcase) {
    & $Godot --path $repoRoot tests/mocap/skinned_demo.tscn -- --no-stun @characterArgs
} else {
    & $Godot --path $repoRoot -- --scenario=motion --seed=3 --skinned-units --motion-camera --no-stun --port=7988 --nohud --preset=high --set=ragdolls:true,dof:false,grass:1,effects:1,vol_fog:false,gi:false --perf=0 --mood=day --quit-after=28 @characterArgs
}
