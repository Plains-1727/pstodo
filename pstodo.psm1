# path to todo.txt
$path = "$env:HOMESHARE\todo.txt"

# internal
function Get-Todo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch] $IncludeDone
    )

    $todos = @()

    if ((Test-Path -Path $path) -eq $false) { New-Item $path | Out-Null }

    $todos += Get-Content -Path $path -Encoding UTF8
    $todoCount = $todos.Length

    $todoList = @()

    if ($todoCount -eq 0) { return }

    for ($i = 0; $i -lt $todoCount; $i++) {
        $done = $null
        $priority = $null
        $project = $null
        $context = $null
        $color = "Gray"

        $todo = $todos[$i]

        if ($todo -eq "") { continue }

        if ($todo -match "^x") {
            if (!$IncludeDone) { continue }

            $done = $true
            $todo = ($todo -replace "^x", "").Trim()

            $color = "DarkGreen"
        }

        if ($todo -match "(\([A-Z]\))") {
            $priority = $Matches[0]
            $todo = ($todo -replace "(\([A-Z]\))", "").Trim()

            if (!$done) { 
                switch ($priority) {
                    "(A)" { $color = "Yellow" }
                    "(B)" { $color = "Green" }
                    "(C)" { $color = "Cyan" }
                    "(D)" { $color = "White" }
                    default { $color = "Gray" }
                }
            }
        }

        if ($todo -match "(\+\w*)") {
            $project = $Matches[0]
            $todo = ($todo -replace "(\+\w*)", "").Trim()
        }

        if ($todo -match "(\@\w*)") {
            $context = $Matches[0]
            $todo = ($todo -replace "(\@\w*)", "").Trim()
        }

        $todoList += [PSCustomObject]@{
            Index       = $i
            Done        = $done
            Priority    = $priority
            Description = $todo
            Project     = $project
            Context     = $context
            Color       = $color
        }
    }

    $todoList = $todoList | Sort-Object -Property Priority

    return $todoList
}

function Format-Todo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [Object] $Todo,

        [Parameter()]
        [switch] $NoIndex
    )

    $output = @()

    foreach ($t in $Todo) {
        $done = $t.done
        $index = $t.index
        $priority = $t.priority
        $description = $t.description
        $project = $t.project
        $context = $t.context
        $color = $t.color

        $string = ""

        if (!$NoIndex) { $string += $index }
        if ($done) { $string += " x" }
        if ($priority) { $string += " $priority" }

        $string += " $description"

        if ($project) { $string += " $project" }
        if ($context) { $string += " $context" }

        $output += [PSCustomObject]@{
            String = $string.Trim()
            Color  = $color
        }
    }

    return $output
}

#external

function Show-Todo {
    [alias ("todols", "todosh")]
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch] $IncludeDone,

        [Parameter()]
        [String] $Project,

        [Parameter()]
        [String] $Context
    )

    [array] $todos = @()

    if ($IncludeDone) { $todos = Get-Todo -IncludeDone }
    else { $todos = Get-Todo }

    if ($todos.Length -eq 0) { Write-Host "No Todos found."; return }

    $max = $todos.Length

    if ($Project -and $Context) { $todos = $todos | Where-Object { $_.Project -like "*$Project*" -or $_.Context -like "*$Context*" } }
    elseif ($Project) { $todos = $todos | Where-Object { $_.Project -like "*$Project*" } }
    elseif ($Context) { $todos = $todos | Where-Object { $_.Context -like "*$Context*" } }

    $count = $todos.Length

    if (!$todos) { Write-Host "$count of $max Todos shown."; return }

    $output = Format-Todo $todos

    foreach ($out in $output) {
        Write-Host $out.String -ForegroundColor $out.Color
    }

    Write-Host "---"
    Write-Host "$count of $max Todos shown."
}

function Add-Todo {
    [alias ("todoadd")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String] $Description,

        [Parameter(Position = 1)]
        [Char] $Priority,

        [Parameter(Position = 2)]
        [String] $Project,

        [Parameter(Position = 3)]
        [String] $Context
    )

    if ((Test-Path -Path $path) -eq $false) { New-Item -Path $path | Out-Null }

    $todo = $Description

    if ($Priority) { 
        [String] $priorityString = $Priority
        $todo = "($($priorityString.ToUpper())) $todo" 
    }

    if ($Project) {
        if ($Project -notcontains "+") { $Project = $Project.Insert(0, "+") }

        $todo += " $Project"
    }

    if ($Context) {
        if ($Context -notcontains "@") { $Context = $Context.Insert(0, "@") }

        $todo += " $Context"
    }

    $todos = Get-Content -Path $path -Encoding UTF8

    $index = $null

    for ($i = 0; $i -lt $todos.Length; $i++) {
        if ($todos[$i] -eq "") { $index = $i; continue }
    }
    
    if ($null -ne $index) { $todos[$index] = $todo }
    else {
        $index = $todos.Length 
        $todos += $todo
    }

    Set-Content -Path $path -Value $todos -Encoding UTF8

    Write-Host "Added '$todo' at index '$index'"
}

function Set-Todo {
    [alias ("todoset")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [int[]] $Index,

        [Parameter()]
        [Switch] $Done,

        [Parameter()]
        [Char] $Priority,

        [Parameter()]
        [String] $Project,

        [Parameter()]
        [String] $Context,

        [Parameter()]
        [Switch] $NoProject,

        [Parameter()]
        [Switch] $NoContext
    )

    $todos = @()
    $todos += Get-Content -Path $path

    if ($todos.Length -eq 0) { return }

    foreach ($i in $Index) {
        if ($todos[$i] -eq "" -or $todos[$i] -match "^x") { return }

        $todo = $todos[$i]

        if ($Done) {
            $currentDate = Get-Date -Format "dd-MM-yyyy"

            $todos[$i] = $todo.Insert(0, "x $currentDate ")

            Write-Host "Set '$todo' done"
        }

        if ($Priority) {
            [String] $priorityString = $Priority
            $prio = "($($priorityString.ToUpper()))"

            if ($todo -match "(\([A-Z]\))") { $newTodo = $todo -replace "(\([A-Z]\))", "$prio" }
            else { $newTodo = $todo.Insert(0, "$prio ") }

            $todos[$i] = $newTodo

            Write-Host "Set '$todo' priority '$prio'"
        }

        if ($Project) {
            if ($Project -notcontains "+") { $Project = $Project.Insert(0, "+") }

            if ($todo -match "(\+\w*)") { $newTodo = $todo -replace "(\+\w*)", $Project }
            else { $newTodo = "$todo $Project" }

            $todos[$i] = $newTodo

            Write-Host "Set '$todo' project '$Project'"
        }

        if ($Context) {
            if ($Context -notcontains "@") { $Context = $Context.Insert(0, "@") }

            if ($todo -match "(\@\w*)") { $newTodo = $todo -replace "(\@\w*)", $Context }
            else { $newTodo = "$todo $Context" }

            $todos[$i] = $newTodo

            Write-Host "Set '$todo' context '$Context'"
        }

        if ($NoProject) {
            $todos[$i] = $todo -replace "\s\+\w*", ""

            Write-Host "Removed '$todo' project"
        }

        if ($NoContext) {
            $todos[$i] = $todo -replace "\s\@\w*", ""

            Write-Host "Removed '$todo' context"
        }
    }
    

    Set-Content -Path $path -Value $todos -Encoding UTF8
}

function Remove-Todo {
    [alias ("tododel")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [int[]] $Index
    )

    $todos = @()
    $todos += Get-Content -Path $path -Encoding UTF8

    if ($todos.Length -eq 0) { return }

    foreach ($i in $Index) {
        $todoToRemove = $todos[$i]

        if ($todoToRemove -eq "" -or $null -eq $todoToRemove) { return }

        $todos[$i] = ""

        <# could be used for a clean up function
        
        $todoArrayList = [System.Collections.ArrayList]@(Get-Content -Path $path -Encoding UTF8)
        $removedTodo = $todoArrayList[$i]
        $todoArrayList.RemoveAt($i) #>

        Set-Content -Path $path -Value $todos -Encoding UTF8

        Write-Host "Removed '$todoToRemove'"
    }   
}

Export-ModuleMember -Function Show-Todo, Remove-Todo, Set-Todo, Add-Todo -Alias todols, todosh, todoadd, todoset, tododel
