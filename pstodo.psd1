@{
RootModule = '.\pstodo.psm1'
ModuleVersion = '1.0'
GUID = '7e71f00d-26fc-4f42-abf1-7f8547096aa0'
Author = 'Jan Draws'
Copyright = '(c) 2021 Jan Draws. Alle Rechte vorbehalten.'
Description = "Simple ToDo directly in PowerShell"
FunctionsToExport = @("Show-Todo", "Remove-Todo", "Add-Todo", "Set-Todo")
CmdletsToExport = @()
VariablesToExport = '*'
AliasesToExport = @("todoadd", "tododel", "todoset", "todosh", "todols")
}
