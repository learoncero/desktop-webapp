$sourcePort = 40000
$targetIp = "127.0.0.1"
$targetPort = 5000

$udp = New-Object System.Net.Sockets.UdpClient($sourcePort)
$endpoint = New-Object System.Net.IPEndPoint (
  [System.Net.IPAddress]::Parse($targetIp),
  $targetPort
)

while ($true) {
  $value = Get-Random -Minimum 0 -Maximum 11

  # Build structured payload
  $payload = @{
    payload = @(
      @{
        displayName = "Random"
        displayUnit = "Dec"
        data        = $value
      }
    )
  }

  # Convert to compact JSON
  $json = $payload | ConvertTo-Json -Depth 4 -Compress

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $udp.Send($bytes, $bytes.Length, $endpoint)

  Start-Sleep 1
}