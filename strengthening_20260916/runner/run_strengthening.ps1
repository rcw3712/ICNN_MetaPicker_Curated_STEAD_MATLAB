param(
 [ValidateSet('Plan','Smoke','Train','Summarize')][string]$Action='Plan',
 [string]$SourceRoot='C:\Drive E\ICNN_MetaPicker_Curated_STEAD_MATLAB',
 [string]$ResultsRoot='C:\Drive E\ICNN_strengthening_results\v1',
 [string]$Matlab='C:\Program Files\MATLAB\R2024a\bin\matlab.exe',
 [ValidateSet('gpu','cpu')][string]$Device='gpu'
)
$ErrorActionPreference='Stop'
function Quote-Matlab([string]$Value) { return "'" + $Value.Replace("'", "''") + "'" }
$package=Quote-Matlab $PSScriptRoot
$source=Quote-Matlab $SourceRoot
function Invoke-Matlab([string]$Expression,[string]$LogName) {
 New-Item -ItemType Directory -Force -Path $ResultsRoot | Out-Null
 $log=Join-Path $ResultsRoot $LogName
 & $Matlab '-batch' "addpath($package); $Expression" '-logfile' $log
 if ($LASTEXITCODE -ne 0) { throw "MATLAB failed (exit $LASTEXITCODE). Stopped; see $log" }
}
if ($Action -eq 'Plan') {
 Write-Output '60 additional fits: bases 43/44 x Full3C/Zonly x (10 OOF + 2 final bases + meta 42/43/44).'
 Write-Output '6 baseline fits: PhaseNet-style MATLAB adaptation x Full3C/Zonly x seeds 42/43/44.'
 Write-Output 'Fixed outer/OOF/inner splits and augmentation seeds. No additional source splits. No ablation reruns.'
 return
}
if ($Action -eq 'Smoke') { Invoke-Matlab "smoke_strengthening('$Device');" 'smoke.log'; return }
if ($Action -eq 'Summarize') { Invoke-Matlab "summarize_strengthening($(Quote-Matlab $ResultsRoot));" 'summary.log'; return }
foreach ($baseSeed in @(43,44)) {
 foreach ($mode in @('Full3C','Zonly')) {
  $run=Quote-Matlab (Join-Path $ResultsRoot "base_$baseSeed\$mode")
  Invoke-Matlab "run_seed_repeat('train',$source,$run,'$Device',$baseSeed,'$mode');" "base_${baseSeed}_${mode}.log"
 }
}
foreach ($mode in @('Full3C','Zonly')) {
 foreach ($seed in @(42,43,44)) {
  $run=Quote-Matlab (Join-Path $ResultsRoot "phasenet\$mode\seed_$seed")
  Invoke-Matlab "run_phasenet_matched($source,$run,'$mode',$seed,'$Device');" "phasenet_${mode}_${seed}.log"
 }
}
Invoke-Matlab "summarize_strengthening($(Quote-Matlab $ResultsRoot));" 'summary.log'
