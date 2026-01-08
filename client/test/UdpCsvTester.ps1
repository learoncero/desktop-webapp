$sourcePort = 40000
$targetIp = "127.0.0.1"
$targetPort = 5000

$udp = New-Object System.Net.Sockets.UdpClient($sourcePort)
$endpoint = New-Object System.Net.IPEndPoint (
  [System.Net.IPAddress]::Parse($targetIp),
  $targetPort
)

while ($true) {
  $temperature = [Math]::Round((Get-Random -Minimum 180 -Maximum 280) / 10.0, 4)
  $humidity = [Math]::Round((Get-Random -Minimum 300 -Maximum 700) / 10.0, 4)
  $pressure = [Math]::Round((Get-Random -Minimum 9800 -Maximum 10200) / 10.0, 2)

  # CSV format: displayName1, displayUnit1, value1, displayName2, displayUnit2, value2, ...
  $csv = "Temperature, °C, $temperature, Humidity, %, $humidity, Pressure, hPa, $pressure"

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($csv)
  $udp.Send($bytes, $bytes.Length, $endpoint)

  Write-Host "Sent: $csv"
  Start-Sleep 1
}
