#region thiết lập hệ thống
class System_Utils {
    static [bool] Is_User_Admin () {
        $user = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($user)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    static [void] Load_Notification ([string]$Noidung, [int]$Loai) {
        $prefix = ""
        $color = "White"
        switch ($Loai) {
            1 { $prefix = "[INFO]";    $color = "Cyan"; break }
            2 { $prefix = "[OK]";      $color = "Green"; break }
            3 { $prefix = "[ERROR]";   $color = "Red"; break }
            4 { $prefix = "[WARNING]"; $color = "Yellow"; break }
            default { $prefix = "[LOG]"; $color = "White" }
        }
        Write-Host "$prefix $Noidung" -ForegroundColor $color
    }
    static [bool] Is_Install ([string]$Ten) {
        $cmd = Get-Command $Ten -ErrorAction SilentlyContinue
        if ($cmd) {
            $path = $cmd.Source
            $type = $cmd.CommandType
            [System_Utils]::Load_Notification("✅ [$type] $Ten đã được cài đặt tại: $path", 2)
            return $true
        } else {
            [System_Utils]::Load_Notification("$Ten chưa được cài đặt hoặc không có trong PATH.", 3)
            return $false
        }
    }
    static [void] Load_Countdown([int]$Thoi_Gian) {
        try {
            if ($Thoi_Gian -le 0) {
                Write-Progress -Activity "Đang chờ..." -Status "Không cần đợi!" -Completed
                return
            }
            for ($i = $Thoi_Gian; $i -ge 1; $i--) {
                $percent = if ($Thoi_Gian -ne 0) { ((($Thoi_Gian - $i) / $Thoi_Gian) * 100) } else { 100 }
                Write-Progress -Activity "Đang chờ..." -Status "$i giây còn lại..." -PercentComplete $percent
                Start-Sleep -Seconds 1
            }
            Write-Progress -Activity "Đang chờ..." -Status "Hoàn tất" -Completed
        }catch{
            [System_Utils]::Load_Notification("loi o [System_Utils]Load_Countdown", 3)
        }
    }
    static [void] Create_New_Window([string]$Command, [bool]$LoadAdmin = $false) {
        if (-not $Command) { return }

        $guid = [guid]::NewGuid().ToString()
        $tempFile = "$env:TEMP\run_temp_$guid.ps1"
        $scriptContent = "try { $Command } finally { Remove-Item -Path `"$tempFile`" -Force }"

        Set-Content -Path $tempFile -Value $scriptContent -Encoding UTF8

        $argsPS = @("-ExecutionPolicy", "Bypass", "-File", $tempFile)
        try {
            if ($LoadAdmin) {
                Start-Process powershell -ArgumentList $argsPS -Verb RunAs
            } else {
                Start-Process powershell -ArgumentList $argsPS
            }
        } catch {
            [System_Utils]::Load_Notification("Không thể tạo cửa sổ mới: $($_.Exception.Message)", 3)
        }
    }
    static [void] Run_Admin([string]$Command) {
        if (-not $Command) {
            [System_Utils]::Load_Notification("Lệnh không hợp lệ, không thể chạy!", 3)
            return
        }

        try {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -Verb RunAs
            [System_Utils]::Load_Notification("🚀 Đã gửi lệnh với quyền Admin: $Command", 1)
        } catch {
            [System_Utils]::Load_Notification("Không thể chạy lệnh Admin: $($_.Exception.Message)", 3)
        }
    }
    static [void] Check_Internet() {
        try {
            $url = "https://www.google.com"
            $result = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
            if ($result.StatusCode -ne 200) {
                throw "Không thể kết nối."
            }
        } catch {
            [System_Utils]::Load_Notification("❌ Không có kết nối Internet. Thoát chương trình!", 3)
            exit
        } 
    }
}
#endregion
#region thiết lập packages manager
Class Packages_Manager {
    static [void] Install () {
         throw "Class con phải override"
    }
    static [void] Install_Packages ([string[]]$Ten) {
        throw "Class con phải override"
    }
    static [bool] Check_Package ([string[]]$Ten) {
        return $false
    }
}
class Scoop : Packages_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("scoop")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Scoop...", 1)
            Invoke-RestMethod https://get.scoop.sh | Invoke-Expression
        }
    }
    static [void] Install_Packages([string[]]$Input_Packages) {
        foreach ($Ten in $Input_Packages) {
            [Scoop]::Check_Package($Ten) | Out-Null
            [System_Utils]::Load_Notification("Đang cài đặt: $Ten", 1)
            scoop install $Ten
        }
    }
    static [void] Install_Bucket ([string[]]$Buckets) {
        foreach ($bucket in $Buckets) {
            if (-not [Scoop]::Check_Package($bucket)) {
                scoop bucket add $bucket
            }
        }
        [System_Utils]::Load_Notification("Đã thêm các bucket cần thiết.", 2)
    }
    static [bool] Check_Package([string]$Ten) {
        $scoopList = scoop list 2>$null
        return ($scoopList -match "^\s*$Ten\s")
    }
}
class Winget : Packages_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("winget")) {
            [System_Utils]::Load_Notification("Winget không khả dụng trên hệ thống này!", 3)
            throw "Winget không được cài sẵn. Hãy cập nhật Windows hoặc dùng Scoop/Choco thay thế."
        }
    }
    static [void] Install_Packages ([string[]]$Packages) {
        if (![System_Utils]::Is_Install($Packages)) {
            foreach ($Name in $Packages) {
                if (-not [Winget]::Check_Package($Name)) {
                    [System_Utils]::Load_Notification("Cài đặt: $Name", 1)
                    winget install $Name -e --accept-source-agreements --accept-package-agreements
                } else {
                    [System_Utils]::Load_Notification("✅ $Name đã được cài đặt.", 2)
                    continue
                }
            }
        } else {
            [System_Utils]::Load_Notification("✅ $Packages đã được cài đặt.", 2)
        }
    }
    static [bool] Check_Package([string]$Ten) {
        $installed = winget list --name $Ten 2>$null
        return $null -ne ($installed | Where-Object { $_ -match "^$Ten" })
    }
}
class Windows_Features : Packages_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("Enable-WindowsOptionalFeature")) {
        [System_Utils]::Load_Notification("Enable-WindowsOptionalFeature không khả dụng trên hệ thống này!", 3)
        throw "Enable-WindowsOptionalFeature không được hỗ trợ. Hãy cập nhật Windows hoặc dùng Scoop/Choco thay thế."
        }
    }
    static [void] Install_Packages ([string[]]$Ten) {
        foreach ($feature in $Ten) {
                [System_Utils]::Run_Admin("Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart")
                [System_Utils]::Load_Notification("✅ Đã cài đặt: $feature", 2)
        }
    }
    static [bool] Check_Package([string]$Ten) {
        return $false
    }
}
#endregion
#region thiết lập tools
class Tools_Manager {
    static [void] Install () {
        throw "Class con phải override"
    }
    static [void] Config (){
        throw "Class con phải override"
    }
}
class Git : Tools_Manager {
    static[void] Install () {
        if (-not [System_Utils]::Is_Install("git")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Git...", 1)
            [Scoop]::Install_Packages("git")
            [System_Utils]::Load_Notification("Git đã được cài đặt thành công!", 2)
        } 
    }
    static [void] Config () {
        [git]::Configure_git()
    }
    static [void] Configure_git () {
        $Name = "Mr.thai-" + $env:COMPUTERNAME
        $Email = "mr.thai2k5@gmail.com"
        try {
            git config --global user.name  $Name
            git config --global user.email $Email
            [System_Utils]::Load_Notification("Đã cấu hình Git với tên: $Name và email: $Email", 2)
        } catch {
            [System_Utils]::Load_Notification("Lỗi khi cấu hình Git: $($_.Exception.Message)", 3)
        }
    }
}
Class Vscode : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("vscode")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Visual Studio Code...", 1)
            [Scoop]::Install_Packages("vscode")
            [System_Utils]::Load_Notification("Visual Studio Code đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
        [System_Utils]::Load_Notification("Cài đặt extension vscode",2)
        $extension_vscode = @(
            "ms-vscode.powershell",                     # PowerShell
            "esbenp.prettier-vscode",                   # Prettier
            "dbaeumer.vscode-eslint",                   # ESLint
            "christian-kohler.path-intellisense",       # Path Intellisense
            "formulahendry.auto-rename-tag",            # Auto Rename Tag
            "dracula-theme.theme-dracula",              # Dracula Theme
            "burkeholland.simple-react-snippets",       # Simple React Snippets
            "bradlc.vscode-tailwindcss",                # Tailwind CSS IntelliSense
            "ritwickdey.liveserver",                    # Live Server
            "streetsidesoftware.code-spell-checker",    # Code Spell Checker
            "wayou.vscode-todo-highlight",              # TODO Highlight
            "alefragnani.bookmarks",                    # Bookmarks
            "eamodio.gitlens"                           # GitLens
        )
        [Vscode]::Install_extension($extension_vscode)
    }
    static [void] Install_extension ([string[]] $extensions){
        foreach ($ext in $extensions){
            [System_Utils]::Load_Notification("Đang cài đặt extension : $ext", 1)
            code --install-extension $ext
        }
    }
}
Class Obsidian : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("obsidian")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Obsidian...", 1)
            [scoop]::Install_Packages("obsidian")
            [System_Utils]::Load_Notification("Obsidian đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
}
Class ObsStudio : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("obs-studio")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt OBS Studio...", 1)
            [Scoop]::Install_Packages("obs-studio")
            [System_Utils]::Load_Notification("OBS Studio đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
}
class Idm : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("idm")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Internet Download Manager...", 1)
            [Winget]::Install_Packages("Tonec.InternetDownloadManager")
            [System_Utils]::Load_Notification("Internet Download Manager đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
    static [void] crack_Idm (){
        [System_Utils]::Run_Admin("iex(irm is.gd/idm_reset)")
    }
}
class Docker : Tools_Manager {
    static [void] install (){
        if (-not [System_Utils]::Is_Install("docker")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Docker...", 1)
            [Winget]::Install_Packages("Docker.DockerDesktop")
            [System_Utils]::Load_Notification("Docker đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
}
class VisualStudio : Tools_Manager{
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("Microsoft.VisualStudio.2022.Community.Preview")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Visual Studio...", 1)
            winget install Microsoft.VisualStudio.2022.Community.Preview -e --accept-source-agreements --accept-package-agreements
            [System_Utils]::Load_Notification("Visual studio đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
}
class AndroidStudio : Tools_Manager{
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("android-studio")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Android Studio...", 1)
            scoop install extras/android-studio
            [System_Utils]::Load_Notification("Android Studio đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
}
class Office : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("Office")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Office...", 1)
            winget install Microsoft.Office -e --accept-source-agreements --accept-package-agreements
            [System_Utils]::Load_Notification("Office đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
        [Office]::Activate_KMS_All()
    }
    static [void] Activate_KMS_All() {
        $url = "irm https://get.activated.win | iex"
        [System_Utils]::Create_New_Window($url, $true)
    }
}
class TeraCopy : Tools_Manager{
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("teracopy")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt TeraCopy...", 1)
            [Winget]::Install_Packages("teracopy")
            [System_Utils]::Load_Notification("TeraCopy đã được cài đặt thành công!", 2)
        }
    }
    static [void] Config () {
    }
}
class LazyVim : Tools_Manager {
    static [void] Install () {
        [LazyVim]::Install_NVim()
        [LazyVim]::Install_Fonts()
        [LazyVim]::Install_LazyVim()
        [System_Utils]::Load_Notification("🎉 LazyVim đã được cài đặt thành công!", 2)
    }
    static [void] Config () {
        [System_Utils]::Load_Notification("⚙️ LazyVim Đang được thiết lập.", 1)
        [LazyVim]::Install_Packages()
        [LazyVim]::Sync_Plugin()
        [System_Utils]::Load_Notification("⚙️ LazyVim đã sẵn sàng để sử dụng.", 2)
    }
    static [void] Install_NVim () {
        if (-not [System_Utils]::Is_Install("nvim")) {
            [System_Utils]::Load_Notification("🔧 Đang cài Neovim...", 1)
            [Scoop]::Install_Packages("neovim")
            [System_Utils]::Load_Notification("✅ Neovim đã được cài đặt!", 2)
        }
    }
    static [void] Install_Fonts () {
        $tempDir = "$env:TEMP\NerdFonts"
        $extractPath = "$tempDir\Extracted"
        $fontsPath = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"

        if (-not (Test-Path $fontsPath)) {
            New-Item -Path $fontsPath -ItemType Directory -Force | Out-Null
        }

        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $extractPath -ItemType Directory -Force | Out-Null

        try {
            Expand-Archive ".\File_Config\FiraCode.zip" -DestinationPath $extractPath -Force

            Get-ChildItem -Path $extractPath -Filter *.ttf | ForEach-Object {
                Copy-Item $_.FullName -Destination "$fontsPath\$($_.Name)" -Force
                Write-Host "✅ Font: $($_.Name)"
                [System_Utils]::Load_Countdown
            }

            [System_Utils]::Load_Notification("✅ Nerd Font đã được cài đặt!", 2)
        } catch {
            [System_Utils]::Load_Notification("❌ Lỗi font: $($_.Exception.Message)", 3)
        }
    }
    static [void] Install_LazyVim () {
        $nvimPath = "$env:LOCALAPPDATA\nvim"
        if (Test-Path $nvimPath) { Remove-Item $nvimPath -Recurse -Force }
        [System_Utils]::Load_Notification("🌀 Đang clone LazyVim config...", 1)

        git clone https://github.com/LazyVim/starter $nvimPath
        Remove-Item "$nvimPath\.git" -Recurse -Force -ErrorAction SilentlyContinue
    }
    static [void] Install_Packages () {
        $pkgs = @("curl", "wget", "gcc", "make", "unzip", "ripgrep", "fd", "llvm", "zig")
        foreach ($p in $pkgs) {
            if (-not [System_Utils]::Is_Install($p)) {
                Write-Host "📦 Cài package: $p..."
                [Scoop]::Install_Packages($p)
            }
        }
    }
    static [void] Sync_Plugin () {
        [System_Utils]::Load_Notification("🔁 Đồng bộ plugin LazyVim...", 1)
        try {
            nvim --headless "+qall"
            nvim --headless "+Lazy! sync" +qa
            [System_Utils]::Load_Notification("✅ Đã đồng bộ plugin LazyVim", 2)
        } catch {
            [System_Utils]::Load_Notification("⚠️ Lỗi khi sync plugin: $($_.Exception.Message)", 3)
        }
    }
}
class Scrcpy : Tools_Manager{
    static [void] Install() {
        $url = "https://github.com/Genymobile/scrcpy/releases/download/v2.4/scrcpy-win64-v2.4.zip"
        $tempZip = "$env:TEMP\scrcpy.zip"
        $extractDir = "$env:LOCALAPPDATA\scrcpy"
        try {
            Write-Host "📥 Đang tải Scrcpy từ GitHub..."
            Invoke-WebRequest -Uri $url -OutFile $tempZip -UseBasicParsing
            if (Test-Path $extractDir) {
                Remove-Item -Path $extractDir -Recurse -Force
            }
            Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force
            $inner = Get-ChildItem $extractDir | Where-Object { $_.PSIsContainer } | Select-Object -First 1
            if ($inner -and (Test-Path "$($inner.FullName)\scrcpy.exe")) {
                Move-Item -Path "$($inner.FullName)\*" -Destination $extractDir -Force
                Remove-Item $inner.FullName -Recurse -Force
            }
            $env:Path += ";$extractDir"
            if (Get-Command "scrcpy" -ErrorAction SilentlyContinue) {
                Write-Host "✅ Đã cài đặt Scrcpy thành công!"
            } else {
                Write-Host "❌ Cài đặt thất bại, không tìm thấy scrcpy.exe"
            }
        } catch {
            Write-Host "❌ Lỗi khi cài Scrcpy: $($_.Exception.Message)"
        } finally {
            if (Test-Path $tempZip) {
                Remove-Item $tempZip -Force
            }
        }
    }
    static [void] Config () {

    }
}
class WSL : Tools_Manager {
    static [void] Install () {
      
    }

    static [void] Config () {
       
    }
}

#endregion
#region thiết lập Windows
class Setup_Win {
    static [void] Disable_UAC () {
        [System_Utils]::Load_Notification("🔧 Đang vô hiệu hóa UAC...", 1)
        $cmd = 'Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -Force'
        try {
            [System_Utils]::Run_Admin($cmd)
        } catch {
            [System_Utils]::Load_Notification("Không thể vô hiệu hóa UAC: $($_.Exception.Message)", 3)
        }
    }
    static [void] Set_TimeZone_UTC8() {
        $tzId = "SE Asia Standard Time"
        try {
            $currentTz = (Get-TimeZone).Id
            if ($currentTz -eq $tzId) {
                [System_Utils]::Load_Notification("⏲️ Múi giờ đã là $tzId, không cần thay đổi.", 1)
                return
            }

            [System_Utils]::Load_Notification("🌏 Đang đặt múi giờ về UTC+8 ($tzId)...", 1)
            Set-TimeZone -Id $tzId
            [System_Utils]::Load_Notification("✅ Đã đặt múi giờ thành công.", 2)
        } catch {
            [System_Utils]::Load_Notification("Lỗi khi đặt múi giờ: $($_.Exception.Message)", 3)
        }
    }
    static [void] Install_VC_AllInOne() {
        $url       = "https://github.com/abbodi1406/vcredist/releases/latest/download/VisualCppRedist_AIO_x86_x64.exe"
        $file      = "$env:TEMP\VisualCppRedist_AIO.exe"
        $vcRegKeys = @(
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86"
        )

        try {
            # Kiểm tra đã cài đặt VC++ chưa
            $isInstalled = $false
            foreach ($key in $vcRegKeys) {
                if (Test-Path $key) {
                    $isInstalled = $true
                    break
                }
            }

            if ($isInstalled) {
                [System_Utils]::Load_Notification("✅ Visual C++ Redistributable đã tồn tại. Bỏ qua cài đặt.", 0)
                return
            }

            [System_Utils]::Load_Notification("📥 Đang tải Visual C++ Redistributable AIO...", 1)

            # Tải file nếu chưa tồn tại
            if (-not (Test-Path $file)) {
                [System_Utils]::Run_Admin("Invoke-WebRequest -Uri '$url' -OutFile '$file' -UseBasicParsing")
            } else {
                [System_Utils]::Load_Notification("🔄 File đã tồn tại. Sử dụng lại để cài đặt.", 1)
            }

            # Cài đặt silent với tham số /y
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Visual C++ Redistributable...", 1)
            [System_Utils]::Run_Admin("Start-Process -FilePath '$file' -ArgumentList '/y' -Wait")

            [System_Utils]::Load_Notification("✅ Hoàn tất cài đặt Visual C++ Redistributable.", 2)
        } catch {
            [System_Utils]::Load_Notification("Lỗi khi xử lý Visual C++ Redistributable: $($_.Exception.Message)", 3)
        }
    }
    static [void] RunChristitus() {
        try {
            $configPath = Join-Path -Path $PSScriptRoot -ChildPath "File_Config\Christitus\config_Default.json"
            if (-not (Test-Path $configPath)) {
                [System_Utils]::Load_Notification("Không tìm thấy file cấu hình Christitus tại: $configPath", 3)
                return
            }
            [System_Utils]::Load_Notification("🔧 Đang chạy script tối ưu hệ thống từ Christitus...", 1)
            $cmd = "`$script = Invoke-RestMethod https://christitus.com/win; & ([scriptblock]::Create(`$script)) -Config `"$configPath`" -Run"
            [System_Utils]::Create_New_Window($cmd, $true)
        } catch {
            [System_Utils]::Load_Notification("Lỗi khi chạy Christitus Script: $($_.Exception.Message)", 3)
        }
    }
    static [void] Create_GodMode() {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $godModeName = "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
        $godModePath = Join-Path $desktopPath $godModeName
        try {
            New-Item -Path $godModePath -ItemType Directory -ErrorAction Stop | Out-Null
            [System_Utils]::Load_Notification("✅ GodMode đã được tạo tại: $godModePath", 2)
        } catch {
            [System_Utils]::Load_Notification("Không thể tạo GodMode: $($_.Exception.Message)", 3)
        }

    }
    static [void] Always_keep_the_screen (){
        [System_Utils]::Run_Admin("powercfg /change standby-timeout-dc 0")
        [System_Utils]::Run_Admin("powercfg /change monitor-timeout-dc 0")
        [System_Utils]::Run_Admin("powercfg /change standby-timeout-ac 0")
        [System_Utils]::Run_Admin("powercfg /change monitor-timeout-ac 0")
        [System_Utils]::Load_Notification("🔧 Đã dừng tắt màn hình", 2)
    }
    static [void] Hide_Widgets () {
        try {
            [System_Utils]::Run_Admin("Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarDa -Value 0")
            Write-Host "✅ Đã ẩn Widgets khỏi Taskbar." -ForegroundColor Green
            Stop-Process -Name explorer -Force
            Start-Process explorer
        } catch {
            Write-Host "Có lỗi xảy ra: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    static [void] Set_DarkMode () {
        [System_Utils]::Load_Notification("🌑 Đang bật Dark Mode cho hệ thống và ứng dụng...", 1)
        try {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
            # Tạo key nếu chưa có
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            # Đặt cả hai giá trị AppsUseLightTheme và SystemUsesLightTheme về 0 (Dark)
            Set-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -Value 0 -Force
            Set-ItemProperty -Path $regPath -Name "SystemUsesLightTheme" -Value 0 -Force

            [System_Utils]::Load_Notification("✅ Đã bật chế độ Dark Mode thành công!", 2)
        } catch {
            [System_Utils]::Load_Notification("Lỗi khi thiết lập Dark Mode: $($_.Exception.Message)", 3)
        }
    }
    static [void] Auto_Hide_Taskbar () {
        [System_Utils]::Load_Notification("📐 Đang thiết lập Taskbar tự động ẩn...", 1)
        try {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
            $binaryData = (Get-ItemProperty -Path $regPath -Name Settings).Settings

            # Bật tự động ẩn: thay bit thứ 8 (giá trị thứ 8 trong chuỗi) thành 03
            $binaryData[8] = 0x03

            # Ghi lại giá trị mới
            Set-ItemProperty -Path $regPath -Name Settings -Value $binaryData

            # Restart Explorer để áp dụng
            Stop-Process -Name explorer -Force
            Start-Process explorer.exe

            [System_Utils]::Load_Notification("✅ Taskbar đã được thiết lập tự động ẩn.", 2)
        } catch {
            [System_Utils]::Load_Notification("Lỗi khi cấu hình Taskbar tự động ẩn: $($_.Exception.Message)", 3)
        }
    }
}
#endregion
#region hiển thị thông tin hệ thống
class Show_Info {
    static [void] Show_OS_Info() {
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $arch = (Get-CimInstance Win32_Processor).AddressWidth
            [System_Utils]::Load_Notification("===== Thông tin Hệ điều hành =====", 1)
            Write-Host "🪟 Tên hệ điều hành:     $($os.Caption)"
            Write-Host "🏗️  Version:             $($os.Version) (Build $($os.BuildNumber))"
            Write-Host "🏁 Kiến trúc:            $arch-bit"   
        }
        catch {
            [System_Utils]::Load_Notification("Ko thể đọc hệ diều hành")
        }
    }
    static [void] Show_RAM_Info() {
        try {
            $maxRamKB = (Get-CimInstance Win32_PhysicalMemoryArray).MaxCapacity
            $maxRamGB = [math]::Round($maxRamKB / 1MB)
            $ramModules = Get-CimInstance Win32_PhysicalMemory
            $currentRamBytes = ($ramModules | Measure-Object -Property Capacity -Sum).Sum
            $currentRamGB = [math]::Round($currentRamBytes / 1GB)
            $slotsUsed = $ramModules.Count
            $totalSlots = (Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices
            [System_Utils]::Load_Notification("===== Thông tin RAM =====", 1)
            Write-Host "💾 RAM đang dùng:         $currentRamGB GB"
            Write-Host "🚀 RAM tối đa hỗ trợ:     $maxRamGB GB"
            Write-Host "🔌 Số khe đã cắm:         $slotsUsed"
            Write-Host "📦 Tổng số khe:           $totalSlots"
        } catch {
            [System_Utils]::Load_Notification("❌ Không thể lấy thông tin RAM!", 3)
        }
    }
    static [void] Show_CPU_Info() {
        try {
            $cpu = Get-CimInstance Win32_Processor
            if (-not $cpu) {
                [System_Utils]::Load_Notification("⚠️ Không phát hiện CPU!", 3)
                return
            }
            [System_Utils]::Load_Notification("===== Thông tin CPU =====", 1)
            Write-Host "🖥️ Tên CPU:               $($cpu.Name)"
            Write-Host "⚙️ Số lõi:                $($cpu.NumberOfCores)"
            Write-Host "🔢 Số luồng:             $($cpu.NumberOfLogicalProcessors)"
            Write-Host "⏱️ Tốc độ cơ bản:         $([math]::Round($cpu.MaxClockSpeed / 1000, 2)) GHz"
        } catch {
            [System_Utils]::Load_Notification("❌ Không thể lấy thông tin CPU!", 3)
        }
    }
    static [void] Show_GPU_Info() {
        try {
        $gpus = Get-CimInstance Win32_VideoController

        if (-not $gpus) {
            [System_Utils]::Load_Notification("⚠️ Không phát hiện GPU!", 3)
            return
        }

        foreach ($gpu in $gpus) {
            [System_Utils]::Load_Notification("===== Thông tin GPU =====", 1)
            Write-Host "🎮 Tên GPU:               $($gpu.Name)"
            Write-Host "🖥️ Bộ nhớ GPU:            $([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB"
            Write-Host "🔄 Phiên bản driver:      $($gpu.DriverVersion)"
        }

        } catch {
            [System_Utils]::Load_Notification("❌ Không thể lấy thông tin GPU!", 3)
        }
    }
    static [void] Show_Disk_Info() {
        try {
            $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3"
            if (-not $drives) {
                [System_Utils]::Load_Notification("⚠️ Không phát hiện ổ đĩa!", 3)
                return
            }
            [System_Utils]::Load_Notification("===== Thông tin Ổ cứng =====", 1)
            foreach ($drive in $drives) {
                $used = [math]::Round(($drive.Size - $drive.FreeSpace)/1GB, 2)
                $total = [math]::Round($drive.Size / 1GB, 2)
                $percent = [math]::Round($used / $total * 100, 1)
                Write-Host "💽 Ổ đĩa $($drive.DeviceID): $used/$total GB ($percent% đã dùng)"
            }
        } catch {
            [System_Utils]::Load_Notification("❌ Không thể lấy thông tin ổ đĩa!", 3)
        }
    }

    static [void] Show_All () {
        [Show_Info]::Show_OS_Info()
        [Show_Info]::Show_Disk_Info()
        [Show_Info]::Show_RAM_Info()
        [Show_Info]::Show_CPU_Info()
        [Show_Info]::Show_GPU_Info()
    }
}

#endregion
#region menu chính
class Main {
    static [void] MainStart (){
        $logFolder = "$PSScriptRoot\Log"
        if (-not (Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder | Out-Null
        }
        $logPath = "$logFolder\$(Get-Date -Format 'ddMMyyyy').log"
        Start-Transcript -Path $logPath -Append
        [Main]::Start()
        Stop-Transcript

    }
    static [void] start (){
        [Setup_Win]::Disable_UAC()
        [System_Utils]::Load_Countdown(5)
        [System_Utils]::Check_Internet()
        [Setup_Win]::RunChristitus()
        $Buckets_Scoop = @("extras", "versions", "main", "nonportable")
        [Scoop]::Install();
        [git]::Install();[git]::Config()
        [Scoop]::Install_Bucket($Buckets_Scoop);
        [Setup_Win]::Install_VC_AllInOne() 
        $Feature = @("Microsoft-Hyper-V","VirtualMachinePlatform","Containers")
        [Windows_Features]::Install(); [Windows_Features]::Install_Packages($Feature)
        $Setup_Tools = @("Vscode", "Obsidian", "ObsStudio", "Idm", "Docker", "VisualStudio", "AndroidStudio", "LazyVim", "Office", "TeraCopy", "Scrcpy", "WSL")
        foreach ($ToolName in $Setup_Tools) {
            try {
                $type = [Type]::GetType($ToolName, $false)
                if ($null -eq $type) {
                    $type = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object {
                        $_.GetType($ToolName, $false)
                    } | Where-Object { $_ -ne $null }
                }

                if ($null -ne $type) {
                    $type::Install()
                    $type::Config()
                } else {
                    [System_Utils]::Load_Notification("❌ Không tìm thấy class: $ToolName", 3)
                }
            } catch {
                [System_Utils]::Load_Notification("❌ Lỗi khi xử lý công cụ $ToolName : $($_.Exception.Message)", 3)
            }
        }
        $Packages_Scoop = @("winrar")
        [Scoop]::Install_Packages($Packages_Scoop)
        $Packages_Winget = @("DucFabulous.UltraViewer")
        [Winget]::Install_Packages($Packages_Winget)
        [Setup_Win]::Set_TimeZone_UTC8()
        [Setup_Win]::Create_GodMode()
        [Setup_Win]::Always_keep_the_screen()
        [Setup_Win]::Hide_Widgets()
        [Setup_Win]::Set_DarkMode()
        [Setup_Win]::Auto_Hide_Taskbar()
        [Show_Info]::Show_All()
    }
}
#endregion
[Main]::MainStart()