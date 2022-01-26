# path to todo.txt
$pathTodo = "$env:USERPROFILE\todo.txt"
$pathDone = "$env:USERPROFILE\done.txt"

# internal
function Get-Todo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch] $IncludeDone
    )

    $todos = @()

    if ((Test-Path -Path $pathTodo) -eq $false) { New-Item $pathTodo | Out-Null }

    $todos += Get-Content -Path $pathTodo -Encoding UTF8

    if ($IncludeDone) { $todos += Get-Content -Path $pathDone -Encoding UTF8 }
    
    $todoCount = $todos.Length

    $todoList = @()

    if ($todoCount -eq 0) { return }

    for ($i = 0; $i -lt $todoCount; $i++) {
        $index = $i
        $done = $null
        $priority = $null
        $project = $null
        $context = $null
        $color = "Gray"
        $sortPriority = 10

        $todo = $todos[$i]

        if ($todo -eq "") { continue }

        if ($todo -match "^x") {
            $index = 0
            $done = $true
            $sortPriority = 99
            $color = "DarkGreen"

            $todo = ($todo -replace "^x", "").Trim()
        }
      
        if ($todo -match "(\([A-Z]\))") {
            $priority = $Matches[0]
            $todo = ($todo -replace "(\([A-Z]\))", "").Trim()

            if (!$done) { 
                switch ($priority) {
                    "(A)" { 
                        $color = "Yellow"
                        $sortPriority = 1
                    }   
                    "(B)" { 
                        $color = "Green" 
                        $sortPriority = 2
                    }
                    "(C)" { $color = "Cyan"
                            $sortPriority = 3
                    }
                    "(D)" { 
                        $color = "White" 
                        $sortPriority = 4
                    }
                    default { 
                        $color = "Gray" 
                        $sortPriority = 5
                    }
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
            Index       = $index
            Done        = $done
            Priority    = $priority
            Description = $todo
            Project     = $project
            Context     = $context
            Color       = $color
            SortPriority = $sortPriority
        }
    }

    $todoList = $todoList | Sort-Object -Property SortPriority

    return $todoList
}

#function Sort-Todo {
    ## Totally unnecessary after I found a typo that hindered the already existing
    ## Sort-Object from properly sorting the todo list.
    ## Still keeping it as this is the first sorting algorithm I wrote
    ## and I'm quite happy that it worked

    #[CmdletBinding()]
    #param (
        #[Parameter(Mandatory, Position = 0)]
        #[array] $todos
    #)

    #$sortedList = New-Object System.Collections.Generic.List[System.Object]

    #$todoCount = $todos.Count

    #foreach ($i in (0..($todoCount -1))) {
        #$todo = $todos[$i]
        #$sortedListCount = $sortedList.Count

        #if ($sortedList.Count -eq 0) { 
            #$sortedList.Add($todo); continue }
        
        #$sortPriority = $todo.SortPriority

        #foreach ($c in (0..$sortedListCount)) {
            #$lastIndex = $sortedListCount - 1
            
            #if ($c -gt $lastIndex) {
                #$sortedList.Add($todo)
                #break
            #}

            #$compareTodoSortPriority = $sortedList[$c].SortPriority

            #if ( $sortPriority -le $compareTodoSortPriority) {
                #$sortedList.Insert($c, $todo)
                #break
            #}
        #}
    #}

    #return $sortedList
#}

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

    if ((Test-Path -Path $pathTodo) -eq $false) { New-Item -Path $pathTodo | Out-Null }

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

    [array]$todos = Get-Content -Path $pathTodo -Encoding UTF8

    $index = $null

    for ($i = 0; $i -lt $todos.Length; $i++) {
        if ($todos[$i] -eq "") { $index = $i; continue }
    }
    
    if ($null -ne $index) { $todos[$index] = $todo }
    else {
        $index = $todos.Length 
        $todos += $todo
    }

    Set-Content -Path $pathTodo -Value $todos -Encoding UTF8

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
    $todos += Get-Content -Path $pathTodo

    if ($todos.Length -eq 0) { return }

    foreach ($i in $Index) {
        if ($todos[$i] -eq "" -or $todos[$i] -match "^x") { return }

        $todo = $todos[$i]

        if ($Done) {
            $currentDate = Get-Date -Format "yyyy-MM-dd"

            $todo = $todos[$i]
            $todoDone = "x $currentDate $todo"

            $todos[$i] = ""
            #$todos[$i] = $todo.Insert(0, "x $currentDate ")

            if (!(Test-Path $pathDone)) { New-Item -Path $pathDone | Out-Null }
            
            Add-Content -Path $pathDone -Value $todoDone

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
    

    Set-Content -Path $pathTodo -Value $todos -Encoding UTF8
}

function Remove-Todo {
    [alias ("tododel")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [int[]] $Index
    )

    $todos = @()
    $todos += Get-Content -Path $pathTodo -Encoding UTF8

    if ($todos.Length -eq 0) { return }

    foreach ($i in $Index) {
        $todoToRemove = $todos[$i]

        if ($todoToRemove -eq "" -or $null -eq $todoToRemove) { return }

        $todos[$i] = ""

        Set-Content -Path $pathTodo -Value $todos -Encoding UTF8

        Write-Host "Removed '$todoToRemove'"
    }   
}

Export-ModuleMember -Function Show-Todo, Remove-Todo, Set-Todo, Add-Todo -Alias todols, todosh, todoadd, todoset, tododel
