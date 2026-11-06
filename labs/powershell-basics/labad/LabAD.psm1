# LabAD: a stand-in for the Windows ActiveDirectory module, for this lab only.
# The real module needs a domain controller and Windows; this one reads a seeded directory
# (directory.json, made by gen_directory.py) and keeps the real cmdlets' names, parameters and
# default output, so the same commands work on a Windows domain.

$script:Dir = Get-Content -Raw (Join-Path $PSScriptRoot 'directory.json') | ConvertFrom-Json
$script:UserDefault = 'DistinguishedName', 'Enabled', 'GivenName', 'Name', 'ObjectClass', 'ObjectGUID',
                      'SamAccountName', 'SID', 'Surname', 'UserPrincipalName'
$script:GroupDefault = 'DistinguishedName', 'GroupCategory', 'GroupScope', 'Name', 'ObjectClass', 'ObjectGUID',
                       'SamAccountName', 'SID'
$script:DateProps = 'LastLogonDate', 'PasswordLastSet', 'WhenCreated'
foreach ($u in $script:Dir.Users) {
    foreach ($p in $script:DateProps) { if ($u.$p) { $u.$p = [datetime]$u.$p } }
}

function script:Out-ADObject($rec, [string[]]$default, [string[]]$extra, [string]$type) {
    $all = $rec.PSObject.Properties.Name
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($n in $default) { $names.Add($n) }
    foreach ($e in $extra) {
        if ($e -eq '*') { $all | Where-Object { $names -notcontains $_ } | ForEach-Object { $names.Add($_) } ; continue }
        $hit = $all | Where-Object { $_ -eq $e } | Select-Object -First 1
        if (-not $hit) { throw "One or more properties are invalid. Parameter name: $e" }
        if ($names -notcontains $hit) { $names.Add($hit) }
    }
    $o = [ordered]@{}
    foreach ($n in $names) { $o[$n] = if ($n -eq 'Members') { Get-MemberDN $rec } else { $rec.$n } }
    $obj = [pscustomobject]$o
    $obj.PSObject.TypeNames.Insert(0, "LabAD.$type")
    $obj
}

# A group's Members property holds distinguished names, like the real one.
function script:Get-MemberDN($grp) {
    foreach ($m in $grp.Members) {
        ($script:Dir.Users + $script:Dir.Groups | Where-Object SamAccountName -eq $m | Select-Object -First 1).DistinguishedName
    }
}

# Turns an AD filter such as "Enabled -eq `$false -and Department -like 'Fin*'" into a script block
# in the caller's scope, so variables in the filter ($cutoff) resolve like they do with the real module.
function script:ConvertTo-FilterBlock([string]$Filter, $Cmdlet) {
    $f = $Filter.Trim()
    if ($f.StartsWith('{') -and $f.EndsWith('}')) { $f = $f.Substring(1, $f.Length - 2).Trim() }
    if ($f -eq '*') { return { $true } }
    $ops = 'eq|ne|like|notlike|gt|lt|ge|le|approx'
    $f = [regex]::Replace($f, "(?<![\$\w.'`"-])([A-Za-z][A-Za-z0-9]*)(?=\s+-(?:$ops)\b)", '$$_.$1')
    $f = $f -replace '-approx\b', '-like'
    $Cmdlet.SessionState.InvokeCommand.NewScriptBlock($f)
}

function script:Find-Identity($list, $id, [string]$kind) {
    if ($id -is [psobject] -and $id.PSObject.Properties['SamAccountName']) { $id = $id.SamAccountName }
    $id = "$id"
    $hit = $list | Where-Object {
        $_.SamAccountName -eq $id -or $_.DistinguishedName -eq $id -or $_.ObjectGUID -eq $id -or $_.SID -eq $id
    } | Select-Object -First 1
    if (-not $hit) {
        throw "Cannot find an object with identity: '$id' under: '$($script:Dir.Domain.DistinguishedName)'."
    }
    $hit
}

function script:Select-Records($list, $Filter, $SearchBase, $Cmdlet) {
    $sb = ConvertTo-FilterBlock $Filter $Cmdlet
    $list | Where-Object { -not $SearchBase -or $_.DistinguishedName -like "*,$SearchBase" } | Where-Object -FilterScript $sb
}

function Get-ADUser {
    <#
    .SYNOPSIS
    Gets one or more Active Directory users (LabAD stand-in: reads the seeded RIDGELINE directory).
    .DESCRIPTION
    Without -Properties you get the default set (DistinguishedName, Enabled, GivenName, Name, ObjectClass,
    ObjectGUID, SamAccountName, SID, Surname, UserPrincipalName). Add more with -Properties, or all with
    -Properties *. -Filter can use any property, requested or not.
    .EXAMPLE
    Get-ADUser -Identity mreyes -Properties Department,Title

    One user by SamAccountName, with two extra properties.
    .EXAMPLE
    Get-ADUser -Filter * -SearchBase 'OU=IT,OU=Staff,OU=Ridgeline,DC=ridgeline,DC=local'

    Every user in one OU.
    .EXAMPLE
    Get-ADUser -Filter 'Enabled -eq $false'

    Every disabled account.
    .EXAMPLE
    Get-ADUser -Filter "Department -like 'Ware*'" -Properties Title | Select-Object Name, Title

    Filter on a property, then keep two columns.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Filter')]
    param(
        [Parameter(ParameterSetName = 'Identity', Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Identity,
        [Parameter(ParameterSetName = 'Filter', Mandatory)]
        [string]$Filter,
        [Parameter(ParameterSetName = 'Filter')]
        [string]$SearchBase,
        [string[]]$Properties
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Identity') {
            try { $recs = Find-Identity $script:Dir.Users $Identity 'user' }
            catch { $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new($_.Exception, 'ADIdentityNotFound', 'ObjectNotFound', $Identity)); return }
        } else {
            $recs = Select-Records $script:Dir.Users $Filter $SearchBase $PSCmdlet
        }
        foreach ($r in $recs) { Out-ADObject $r $script:UserDefault $Properties 'ADUser' }
    }
}

function Get-ADGroup {
    <#
    .SYNOPSIS
    Gets one or more Active Directory groups (LabAD stand-in).
    .EXAMPLE
    Get-ADGroup -Filter * | Select-Object Name

    Every group in the domain.
    .EXAMPLE
    Get-ADGroup -Identity 'Domain Admins' -Properties Description
    #>
    [CmdletBinding(DefaultParameterSetName = 'Filter')]
    param(
        [Parameter(ParameterSetName = 'Identity', Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Identity,
        [Parameter(ParameterSetName = 'Filter', Mandatory)]
        [string]$Filter,
        [Parameter(ParameterSetName = 'Filter')]
        [string]$SearchBase,
        [string[]]$Properties
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'Identity') {
            try { $recs = Find-Identity $script:Dir.Groups $Identity 'group' }
            catch { $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new($_.Exception, 'ADIdentityNotFound', 'ObjectNotFound', $Identity)); return }
        } else {
            $recs = Select-Records $script:Dir.Groups $Filter $SearchBase $PSCmdlet
        }
        foreach ($r in $recs) { Out-ADObject $r $script:GroupDefault $Properties 'ADGroup' }
    }
}

function Get-ADGroupMember {
    <#
    .SYNOPSIS
    Gets the members of an Active Directory group (LabAD stand-in).
    .DESCRIPTION
    Without -Recursive you get the direct members, groups included. With -Recursive, nested groups are
    expanded and only the users at the end of each chain are returned.
    .EXAMPLE
    Get-ADGroupMember -Identity 'Domain Admins'
    .EXAMPLE
    Get-ADGroupMember -Identity 'Domain Admins' -Recursive | Get-ADUser -Properties Department
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]$Identity,
        [switch]$Recursive
    )
    process {
        try { $grp = Find-Identity $script:Dir.Groups $Identity 'group' }
        catch { $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]::new($_.Exception, 'ADIdentityNotFound', 'ObjectNotFound', $Identity)); return }
        $seen = @{}
        $queue = [System.Collections.Generic.Queue[object]]::new()
        $queue.Enqueue($grp)
        while ($queue.Count) {
            $g = $queue.Dequeue()
            foreach ($m in $g.Members) {
                $rec = $script:Dir.Users | Where-Object SamAccountName -eq $m | Select-Object -First 1
                if (-not $rec) { $rec = $script:Dir.Groups | Where-Object SamAccountName -eq $m | Select-Object -First 1 }
                if (-not $rec -or $seen[$rec.SamAccountName]) { continue }
                $seen[$rec.SamAccountName] = $true
                if ($Recursive -and $rec.ObjectClass -eq 'group') { $queue.Enqueue($rec); continue }
                $o = [pscustomobject][ordered]@{
                    distinguishedName = $rec.DistinguishedName; name = $rec.Name; objectClass = $rec.ObjectClass
                    objectGUID = $rec.ObjectGUID; SamAccountName = $rec.SamAccountName; SID = $rec.SID
                }
                $o.PSObject.TypeNames.Insert(0, 'LabAD.ADPrincipal')
                $o
            }
        }
    }
}

function Get-ADDomain {
    <#
    .SYNOPSIS
    Gets the domain (LabAD stand-in): its names and distinguished name.
    #>
    [CmdletBinding()] param()
    [pscustomobject]$script:Dir.Domain
}

Export-ModuleMember -Function Get-ADUser, Get-ADGroup, Get-ADGroupMember, Get-ADDomain
