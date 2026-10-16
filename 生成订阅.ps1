param(
    [Parameter(Mandatory = $true)]
    [string]$BaseUrl
)

$ErrorActionPreference = 'Stop'
$baseUri = [uri]$BaseUrl
if (-not $baseUri.IsAbsoluteUri -or $baseUri.Scheme -notin @('http', 'https') -or $baseUri.Query -or $baseUri.Fragment) {
    throw '请输入文件所在目录的完整 HTTP/HTTPS 地址，不要包含查询参数或 #。'
}
$BaseUrl = $BaseUrl.TrimEnd('/')
$preferred = 'xiaoban.js', 'tgchannel.js', 'labi.js', 'huban.js', 'ouge.js', 'tgsou.js', 'shandian.js'
$allFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter '*.js' | Sort-Object Name | Select-Object -ExpandProperty Name)
$files = @($preferred | Where-Object { $_ -in $allFiles }) + @($allFiles | Where-Object { $_ -notin $preferred })
if ($files.Count -eq 0) { throw '目录中没有 JS 模块。' }
$seenIds = @{}
$widgets = foreach ($file in $files) {
    $source = Get-Content -LiteralPath (Join-Path $PSScriptRoot $file) -Raw -Encoding UTF8
    $metadata = [ordered]@{}
    if ($source.StartsWith('REXENC')) {
        Write-Warning "跳过加密模块 $file：缺少可核实的 ID、版本等清单信息，暂不加入订阅。"
        continue
    } else {
    foreach ($field in @('id', 'title', 'description', 'requiredVersion', 'version', 'author')) {
        $match = [regex]::Match($source, '(?m)^\s*' + $field + ':\s*"([^"\r\n]*)"')
        if (-not $match.Success) { throw "文件 $file 缺少元数据：$field" }
        $metadata[$field] = $match.Groups[1].Value
    }
    if ($seenIds.ContainsKey($metadata['id'])) { throw "重复模块 ID：$($metadata['id'])" }
    $seenIds[$metadata['id']] = $true
    }
    $metadata['url'] = "$BaseUrl/$([uri]::EscapeDataString($file))"
    $metadata
}
$subscription = [ordered]@{
    title = '网盘模块合集'
    description = (@($widgets | ForEach-Object { $_['title'] }) -join '、')
    icon = "$BaseUrl/icon.png"
    widgets = @($widgets)
}
$json = $subscription | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'widgets.fwd'), $json, [System.Text.UTF8Encoding]::new($false))
Write-Output "已生成 widgets.fwd，共 $($widgets.Count) 个模块。"
Write-Output "上传这 $($widgets.Count) 个 JS、icon.png 和 widgets.fwd 后，在 Rex 模块库导入处填写：$BaseUrl/widgets.fwd"
