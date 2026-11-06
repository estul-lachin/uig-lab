# Reference solution for powershell-basics: every answer from PowerShell, then the CSV report.
set -eu
umask 022
ps() { pwsh -NoProfile -NonInteractive -Command "$1" | tr -d '\r'; }

{
  echo "WHOAMI=$(whoami)"
  echo "COMPUTER=$(hostname)"
  ps '"IDENTITY={0}\{1}" -f [Environment]::UserDomainName, [Environment]::UserName'
  ps '"OS_NAME=" + $PSVersionTable.OS'
  ps '$a = foreach ($n in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) { if ($n.Name -eq "eth0") { $n.GetIPProperties().UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq "InterNetwork" } } }; "IPV4=" + $a[0].Address'
  echo "NAMING=Verb-Noun"
  echo "SERVICE_CMDLET=Get-Service"
  ps '"PROCESS_CMDLET=" + (Get-Command -Verb Get -Noun Process).Name'
  ps '"DIR_ALIAS=" + (Get-Alias -Name dir).Definition'
  ps '"PS_VERSION=" + $PSVersionTable.PSVersion'
  ps '"AD_CMDLET=" + (Get-Command -Noun ADUser -Verb Get).Name'
  ps '"AD_MODULE=" + (Get-Command -Name Get-ADUser).ModuleName'
  ps '"MREYES_TITLE=" + (Get-ADUser mreyes -Properties Title).Title'
  ps '$d = Get-ADUser -Filter "Enabled -eq `$false" -Properties Department | Where-Object Department; "DISABLED_USER=" + $d.SamAccountName'
  ps '$c = [datetime]"2026-11-05" - [timespan]::FromDays(90); $s = Get-ADUser -Filter "Enabled -eq `$true -and LastLogonDate -lt `$c"; "STALE_USER=" + $s.SamAccountName'
  ps '$p = Get-ADUser -Filter "PasswordNeverExpires -eq `$true -and Enabled -eq `$true" | Where-Object SamAccountName -notlike "svc-*"; "NEVER_EXPIRES_USER=" + $p.SamAccountName'
  ps '$h = Get-ADGroupMember "Domain Admins" -Recursive | Get-ADUser -Properties Department | Where-Object { $_.Department -and $_.Department -ne "IT" }; "HIDDEN_ADMIN=" + $h.SamAccountName'
  ps '$todo = @("Domain Admins"); while ($todo) { $g, $todo = $todo; foreach ($m in Get-ADGroupMember $g) { if ($m.objectClass -eq "group") { $todo += $m.name } elseif ($m.SamAccountName -eq "bnakamura") { "HIDDEN_VIA=$g" } } }'
} > /root/answers.txt

mkdir -p /root/reports
ps '$ou = "OU=Finance,OU=Staff,OU=Ridgeline," + (Get-ADDomain).DistinguishedName; Get-ADUser -Filter "*" -SearchBase $ou -Properties Title | Select-Object SamAccountName, Title, Enabled | Export-Csv -Path /root/reports/finance-users.csv'
