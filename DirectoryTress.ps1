function Get-DirectoryTree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [ValidateRange(-1, 1000)]
        [int]$Depth = -1,

        # Names (wildcards allowed) to leave out of the tree
        [string[]]$Exclude = @('node_modules')
    )

    $root = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $root.PSIsContainer) {
        throw "The specified path is not a directory: $Path"
    }

    function Get-TreeNode {
        param(
            [System.IO.FileSystemInfo]$Item,
            [int]$Level,
            [int]$MaxDepth,
            [string[]]$Exclude
        )

        if (-not $Item.PSIsContainer) {
            return [PSCustomObject]@{
                name      = $Item.Name
                path      = $Item.FullName
                type      = 'file'
                extension = $Item.Extension
                size      = $Item.Length
            }
        }

        $children  = [System.Collections.Generic.List[object]]::new()
        $truncated = -not ($MaxDepth -eq -1 -or $Level -lt $MaxDepth)

        if (-not $truncated) {
            $entries = Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction SilentlyContinue

            foreach ($entry in $entries) {
                # Skip excluded names (e.g. node_modules)
                $skip = $false
                foreach ($pattern in $Exclude) {
                    if ($entry.Name -like $pattern) { $skip = $true; break }
                }
                if ($skip) { continue }

                # Do not follow junctions / symlinks to directories (avoids loops)
                if ($entry.PSIsContainer -and
                    ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    $children.Add([PSCustomObject]@{
                        name      = $entry.Name
                        path      = $entry.FullName
                        type      = 'directory'
                        children  = @()
                        truncated = $true
                    })
                    continue
                }

                $children.Add((Get-TreeNode -Item $entry -Level ($Level + 1) -MaxDepth $MaxDepth -Exclude $Exclude))
            }
        }

        return [PSCustomObject]@{
            name      = $Item.Name
            path      = $Item.FullName
            type      = 'directory'
            children  = $children.ToArray()
            truncated = $truncated
        }
    }

    $tree = Get-TreeNode -Item $root -Level 0 -MaxDepth $Depth -Exclude $Exclude
    ConvertTo-Json -InputObject $tree -Depth 100
}
