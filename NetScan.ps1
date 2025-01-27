$range = 1..254
#Read-Host for Subnet?


$range | ForEach-Object {

  $address = “192.168.1.$_”

  Write-Progress “Scanning Network” $address -PercentComplete (($_/$range.Count)*100)

  New-Object PSObject -Property @{

    Address = $address

    Ping = Test-Connection $address -Quiet -Count 2

  }

} | Out-File D:\Tech\IpscanResult.csv