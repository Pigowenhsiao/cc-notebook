param(
    [Parameter(Mandatory = $true)]
    [string]$IdsFile,

    [Parameter(Mandatory = $true)]
    [string]$SessionLog,

    [Parameter(Mandatory = $true)]
    [string]$VaultRoot,

    [string]$OutRelativeDir = "Learning/notion-ai-database-full-sync"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-IdList {
    param([string]$Path)
    $ids = @()
    Get-Content -Path $Path | ForEach-Object {
        if ($_ -match '`([0-9a-f]{32})`') {
            $ids += $Matches[1].ToLower()
        }
    }
    return $ids
}

function Convert-ToDashedId {
    param([string]$Id32)
    if ($Id32 -notmatch '^[0-9a-f]{32}$') {
        return $Id32
    }
    return "{0}-{1}-{2}-{3}-{4}" -f $Id32.Substring(0, 8), $Id32.Substring(8, 4), $Id32.Substring(12, 4), $Id32.Substring(16, 4), $Id32.Substring(20, 12)
}

function Sanitize-FileName {
    param([string]$Name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars() + [char[]]':\/?*"<>|'
    $s = $Name
    foreach ($c in $invalid) {
        $s = $s.Replace([string]$c, "-")
    }
    $s = ($s -replace "\s+", " ").Trim()
    if ([string]::IsNullOrWhiteSpace($s)) {
        $s = "untitled"
    }
    if ($s.Length -gt 120) {
        $s = $s.Substring(0, 120).Trim()
    }
    return $s
}

function Extract-TagBlock {
    param(
        [string]$Text,
        [string]$TagName
    )
    $pattern = "<$TagName>\s*(?<body>[\s\S]*?)\s*</$TagName>"
    $m = [regex]::Match($Text, $pattern)
    if ($m.Success) {
        return $m.Groups["body"].Value
    }
    return ""
}

$ids = Get-IdList -Path $IdsFile
$idSet = New-Object System.Collections.Generic.HashSet[string]
$ids | ForEach-Object { [void]$idSet.Add($_) }

$callIdToId = @{}
$pageDataById = @{}

Get-Content -Path $SessionLog | ForEach-Object {
    $line = $_
    if ([string]::IsNullOrWhiteSpace($line)) {
        return
    }

    try {
        $obj = $line | ConvertFrom-Json -Depth 100
    } catch {
        return
    }

    if ($obj.type -eq "response_item" -and $obj.payload.type -eq "function_call" -and $obj.payload.name -eq "mcp__notion__notion_fetch") {
        try {
            $argObj = $obj.payload.arguments
            if ($argObj -is [string]) {
                $argObj = $argObj | ConvertFrom-Json -Depth 20
            }
            $pageIdRaw = [string]$argObj.id
            $pageId = ($pageIdRaw -replace "-", "").ToLower()
            if ($idSet.Contains($pageId)) {
                $callIdToId[[string]$obj.payload.call_id] = $pageId
            }
        } catch {
        }
        return
    }

    if ($obj.type -eq "event_msg" -and $obj.payload.type -eq "mcp_tool_call_end") {
        try {
            $callId = [string]$obj.payload.call_id
            if (-not $callIdToId.ContainsKey($callId)) {
                return
            }
            $pageId = $callIdToId[$callId]
            $textBlob = [string]$obj.payload.result.Ok.content[0].text
            if ([string]::IsNullOrWhiteSpace($textBlob)) {
                return
            }
            $pageObj = $textBlob | ConvertFrom-Json -Depth 100
            $pageDataById[$pageId] = $pageObj
        } catch {
        }
    }
}

$outDir = Join-Path $VaultRoot $OutRelativeDir
New-Item -Path $outDir -ItemType Directory -Force | Out-Null

$report = New-Object System.Collections.Generic.List[object]
$now = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")

foreach ($id in $ids) {
    if (-not $pageDataById.ContainsKey($id)) {
        $report.Add([pscustomobject]@{
                id      = $id
                status  = "missing_in_session_log"
                file    = ""
                title   = ""
                url     = "https://www.notion.so/$id"
            })
        continue
    }

    $p = $pageDataById[$id]
    $title = [string]$p.title
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = "notion-page-$id"
    }
    $safeTitle = Sanitize-FileName -Name $title
    $fileName = "$safeTitle-$id.md"
    $filePath = Join-Path $outDir $fileName

    $url = [string]$p.url
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = "https://www.notion.so/$id"
    }

    $rawView = [string]$p.text
    $propertiesBody = Extract-TagBlock -Text $rawView -TagName "properties"
    $contentBody = Extract-TagBlock -Text $rawView -TagName "content"
    if ([string]::IsNullOrWhiteSpace($contentBody)) {
        $contentBody = "_（此頁無可抽取的 content 區段）_"
    }

    $escapedTitle = $title.Replace('"', '\"')
    $dashed = Convert-ToDashedId -Id32 $id

    $noteLines = @(
        "---",
        "title: `"$escapedTitle`"",
        "source_url: `"$url`"",
        "source_page_id: `"$dashed`"",
        "processed: true",
        "sync_method: `"notion-fetch-session-log`"",
        "synced_at: `"$now`"",
        "---",
        "",
        "# $title",
        "",
        "## Source",
        "- Notion URL: $url",
        "- Page ID: $id",
        "",
        "## Content (Notion 原文)",
        $contentBody,
        "",
        "## Properties Snapshot",
        "~~~json",
        $propertiesBody,
        "~~~",
        "",
        "## Raw Notion View Snapshot",
        "~~~xml",
        $rawView,
        "~~~"
    )
    $note = $noteLines -join "`n"

    [System.IO.File]::WriteAllText($filePath, $note, [System.Text.Encoding]::UTF8)

    $report.Add([pscustomobject]@{
            id     = $id
            status = "imported"
            file   = $filePath
            title  = $title
            url    = $url
        })
}

$manifestJsonPath = Join-Path $outDir "_manifest.json"
$manifestCsvPath = Join-Path $outDir "_manifest.csv"
$json = $report | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($manifestJsonPath, $json, [System.Text.Encoding]::UTF8)
$csv = $report | ConvertTo-Csv -NoTypeInformation
[System.IO.File]::WriteAllText($manifestCsvPath, ($csv -join "`n"), [System.Text.Encoding]::UTF8)

$importedCount = ($report | Where-Object { $_.status -eq "imported" } | Measure-Object).Count
$missingCount = ($report | Where-Object { $_.status -ne "imported" } | Measure-Object).Count

Write-Output "IMPORTED=$importedCount"
Write-Output "MISSING=$missingCount"
Write-Output "OUT_DIR=$outDir"
Write-Output "MANIFEST_JSON=$manifestJsonPath"
Write-Output "MANIFEST_CSV=$manifestCsvPath"
