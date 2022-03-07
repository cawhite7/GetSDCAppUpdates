
# Hiding Progress Bar significantly increases download speed, created a separate script with a progress bar that is called
$ProgressPreference = 'SilentlyContinue'

##################### Application Updater

#############
###############
################# SDC Apps

# List of Apps to get
$getAppsFilter = @(
             'Google Chrome',
             'Microsoft NetBanner',
             'Mozilla Firefox',
             'Adobe Acrobat Professional DC Update'
             )

# Pull Website links and store cookie in SDCSession Variable using CAC Certificate

$getCert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object {$_.FriendlyName -like "Authentication - *"}

if (!$getCert) {

    Write-Host "`nCOULD NOT LOAD CERTIFICATE`n" -ForegroundColor Red

    exit

}

try {

    $sdcRequest = (Invoke-WebRequest -Uri https://ceds.gunter.af.mil/AISHome.aspx?AIS=92 -CertificateThumbprint $getCert.Thumbprint -SessionVariable SDCSession).Links

} catch {

    Write-Host "`nFailed to Request Website" -ForegroundColor Red

    pause

    exit

}
# Filter Website Links to only download links and exclude Microsoft Office and hash txt files
$sdcRequestFilter = $sdcRequest | Where-Object {(($_.href -like "*Download*" -and $_.innerText -notlike "SDC NIPR - *") -and $_.innerText -notlike "*Microsoft_Office_2016*") -and $_.innerText -notlike "* hash.txt"}

# Loop through each object in the Filter request

try {

    foreach ($sdc in $sdcRequestFilter) {

        # Split working object by dashes into a string array and trim off spaces. Then each line remove .zip or .txt
        $innerText = (($sdc.innerText).Split('-')).Trim() | foreach {($_ -replace ".zip","") -replace ".txt",""}

        # Add strings as properties to custom object being stored in an array called sdcApps
        [array]$sdcApps += [PSCustomObject]@{
    
            Classification = $innerText[0]
            Name = $innerText[1]
            Version = $innerText[2]

        }
    
    }

} catch {

    Write-Host "`nFailed sdcApps loop" -ForegroundColor Red

    pause

    exit

}

# Pathing
$sdcRootPath = "\\REMOVEDPATH\SDC App Updates"
$sdcAppPath = "$($sdcRootPath)\SDC Apps"
New-Item -Path "\\REMOVEDPATH\Reference Library" -Name 'SDC App Updates' -ItemType Directory -Force | Out-Null

# Places path in variable with current date formatting file name as SDCVersions_yyyyMMdd.csv (ex. SDCVersions_20210521.csv)
$sdcVersionsPath = "$($sdcRootPath)\$(Get-Date -Format 'yyyyMMdd')_SDCVersions.csv"

# Exports custom objects to csv
$sdcApps | Export-Csv -Path $sdcVersionsPath -NoTypeInformation -Force

### Check for Updates (ie. newer versions)

# Get CSVs and sort by most recent then select the 2 most recent
$getCSVs = Get-ChildItem -Path $sdcRootPath -Filter *.csv | Sort-Object -Descending | Select-Object -First 2

# Import CSVs as objects select the most recent by array of 0 and older CSV
$newCSV = Import-Csv -Path $getCSVs[0].FullName
if ($getCSVs.Count -ne  1) {

    $oldCSV = Import-Csv -Path $getCSVs[1].FullName

}

# Detect any new software
foreach ($newRow in $newCSV) {

    $match = $oldCSV | Where-Object {$_.Name -eq $newRow.Name}

    if (!$match) {

        [array]$notFound += $newRow

    }

}

# Log and report any new software
if ($notFound) {

    $notFound | Out-File -FilePath "$($sdcRootPath)\$(Get-Date -Format 'yyyyMMdd')_NewSoftware.txt" -Encoding ascii -Force

    Write-Host "`n:: New Software ::" -ForegroundColor Green

    foreach ($nf in $notFound) {

        Write-Host "$($nf.Name)" -ForegroundColor Green

    }

    Write-Host "`n"

}

# Reset Variable
$notFound = $null

# Detect any old software
foreach ($oldRow in $oldCSV) {

    $match = $newCSV | Where-Object {$_.Name -eq $oldRow.Name}

    if (!$match) {

        [array]$notFound += $oldRow

    }

}

# Log and report and removed software
if ($notFound) {
    
    $notFound | Out-File -FilePath "$($sdcRootPath)\$(Get-Date -Format 'yyyyMMdd')_RemovedSoftware.txt" -Encoding ascii -Force

    Write-Host "`n:: Removed Software ::" -ForegroundColor Yellow

    foreach ($nf in $notFound) {

        Write-Host "$($nf.Name)" -ForegroundColor Yellow

    }

    Write-Host "`n"

}

# Get app objects from Apps Filter
[array]$getApps = $newCSV | Where-Object {$_.Name -in $getAppsFilter}

# Verify Apps exist
[array]$validateApp = $getAppsFilter | Where-Object {$_ -notin $newCSV.Name}

# If validateApp is not null then if condition is true and report
if ($validateApp) {

    Write-Host "`nCould not find the following app(s)!!:" -ForegroundColor Red
    
    foreach ($app in $validateApp) {

        Write-Host $app -ForegroundColor Red

    }

    Write-Host "`nExiting Script. Please check variable getAppsFilter or CSV list for comparison"

    pause

    exit

}

# Loop through each app to get and store in a variable new, same, and regressed versions
foreach ($app in $getApps) {

    $oVersion = $oldCSV | Where-Object {$_.Name -eq $app.Name} | Select-Object -ExpandProperty Version
    $nVersion = $newCSV | Where-Object {$_.Name -eq $app.Name} | Select-Object -ExpandProperty Version

    if ($nVersion -gt $oVersion) {

        [array]$newVersions += $app

    } elseif ($nVersion -lt $oVersion) {

        [array]$regressedVersions += $app

    } else {

        [array]$sameVersions += $app
        
    }

}

# Log and report regressed Versions
if ($regressedVersions) {
    
    $regressedVersions | Out-File -FilePath "$($sdcRootPath)\$(Get-Date -Format 'yyyyMMdd')_RegressedSoftware.txt" -Encoding ascii -Force

    Write-Host "`n:: Regressed Versions ::" -ForegroundColor Yellow

    foreach ($rv in $regressedVersions) {

        Write-Host "$($rv.Name)" -ForegroundColor Yellow

    }

    Write-Host "`n"

}

# Log and report new Versions
if ($newVersions) {

    $newVersions | Out-File -FilePath "$($sdcRootPath)\$(Get-Date -Format 'yyyyMMdd')_NewVersions.txt" -Encoding ascii -Force

    Write-Host "`n:: New Versions ::" -ForegroundColor Green

    foreach ($nv in $newVersions) {

        Write-Host "$($nv.Name)" -ForegroundColor Green

    }

    Write-Host "`n"

}

################### Download New Software Versions

if ($newVersions) {

    Remove-Item -Path "$($sdcRootPath)\_DVD" -ErrorAction Ignore -Recurse -Force

    New-Item -Path "$($sdcRootPath)" -Name _DVD -ItemType Directory -ErrorAction Ignore -Force

    New-Item -Path "$($sdcRootPath)" -Name 'SDC Apps' -ItemType Directory -ErrorAction Ignore -Force

    Write-Host "`nDownloading new software versions" -ForegroundColor Green

}

foreach ($app in $newVersions) {

    New-Item -Path "$($sdcAppPath)\$($app.Name)" -Name "$($app.Version)" -ItemType Directory -Force | Out-Null

    Write-Host "`nDownloading $($app.Name)" -ForegroundColor Green

    $reconstructInnerText = $app.Classification + " - " + $app.Name + " - " + $app.Version

    $appLink = $sdcRequestFilter | Where-Object {$_.innerText -like "$($reconstructInnerText)*"}

    [int64]$fileSize = (Invoke-WebRequest -Uri "https://ceds.gunter.af.mil$($appLink.href)" -WebSession $SDCSession -Method Head).Headers.'Content-Length'

    Copy-Item -Path "$($sdcRootPath)\Script\ProgressBar.ps1" -Destination "$($env:windir)\Temp"

    Start-Process -FilePath powershell -ArgumentList "-File ""$($env:windir)\Temp\ProgressBar.ps1"" ""$($app.Name)"" $($fileSize) ""$($sdcAppPath)\$($app.Name)\$($app.Version)\$($appLink.innerText)"""

    Start-Sleep -Seconds 1
    
    $download = Invoke-WebRequest -Uri "https://ceds.gunter.af.mil$($appLink.href)" -WebSession $SDCSession -OutFile "$($sdcAppPath)\$($app.Name)\$($app.Version)\$($appLink.innerText)"

    $hashLink = $sdcRequest | Where-Object {$_.innerText -like "$($reconstructInnerText) hash.txt"}

    $downloadHash = Invoke-WebRequest -Uri "https://ceds.gunter.af.mil$($hashLink.href)" -WebSession $SDCSession -OutFile "$($sdcAppPath)\$($app.Name)\$($app.Version)\$($hashLink.innerText)"

    Write-Host "`nFinished Downloading $($app.Name)" -ForegroundColor Green

    $getContentHash = (Get-Content "$($sdcAppPath)\$($app.Name)\$($app.Version)\$($hashLink.innerText)" | Select-String -Pattern "Hash:").Line.Substring(6)

    Write-Host "`nCalculating Hash" -ForegroundColor Green

    $getHash = Get-FileHash -Path "$($sdcAppPath)\$($app.Name)\$($app.Version)\$($appLink.innerText)" -Algorithm SHA256 | Select-Object -ExpandProperty Hash

    if ($getContentHash -ne $getHash) {

        [array]$failedHash += $app

        Write-Host "`nHash does NOT match" -ForegroundColor Red

    } else {

        Write-Host "`nHash Matched" -ForegroundColor Green
        New-Item -Path "$($sdcRootPath)\_DVD" -Name "$($app.Name)" -ItemType Directory -Force
        New-Item -Path "$($sdcRootPath)\_DVD\$($app.Name)" -Name "$($app.Version)" -ItemType Directory -Force
        Copy-Item -Path "$($sdcAppPath)\$($app.Name)\$($app.Version)" -Destination "$($sdcRootPath)\_DVD\$($app.Name)" -Recurse -Force

    }

}

if ($failedHash) {

    Write-Host "`nFAILED HASHES:" -ForegroundColor Red

    foreach ($fh in $failedHash) {

        Write-Host "$($fh)" -ForegroundColor Red

    }

    Write-Host "PLEASE DELETE Apps listed AND RESTART" -ForegroundColor Red

    pause

    exit

}

if (!$newVersions) {

    Write-Host "NO NEW SOFTWARE" -ForegroundColor Green

}

Write-Host "`nFINISHED" -ForegroundColor Green

if ($newVersions) {

    explorer "$($sdcRootPath)\_DVD"

}

pause