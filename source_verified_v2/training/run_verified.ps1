param(
 [ValidateSet('Plan','Validate','TrainMain','TrainStrengthening','Summarize')][string]$Action='Plan',
 [string]$SourceRoot='D:\STEAD_identity_recovery\prepared_source_v2',
 [string]$ResultsRoot='D:\ICNN_source_verified_results\v2',
 [string]$Matlab='C:\Program Files\MATLAB\R2024a\bin\matlab.exe',
 [ValidateSet('gpu','cpu')][string]$Device='gpu'
)
$ErrorActionPreference='Stop'
function Q([string]$Value){return "'"+$Value.Replace("'","''")+"'"}
$source=Q $SourceRoot
$main=Join-Path $ResultsRoot 'submission40'
$strength=Join-Path $ResultsRoot 'strengthening'
if($Action -eq 'Plan'){
 Write-Output 'Source-verified v2: 2234 records, 1477 sources. Split: 1544 train / 360 validation / 330 test.'
 Write-Output 'Five frozen source-disjoint OOF folds, shared across modes and seeds.'
 Write-Output 'TrainMain: 40 fits. TrainStrengthening: 60 additional fits + 6 PhaseNet-style fits.'
 Write-Output 'No training starts with Plan or Validate. Run TrainMain before TrainStrengthening.'
 return
}
if($Action -eq 'TrainStrengthening'){
 & (Join-Path $PSScriptRoot 'strengthening\run_strengthening.ps1') -Action Train -SourceRoot $SourceRoot -ResultsRoot $strength -BaseResultsRoot $main -Matlab $Matlab -Device $Device
 return
}
New-Item -ItemType Directory -Force -Path $ResultsRoot | Out-Null
switch($Action){
 'Validate' {$expression="addpath($(Q $PSScriptRoot)); validate_source_protocol($source,$(Q (Join-Path $ResultsRoot 'validation')));"}
 'TrainMain' {$expression="addpath($(Q (Join-Path $PSScriptRoot 'submission'))); run_submission40('train',$source,$(Q $main),'$Device');"}
 'Summarize' {$expression="addpath($(Q (Join-Path $PSScriptRoot 'strengthening'))); summarize_strengthening($(Q $strength),$(Q $main),$source);"}
}
& $Matlab '-batch' $expression '-logfile' (Join-Path $ResultsRoot ($Action+'.log'))
if($LASTEXITCODE -ne 0){throw "MATLAB failed ($LASTEXITCODE); inspect the log. No later stage was started."}
