# Shim: NITRO-KB_GetLinkedPages.ps1 -> 30..70 sequence
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot\30_Extract_Links.ps1"
& "$PSScriptRoot\40_Download_Linked.ps1"
& "$PSScriptRoot\50_Rewrite_Links.ps1"
& "$PSScriptRoot\60_Build_Index.ps1"
& "$PSScriptRoot\70_Bundle_Metadata.ps1"
