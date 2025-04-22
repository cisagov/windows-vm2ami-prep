# Configure the Windows time settings for running in AWS

function RegKeyHT($Path, $Key, $Type, $Value) {
  @{
    Name=$Key
    Path=$Path
    Type=$Type
    Value=$Value
  }
}

$RegistryBase = "HKLM:\SYSTEM\CurrentControlSet"
$w32tmBase = "$RegistryBase\Services\w32time"
$UpdatedRegKeys = @(
  RegKeyHT "$RegistryBase\Control\TimeZoneInformation" "RealTimeIsUniversal" "DWord" "1"
  RegKeyHT "$w32tmBase\Config" "UpdateInterval" "DWord" "120"
  RegKeyHT "$w32tmBase\Parameters" "NtpServer" "String" "169.254.169.123,0x9"
  RegKeyHT "$w32tmBase\Parameters" "Type" "String" "NTP"
  RegKeyHT "$w32tmBase\TimeProviders\NtpClient" "Enabled" "DWord" "1"
  RegKeyHT "$w32tmBase\TimeProviders\NtpClient" "InputProvider" "DWord" "1"
  RegKeyHT "$w32tmBase\TimeProviders\NtpClient" "SpecialPollInterval" "DWord" "900"
)


# Make sure w32time is running
net.exe start w32time

# Configure w32time to start and stop based on IP address assignment
sc.exe triggerinfo w32time delete
sc.exe triggerinfo w32time start/networkon stop/networkoff

# Set the NTP servers to the AWS internal servers
w32tm.exe /config /manualpeerlist:169.254.169.123 /syncfromflags:manual /update

# Update registry settings
foreach ($RegKey in $UpdatedRegKeys) {
  Set-ItemProperty @RegKey -Force
}

# Set the timezone to UTC
Set-TimeZone -Id "UTC"
