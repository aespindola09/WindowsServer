#
# Install Feature ADDS incluide All SubFeature and ManagementTools
#
Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools

Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$true `
-CriticalReplicationOnly:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainName "DOMAIN.COM" `
-InstallDns:$true `
-LogPath "D:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SiteName "SITE" `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true

