# Use the first script argument as the target directory
$targetDirectory = $args[0]

# Find all .json files recursively in the target directory
$jsonFiles = Get-ChildItem -Path $targetDirectory -Filter *.json -Recurse
$schemaMarker = "https://schema.management"

foreach ($file in $jsonFiles) {
    # Read the content of the JSON file as a single string
    $content = Get-Content -Path $file.FullName -Raw

    # Check if the content contains the required schema URL
    if ($content -match [regex]::Escape($schemaMarker)) {
        # Construct the output Bicep file path
        $bicepFilePath = $file.FullName -replace '\.json$', '.bicep'

        # Run Bicep decompile
        & bicep decompile $file.FullName --outfile $bicepFilePath
        
        Write-Output "Decompiled `'$($file.FullName)`' to `'$bicepFilePath`'"
    }
    else {
        Write-Output "Skipped `'$($file.FullName)`' as it does not contain the required schema."
    }
}

Write-Output "Decompile process completed."
