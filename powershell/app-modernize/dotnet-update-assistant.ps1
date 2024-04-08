# Assume $args[0] is the solution directory and $args[1] (optional) is the new target framework
$solutionDir = $args[0]
$newTargetFramework = if ($args.Count -gt 1) { $args[1] } else { "net8.0" }

# Initialize an array to keep track of errors
$global:errors = @()

# Function to parse a project file and find its references
function Get-ProjectReferences {
    param (
        [string]$ProjectPath
    )
    Write-Host "Processing project: $($ProjectPath)"

    [xml]$projectXml = Get-Content $ProjectPath
    $references = $projectXml.Project.ItemGroup.ProjectReference.Include
    if ($null -eq $references -or $references.Count -eq 0) {
        # Return an empty array if no references are found
        return @()
    } else {
        return $references
    }
}

# Function to build a dependency graph
function Build-DependencyGraph {
    param (
        [System.Collections.Generic.Dictionary[string, string[]]]$graph,
        [System.IO.FileInfo[]]$projects
    )

    foreach ($project in $projects) {
        $references = Get-ProjectReferences -ProjectPath $project.FullName
        $refPaths = $references | ForEach-Object { $_.Replace("..\","$solutionDir\") }
        $graph[$project.FullName] = @($refPaths)
    }
}

# Function to sort projects based on their dependencies
function Topological-Sort {
    param (
        [System.Collections.Generic.Dictionary[string, string[]]]$graph
    )

    $noIncomingEdges = @()
    $sortedList = @()

    # Find nodes with no incoming edges
    foreach ($node in $graph.Keys) {
        $isIncomingEdge = $false
        foreach ($edgeList in $graph.Values) {
            if ($edgeList -contains $node) {
                $isIncomingEdge = $true
                break
            }
        }
        if (-not $isIncomingEdge) {
            $noIncomingEdges += $node
        }
    }

    while ($noIncomingEdges.Count -gt 0) {
        $n = $noIncomingEdges[0]
        $noIncomingEdges = $noIncomingEdges[1..$noIncomingEdges.Count]
        $sortedList += $n
        if ($graph.ContainsKey($n)) {
            foreach ($m in $graph[$n]) {
                $graph[$n] = @($graph[$n] | Where-Object { $_ -ne $m })
                $isIncomingEdge = $false
                foreach ($edgeList in $graph.Values) {
                    if ($edgeList -contains $m) {
                        $isIncomingEdge = $true
                        break
                    }
                }
                if (-not $isIncomingEdge -and -not $noIncomingEdges -contains $m) {
                    $noIncomingEdges += $m
                }
            }
        }
    }

    # Cycle Detection
    foreach ($key in $graph.Keys) {
        if ($graph[$key].Count -gt 0) {
            $errorMsg = "Potential Cycle detected involving: $key"
            foreach ($dep in $graph[$key]) {
                $errorMsg += "`n  Unresolved dependency: $dep"
            }
            $global:errors += $errorMsg
            Write-Host $errorMsg
        }
    }

    return $sortedList
}


# Function to update NuGet packages in a project file to the latest version
function Update-NuGetPackagesToLatestVersion {
    param (
        [string]$ProjectPath
    )

        Write-Host "Updating packages in project $ProjectPath to the latest version..."
    # Extract all PackageReference items from the project file
    [xml]$projectXml = Get-Content $ProjectPath
    $packageReferences = $projectXml.Project.ItemGroup.PackageReference

    foreach ($package in $packageReferences) {
        $packageName = $package.Include

        if (-not [string]::IsNullOrWhiteSpace($packageName)) {
            Write-Host "Updating package $packageName for project $ProjectPath to the latest version..."
            try {
                dotnet add "$ProjectPath" package $packageName -v n 2>&1 | Out-Null 
            } catch {
                $global:errors += "Error updating $packageName in $ProjectPath : $_"
            }
        }
    }
}

# Get all project files in the solution directory
$projectFiles = Get-ChildItem -Path $solutionDir -Recurse -Filter "*.csproj"

# Update the target framework for each project file
#foreach ($projectFile in $projectFiles) {
#    [xml]$projectContent = Get-Content $projectFile.FullName
#
#    # Check if the project file already uses the new target framework
#    $currentFramework = $projectContent.Project.PropertyGroup.TargetFramework
#    if ($currentFramework -ne $newTargetFramework) {
#        # Update the TargetFramework element
#        $projectContent.Project.PropertyGroup.TargetFramework = $newTargetFramework
#
#        # Save the updated project file
#        $projectContent.Save($projectFile.FullName)
#        Start-Sleep -Milliseconds 100
#        Write-Host "Updated target framework for $($projectFile.Name) to $newTargetFramework"
#    }
#    else {
#        Write-Host "$($projectFile.Name) already targets $newTargetFramework"
#    }
#}

# Build dependency graph
$dependencyGraph = New-Object 'System.Collections.Generic.Dictionary[string, string[]]'
Build-DependencyGraph -graph $dependencyGraph -projects $projectFiles

# Sort projects based on their dependencies
$sortedProjects = Topological-Sort -graph $dependencyGraph

# Update projects and NuGet packages based on the sorted order
Write-Host "Updating Packages in Projects... $sortedProjects"
foreach ($projectPath in $sortedProjects) {
    [xml]$projectContent = Get-Content $projectPath

    # Check if the project file already uses the new target framework
    $currentFramework = $projectContent.Project.PropertyGroup.TargetFramework
    if ($currentFramework -ne $newTargetFramework) {
        upgrade-assistant upgrade $projectPath --operation Inplace --non-interactive --targetFramework $newTargetFramework
        Write-Host "Updated target framework for $($projectPath) to $newTargetFramework"
    }
    else {
        Write-Host "$($projectPath) already targets $newTargetFramework"
    }
}

# Build the solution to verify if the migration was successful
Write-Host "Building Solution..."
$solutionFile = Get-ChildItem -Path $solutionDir -Filter *.sln | Select-Object -First 1 -ExpandProperty FullName

try {
    dotnet restore $solutionFile
} catch {
    $global:errors += "Solution restore failed for $solutionFile : $_"
}

try {
    dotnet build $solutionFile --configuration Release --framework $newTargetFramework
} catch {
    $global:errors += "Solution build failed for $solutionFile : $_"
}


if ($global:errors.Count -gt 0) {
    Write-Host "Migration encountered errors:"
    $global:errors | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "Migration completed without errors."
}

Write-Host "Migration process completed. Please check the build output for errors and warnings."