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
        [String]$Thumbprint = 'fe9c9f34be2c119aadf25aa79c644900010efab5',
        [String]$HostName = 'www.test-web.com'
    )

##### Importing Modules which are used in the MOF file
    Import-DscResource -ModuleName PsDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName AccessControlDsc
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName CertificateDsc

    
    Node $Node
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $True
        }

##### Enable WebServer Role
        WindowsFeature WebServerRole
        {
            Name = 'Web-Server'
            Ensure = $State
        }

##### Reboot Server After IIS
        PendingReboot RebootForIIS
        {
            Name = 'RebootIIS'
            DependsOn = '[WindowsFeature]WebServerRole'
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

##### Enable ASPNet 4.5
        WindowsFeature ASPNet45
        {
          Name = 'Web-Asp-Net45'
          Ensure = $State
        }

##### Reboot Server After ASPNet 4.5
        PendingReboot RebootForASP
        {
            Name = 'Reboot-ASP'
            DependsOn = '[WindowsFeature]ASPNet45'
        }

##### Enable HTTP Redirection
        WindowsFeature HTTPRedirection
        {
          Name = 'Web-Http-Redirect'
          Ensure = $State
        }

##### Enable WCF Service
       	WindowsFeature WCFServices45
        {
          Name = 'NET-WCF-Services45'
          Ensure = $State
        }

##### Reboot Server After WCF
        PendingReboot RebootForWCF45
        {
            Name = 'Reboot-WCF'
            DependsOn = '[WindowsFeature]WCFServices45'
        }

##### Enable Net.TCP
        WindowsFeature TCPActivation
        {
          Name = 'NET-WCF-TCP-Activation45'
          Ensure = $State
        }

##### Reboot Server After NET-TCP
        PendingReboot RebootForNETTCP
        {
            Name = 'Reboot-NETTCP'
            DependsOn = '[WindowsFeature]TCPActivation'
        }

##### Install URL Rewrite
        Package UrlRewrite
		{
			DependsOn = '[WindowsFeature]WebServerRole'
            Ensure = $State
            Name = 'IIS URL Rewrite Module 2'
            Path = 'C:\Users\administrator\desktop\rewrite_amd64_en-US.msi'
            Arguments = '/quiet'
            ProductId = '38D32370-3A31-40E9-91D0-D236F47E3C4A'
        }

##### Create a local user for the website
        User CreateSaUser
        {
            Ensure = $State
            Username = $UserName
            #Password = $Password
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

##### Import Certificate on the IIS
        PfxImport ImportSSL
        {
            Ensure = $State
            Thumbprint = $Thumbprint
            Location = 'LocalMachine'
            Path = 'C:\Users\Administrator\Desktop\www.test-web.com.pfx'
            Store = 'MY'
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
            Force = $true
            MatchSource = $true
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
                            Ensure = $State
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
            DependsOn = '[WindowsFeature]WebServerRole', '[User]CreateSaUser'
        }

##### Create Website in IIS 
        xWebSite AddWebSite
        {
            Name = 'Test-Web'
            Ensure = $State
            State = 'Started'
            ApplicationPool = 'Test-Web'
            BindingInfo     = @(
                    @(MSFT_xWebBindingInformation   
                        {  
                            Protocol              = 'HTTP'
                            Port                  = 80 
                            HostName              = $HostName
                        }
                    );
                    @(MSFT_xWebBindingInformation
                        {
                            Protocol              = 'HTTPS'
                            Port                  = 443
                            HostName              = $HostName
                            CertificateThumbprint = $Thumbprint
                        }
                    );
                    @(MSFT_xWebBindingInformation
                        {
                            Protocol              = 'net.tcp'
                            BindingInformation    = '808:*'
                        }
                    )
                  )
            PhysicalPath = $DestinationPath
            EnabledProtocols = 'http,net.tcp'
            DependsOn = '[WindowsFeature]WebServerRole', "[xWebAppPool]AddAppPool"
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
WebsiteDeployment -OutputPath 'C:\DscConfiguration' -ConfigurationData $configData

Start-DscConfiguration -Wait -Verbose -Path "C:\DscConfiguration" -Force