param(
  [Parameter(Mandatory = $true)][string]$Manifest
)

# Reads a JSON list of { out, voice, rate, ssml } and writes one 16 kHz mono 16-bit WAV per entry.
Add-Type -AssemblyName System.Speech
$items = Get-Content -Raw -Path $Manifest | ConvertFrom-Json
$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
foreach ($item in $items) {
  $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $synth.SelectVoice($item.voice)
  $synth.Rate = [int]$item.rate
  $synth.SetOutputToWaveFile($item.out, $format)
  $synth.SpeakSsml($item.ssml)
  $synth.Dispose()
}
