## Authored by Scott Bennett
## Latency-Checker.ps1
## ONLY EDIT $TargetList

##Global Variables
#$LatencyCollection = @{}


##Function Definitions
##Latency  Check takes Target and Count - outputs raw result and stats
function Latency-Check {
    param (
        [Parameter(position = 0, mandatory = $true)] $Target,
        [Parameter(Position = 1)] $PacketCount
    )
    #Setting Default Packet Count = 12
    if($PacketCount -eq $null){ $PacketCount = 12 }


    $LatencyResult = Test-Connection -ComputerName $Target -Count $PacketCount
    $LatencyStats = ($LatencyResult | Measure-Object -Property Latency -Minimum -Maximum -Average -ErrorAction Continue)
    if ($LatencyStats -eq $null) {
        $LatencyStats = ($LatencyResult | Measure-Object -Property ResponseTime -Minimum -Maximum -Average -ErrorAction Stop)
    }
    Write-Output $LatencyResult
    Write-Output $LatencyStats
    
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


    $currTime = Get-Date -Hour -Minute -Second -Millisecond
    $DNSresolve = Resolve-DnsName -Name $Target -QuickTimeout -NoHostsFile -DnsOnly -ErrorAction SilentlyContinue
    return $DNSresolve, $currTime
    
    #return $DNSreslove
    #Write-Output $DNSresults
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
        $error = ""
    } else {
        $latency = "N/A"
        $packetLoss = "N/A"
        $success = $false
        $error = "Failed to resolve"
    }

    return [PSCustomObject]@{
        DNSServer = $DNSServer
        Domain = $Domain
        Success = $success
        Latency = $latency
        PacketLoss = $packetLoss
        Error = $error
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




$TargetList = @(
    '1.1.1.1', 'hulu.com', 'teams.microsoft.com', '', 'youtube.com'
)
$dnsServers = @(
    '1.1.1.1', '9.9.9.9', '8.8.8.8', '192.168.1.5'
)

foreach($Target in $TargetList) {
    Write-Output "Ping Latency and DNS Resolution from default DNS server for $Target [" | Out-File -FilePath $FileName -Append
    Latency-Check -Target $Target | Out-File -FilePath $FileName -Append
    DNS-NameResolve -Target $Target | Out-File -FilePath $FileName -Append
    Write-Output "]" | Out-File -FilePath $FileName -Append
}

foreach($server in $dnsServers) {
    Write-Output "DNS Benchmark for target list using $server [" | Out-File -FilePath $FileName -Append
    DNS-Benchmark -Server $server -Domains $TargetList | Out-File -FilePath $FileName -Append
    Write-Output "]" | Out-File -FilePath $FileName -Append
}