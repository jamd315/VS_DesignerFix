function ConvertTo-TimeAgo {
    param (
        [DateTime]$DateTime
    )
    
    $currentDateTime = Get-Date
    $timeSpan = New-TimeSpan -Start $DateTime -End $currentDateTime
    $sb = [System.Text.StringBuilder]::new()

    if ($timeSpan.Days -gt 0) {
        [void]$sb.Append($timeSpan.Days)
        [void]$sb.Append(" day")
        if ($timeSpan.Days -ne 1) {
            [void]$sb.Append("s")
        }
        [void]$sb.Append(" ago")
        return $sb.ToString()
    } elseif ($timeSpan.Hours -gt 0) {
        [void]$sb.Append($timeSpan.Hours)
        [void]$sb.Append(" hour")
        if ($timeSpan.Hours -ne 1) {
            [void]$sb.Append("s")
        }
        [void]$sb.Append(" ago")
        return $sb.ToString()
    } elseif ($timeSpan.Minutes -gt 0) {
        [void]$sb.Append($timeSpan.Minutes)
        [void]$sb.Append(" minute")
        if ($timeSpan.Minutes -ne 1) {
            [void]$sb.Append("s")
        }
        [void]$sb.Append(" ago")
        return $sb.ToString()
    } else {
        return "just now"
    }
}

# Ensure VS isn't running
$vsProcess = Get-Process -Name devenv -ErrorAction SilentlyContinue

if ($vsProcess) {
    Write-Host "Visual Studio is currently running. Please close it before proceeding."
    Write-Host "Waiting... (CTRL-C to cancel)"
    do {
        Start-Sleep -Seconds 1
        $vsProcess = Get-Process -Name devenv -ErrorAction SilentlyContinue
    } while ($vsProcess)
}

#Delete ComponentModelCache
Write-Host "Fixing VS ComponentModelCache..."
$vsCachePath = "$env:LOCALAPPDATA\Microsoft\VisualStudio"
if (Test-Path $vsCachePath) {
    Get-ChildItem -Path $vsCachePath -Recurse -Filter "ComponentModelCache" | ForEach-Object {
        try {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Host "Deleted: $($_.FullName)"
        } catch {
            Write-Warning "Failed to delete: $($_.FullName)"
        }
    }
} else {
    Write-Host "ComponentModelCache not found in: $componentModelCachePath"
}


# Get most recently used projects
$projects = Get-ChildItem -Path $directory -Recurse -Depth 1 -Directory | ForEach-Object {
    # Check if the folder contains a .csproj file
    $csprojFile = Get-ChildItem -Path $_.FullName -Filter *.csproj -ErrorAction SilentlyContinue
    if ($csprojFile) {
        # Get the latest modification time for the .csproj file or any other file in the project folder
        $latestItem = Get-ChildItem -Path $_.FullName -Recurse | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -First 1
        
        # Get the project name (current folder) and the solution name (parent folder)
        $projectName = $_.Name
        $solutionName = Split-Path $_.FullName -Parent | Split-Path -Leaf
        
        # Store in a custom object
        [PSCustomObject]@{
            SolutionName = $solutionName
            ProjectName  = $projectName
            Folder       = $_.FullName
            LastWriteTime = $latestItem.LastWriteTime
        }
    }
} | Sort-Object LastWriteTime -Descending | Select-Object -First 10

# Prompt for project selection
Write-Host "10 most recent projects:" -ForegroundColor Cyan
for ($i = 0; $i -lt $projects.Count; $i++) {
    Write-Host "[$($i)]" -NoNewline -ForegroundColor White
    Write-Host " $($projects[$i].SolutionName)" -NoNewline -ForegroundColor Magenta
    Write-Host " $($projects[$i].ProjectName)" -NoNewline -ForegroundColor Cyan
    Write-Host " $(ConvertTo-TimeAgo($projects[$i].LastWriteTime))" -ForegroundColor Yellow
}
$projectSelection = Read-Host "Select a project to fix (default 0)"
if ($projectSelection -eq "") { $projectSelection = 0 }
$selectedProject = $projects[$projectSelection]


# Delete stuff
if (Test-Path "$($selectedProject.Folder)\bin") {
    Remove-Item "$($selectedProject.Folder)\bin" -Recurse -Force
}
if (Test-Path "$($selectedProject.Folder)\obj") {
    Remove-Item "$($selectedProject.Folder)\obj" -Recurse -Force
}

Write-Host "Fix applied"
