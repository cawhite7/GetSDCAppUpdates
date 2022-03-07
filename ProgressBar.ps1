param ([string]$app,[int64]$fileSize,[string]$filePath)

while (!(Test-Path -Path $filePath)) {

    Start-Sleep -Milliseconds 20

}
<#
Function Get-TimeLeft {

    param(
        [datetime[]]$Time,
        [int]$p
    )

    if ($Time.Count -ge 5) {

        $totalTime = (New-TimeSpan -Start $time[-5] -End $time[-1]).TotalMilliseconds / 1000

        $avg = $totalTime / 5

        $remainingPercentage = 100 - $time.Count

        $estimatedSecondsLeft = $avg * $remainingPercentage

        $timeLeft = "$([math]::Floor($estimatedSecondsLeft / 60)) Minutes and " + "$([math]::Round($estimatedSecondsLeft % 60)) Seconds Left"

        return "$($timeLeft) @"

    }

}#>

Function Get-Speed {

    param(

        [array]$aSize

    )

    if ($aSize.Count -ge 5) {

        $diffMB = ($aSize[-1] - $aSize[-10]) / 1024 / 1024 / 5

        return "$([math]::Round($diffMB, 2)) MB/s"

    }

}

do {

    $currentSize = (Get-Item -Path $filePath).Length

    [array]$arraySize += $currentSize

    if ($arraySize.Count -gt 10) {

        $arraySize += $arraySize[-10..-1]

    }

    #$oPercent = $percent

    $percent = [math]::Round(($currentSize / $fileSize) * 100)

    #[datetime[]]$timeKeep += Get-Date

    #$tL = $(Get-TimeLeft -Time $timeKeep)

    Write-Progress -Activity "Downloading $app" -Status "$($percent)% Complete    $(Get-Speed -aSize $arraySize)" -PercentComplete $([math]::Round($percent))

    Start-Sleep -Seconds 1

} while ($currentSize -lt $fileSize)
