###
# Perform the last steps to prepare the virtual machine for export to be run as an AMI
# in the COOL.
###

function RegKeyHT($Path, $Key, $Type, $Value) {
  @{
    Name=$Key
    Path=$Path
    Type=$Type
    Value=$Value
  }
}

# Setup some variables
$WindowsUninstallPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
$ControlSetBase = "HKLM:\SYSTEM\CurrentControlSet"
$TerminalServerBase = "$ControlSetBase\Control\Terminal Server"
$ShutdownDisable = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideShutDown"
$UpdatedRegKeys = @(
  # Allow guest authentication when connecting to the Samba share
  RegKeyHT "$ControlSetBase\Services\LanmanWorkstation\Parameters" "AllowInsecureGuestAuth" "DWord" "1"
  # Enable Remote Desktop (RDP)
  RegKeyHT "$TerminalServerBase" "fDenyTSConnections" "DWord" "0"
  # Disable shutdown from the Power options of the Start Menu
  RegKeyHT "$ShutdownDisable" "value" "Dword" "1"
)

# Update registry settings
foreach ($RegKey in $UpdatedRegKeys) {
  Set-ItemProperty @RegKey -Force
}

# Download UltraVNC installer
$DownloadPath = "$env:USERPROFILE\Downloads"
$VncUrls = @(
  "https://www.uvnc.eu/download/1342/UltraVNC_1_3_42_X64_Setup.exe"
  "https://www.tightvnc.com/download/2.8.63/tightvnc-2.8.63-gpl-setup-64bit.msi"
)
foreach ($Url in VncUrls) {
  $LocalFile = $(Split-Path -Path $Url -Leaf)
  $DownloadFile = "$DownloadPath\$LocalFile"
  Invoke-WebRequest -Uri $Url -OutFile $DownloadFile
}

# Allow Remote Desktop through the Windows Firewall
netsh.exe advfirewall firewall set rule group="remote desktop" new enable=Yes

# Install the OpenSSH server per Microsoft's installation instructions at:
# https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse

# Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start the sshd service
Start-Service sshd

# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType "Automatic"

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
  Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
  New-NetFirewallRule `
    -Name "OpenSSH-Server-In-TCP" `
    -DisplayName "OpenSSH Server (sshd)" `
    -Enabled True `
    -Direction Inbound `
    -Protocol TCP `
    -Action Allow `
    -LocalPort 22
} else {
  Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}

# Remove the recovery partition and extend the data partition to include the freed space
$DiskpartCommands = @(
  "select disk 0"
  "select partition 3"
  "delete partition override"
  "select partition 2"
  "extend"
)
Out-String -InputObject $DiskpartCommands | diskpart.exe

# Prompt before continuing with VMware Tools removal so any last steps that may need copy/paste
# can be performed.
Do {
  $Confirmation = Read-Host -Prompt "Proceed with VMware Tools removal (y/n)?"
}
while ($Confirmation -ne "y")

# Get the VMware Tools GUID and use it to uninstall VMware Tools
$VMwToolsGuid = Get-ChildItem  $WindowsUninstallPath `
  | Get-ItemProperty `
  | ForEach-Object { if ($PSItem.DisplayName -eq "VMware Tools") { $PSItem.PSChildName } }
msiexec.exe /q /x $VMwToolsGuid
