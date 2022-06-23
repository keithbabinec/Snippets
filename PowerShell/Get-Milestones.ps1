$ErrorActionPreference = "Stop"

# import NodaTime assembly (at least v3). 
# this provides accurate timespan calculations (like months and years)
# that are difficult to do natively in .NET

if (!(Test-Path -Path ".\NodaTime.dll"))
{
    throw "NodaTime.dll v3.x is required."
}

Add-Type -Path ".\NodaTime.dll"

$dates = [ordered]@{
    "Milestone 1" = [NodaTime.LocalDate]::new(2015, 5, 12)
    "Milestone 2" = [NodaTime.LocalDate]::new(2022, 6, 20)
    "Milestone 3" = [NodaTime.LocalDate]::new(2018, 12, 5)
}

$zone = [NodaTime.DateTimeZoneProviders]::Tzdb["Pacific/Pitcairn"]
$clock = ([NodaTime.SystemClock]::Instance.GetCurrentInstant()).InZone($zone)
$today = $clock.LocalDateTime.Date

foreach ($item in $dates.GetEnumerator())
{
    $diff = [NodaTime.Period]::Between($item.Value, $today)

    $years = $diff.Years
    $months = $diff.Months
    $days = $diff.Days

    Write-Host "$($item.Key): $years year(s), $months month(s), $days day(s)."
}
