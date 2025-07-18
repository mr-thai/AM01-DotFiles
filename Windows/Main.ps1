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
    static [void] Load_Countdown ([int]$Seconds) {
        for ($i = $Seconds; $i -ge 1; $i--) {
            Write-Host "`rĐang đợi $i giây..." -NoNewline -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
        Write-Host "`n" 
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
    static [bool] Check_Package ([string]$Ten) {
        if (scoop list | Select-String -Pattern $Ten) {
            Write-Host "$Ten đã được cài đặt."
            return $true
        } else {
            Write-Host "$Ten chưa được cài đặt."  
            return $false
        }
    }
}
class Winget : Packages_Manager {
    static [void] Install () {
        if (-not [System_Utils]::Is_Install("winget")) {
            [System_Utils]::Load_Notification("❌ Winget không khả dụng trên hệ thống này!", 3)
            throw "Winget không được cài sẵn. Hãy cập nhật Windows hoặc dùng Scoop/Choco thay thế."
        }
    }
    static [void] Install_Packages ([string[]]$Ten) {
        if (![System_Utils]::Is_Install($Ten)) {
            [System_Utils]::Load_Notification("Đang cài đặt $Ten bằng Winget...", 1)
            foreach ($Ten in $Ten) {
                if (-not [Winget]::Check_Package($Ten)) {
                    [System_Utils]::Load_Notification("Cài đặt: $Ten", 1)
                    winget install $Ten -e --accept-source-agreements --accept-package-agreements
                } else {
                    [System_Utils]::Load_Notification("✅ $Ten đã được cài đặt.", 2)
                    continue
                }
            }
                # Cài đặt gói bằng Winget
        } else {
            [System_Utils]::Load_Notification("✅ $Ten đã được cài đặt.", 2)
        }
    }
    static [bool] Check_Package ([string]$Ten) {
        try {
            $found = winget list | Select-String -Pattern $Ten
            if ($found) {
                Write-Host "$Ten đã được cài đặt." -ForegroundColor Green
                return $true
            } else {
                Write-Host "$Ten chưa được cài đặt." -ForegroundColor Yellow
                return $false
            }
        } catch {
            [System_Utils]::Load_Notification("⚠️ Không thể kiểm tra gói $Ten bằng Winget!", 3)
            return $false
        }
    }
    static [void] Optimize () {
        [System_Utils]::Load_Notification("⚙️ Winget không cần tối ưu thêm.", 1)
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
    static [void] Config ([string]$Name = $null, [string]$Email = $null) {
        if (-not $Name) {
            $Name = "Mr.thai" + $env:COMPUTERNAME
        }
        if (-not $Email) {
            $Email = "mr.thai2k5@gmail.com"
        }
        try {
            git config --global user.name  $Name
            git config --global user.email $Email
            [System_Utils]::Load_Notification("Đã cấu hình Git với tên: $Name và email: $Email", 2)
        } catch {
            [System_Utils]::Load_Notification("❌ Lỗi khi cấu hình Git: $($_.Exception.Message)", 3)
        }

    }
}
# Vscode
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
# Obsstudio
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
            [System_Utils]::Load_Notification("🔧 Đang cài đặt Internet Download Manager...", 1)
            winget install Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements
            [System_Utils]::Load_Notification("Internet Download Manager đã được cài đặt thành công!", 2)
        }
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
}
#endregion

#region menu chính
class Menu {
    static [void] MenuMain (){
        $logFolder = "$PSScriptRoot\Log"
        if (-not (Test-Path $logFolder)) {
            New-Item -ItemType Directory -Path $logFolder | Out-Null
        }
        $logPath = "$logFolder\$(Get-Date -Format 'ddMMyyyy').log"
        Start-Transcript -Path $logPath -Append
        [Menu]::Show()
        Stop-Transcript

    }
    static [void] Show () {
        [System_Utils]::Load_Notification("🔧 Chào mừng đến với Menu thiết lập hệ thống!", 1)
        [System_Utils]::Load_Notification("1. Setup All", 0)
        [System_Utils]::Load_Notification("2. Setup All -no Config", 0)
        [System_Utils]::Load_Notification("3. Show Info", 0)
        [System_Utils]::Load_Notification("4. Crack IDM", 0)
        [System_Utils]::Load_Notification("5. Crack Win 365", 0)
        [System_Utils]::Load_Notification("0. Thoát", 0)


        $choice = Read-Host "choice "
        switch ($choice) {
            1 { [Menu]::Setup_new_computer(); break }
            2 { [Menu]::Setup_No_Config(); break }
            3 { [Menu]::Show_Info(); break }
            4 { [Menu]::crack_Idm(); break }
            5 { [Menu]::crack_Win_365(); break }
            0 { exit }
            default { Write-Host "Lựa chọn không hợp lệ, vui lòng thử lại." -ForegroundColor Red; [Menu]::Show() }
        }
    }
    static [void] Setup_new_computer() {
        [Setup_Win]::Disable_UAC()
        [Setup_Win]::Set_TimeZone_UTC8()
        [Scoop]::Install()
        [git]::Install();[git]::Config("Mr.thai", "Mr.thai2k5@gmail.com")
        $Buckets_Scoop = @("extras", "versions", "main")
        $Packages_Scoop = @("extras/googlechrome","extras/winrar")
        [Scoop]::Install_Bucket($Buckets_Scoop);[Scoop]::Install_Packages($Packages_Scoop)
        [Setup_Win]::RunChristitus()
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
        [Vscode]::Install(); [Vscode]::Config(); [Vscode]::Install_extension($extension_vscode)
        [Obsidian]::Install(); [Obsidian]::Config()
        [ObsStudio]::Install(); [ObsStudio]::Config()
        [Idm]::Install(); [Idm]::Config()
        $Packages_Winget = @("DucFabulous.UltraViewer","Microsoft.VisualStudio.2022.Community.Preview","Microsoft.Office")
        [Winget]::Install_Packages($Packages_Winget)
        [Setup_Win]::Install_VC_AllInOne()
        [Setup_Win]::Activate_Win_Office()
        [Setup_Win]::Create_GodMode()
        [Setup_Win]::Setup_Virtual()
        [Setup_Win]::Always_keep_the_screen()
    }
    static [void] Setup_No_Config () {

        [System_Utils]::Load_Notification("🔧 Bắt đầu cài đặt hệ thống không cấu hình...", 1)
    }
    static [void] Show_Info () {
        [Show_Info]::Show_RAM_Info()
        [Show_Info]::Show_CPU_Info()
        [Show_Info]::Show_GPU_Info()
        [System_Utils]::Load_Notification("✅ Hiển thị thông tin hệ thống hoàn tất!", 2)
    }
    
    static [void] crack_Win_365 (){
        [System_Utils]::Load_Notification("🔧 Đang kích hoạt Windows 365...", 1)
        [Setup_Win]::Activate_Win_Office()
        [System_Utils]::Load_Notification("✅ Kích hoạt Windows 365 thành công!", 2)
    }
}

#endregion
# Khối script chính
[Menu]::MenuMain()