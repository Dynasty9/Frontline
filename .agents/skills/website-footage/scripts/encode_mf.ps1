# Encode an AVI as H.264 MP4 (AAC sound if AudioKbps > 0) with Windows Media Foundation, for machines
# without ffmpeg. Runs in Windows PowerShell 5.1 (powershell.exe), which can still call WinRT. build.py
# calls it, then moves the moov box to the front (Media Foundation writes it last).
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File encode_mf.ps1 IN OUTDIR OUTNAME W H KBPS FPS AUDIOKBPS
param([string]$In, [string]$OutDir, [string]$OutName, [int]$W = 1280, [int]$H = 720, [int]$Kbps = 1800, [int]$Fps = 30, [int]$AudioKbps = 0)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$methods = [System.WindowsRuntimeSystemExtensions].GetMethods()
$asTaskOp = ($methods | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskActProg = ($methods | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' })[0]
function Await($op, [Type]$t) {
    $task = $asTaskOp.MakeGenericMethod($t).Invoke($null, @($op))
    try { $task.Wait(-1) | Out-Null } catch { Write-Output "FAILED $t : $($task.Exception.InnerException.Message)"; exit 1 }
    $task.Result
}
[void][Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
[void][Windows.Media.Transcoding.MediaTranscoder, Windows.Media.Transcoding, ContentType = WindowsRuntime]
[void][Windows.Media.MediaProperties.MediaEncodingProfile, Windows.Media.MediaProperties, ContentType = WindowsRuntime]
$src = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path $In).Path)) ([Windows.Storage.StorageFile])
$folder = Await ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync((Resolve-Path $OutDir).Path)) ([Windows.Storage.StorageFolder])
$dst = Await ($folder.CreateFileAsync($OutName, [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
$p = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateMp4([Windows.Media.MediaProperties.VideoEncodingQuality]::HD720p)
$p.Video.Width = $W; $p.Video.Height = $H
$p.Video.Bitrate = $Kbps * 1000
$p.Video.FrameRate.Numerator = $Fps; $p.Video.FrameRate.Denominator = 1
$p.Video.ProfileId = [Windows.Media.MediaProperties.H264ProfileIds]::High
if ($AudioKbps -gt 0) { $p.Audio = [Windows.Media.MediaProperties.AudioEncodingProperties]::CreateAac(48000, 2, $AudioKbps * 1000) } else { $p.Audio = $null }
$tr = New-Object Windows.Media.Transcoding.MediaTranscoder
$tr.HardwareAccelerationEnabled = ($env:MF_HW -ne '0')
$prep = Await ($tr.PrepareFileTranscodeAsync($src, $dst, $p)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
if (-not $prep.CanTranscode) { Write-Output "cannot transcode: $($prep.FailureReason)"; exit 1 }
$task = $asTaskActProg.MakeGenericMethod([double]).Invoke($null, @($prep.TranscodeAsync()))
try { $task.Wait(-1) | Out-Null } catch { Write-Output "FAILED transcoding: $($task.Exception.InnerException.Message)"; exit 1 }
Write-Output "ok $((Get-Item (Join-Path $OutDir $OutName)).Length) bytes"
