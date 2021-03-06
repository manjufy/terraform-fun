param(
    [Parameter(Mandatory=$true)]
    [string] $resourceGroupName,
    [Parameter(Mandatory=$true)]
    [string] $appName,
    [Parameter(Mandatory=$true)]
    [string] $sourceDir
)

$secpasswd = ConvertTo-SecureString $env:ARM_CLIENT_SECRET -AsPlainText -Force
$ServicePrincipalCredential = New-Object System.Management.Automation.PSCredential ($env:ARM_CLIENT_ID, $secpasswd)
Connect-AzureRmAccount -Credential $ServicePrincipalCredential -Tenant $env:ARM_TENANT_ID -ServicePrincipal | Out-Null

$PublishingProfile = [xml](Get-AzureRmWebAppPublishingProfile -ResourceGroupName $ResourceGroupName -Name $appName)

$Username = (Select-Xml -Xml $PublishingProfile -XPath "//publishData/publishProfile[contains(@profileName,'Web Deploy')]/@userName").Node.Value
$Password = (Select-Xml -Xml $PublishingProfile -XPath "//publishData/publishProfile[contains(@profileName,'Web Deploy')]/@userPWD").Node.Value

$apiUrl = "https://${appName}.scm.azurewebsites.net/api/zipdeploy"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$filePath = "${appName}.zip"
Compress-Archive -Path $sourceDir\* -DestinationPath $filePath | Out-Null

Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UserAgent "powershell/1.0" -Method POST -InFile $filePath -ContentType "multipart/form-data" | Out-Null

Remove-Item $filePath | Out-Null

$result = @{
    zip = $filePath
    site = $appName
}
$result | ConvertTo-Json | Out-Default
