$pgBackupDir = "Z:\postrges"
$pgBackupCopy = 2
$pgBackupLabel = (get-date -Format "yyyyMMdd")
$pgBackup = Join-Path $pgBackupDir $pgBackupLabel
$pgUser = "postgres"
$pgBackupProcess = "C:\Program Files\PostgreSQL\9.4\bin\pg_basebackup.exe"
$PgBackupErrorLog = "error.log"
$EventSource = "pg_basebackup"


function isOldBackup()
{
    $one = getCurrentBackups $pgBackupDir
    if ($one.count -ge $pgBackupCopy){
        return 1
    }
    return 0
}

# log erros to Windows Application Event Log
function Log([string] $message, [System.Diagnostics.EventLogEntryType] $type){
    # create EventLog source
    if (![System.Diagnostics.EventLog]::SourceExists($EventSource)){
        New-Eventlog -LogName 'Application' -Source $EventSource;
    }
# write to EventLog
    Write-EventLog -LogName 'Application'`
        -Source $EventSource -EventId 1 -EntryType $type -Message $message;
}


function getDiskSpace ([string] $backupRoot)
{

     # calculate last backup size
     $lastBackup = Get-ChildItem $backupRoot | sort Name -desc | select -f 1;
     $lastBackupDir = Join-Path $backupRoot $lastBackup;
     $lastBackupSize = Get-ChildItem $lastBackupDir
     $last = $lastBackupSize.length

     Write-Host "Last Backup Size: $last"
  
    $firstBackup = Get-ChildItem $backupRoot | sort Name | select -f 1;
    $firstBackupDir = Join-Path $backupRoot $firstBackup;
    $firstBackupSize = Get-ChildItem $firstBackupDir
    $first = $firstBackupSize.length

    $deltas = $last - $first
    $predictionsize = $last + $deltas
    Write-Host "First Backup Size: $first"
    Write-Host "Deltas is: $deltas"
    Write-Host "Prediction is: $predictionsize"


    $currentDrive = Split-Path -qualifier $backupRoot
    $drive = Get-PSDrive -Name $currentDrive[0]
    $free = $drive.free
  
    $rm = isOldBackup;
    Write-Host "Need to remove? - $rm"

    if ($rm -ne 0){
        $available = $free+$first
    
    }else{

        $available = $free
    }
 
    Write-Host "available $available"

    if ($predictionsize -gt $available)
    {
        return 0
    }
    return 1
}

function getCurrentBackups ([string] $backupRoot)
{

    $bklist = $null
    $bklist = @{}
    $backups = Get-ChildItem $pgBackupDir -name
    foreach ($item in $backups)
    {
        $itemPath =  Join-Path $pgBackupDir $item
        $bk = Get-ChildItem $itemPath
        $bklist.add($item, $bk.length)
    }

    return $bklist
}


function  rmFirstBackup ([string] $backupRoot)
{
     $firstBackup = Get-ChildItem $backupRoot | sort Name  | select -f 1;
     $firstBackupDir = Join-Path $backupRoot $firstBackup;
     Remove-Item $firstBackupDir -Force -Recurse
}

# Searching backups to remove
$rmFst = isOldBackup
$isSpace = getDiskSpace $pgBackupDir
Write-Host $isSpace

if ($isSpace -gt 0) {
    Write-Host "Creating Backup"

    try {
        Write-Host ("Do we need to remove? $rmFst")
        if ($rmFst -gt 0) {
            rmFirstBackup $backupRoot
        }

        Start-Process $pgBackupProcess -ArgumentList "-D $pgBackup", "-Ft", "-z", "-x", "-R",
        "-U $pgUser", "-w"`
        -Wait -NoNewWindow -RedirectStandardError $PgBackupErrorLog;
    
    }
    catch {
        Write-Error $_.Exception.Message;
        Log $_.Exception.Message Error;
        Exit 1;
    }

}
else {
    Write-Host "Backup error"
}