###
# Download the following requirements and either install now or prepare for later
# installation:
# - Amazon EC2Launch v2
# - AWS Paravirtual driver
# - Amazon SSM Agent (Installed)
# - Amazon CloudWatch Agent (Installed)
# - AWS Elastic Network Adapter driver (Installed)
# - AWS NVMe driver (Installed)
###

# Set up some variables
$DownloadPath = "$env:USERPROFILE\Downloads\AWS"
$DownloadUrls = @(
  "https://s3.amazonaws.com/amazon-ec2launch-v2-utils/MigrationTool/windows/amd64/latest/EC2LaunchMigrationTool.zip"
  "https://s3.amazonaws.com/ec2-windows-drivers-downloads/AWSPV/Latest/AWSPVDriver.zip"
  "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe"
  "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
  "https://s3.amazonaws.com/ec2-windows-drivers-downloads/ENA/Latest/AwsEnaNetworkDriver.zip"
  "https://s3.amazonaws.com/ec2-windows-drivers-downloads/NVMe/Latest/AWSNVMe.zip"
)
$LocalFiles = @()

# Create the download directory
New-Item -ItemType Directory -Force -Path "$DownloadPath"

# Download each file we need
foreach ($Url in $DownloadUrls) {
  $LocalFile = $(Split-Path -Path $Url -Leaf)
  $DownloadFile = "$DownloadPath\$LocalFile"
  Invoke-WebRequest -Uri $Url -OutFile $DownloadFile
  $LocalFiles += $LocalFile
}

# Extract the EC2Launch Migration Tool
# Note: Installation should occur post VM import
$MigrationToolZip = "{0}\{1}" -f $DownloadPath, $LocalFiles[0]
$MigrationToolPath = "$DownloadPath\EC2LaunchMigrationTool"
Expand-Archive -LiteralPath "$MigrationToolZip" -DestinationPath "$MigrationToolPath" -Force

# Extract the PV driver
# Note: Installation should occur post VM import
$PvZip = "{0}\{1}" -f $DownloadPath, $LocalFiles[1]
$PvPath = "$DownloadPath\PV_Driver"
Expand-Archive -LiteralPath "$PvZip" -DestinationPath "$PvPath" -Force

# Install the SSM agent
Start-Process -FilePath $("{0}\{1}" -f $DownloadPath, $LocalFiles[2]) -ArgumentList "/S"

# Install the CloudWatch agent
msiexec.exe /i $("{0}\{1}" -f $DownloadPath, $LocalFiles[3]) /q

# Install the ENA driver
$EnaZip = "{0}\{1}" -f $DownloadPath, $LocalFiles[4]
$EnaPath = "$DownloadPath\ENA_Driver"
Expand-Archive -LiteralPath "$EnaZip" -DestinationPath "$EnaPath" -Force
& "$EnaPath\install.ps1"

# Ensure we return to the directory we started in (the ENA driver install script changes directories)
Set-Location -Path "$PSScriptRoot"

# Install the NVMe driver
# Note: Windows will reboot as soon as this is finished
$NvmeZip = "{0}\{1}" -f $DownloadPath, $LocalFiles[5]
$NvmePath = "$DownloadPath\NVMe_Driver"
Expand-Archive -LiteralPath "$NvmeZip" -DestinationPath "$NvmePath" -Force
& "$NvmePath\install.ps1"
