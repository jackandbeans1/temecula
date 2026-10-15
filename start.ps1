# TEMECULA MEGA STACK v5 — server + multi-upstream proxy (byte-safe)
param(
  [int]$Port=8787,
  [string]$VeniceKey=$env:VENICE_API_KEY,
  [string]$OpenRouterKey=$env:OPENROUTER_API_KEY,
  [string]$GroqKey=$env:GROQ_API_KEY,
  [string]$DeepSeekKey=$env:DEEPSEEK_API_KEY,
  [switch]$Open
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path

Add-Type -AssemblyName System.Net.Http | Out-Null

$UP=@{}
if($VeniceKey)    {$UP['venice']    =@('https://api.venice.ai/api/v1',$VeniceKey)}
if($OpenRouterKey){$UP['openrouter']=@('https://openrouter.ai/api/v1',$OpenRouterKey)}
if($GroqKey)      {$UP['groq']      =@('https://api.groq.com/openai/v1',$GroqKey)}
if($DeepSeekKey)  {$UP['deepseek']  =@('https://api.deepseek.com/v1',$DeepSeekKey)}
$UP['ollama']   =@('http://localhost:11434/v1','')
$UP['lmstudio'] =@('http://localhost:1234/v1','')
$UP['a1111']    =@('http://localhost:7860','')

if(-not $VeniceKey){
  $k=Read-Host 'Venice API key (blank to skip)'
  if($k){$UP['venice']=@('https://api.venice.ai/api/v1',$k)}
}

$http=[System.Net.Http.HttpClient]::new()
$http.Timeout=[TimeSpan]::FromSeconds(300)

$l=[System.Net.HttpListener]::new()
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "`n  TEMECULA MEGA STACK v5  ->  http://localhost:$Port/`n" -ForegroundColor Magenta
Write-Host "  proxied: $($UP.Keys -join ', ')`n  Ctrl+C to stop`n" -ForegroundColor DarkGray
if($Open){Start-Process "http://localhost:$Port/"}

# always bytes in, always bytes out
function Reply($c,[byte[]]$bytes,[string]$ct){
  $c.Response.ContentType=$ct
  $c.Response.ContentLength64=$bytes.Length
  if($bytes.Length -gt 0){$c.Response.OutputStream.Write($bytes,0,$bytes.Length)}
  $c.Response.Close()
}
function ReplyJson($c,[string]$s){ Reply $c ([Text.Encoding]::UTF8.GetBytes($s)) 'application/json; charset=utf-8' }

$types=@{'.html'='text/html; charset=utf-8';'.js'='application/javascript; charset=utf-8';'.css'='text/css; charset=utf-8'}

while($l.IsListening){
  $c=$l.GetContext()
  try{
    $p=$c.Request.Url.AbsolutePath

    if($p -match '^/p/([^/]+)/(.*)$'){
      $name=$Matches[1]; $rest=$Matches[2]
      if(-not $UP.ContainsKey($name)){throw "no upstream '$name'"}
      $target=$UP[$name][0].TrimEnd('/')+'/'+$rest
      $key=$UP[$name][1]

      # read body as bytes -> string
      $ms=[IO.MemoryStream]::new()
      $c.Request.InputStream.CopyTo($ms)
      $bodyBytes=$ms.ToArray(); $ms.Dispose()
      $body=[Text.Encoding]::UTF8.GetString($bodyBytes)

      $req=[System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::new($c.Request.HttpMethod), $target)
      if($body){
        $req.Content=[System.Net.Http.StringContent]::new($body,[Text.Encoding]::UTF8,'application/json')
      }
      if($key){
        $req.Headers.Authorization=[System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer',$key)
      }

      $resp=$http.SendAsync($req).GetAwaiter().GetResult()
      $out=$resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
      $ct=$resp.Content.Headers.ContentType.ToString()
      if(-not $ct){$ct='application/json'}
      $c.Response.StatusCode=[int]$resp.StatusCode
      Reply $c $out $ct
      $req.Dispose(); $resp.Dispose()
    }
    else{
      $f=if($p -eq '/' -or $p -eq '/index.html'){'index.html'}else{$p.TrimStart('/')}
      $full=Join-Path $root $f
      if(Test-Path $full){
        $ext=[IO.Path]::GetExtension($full)
        $ct=if($types.ContainsKey($ext)){$types[$ext]}else{'application/octet-stream'}
        Reply $c ([IO.File]::ReadAllBytes($full)) $ct
      } else {
        $c.Response.StatusCode=404; $c.Response.Close()
      }
    }
  }
  catch{
    $msg='{"error":"'+($_.Exception.Message -replace '\\','\\' -replace '"','\"')+'"}'
    try{ ReplyJson $c $msg }catch{}
  }
}