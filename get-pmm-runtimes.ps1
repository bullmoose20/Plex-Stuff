$logFile = "\\nzwhs01\appdata\kometa\logs\meta.log"
# Read the log file and split it into lines
$lines = Get-Content $logFile

# Create an empty array to store the collections and their times
$collections = @()

# Loop through each line in the log file
foreach ($line in $lines) {
    # Check if the line contains the word "Finished"
    if ($line -match "Finished") {
        # Extract the collection name
        $collection = ($line -split "Finished")[1].Trim().TrimEnd(" ", "|")

        # Extract the operation by taking the last word in the line
        switch (($line -replace " *\|$", "").Trim().Split(" ")[-1]) {
            "Collection" { $operation = "Collection" }
            "Overlay" { $operation = "Overlay" }
            "Playlist" { $operation = "Playlist" }
        }
    }

    # Check if the line contains the word "Run Time"
    if ($line -match "Run Time:") {
        # Extract the time and remove the trailing white spaces and pipe character
        $time = ($line -split "Run Time: ")[1].Trim().TrimEnd(" ", "|")

        # Check if the time variable is not null
        if ($time) {
            # Add the collection, operation, and time to the collections array
            $collections += New-Object -TypeName PSObject -Property @{
                Collection = $collection
                Operation  = $operation
                Time       = [timespan]::Parse($time)
            }
        }
    }
}

# Sort the collections by operation and return the result
$collections | Sort-Object -Property Time -Descending | Select-Object Collection, Time, Operation | Out-GridView # | Format-Table -AutoSize
