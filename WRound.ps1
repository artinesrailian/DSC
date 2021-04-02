Configuration WebsiteDeployment
{
##### Define Parameters
    param
    (
        [String]$Node = 'Web001',
        [String]$SourcePath = 'C:\Test',
        [String]$DestinationPath = 'C:\inetpub\Test-Site',
        [String]$State = 'Present',
        [String]$UserName = 'sa-WebUser',
        [Parameter()]$Password = 'MyStrongPassword',
        #[securestring]$secStringPassword = (ConvertTo-SecureString 'MyStrongPassword' -AsPlainText -Force),
        #[System.Management.Automation.PSCredential]$credObject = (New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword))
        #[securestring]$secStringPassword,
        #[pscredential]$credObject
        #[System.Management.Automation.PSCredential]$PasswordCredential
        
    )

##### Importing Modules which are used in the MOF file
    Import-DscResource -ModuleName PsDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName AccessControlDsc
    
    Node $Node
    {
    #$secStringPassword = (ConvertTo-SecureString 'MyStrongPassword' -AsPlainText -Force)
    #$credObject = (New-Object System.Management.Automation.PSCredential ('sa-WebUser', $secStringPassword))
##### Enable WebServer Role
        WindowsFeature WebServerRole
        {
            Name = 'Web-Server'
            Ensure = $State
        }

##### Enable Web Management Tools Component
        WindowsFeature WebTools
        {
            Name = 'Web-Mgmt-Tools'
            Ensure = $State
            DependsOn = '[WindowsFeature]WebServerRole'
        }

##### Enable ASP.Net Component
        WindowsFeature WebAspNet
        {
            Name = 'Web-Asp-Net'
            Ensure = $State
            DependsOn = '[WindowsFeature]WebServerRole'
        }

##### Create a local user for the website
        User CreateSaUser
        {
            Ensure = $State
            Username = $UserName
            Password = $Password
            PasswordChangeRequired = $false
            PasswordChangeNotAllowed = $true
            Disabled = $false
            FullName = 'Site User'
            Description = 'Service Acount for Test-Web Website'
        }

##### Add the created user to the RDP User Group
        GroupSet RDP
        {
            GroupName = 'Remote Desktop Users'
            Ensure = $State
            MembersToInclude = $UserName
            DependsOn = '[User]CreateSaUser'
        }

##### Publish the Website
        File Publish
        {
            Ensure = $State
            Type = 'Directory'
            Recurse = $true
            SourcePath = $SourcePath
            DestinationPath = $DestinationPath
            DependsOn = '[WindowsFeature]WebServerRole'
        }

##### FolderPermission for the Service Account User
        NTFSAccessEntry AddSaUser
        {
            Path = $DestinationPath
            DependsOn = '[File]Publish'
            AccessControlList = @(
                NTFSAccessControlList
                {
                    Principal = $UserName
                    ForcePrincipal = $true
                    AccessControlEntry = @(
                        NTFSAccessControlEntry
                        {
                            AccessControlType = 'Allow'
                            FileSystemRights = 'FullControl'
                            Inheritance = 'This folder and files'
                            Ensure = 'Present'
                        }
                    )
                } 
            )      
        }

##### Create App Pool for the Website with Specific user created in the previous Step
        xWebAppPool AddAppPool
        {
            Name = 'Test-Web'
            Ensure = $State
            autoStart = $true
            startMode = 'AlwaysRunning'
            identityType = 'ApplicationPoolIdentity'
            #Credential = $credential
            <#{
                UserName = $UserName
                Password = $Password
            }#>
            DependsOn = '[WindowsFeature]WebServerRole', '[User]CreateSaUser'
        }

##### Create Website in IIS 
        xWebSite AddWebSite
        {
            Name = 'Test-Web'
            Ensure = $State
            State = 'Started'
            ApplicationPool = 'Test-Web'
            BindingInfo = MSFT_xWebBindingInformation
            {
                Protocol = 'HTTP'
                Port = 80
                HostName = 'Test-Web'
            }
            PhysicalPath = $DestinationPath
            DependsOn = "[WindowsFeature]WebServerRole"#, "[xWebAppPool]AddAppPool"
        }
    }
}
$configData = 'a'
 
$configData = @{
                AllNodes = @(
                              @{
                                 NodeName = 'Web001';
                                 PSDscAllowPlainTextPassword = $true
                                    }
                    )
               }
WebsiteDeployment -OutputPath 'C:\DscConfiguration'

#$secStringPassword = (ConvertTo-SecureString 'MyStrongPassword' -AsPlainText -Force)
#$credObject = (New-Object System.Management.Automation.PSCredential ('sa-WebUser', $secStringPassword))

Start-DscConfiguration -Wait -Verbose -Path "C:\DscConfiguration" -Force