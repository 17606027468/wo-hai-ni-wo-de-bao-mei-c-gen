<#
  成本计算器 · 一键部署到 GitHub Pages
  ------------------------------------------------------------
  运行前准备：
    1. 已注册并登录 GitHub（邮箱已验证）
    2. 已生成 Classic Token，并勾选了 repo 权限
  运行方式：
    双击同目录下的 deploy-to-github.cmd
  说明：
    - 脚本会自动：创建仓库 → 上传全部文件 → 开启 GitHub Pages → 输出网址
    - Token 只在本机内存里使用，不保存、不上传、不发给任何人
#>
param(
  [string]$RepoName = 'cost-calculator',
  [string]$Username = '',
  [switch]$DryRun,
  [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Api = 'https://api.github.com'
$AppDir = Join-Path $PSScriptRoot 'stone-cost-app'

function Exit-With([int]$code) {
  if (-not $NoPause) { Read-Host '按回车退出' | Out-Null }
  exit $code
}

if (-not (Test-Path -LiteralPath $AppDir)) {
  Write-Host '× 找不到 stone-cost-app 文件夹。' -ForegroundColor Red
  Write-Host '  请把本脚本放在 stone-cost-app 的上一级目录里再运行。'
  Exit-With 1
}

$fileList = @()
Get-ChildItem -LiteralPath $AppDir -Recurse -File |
  Where-Object { $_.Name -ne '_headers' } |
  ForEach-Object {
    $fileList += [pscustomobject]@{
      Path     = $_.FullName.Substring($AppDir.Length + 1).Replace('\', '/')
      FullName = $_.FullName
      Size     = $_.Length
    }
  }

if ($DryRun) {
  Write-Host '文件检查（DryRun，不联网）：'
  foreach ($f in $fileList) { Write-Host ('  {0} ({1} 字节)' -f $f.Path, $f.Size) }
  Write-Host ('共 {0} 个文件，目录：{1}' -f $fileList.Count, $AppDir)
  Exit-With 0
}

Write-Host ''
Write-Host '=== 成本计算器 · 一键部署到 GitHub Pages ===' -ForegroundColor Cyan
Write-Host ''

$Token = $env:GITHUB_TOKEN
if ([string]::IsNullOrWhiteSpace($Token)) {
  if ([string]::IsNullOrWhiteSpace($Username)) {
    $Username = (Read-Host '输入你的 GitHub 用户名').Trim()
  }
  Write-Host '粘贴 Token 时不会显示，粘贴后按回车即可。'
  $secureToken = Read-Host '粘贴 GitHub Token' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
  try {
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

if ([string]::IsNullOrWhiteSpace($Token)) {
  Write-Host '× Token 不能为空。' -ForegroundColor Red
  Exit-With 1
}

$script:Headers = @{
  Authorization = 'token ' + $Token
  Accept        = 'application/vnd.github+json'
  'User-Agent'  = 'cost-calculator-deploy'
}

function Invoke-GitHub {
  param([string]$Method, [string]$Path, $Body)
  $request = @{
    Uri        = $Api + $Path
    Method     = $Method
    Headers    = $script:Headers
    TimeoutSec = 60
  }
  if ($null -ne $Body) {
    $request['Body'] = ($Body | ConvertTo-Json -Depth 12 -Compress)
    $request['ContentType'] = 'application/json; charset=utf-8'
  }
  Invoke-RestMethod @request
}

function Get-HttpStatus($err) {
  try { return [int]$err.Exception.Response.StatusCode } catch { return 0 }
}

function Get-ApiErrorText($err) {
  try {
    $response = $err.Exception.Response
    if ($response) {
      $stream = $response.GetResponseStream()
      if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $text = $reader.ReadToEnd()
        $reader.Close()
        return ('HTTP ' + [int]$response.StatusCode + '：' + $text)
      }
    }
  } catch { }
  return $err.Exception.Message
}

try {
  Write-Host '[1/5] 验证 Token 和账号 …'
  $me = Invoke-GitHub -Method GET -Path '/user'
  if (-not [string]::IsNullOrWhiteSpace($Username) -and $Username -ne $me.login) {
    Write-Host ('      注意：Token 属于账号 {0}，将使用该账号。' -f $me.login) -ForegroundColor Yellow
  }
  $Username = $me.login
  Write-Host ('      ✓ 已登录：{0}' -f $Username) -ForegroundColor Green

  Write-Host '[2/5] 创建（或复用）仓库 …'
  $repo = $null
  try {
    $repo = Invoke-GitHub -Method POST -Path '/user/repos' -Body @{
      name        = $RepoName
      private     = $false
      description = '成本计算器：输入总价值和每人占比，自动计算每人成本'
      auto_init   = $false
    }
    Write-Host ('      ✓ 已创建：{0}' -f $repo.full_name) -ForegroundColor Green
  } catch {
    $status = Get-HttpStatus $_
    if ($status -eq 422) {
      $repo = Invoke-GitHub -Method GET -Path ('/repos/' + $Username + '/' + $RepoName)
      Write-Host ('      仓库已存在，继续更新：{0}' -f $repo.full_name) -ForegroundColor Yellow
    } else { throw }
  }

  Write-Host '[3/5] 上传文件 …'
  $treeItems = @()
  $index = 0
  foreach ($item in $fileList) {
    $index++
    Write-Host ('      [{0}/{1}] {2}' -f $index, $fileList.Count, $item.Path)
    $bytes = [IO.File]::ReadAllBytes($item.FullName)
    $blob = Invoke-GitHub -Method POST -Path ('/repos/' + $Username + '/' + $RepoName + '/git/blobs') -Body @{
      content  = [Convert]::ToBase64String($bytes)
      encoding = 'base64'
    }
    $treeItems += @{
      path = $item.Path
      mode = '100644'
      type = 'blob'
      sha  = $blob.sha
    }
  }
  $tree = Invoke-GitHub -Method POST -Path ('/repos/' + $Username + '/' + $RepoName + '/git/trees') -Body @{ tree = $treeItems }

  Write-Host '[4/5] 提交代码并开启 GitHub Pages …'
  $branch = $repo.default_branch
  $parents = @()
  try {
    $ref = Invoke-GitHub -Method GET -Path ('/repos/' + $Username + '/' + $RepoName + '/git/ref/heads/' + $branch)
    $parents = @($ref.object.sha)
  } catch { }

  $commit = Invoke-GitHub -Method POST -Path ('/repos/' + $Username + '/' + $RepoName + '/git/commits') -Body @{
    message = 'deploy: 成本计算器'
    tree    = $tree.sha
    parents = $parents
  }

  try {
    Invoke-GitHub -Method POST -Path ('/repos/' + $Username + '/' + $RepoName + '/git/refs') -Body @{
      ref = 'refs/heads/' + $branch
      sha = $commit.sha
    } | Out-Null
  } catch {
    Invoke-GitHub -Method PATCH -Path ('/repos/' + $Username + '/' + $RepoName + '/git/refs/heads/' + $branch) -Body @{
      sha   = $commit.sha
      force = $false
    } | Out-Null
  }

  try {
    Invoke-GitHub -Method POST -Path ('/repos/' + $Username + '/' + $RepoName + '/pages') -Body @{
      source = @{ branch = $branch; path = '/' }
    } | Out-Null
  } catch {
    $status = Get-HttpStatus $_
    if ($status -eq 409 -or $status -eq 422) {
      Invoke-GitHub -Method PUT -Path ('/repos/' + $Username + '/' + $RepoName + '/pages') -Body @{
        source = @{ branch = $branch; path = '/' }
      } | Out-Null
    } else { throw }
  }

  $url = 'https://' + $Username + '.github.io/' + $RepoName + '/'
  Write-Host '[5/5] 等待网站上线（通常 1–2 分钟）…'
  Write-Host ('      网址：{0}' -f $url) -ForegroundColor Cyan

  $online = $false
  for ($attempt = 1; $attempt -le 36; $attempt++) {
    Start-Sleep -Seconds 5
    try {
      $probe = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
      if ($probe.StatusCode -eq 200) { $online = $true; break }
    } catch { }
  }

  Write-Host ''
  if ($online) {
    Write-Host '✓ 部署成功，网站已经上线！' -ForegroundColor Green
    Start-Process $url
  } else {
    Write-Host '✓ 文件已上传、Pages 已开启。' -ForegroundColor Green
    Write-Host '  网站可能还在构建，稍等 1–2 分钟手动打开：'
    Write-Host ('  {0}' -f $url)
  }
  Write-Host ''
  Write-Host '下一步：iPhone 用 Safari 打开上面的网址'
  Write-Host '        → 点底部「分享」→「添加到主屏幕」→ 添加'
  Write-Host ''
  Write-Host '安全提示：部署完成后，建议到 GitHub 删除这个 Token。'
  Exit-With 0
} catch {
  Write-Host ''
  Write-Host '× 部署失败' -ForegroundColor Red
  Write-Host (Get-ApiErrorText $_)
  Write-Host ''
  Write-Host '排查提示：'
  Write-Host '  · 401：Token 复制不完整或已过期 → 重新生成'
  Write-Host '  · 403：Token 没有勾选 repo 权限'
  Write-Host '  · 422：仓库名被占用 → 把脚本开头的 RepoName 改成别的名字'
  Write-Host '  · 网络错误：检查是否能正常访问 github.com'
  Write-Host ''
  Write-Host '把上面的报错文字发给我（注意不要带 Token）'
  Exit-With 1
}
