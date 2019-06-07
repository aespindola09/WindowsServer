#create 02/2019 v1

<#
.SYNOPSIS
    Script que crea reporte DFSR
.DESCRIPTION
    Script que crea reporte DFSR
.EXAMPLE
    PS C:\>./report-dfs.ps1
    Explanation of what the example does

    Recuerde bajar al final (línea 202) y agregue su servidor de correo, etc.
    $EmailRecipients =  #"email@scania.com","email2@scania.com"
    $EmailFrom = "server01@example.com"
    $EmailSMTPServer = 'mail.scania.com'

    Recuerde habilitar envio de mail (linea 58) si es que lo requiere

.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (C:\DFSReports)

    Ejemplo:

    0 updates in backlog DC2->DC1 for Domain System Volume
0 updates in backlog DC1->DC2 for Domain System Volume
0 updates in backlog DC2->DC1 for ReplicacionDeptos
0 updates in backlog DC1->DC2 for ReplicacionDeptos
4 successful, 0 warnings and 0 errors from 4 replications.

Updates can be new, modified, or deleted files and folders. Any files or folders
listed in the DFS Replication backlog have not yet replicated from the source
computer to the destination computer. This is not necessarily an indication of
problems.
A backlog indicates latency, and a backlog may be expected in your environment,
depending on configuration, rate of change, network, and other factors.

File System Free Space on DC1 (09/24/2018 16:16:34) 
---------------------------------------------------------------------------------------------
Root Free (GB) Used (GB) Description
---- --------- --------- -----------
C:\  113,1     13,4                 
D:\  0,0       0,0  

.NOTES
    Se debe ejecutar en Servidor DFS
#>
$RGroups = Get-WmiObject  -Namespace "root\MicrosoftDFS" -Query "SELECT * FROM DfsrReplicationGroupConfig"
$ComputerName=$env:ComputerName
$Succ=0
$Warn=0
$Err=0
$ErrInfo=0
$ErrText=''
$EmailHint = ''
#Backlog archivos cuentan advertencia

$EmailNotification = 1  #enable (1) or disable (0) notoficacion por Email
$ExportReporttoFile = 1 #enable (1) or disable (0) guardar archivo
$ExportReporFolder = 'C:\DFSReports' #Export Path 
$Last7days = (Get-Date).AddDays(-7) #la semana pasada, para los informes semanales del registro de eventos

$EmailText ="---------------------------------------------------------------------------------------------`r`nInforme DFSR $(get-date -format 'dd-MMMM-yyyy HH:mm')"
$EmailText +="`r`n---------------------------------------------------------------------------------------------`r`n"

Write-Host $EmailText
 
foreach ($Group in $RGroups)
{
    $RGFoldersWMIQ = "SELECT * FROM DfsrReplicatedFolderConfig WHERE ReplicationGroupGUID='" + $Group.ReplicationGroupGUID + "'"
    $RGFolders = Get-WmiObject -Namespace "root\MicrosoftDFS" -Query  $RGFoldersWMIQ
    $RGConnectionsWMIQ = "SELECT * FROM DfsrConnectionConfig WHERE ReplicationGroupGUID='"+ $Group.ReplicationGroupGUID + "'"
    $RGConnections = Get-WmiObject -Namespace "root\MicrosoftDFS" -Query  $RGConnectionsWMIQ
    foreach ($Connection in $RGConnections)
    {
        $ConnectionName = $Connection.PartnerName#.Trim()
        if ($Connection.Enabled -eq $True)
        {           
                foreach ($Folder in $RGFolders)
                {
                    $RGName = $Group.ReplicationGroupName
                    $RFName = $Folder.ReplicatedFolderName
 
                    if ($Connection.Inbound -eq $True)
                    {
                        $SendingMember = $ConnectionName
                        $ReceivingMember = $ComputerName
                        $Direction="inbound"
                    }
                    else
                    {
                        $SendingMember = $ComputerName
                        $ReceivingMember = $ConnectionName
                        $Direction="outbound"
                    }
 
                    $BLCommand = "dfsrdiag Backlog /RGName:'" + $RGName + "' /RFName:'" + $RFName + "' /SendingMember:" + $SendingMember + " /ReceivingMember:" + $ReceivingMember
                    $Backlog = Invoke-Expression -Command $BLCommand
                    
                    #Hint Command example at the end of Email message
                    $EmailHint += "`r`ndfsrdiag Backlog /RGName:$RGName /RFName:$RFName /SendingMember:$SendingMember /ReceivingMember:$ReceivingMember"
 
                    $BackLogFilecount = 0
                    foreach ($item in $Backlog)
                    {
                        
                        if (($item -ilike "[ERROR]*") -and ($item -inotlike "*Operation Succeeded*")  )
                        {
                        $BacklogFileCount = "[ERROR]"
                        $Color="red"
                        $ErrInfo=1
                        $ErrText+= "$item `r`n" 
                        $Err++
                        }                                            
                        elseif ($item -ilike "*No Backlog*")
                        {
                        $BacklogFileCount = 0
                        $Color="white"
                        $Succ++
                        }
                        elseif ($item -ilike "*Backlog File count*")
                        {
                            $BacklogFileCount = [int]$Item.Split(":")[1].Trim()
                            if ($BacklogFileCount -lt 5)
                            {
                            $Color="white"
                            $Succ++
                            }
                            elseif ($BacklogFilecount -le 100)
                            {
                            $Color="yellow"
                            $Warn++
                            }
                            elseif ($BacklogFilecount -gt 100)
                            {
                            $Color="red"
                            $Err++
                            }
                        }
                    } 
                    
                    Write-Host "$BacklogFileCount updates in backlog $SendingMember->$ReceivingMember for $RGName" -ForegroundColor $Color 
                    $EmailText += "$BacklogFileCount updates in backlog $SendingMember->$ReceivingMember for $RGName"
                    $EmailText += "`r`n"

 
                } # Closing iterate through all folders
            #} # Closing  If replies to ping
        } # Closing  If Connection enabled
    } # Closing iteration through all connections
} # Closing iteration through all groups

$ReplicationState = Invoke-Expression "dfsrdiag replicationstate -v"

Write-Host "$Succ successful, $Warn warnings and $Err errors from $($Succ+$Warn+$Err) replications.`n"
Write-Host "Updates can be new, modified, or deleted files and folders. Any files or folders listed`nin the DFS Replication backlog have not yet replicated from the source computer"
Write-Host "to the destination computer. This is not necessarily an indication of problems.`nA backlog indicates latency, and a backlog may be expected in your environment,`ndepending on configuration, rate of change, network, and other factors.`n`n"

$EmailText += "$Succ successful, $Warn warnings and $Err errors from $($Succ+$Warn+$Err) replications.`r`n`r`n"
$EmailText += "Updates can be new, modified, or deleted files and folders. Any files or folders`r`nlisted in the DFS Replication backlog have not yet replicated from the source`r`n"
$EmailText += "computer to the destination computer. This is not necessarily an indication of`nproblems.`r`nA backlog indicates latency, and a backlog may be expected in your environment,`r`ndepending on configuration, rate of change, network, and other factors.`r`n`r`n"

Write-Host "File System Free Space on $ComputerName ($(get-date)) `n---------------------------------------------------------------------------------------------"
$EmailText += "File System Free Space on $ComputerName ($(get-date)) `r`n---------------------------------------------------------------------------------------------"
$FreeSpace = psdrive -PSProvider FileSystem |Select-Object root,  @{Name="Free (GB)";Expression={"{0:N1}" -f ($_.free / 1gb)}}, @{Name="Used (GB)";Expression={"{0:N1}" -f ($_.used / 1gb)}}, description | ft -AutoSize
$EmailText += $FreeSpace | Out-String
$FreeSpace | Out-String

 if ($ErrInfo -eq "1" ) {
   Write-Host "DFSR Backlog Errors ($(get-date)) `n---------------------------------------------------------------------------------------------`n"
   Write-Host "$ErrText`n"
   $EmailText +="DFSR Backlog Errors ($(get-date)) `r`n---------------------------------------------------------------------------------------------`r`n"
   $EmailText += "$ErrText`r`n"
   }


Write-Host "DFSR replication State ($(get-date)) `n---------------------------------------------------------------------------------------------`n"
$EmailText +="DFSR replication State ($(get-date)) `r`n---------------------------------------------------------------------------------------------`r`n"

$ReplicationState = invoke-expression "dfsrdiag replicationstate -v"
$ReplicationState

$EmailText += $ReplicationState | Out-String

Write-Host "Latest DFSR events (Error, Warning) from $Last7days to $(get-date) `n---------------------------------------------------------------------------------------------`n"
$EmailText += "Latest DFSR events (Error, Warning) from $Last7days to $(get-date) `r`n---------------------------------------------------------------------------------------------`r`n"

$DFSRError = (Get-EventLog -LogName "DFS Replication" -Newest 5 -EntryType Error -After $Last7days  | fl timegenerated, entrytype, message | Out-String )
$DFSRError
$DFSRWarrning = (Get-EventLog -LogName "DFS Replication" -Newest 3 -EntryType warning -After $Last7days| fl timegenerated, entrytype, message | Out-String )
$DFSRWarrning

$EmailText += $DFSRError
$EmailText += $DFSRWarrning

$EmailText +="[Hint] You can allways check current DFS-R status with this commands:`r`n---------------------------------------------------------------------------------------"
$EmailText +="`r`ndfsrdiag replicationstate"
$EmailText += $EmailHint 

#Enviar informe al correo electrónico 
If ($EmailNotification -eq '1') { 
$EmailSubject = "Informe DFSR $(get-date -format 'dd-MMMM-yyyy') - ($Err Errors, $Warn Warrnings)"

# CONFIGURACION DE ENVIO DE EMAIL: DESCOMENTAR e ingresar los datos:

#$EmailRecipients ="usuario@domain.com"
#$EmailFrom = "dfsr@domain.com"
#$EmailSMTPServer = '10.0.0.1'          # Servidor de Mail
#$EmailEncoding = [System.Text.Encoding]::UTF7 #UTF7,UTF8,ASCII

#Send-MailMessage -To $EmailRecipients -Subject $EmailSubject -From $EmailFrom -Body $EmailText -SmtpServer $EmailSMTPServer -Encoding $EmailEncoding 

}

#save report to file
if ( $ExportReporttoFile -eq '1' )
    {
    if((Test-Path $ExportReporFolder) -eq $False) #If export directory doesn't exzist, create new directory 
        {
        New-Item -ItemType Directory -Path $ExportReporFolder
        }
        $ExportFilePath  = "$ExportReporFolder\DFSR_report_$(get-date -f yyyy-MM-dd).txt"
        Out-File -InputObject $EmailText -FilePath $ExportFilePath   -Encoding unicode 

        }