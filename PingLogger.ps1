#Script to Log dropped pings

New-Item -Path "C:\" -Name "Datavizion" -ItemType "Directory"
Start-Transcript 'C:\Datavizion\ping_results.txt' #Create and begin logging to a results.txt
ping -t teams.microsoft.com | Foreach{"{0} - {1}" -f (Get-Date -f "yyyyMMdd HH:mm:ss"),$_}  #Ping a host continuously and log them all with a timestamp
Stop-Transcript #Stop transcription