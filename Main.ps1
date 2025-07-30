#region thiết lập hệ thống
class System_Utils {
    static [bool] Is_User_Admin () {
        if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            return $false
        }else{
            return $true
        }
    } 
    static [void] Load_Notification ([string]$Noidung, [int]$Loai) {
        switch ($Loai) {
            1 { Write-Host "$Noidung" -ForegroundColor Cyan; break }
            2 { Write-Host "$Noidung" -ForegroundColor Green; break }
            3 { Write-Host "$Noidung" -ForegroundColor Red; break }
            4 { Write-Host "$Noidung" -ForegroundColor Yellow; break }
            default { Write-Host "$Noidung" }
        }
    }
    static [bool] Is_Install ([string]$Ten) {
        if (Get-Command $Ten -ErrorAction SilentlyContinue) {
            [System_Utils]::Load_Notification("$Ten đã được cài đặt.",2) 
            return $true
        } else {
            [System_Utils]::Load_Notification("$Ten chưa được cài đặt.",3)
            return $false
        }
    }
    static [void] Load_Countdown([int]$Thoi_Gian) {
        for ($i = $Thoi_Gian; $i -ge 0; $i--) {
            Write-Progress -Activity "Đang chờ..." -Status "$i giây còn lại..." -PercentComplete ((($Thoi_Gian - $i) / $Thoi_Gian) * 100)
            Start-Sleep -Seconds 1
        }
        Write-Progress -Activity "Đang chờ..." -Status "Hoàn tất" -Completed
    }
    static [void] Create_New_Window([string]$Command, [bool]$LoadAdmin = $false) {
        if (-not $Command) { return }

        $tempFile = "$env:TEMP\__run_temp__.ps1"
        $scriptContent = "try { $Command } finally { Remove-Item -Path `"$tempFile`" -Force }"
        Set-Content -Path $tempFile -Value $scriptContent -Encoding UTF8

        $argsPS = @("-ExecutionPolicy", "Bypass", "-File", $tempFile)
        if ($LoadAdmin) {
            Start-Process powershell -ArgumentList $argsPS -Verb RunAs
        } else {
            Start-Process powershell -ArgumentList $argsPS
        }
    }
    static [void] Run_Admin([string]$Command) {
        if (-not $Command) {
            [System_Utils]::Load_Notification("Lệnh không hợp lệ, không thể chạy!",3)
            return
        }
        try {
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
           Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -Verb RunAs
        } catch {
            [System_Utils]::Load_Notification("❌ Không thể chạy lệnh với quyền Admin: $Command", 3)
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
    static [void] Optimize () {
        throw "Class con phải override"
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
            [System_Utils]::Load_Notification("❌ Winget không khả dụng trên hệ thống này!", 3)
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
                # Cài đặt gói bằng Winget
        } else {
            [System_Utils]::Load_Notification("✅ $Packages đã được cài đặt.", 2)
        }
    }
    static [bool] Check_Package([string]$Ten) {
        $installed = winget list --name $Ten 2>$null
        return $null -ne ($installed | Where-Object { $_ -match "^$Ten" })
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
            scoop install git
            [System_Utils]::Load_Notification("Git đã được cài đặt thành công!", 2)
        } 
    }
    static [void] Config () {
            $Name = "Mr.thai" + $env:COMPUTERNAME
            $Email = "mr.thai2k5@gmail.com"
        try {
            git config --global user.name  $Name
            git config --global user.email $Email
            [System_Utils]::Load_Notification("Đã cấu hình Git với tên: $Name và email: $Email", 2)
        } catch {
            [System_Utils]::Load_Notification("❌ Lỗi khi cấu hình Git: $($_.Exception.Message)", 3)
        }

    }
}
Class Vscode : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("vscode")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Visual Studio Code...", 1)
            scoop install extras/vscode
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
# Obsidian
Class Obsidian : Tools_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("obsidian")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Obsidian...", 1)
            scoop install obsidian
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
            scoop install extras/obs-studio
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
            winget install Tonec.InternetDownloadManager -e --accept-source-agreements --accept-package-agreements
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
            winget install Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements
            [System_Utils]::Load_Notification("Docker đã được cài đặt thành công!", 2)
        }
    }
}
class VisualStudio : Tools_Manager{
}
class AndroidStudio : Tools_Manager{
}
class LazyVim : Tools_Manager {
    static [void] Install () {
        [LazyVim]::Install_NVim()
        [LazyVim]::Install_Nerd_Fonts()
        [LazyVim]::Install_LazyVim()
        [LazyVim]::Install_Packages()
        [LazyVim]::Auto_Download_Plugin_Lazyvim()
        [System_Utils]::Load_Notification("🎉 LazyVim đã được cài đặt thành công!", 2)
    }
    static [void] Config () {
        [System_Utils]::Load_Notification("⚙️ LazyVim đã sẵn sàng để sử dụng.", 2)
    }
    static [void] Install_NVim () {
        if (-not [System_Utils]::Is_Install("nvim")) {
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Neovim...", 1)
            [Scoop]::Install_Packages("neovim")
        }
    }
    static [void] Install_Nerd_Fonts () {
        $fontName = "Meslo"
        $version = "v3.2.0"
        $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$version/$fontName.zip"
        $tempFolder = "$env:TEMP\NerdFonts"
        $zipPath = "$tempFolder\$fontName.zip"
        $extractPath = "$tempFolder\Extracted"

        [System_Utils]::Load_Notification("📥 Đang tải font $fontName ($version)...", 1)

        if (-Not (Test-Path $tempFolder)) {
            New-Item -ItemType Directory -Path $tempFolder | Out-Null
        }

        try {
            Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        } catch {
            [System_Utils]::Load_Notification("❌ Lỗi khi tải font: $_", 3)
            return
        }

        try {
            if (Test-Path $extractPath) {
                Remove-Item -Recurse -Force $extractPath
            }
            Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
        } catch {
            [System_Utils]::Load_Notification("❌ Lỗi khi giải nén font: $_", 3)
            return
        }

        $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        if (-Not (Test-Path $fontsFolder)) {
            New-Item -ItemType Directory -Path $fontsFolder | Out-Null
        }

        $fontsInstalled = 0
        Get-ChildItem -Path $extractPath -Filter *.ttf | ForEach-Object {
            $targetPath = Join-Path $fontsFolder $_.Name
            try {
                Copy-Item $_.FullName -Destination $targetPath -Force
                $fontsInstalled++
                [System_Utils]::Load_Notification("✅ Đã cài: $($_.Name)", 2)
            } catch {
                Write-Host "⚠️ Không thể cài font: $($_.Name)"
            }
        }

        if ($fontsInstalled -gt 0) {
            [System_Utils]::Load_Notification("🎉 Cài đặt font $fontName thành công!", 2)
        } else {
            [System_Utils]::Load_Notification("⚠️ Không cài được font nào.", 2)
        }

        Remove-Item -Recurse -Force $extractPath, $zipPath
    }
    static [void] Install_LazyVim () {
        [System_Utils]::Load_Notification("🔧 Đang clone LazyVim từ GitHub...", 1)
        git clone https://github.com/LazyVim/starter $env:LOCALAPPDATA\nvim
        Remove-Item "$env:LOCALAPPDATA\nvim\.git" -Recurse -Force
    }
    static [void] Install_Packages () {
        $packages = @(
            "curl", "wget", "gcc", "make", "unzip", "ripgrep", "fd", 
            "llvm", "zig", "python", "nodejs-lts"
        )

        foreach ($pkg in $packages) {
            if (-not [System_Utils]::Is_Install($pkg)) {
                Write-Host "📦 Đang cài: $pkg"
                [Scoop]::Install_Packages($pkg)
            }
        }

        [System_Utils]::Load_Notification("🔧 Đang cài pip & npm packages...", 1)
        python -m pip install --upgrade pip pynvim
        npm install -g typescript typescript-language-server vscode-langservers-extracted eslint_d
        [System_Utils]::Load_Notification("✅ Đã cài đặt đầy đủ các gói!", 2)
    }
    static [void] Auto_Download_Plugin_Lazyvim () {
        [System_Utils]::Load_Notification("⚙️ Đồng bộ plugin LazyVim...", 1)
        nvim --headless "+Lazy! sync" +qa
    }
}
#endregion
#region thiết lập Windows
class Setup_Win {
    static [void] Disable_UAC () {
        [System_Utils]::Load_Notification("🔧 Đang vô hiệu hóa UAC...", 1)
        $cmd = "Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0"
        if ([System_Utils]::Is_User_Admin()) {
            [System_Utils]::Run_Admin("Invoke-Expression $cmd")
        } else {
            [System_Utils]::Run_Admin($cmd)
        }
    }
    static [void] Set_TimeZone_UTC8() {
        $tzId = "SE Asia Standard Time"
        try {
            [System_Utils]::Load_Notification("🌏 Đang đặt múi giờ về UTC+8 ($tzId)...", 1)
            tzutil /s $tzId
            [System_Utils]::Load_Notification("✅ Đã đặt múi giờ thành công.", 2)
        } catch {
            [System_Utils]::Load_Notification("❌ Lỗi khi đặt múi giờ: $_", 3)
        }
    }
    static [void] Activate_Win_Office() {
        $winActivated     = $null -ne (Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.Name -like "Windows*" -and $_.LicenseStatus -eq 1 })
        $officeInstalled  = Get-CimInstance Win32_Product | Where-Object { $_.Name -match "Office" }
        $officeActivated  = $null -ne $officeInstalled -and $null -ne (Get-CimInstance SoftwareLicensingProduct | Where-Object { $_.Name -match "Office" -and $_.LicenseStatus -eq 1 })

        if ($winActivated -and ($null -eq $officeInstalled -or $officeActivated)) {
            [System_Utils]::Load_Notification("✅ Windows và Office đã được kích hoạt. Bỏ qua bước này.", 0)
            return
        }

        $cmd = 'irm https://get.activated.win | iex; MAS_AIO.cmd /Online /Silent'
        [System_Utils]::Load_Notification("⚙️ Đang kích hoạt Windows + Office (Online KMS, silent)...", 1)
        [System_Utils]::Create_New_Window($cmd, $true)
    }
    static [void] Install_VC_AllInOne() {
        $url  = "https://github.com/abbodi1406/vcredist/releases/latest/download/VisualCppRedist_AIO_x86_x64.exe"
        $file = "$env:TEMP\VisualCppRedist_AIO.exe"

        try {
            Write-Host "📥 Đang tải VC++ Redistributable AIO..." -ForegroundColor Cyan
            [System_Utils]::Run_Admin("Invoke-WebRequest '$url' -OutFile '$file' -UseBasicParsing")

            Write-Host "🔧 Đang cài đặt VC++ Redistributable..." -ForegroundColor Yellow
            [System_Utils]::Run_Admin("Start-Process -FilePath '$file' -ArgumentList '/y' -Wait")

            Write-Host "✅ Cài đặt VC++ hoàn tất." -ForegroundColor Green
        } catch {
            Write-Host "❌ Lỗi khi cài đặt VC++: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    static [void] RunChristitus() {
        $Config = Join-Path -Path $PSScriptRoot -ChildPath "File_Config\Christitus\config_Default.json"
        $cmd = "`$script = Invoke-RestMethod https://christitus.com/win; & ([scriptblock]::Create(`$script)) -Config `"$Config`" -Run"
        [System_Utils]::Create_New_Window($cmd, $true)
    }
    static [void] Create_GodMode() {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $godModeName = "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
        $godModePath = Join-Path $desktopPath $godModeName
        if (-Not (Test-Path $godModePath)) {
            New-Item -Path $godModePath -ItemType Directory | Out-Null
            Write-Host "✅ GodMode đã được tạo tại: $godModePath"
        } else {
            Write-Host "⚠️ Thư mục GodMode đã tồn tại tại: $godModePath"
        }
    }
    static [void] Setup_Virtual() {
        [System_Utils]::Load_Notification("🔧 Đang thiết lập Ảo hoá: hyper-v, WSL và Ubuntu...", 1)
        # Bật các tính năng cần thiết
        $features = @(
            "Microsoft-Hyper-V",
            "Microsoft-Windows-Subsystem-Linux",
            "VirtualMachinePlatform",
            "Containers"
        )
        $featureCmds = $features | ForEach-Object {
            "Enable-WindowsOptionalFeature -Online -FeatureName $_ -All -NoRestart"
        }
        [System_Utils]::Run_Admin($featureCmds -join "`n")

        # Cài đặt hoặc cập nhật WSL Core
        try {
            wsl --status *>$null
            [System_Utils]::Run_Admin("wsl --update")
        } catch {
            [System_Utils]::Run_Admin("wsl --install --no-launch --web-download")
        }

        # Kiểm tra và cài Ubuntu nếu chưa có
        $hasUbuntu = (& wsl -l -q) -match "^Ubuntu"
        if (-not $hasUbuntu) {
            [System_Utils]::Run_Admin("wsl --install -d Ubuntu-22.04 --no-launch")
        }
        [Winget]::Install_Packages("9PN20MSR04DW") # Cài đặt Ubuntu từ Microsoft Store
        # Thông báo
        [System_Utils]::Load_Notification("✅ Ảo hoá, WSL & Ubuntu đã cài thành công! Nhớ **khởi động lại** máy.", 2)
    }
    static [void] Always_keep_the_screen (){
        [System_Utils]::Run_Admin("powercfg /change standby-timeout-dc 0")
        [System_Utils]::Run_Admin("powercfg /change monitor-timeout-dc 0")
        [System_Utils]::Run_Admin("powercfg /change standby-timeout-ac 0")
        [System_Utils]::Run_Admin("powercfg /change monitor-timeout-ac 0")

    }
}
#endregion

#region hiển thị thông tin hệ thống
Class Show_Info {
    static [void] Show_RAM_Info() {
        $maxRamKB = (Get-CimInstance Win32_PhysicalMemoryArray).MaxCapacity
        $maxRamGB = [math]::Round($maxRamKB / 1MB)
        $ramModules = Get-CimInstance Win32_PhysicalMemory
        $currentRamBytes = ($ramModules | Measure-Object -Property Capacity -Sum).Sum
        $currentRamGB = [math]::Round($currentRamBytes / 1GB)
        $slotsUsed = $ramModules.Count
        $totalSlots = (Get-CimInstance Win32_PhysicalMemoryArray).MemoryDevices
        Write-Host "`n===== Thông tin RAM =====" -ForegroundColor Cyan
        Write-Host "💾 RAM đang dùng:         $currentRamGB GB"
        Write-Host "🚀 RAM tối đa hỗ trợ:     $maxRamGB GB"
        Write-Host "🔌 Số khe đã cắm:         $slotsUsed"
        Write-Host "📦 Tổng số khe:           $totalSlots"
    }
    static [void] Show_CPU_Info() {
        $cpu = Get-CimInstance Win32_Processor
        Write-Host "`n===== Thông tin CPU =====" -ForegroundColor Cyan
        Write-Host "🖥️ Tên CPU:               $($cpu.Name)"
        Write-Host "⚙️ Số lõi:                $($cpu.NumberOfCores)"
        Write-Host "🔢 Số luồng:              $($cpu.NumberOfLogicalProcessors)"
        Write-Host "⏱️ Tốc độ cơ bản:         $([math]::Round($cpu.MaxClockSpeed / 1000, 2)) GHz"
    }
    static [void] Show_GPU_Info() {
        $gpu = Get-CimInstance Win32_VideoController
        Write-Host "`n===== Thông tin GPU =====" -ForegroundColor Cyan
        Write-Host "🎮 Tên GPU:               $($gpu.Name)"
        Write-Host "🖥️ Bộ nhớ GPU:            $([math]::Round($gpu.AdapterRAM / 1GB, 2)) GB"
        Write-Host "🔄 Phiên bản driver:      $($gpu.DriverVersion)"
    }
    static [void] Show_All (){
        [Show_Info]::Show_RAM_Info();
        [Show_Info]::Show_CPU_Info();
        [Show_Info]::Show_GPU_Info();

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
        # initial setup
        [Setup_Win]::Disable_UAC()
        $Buckets_Scoop = @("extras", "versions", "main")
        [Scoop]::Install(); [Scoop]::Install_Bucket($Buckets_Scoop);
        [git]::Install();[git]::Config()
        
        # Setup tools
        $Packages_Scoop = @("extras/winrar")
        [Scoop]::Install_Packages($Packages_Scoop)
        
        
        $Packages_Winget = @("DucFabulous.UltraViewer","Microsoft.VisualStudio.2022.Community.Preview","Microsoft.Office")
        [Winget]::Install_Packages($Packages_Winget)

        $Setup_Tools = @("Vscode", "Git", "Obsidian")
        foreach ($tool in $Setup_Tools) {
            try {
                $type = [AppDomain]::CurrentDomain.GetAssemblies().GetTypes() | Where-Object { $_.Name -eq $tool }
                if ($null -eq $type) {
                    [System_Utils]::Load_Notification("❌ Không tìm thấy class $tool", 3)
                    continue
                }
                if ($type.GetMethod("Install")) {
                    $type::Install()
                }
                if ($type.GetMethod("Config")) {
                    $type::Config()
                }
            } catch {
                $msg = "❌ Lỗi khi xử lý công cụ $tool : $($_.Exception.Message)"
                [System_Utils]::Load_Notification($msg, 3)
            }
        }
        
        # setup win    
        [Setup_Win]::Set_TimeZone_UTC8()
        [Setup_Win]::RunChristitus()
        [Setup_Win]::Install_VC_AllInOne()
        [Setup_Win]::Activate_Win_Office()
        [Setup_Win]::Create_GodMode()
        [Setup_Win]::Setup_Virtual()
        [Setup_Win]::Always_keep_the_screen()
        # show info
        [Show_Info]::Show_All()
    }
}
#endregion
# Khối script chính
[Main]::MainStart()