param([string]$Name)
$root='C:\Users\catur\.codex\visualizations\2026\09\11\01a08fc7-0cf1-7772-a384-020417c19593\audit_replay_threshold_station_20260918\Documents'
$path=Join-Path $root ($Name+'.docx')
$pdf=Join-Path $root ($Name+'.pdf')
$word=New-Object -ComObject Word.Application
$word.Visible=$false
$word.DisplayAlerts=0
try {
 $doc=$word.Documents.Open($path,$false,$true)
 $doc.ExportAsFixedFormat($pdf,17)
 $doc.Close(0)
 Write-Output ('EXPORTED '+$pdf)
} finally {try {$word.Quit()} catch {Write-Output $_.Exception.Message}}
