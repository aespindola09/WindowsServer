

#Script para crear un nuevo Dominio de ADDS
#Pide las credenciales SafeModeAdministratorPassword

#
# Install Feature ADDS incluide All SubFeature and ManagementTools
#
Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools

install-ADDSForest `
-DomainName "algeibalab.local" `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainNetbiosName "adatum" ` 
-InstallDns:$true ` 
-LogPath "C:\Windows\NTDS" ` 
-NoRebootOnCompletion:$false ` 
-SysvolPath "C:\Windows\SYSVOL" ` 
-Force:$true

#Comando para crear un nuevo Dominio de ADDS
#install-ADDSForest -DomainName "adatum.local" -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "7" -DomainNetbiosName "adatum" -ForestMode "7" #-InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true