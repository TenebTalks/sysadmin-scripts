## Authored by Scott Bennett
## Latency-Checker.ps1
## ONLY EDIT $TargetList

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
    $LatencyStats = ($LatencyResult | Measure-Object -Property Latency -Minimum -Maximum -Average)
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

$FileName = Create-LogFile -FileName "LatencyCheck"

$LogDate = Get-Date
Write-Output "Latency Check Log taken at $LogDate" | Out-File -FilePath $FileName -Append


#Latency-Check -Target 1.1.1.1 | Log-ToFile -FileName $FileName
#Latency-Check -Target heritagecrv.tx.3cx.us | Log-ToFile -FileName $FileName

$TargetList = @(
    '1.1.1.1', 'hulu.com', 'teams.microsoft.com'
)

foreach($Target in $TargetList) {
    Latency-Check -Target $Target | Out-File -FilePath $FileName -Append
}