@{
    RootModule        = 'LabAD.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '2f6b1c0e-5a3d-4e8f-9b17-6c2d4a8e1f30'
    Author            = 'uig-lab'
    Description       = 'Lab stand-in for the ActiveDirectory module: Get-ADUser, Get-ADGroup, Get-ADGroupMember and Get-ADDomain over a seeded directory.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Get-ADUser', 'Get-ADGroup', 'Get-ADGroupMember', 'Get-ADDomain')
    CmdletsToExport   = @()
    AliasesToExport   = @()
    VariablesToExport = @()
}
