## Authored by Scott Bennett
## Latency-Checker.ps1
## Use -TargetListCSV parameter with path to a csv file containing only legal IP addresses and DNS addresses as strings when running
## Use -DNSServerCSV arameter with path to a csv file containing only legal IP addresses as strings when running


param(
    [String]$TargetListCSV,
    [String]$DNSServerCSV
)

##Global Variable Handling
$TargetList = @()

if ($TargetListCSV) {
    $TargetList = Get-Content -Path $TargetListCSV
    
    #$TargetList ##ForDebug
} else {
    $gateways = (Get-NetRoute "0.0.0.0/0").NextHop

    $TargetList = @(
        '1.1.1.1', 'hulu.com', 'teams.microsoft.com', 'youtube.com', 'outlook.office.com'
    )

    $TargetList += $gateways
}
#Write-Host "Target List: $TargetList"

$dnsServers = @()
if ($DNSServerCSV) {
    $dnsServers = Get-Content -Path $DNSServerCSV
    $dnsServers
} else {
    $LocalDNSservers = Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses

    $defaultDNSservers = @(
        '1.1.1.1', '9.9.9.9', '8.8.8.8'
    )

    $dnsServers = $LocalDNSservers + $defaultDNSservers
}
#Write-Host "DNS Server List: $dnsServers"

##Function Definitions
##Latency  Check takes Target and Count - outputs raw result and stats
function Latency-Check {
    param (
        [Parameter(position = 0, mandatory = $true)] $Target,
        [Parameter(Position = 1)] $PacketCount
    )
    #Setting Default Packet Count = 12
    if($PacketCount -eq $null){ $PacketCount = 12 }
    
    $StartTime = Get-Date


    $LatencyResult = Test-Connection -ComputerName $Target -Count $PacketCount
    if ($LatencyResult.Latency -ne $null) {
        $LatencyStats = ($LatencyResult | Measure-Object -Property Latency -Minimum -Maximum -Average -ErrorAction SilentlyContinue)    
    } elseif ($LatencyResult.ResponseTime -ne $null) {    
        $LatencyStats = ($LatencyResult | Measure-Object -Property ResponseTime -Minimum -Maximum -Average -ErrorAction SilentlyContinue)
    } else {
        $LatencyProps = ($LatencyResult | Get-Member)
        return "Due to disparate behavior across different powershell versions, Latency Stats cannot be collected at this time.  Please try running this script from the latest version of PWSH7 (latency) OR if that is not possible, run from the latest version of Powershell 5 (ResponseTime).  Your version gives these properties:", $LatencyProps
    }
    
    $EndTime = Get-Date

    return "ICMP Latency Start Time:", $StartTime, $LatencyResult, $LatencyStats, "ICMP Latency End Time:", $EndTime
    
}

#These two simplify the logging process (can use anywhere)
function Create-LogFile {
    param (
        [Parameter(Position = 0, mandatory = $true)] $FileName,
        [Parameter(Position = 1)] $FileExtension
    )
    #Set Default Extension to .log
    if($FileExtension -eq $null){ $FileExtension = ".log"}

    $FileDate = Get-Date -Format "MM-dd-yyyy-HH-mm"
    $LogFile = $FileName + $FileDate + ".log"
    Out-File -FilePath $LogFile
    Write-Output $LogFile
}

function Log-ToFile {
    param (
        [Parameter(ValueFromPipeline, Position = 0, mandatory = $true)] $LogObj,
        [Parameter(Position = 1, mandatory = $true)] $FileName
    )

    $LogObj | Out-File -FilePath $FileName -Append
}


function DNS-NameResolve {
    param (
        [Parameter(position = 0, mandatory = $true)] [String]$Target
        #[Parameter(Position = 1)] [int]$Count
    )


    $currTime = Get-Date
    $DNSresolve = Resolve-DnsName -Name $Target -QuickTimeout -NoHostsFile -DnsOnly -ErrorAction SilentlyContinue
    $endTime = Get-Date
    $timeDiff = $endTime - $currTime
    return "DNS Resolution Start Time: ", $currTime, $DNSresolve, "DNS Resolution End Time: ", $endTime, "Time Difference (ms): ", $timeDiff.TotalMilliseconds
    
}


function Test-Dns {
    #FROM https://github.com/DGAcode/DNS-Benchmark/
    param ($DNSServer, $Domain)

    $startTime = Get-Date
    $response = Resolve-DnsName -Server $DNSServer -Name $Domain -ErrorAction SilentlyContinue
    $endTime = Get-Date

    if ($response) {
        $latency = ($endTime - $startTime).TotalMilliseconds
        $packetLoss = 0
        $success = $true
        $DNSerror = ""
    } else {
        $latency = "N/A"
        $packetLoss = "N/A"
        $success = $false
        $DNSerror = "Failed to resolve"
    }

    return [PSCustomObject]@{
        DNSServer = $DNSServer
        Domain = $Domain
        Success = $success
        Latency = $latency
        PacketLoss = $packetLoss
        Error = $DNSerror
    }
}

function DNS-Benchmark {
    param ($Server, $Domains)
    $results = @()
    foreach ($domain in $Domains) {
        $testResult = Test-Dns -DNSServer $server -Domain $domain
        $results += $testResult
    }
    return $results
}

$FileName = Create-LogFile -FileName "LatencyCheck"

$LogDate = Get-Date
Write-Output "Latency Check Log taken at $LogDate" | Out-File -FilePath $FileName -Append






foreach($Target in $TargetList) {
    Write-Output "Ping Latency and DNS Resolution from default DNS server for $Target [[" | Out-File -FilePath $FileName -Append
    Latency-Check -Target $Target | Out-File -FilePath $FileName -Append
    DNS-NameResolve -Target $Target | Out-File -FilePath $FileName -Append
    Write-Output "]]" | Out-File -FilePath $FileName -Append
}

foreach($server in $dnsServers) {
    Write-Output "DNS Benchmark for target list using $server [[" | Out-File -FilePath $FileName -Append
    DNS-Benchmark -Server $server -Domains $TargetList | Out-File -FilePath $FileName -Append
    Write-Output "]]" | Out-File -FilePath $FileName -Append
}