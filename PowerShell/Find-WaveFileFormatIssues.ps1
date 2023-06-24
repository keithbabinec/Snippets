<#
    .SYNOPSIS
        Scans a folder (recursively) to detect .wav files that might be incompatible on Pioneer DJ equipment.

    .DESCRIPTION
        Scans a folder (recursively) to detect .wav files that might be incompatible on Pioneer DJ equipment.
        
        IMPORTANT: this is a 'detection only' script-- in that it identifies specific issues. The most common 
        fix to apply would be to re-encoded the file to the correct format in an audio editor like Audacity.

        If the script returns no output: double check that the folder you pointed it to actually has 
        .wav files present.

    .PARAMETER FolderPath
        Specify the folder path to search recursively.

    .EXAMPLE
        PS C:\> .\Find-WaveFileFormatIssues.ps1 -FolderPath 'D:\music\imports'
        Runs the script against files against the specified folder and returns all output.

    .EXAMPLE
        PS C:\> .\Find-WaveFileFormatIssues.ps1 -FolderPath 'D:\music\imports' | Format-List FileName, Result
        Runs the script against files against the specified folder and returns all output, formatted as 
        list instead of table and excludes the full file path from the output.

    .EXAMPLE
        PS C:\> .\Find-WaveFileFormatIssues.ps1 -OnlyReturnInvalidFiles -FolderPath 'D:\music\imports' | Format-List FileName, Result
        Runs the script against files against the specified folder and returns only the invalid files, 
        and formats the output as a list.
#>
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true)]
    [System.String]
    $FolderPath,

    [Parameter(Mandatory=$false)]
    [Switch]
    $OnlyReturnInvalidFiles
)

$errorInvalidWave = "Unexpected file format headers (missing RIFF or WAVE)"
$errorJunkPadding = "Unexpected file format headers (JUNK padding)"
$errorBitDepth = "Unexpected bit depth (not 16 or 24 bits)"
$errorWaveExt = "Unexpected wav format (WaveFormatExtensible)"
$ok = "OK"

Class WavResult
{
    [string]$Result
    [string]$FileName
    [string]$FullName

    WavResult($file, $result)
    {
        $this.Result = $result
        $this.FullName = $file.FullName
        $this.FileName = $file.Name
    }
}

$results = New-Object -TypeName 'System.Collections.Generic.List[WavResult]'

foreach ($file in Get-ChildItem -Path $FolderPath -Filter *.wav -Recurse)
{
    # read the first 44 bytes to collect header information.

    Write-Verbose "Processing file: $($file.FullName)"
    
    $fileHandle = [System.IO.File]::OpenRead($file.FullName)
    $bytes = New-Object -TypeName System.Byte[] -ArgumentList 44
    $null = $fileHandle.Read($bytes, 0, $bytes.Length)
    $fileHandle.Close()
    
    # is this a wav file?
    
    if (($bytes[0] -ne [int]([char]'R')) -or 
        ($bytes[1] -ne [int]([char]'I')) -or 
        ($bytes[2] -ne [int]([char]'F')) -or 
        ($bytes[3] -ne [int]([char]'F')))
    {
        # riff bytes not present.
        $results.Add([WavResult]::New($file, $errorInvalidWave))
        continue
    }
    
    if (($bytes[8] -ne [int]([char]'W')) -or 
        ($bytes[9] -ne [int]([char]'A')) -or 
        ($bytes[10] -ne [int]([char]'V')) -or 
        ($bytes[11] -ne [int]([char]'E')))
    {
        # wave bytes not present.
        $results.Add([WavResult]::New($file, $errorInvalidWave))
        continue
    }

    if (($bytes[12] -eq [int]([char]'J')) -and 
        ($bytes[13] -eq [int]([char]'U')) -and
        ($bytes[14] -eq [int]([char]'N')) -and 
        ($bytes[15] -eq [int]([char]'K')))
    {
        # some files may have extra 'JUNK' padding in the beginning which changes
        # the length of the header information. Pioneer unit should still play
        # this type of file fine, but its an uncommon format and I like to re-encoded
        # these anyway for consistency.
        $results.Add([WavResult]::New($file, $errorJunkPadding))
        continue
    }
    
    # Check if the file is a supported bit depth.
    # Pioneer units will most commonly support 16 and 24 bit wav. 
    # 32-bit wav files will typically be unsupported.
    
    if ($bytes[34] -ne 16 -and $bytes[34] -ne 24)
    {
        $results.Add([WavResult]::New($file, $errorBitDepth))
        continue
    }
    
    # Check if wav format is Linear PCM or WaveFormatExtensible.
    # This is because some Pioneer units will throw an E-8305 Unsupported message 
    # when attempting to play WaveFormatExtensible files.
    
    if ($bytes[20] -eq 254)
    {
        $results.Add([WavResult]::New($file, $errorWaveExt))
        continue
    }

    $results.Add([WavResult]::New($file, $ok))
}

if ($PSBoundParameters.ContainsKey("OnlyReturnInvalidFiles"))
{
    $results | Where-Object -Property Result -ne $ok
}
else
{
    $results
}
