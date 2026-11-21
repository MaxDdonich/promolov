# ============================================================
# PromoLov local server + LAN access (no Node.js/Python).
# Start: powershell -ExecutionPolicy Bypass -File serve.ps1
#
# Listens on 0.0.0.0:8787. Other devices in the same Wi-Fi can
# open http://<your-ip>:8787/ .
# ============================================================
param(
  [switch]$NoCollect,
  [int]$Port = 8787,
  [string]$BindAddress = '0.0.0.0'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }
$rootFull = [IO.Path]::GetFullPath($root)

$collector = Join-Path $root 'collector.ps1'
$feedFile = Join-Path $root 'data\codes.json'
$collectorJob = $null

if (-not $NoCollect -and (Test-Path $collector)) {
  $stale = $true
  if (Test-Path $feedFile) {
    $stale = ((Get-Date) - (Get-Item $feedFile).LastWriteTime).TotalMinutes -ge 30
  }
  if ($stale) {
    Write-Host 'Collecting promo codes (first run)...'
    try {
      & powershell -NoProfile -ExecutionPolicy Bypass -File $collector -OutFile $feedFile -Force
    } catch {
      Write-Host "Collector failed: $($_.Exception.Message)"
    }
  }

  try {
    $collectorJob = Start-Job -ScriptBlock {
      param($script, $out)
      while ($true) {
        Start-Sleep -Minutes 30
        & powershell -NoProfile -ExecutionPolicy Bypass -File $script -OutFile $out -Force | Out-Null
      }
    } -ArgumentList $collector, $feedFile
    Write-Host 'Background collector started (every 30 min).'
  } catch {
    Write-Host "Background collector not started: $($_.Exception.Message)"
  }
}

function Get-LanIp {
  try {
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
      Where-Object { $_.NextHop -ne '0.0.0.0' } |
      Sort-Object RouteMetric |
      Select-Object -First 1
    if ($route) {
      $addr = Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notmatch '^169\.254\.' } |
        Select-Object -First 1
      if ($addr) { return $addr.IPAddress }
    }
  } catch { }
  try {
    $addr = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254\.' } |
      Select-Object -First 1
    if ($addr) { return $addr.IPAddress }
  } catch { }
  return $null
}

$lanIp = Get-LanIp
$lanUrl = if ($lanIp) { "http://${lanIp}:$Port/" } else { "" }

$csharp = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

public class PromoLovHttpServer
{
    private readonly string root;
    private readonly int port;
    private readonly string lanUrl;
    private TcpListener listener;
    private volatile bool running;

    public PromoLovHttpServer(string root, int port, string lanUrl)
    {
        this.root = Path.GetFullPath(root);
        this.port = port;
        this.lanUrl = lanUrl ?? "";
    }

    public void Start()
    {
        listener = new TcpListener(IPAddress.Any, port);
        listener.Server.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        listener.Start();
        running = true;
        Thread thread = new Thread(AcceptLoop);
        thread.IsBackground = true;
        thread.Start();
    }

    public void Stop()
    {
        running = false;
        if (listener != null) { try { listener.Stop(); } catch { } }
    }

    private void AcceptLoop()
    {
        while (running)
        {
            TcpClient client = null;
            try
            {
                client = listener.AcceptTcpClient();
                TcpClient captured = client;
                ThreadPool.QueueUserWorkItem(delegate { HandleClient(captured); });
            }
            catch
            {
                if (client != null) { try { client.Close(); } catch { } }
                if (!running) break;
                Thread.Sleep(50);
            }
        }
    }

    private void HandleClient(TcpClient client)
    {
        try
        {
            client.ReceiveTimeout = 10000;
            client.SendTimeout = 10000;
            client.NoDelay = true;

            using (NetworkStream stream = client.GetStream())
            using (StreamReader reader = new StreamReader(stream, Encoding.ASCII, false, 1024, true))
            {
                string requestLine = reader.ReadLine();
                if (string.IsNullOrEmpty(requestLine)) return;
                bool acceptsGzip = false;
                string header;
                while (!string.IsNullOrEmpty(header = reader.ReadLine()))
                {
                    if (header.StartsWith("Accept-Encoding:", StringComparison.OrdinalIgnoreCase) &&
                        header.IndexOf("gzip", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        acceptsGzip = true;
                    }
                }

                string[] parts = requestLine.Split(' ');
                if (parts.Length < 2) return;
                string method = parts[0].ToUpperInvariant();
                if (method != "GET" && method != "HEAD")
                {
                    WriteResponse(stream, 405, "Method Not Allowed", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Method not allowed"), method != "HEAD", false);
                    return;
                }

                string target = parts[1];
                int queryIndex = target.IndexOf('?');
                if (queryIndex >= 0) target = target.Substring(0, queryIndex);

                string path;
                try { path = Uri.UnescapeDataString(target); } catch { path = target; }
                if (string.IsNullOrEmpty(path) || path == "/") path = "/index.html";

                if (path == "/api/info")
                {
                    string json = "{\"hostName\":\"" + Escape(Environment.MachineName) + "\",\"port\":" + port +
                                  ",\"localUrl\":\"http://localhost:" + port + "/\",\"lanUrl\":\"" + Escape(lanUrl) + "\"}";
                    WriteResponse(stream, 200, "OK", "application/json; charset=utf-8", Encoding.UTF8.GetBytes(json), method != "HEAD", acceptsGzip);
                    return;
                }

                string relative = path.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
                string file = Path.GetFullPath(Path.Combine(root, relative));
                string rootPrefix = root.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
                if (!file.StartsWith(rootPrefix, StringComparison.OrdinalIgnoreCase) && !string.Equals(file, root, StringComparison.OrdinalIgnoreCase))
                {
                    WriteResponse(stream, 403, "Forbidden", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Forbidden"), method != "HEAD", false);
                    return;
                }

                if (File.Exists(file))
                {
                    byte[] body = File.ReadAllBytes(file);
                    WriteResponse(stream, 200, "OK", GetContentType(Path.GetExtension(file)), body, method != "HEAD", acceptsGzip);
                }
                else
                {
                    WriteResponse(stream, 404, "Not Found", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Not found"), method != "HEAD", false);
                }
            }
        }
        catch
        {
            // Broken client; ignore.
        }
        finally
        {
            try { client.Close(); } catch { }
        }
    }

    private static string Escape(string value)
    {
        if (value == null) return "";
        return value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "").Replace("\n", "");
    }

    private static void WriteResponse(NetworkStream stream, int code, string text, string contentType, byte[] body, bool includeBody, bool gzip)
    {
        bool compressed = false;
        if (gzip && body.Length > 512 && IsCompressible(contentType))
        {
            body = Compress(body);
            compressed = true;
        }

        string header = "HTTP/1.1 " + code + " " + text + "\r\n" +
                        "Content-Type: " + contentType + "\r\n" +
                        "Content-Length: " + body.Length + "\r\n" +
                        (compressed ? "Content-Encoding: gzip\r\nVary: Accept-Encoding\r\n" : "") +
                        "Cache-Control: no-store\r\n" +
                        "Access-Control-Allow-Origin: *\r\n" +
                        "Connection: close\r\n\r\n";
        byte[] headerBytes = Encoding.ASCII.GetBytes(header);
        stream.Write(headerBytes, 0, headerBytes.Length);
        if (includeBody && body.Length > 0) stream.Write(body, 0, body.Length);
        stream.Flush();
    }

    private static bool IsCompressible(string contentType)
    {
        return contentType.StartsWith("text/", StringComparison.OrdinalIgnoreCase) ||
               contentType.IndexOf("json", StringComparison.OrdinalIgnoreCase) >= 0 ||
               contentType.IndexOf("javascript", StringComparison.OrdinalIgnoreCase) >= 0 ||
               contentType.IndexOf("svg", StringComparison.OrdinalIgnoreCase) >= 0;
    }

    private static byte[] Compress(byte[] data)
    {
        using (MemoryStream output = new MemoryStream())
        {
            using (GZipStream gzip = new GZipStream(output, CompressionMode.Compress, true))
            {
                gzip.Write(data, 0, data.Length);
            }
            return output.ToArray();
        }
    }

    private static string GetContentType(string extension)
    {
        switch ((extension ?? "").ToLowerInvariant())
        {
            case ".html": return "text/html; charset=utf-8";
            case ".css": return "text/css; charset=utf-8";
            case ".js": return "application/javascript; charset=utf-8";
            case ".json": return "application/json; charset=utf-8";
            case ".svg": return "image/svg+xml";
            case ".png": return "image/png";
            case ".jpg":
            case ".jpeg": return "image/jpeg";
            case ".webp": return "image/webp";
            case ".ico": return "image/x-icon";
            case ".woff2": return "font/woff2";
            case ".txt":
            case ".md": return "text/plain; charset=utf-8";
            default: return "application/octet-stream";
        }
    }
}
'@

Add-Type -TypeDefinition $csharp -Language CSharp

$server = New-Object PromoLovHttpServer($rootFull, $Port, $lanUrl)
$server.Start()

Write-Host ''
Write-Host 'PromoLov is running:'
Write-Host "  this computer: http://localhost:$Port/"
if ($lanUrl) {
  Write-Host "  LAN / Wi-Fi:   $lanUrl" -ForegroundColor Green
  Write-Host '  Open the LAN link on another device in the same Wi-Fi network.'
}
Write-Host ''
Write-Host 'If another device cannot connect, run "Разрешить в брандмауэре.bat" once'
Write-Host '(adds a Windows Firewall rule for TCP 8787; requires administrator).'
Write-Host 'For a public internet link run "Публичная ссылка.bat".'
Write-Host ''

while ($true) {
  Start-Sleep -Seconds 3600
}
