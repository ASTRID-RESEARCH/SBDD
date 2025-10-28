param(
    [ValidateSet('setup', 'install-docker', 'enable-virtualization', 'run-tests', 'help')]
    [string]$Command = 'setup',
    [string]$Marker = "",
    [switch]$Verbose,
    [switch]$Full
)

$IsLinux = $PSVersionTable.Platform -eq 'Unix' -or $PSVersionTable.OS -match 'Linux|Darwin'
$IsMac = $PSVersionTable.OS -match 'Darwin'
$IsWindows = $PSVersionTable.Platform -eq 'Win32NT' -or (-not $IsLinux -and -not $IsMac)

if (-not $IsWindows) {
    $IsWindows = $true
}

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

function Show-Help {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "SBDD - Setup & Management Script"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    Write-Output "Usage: .\setup.ps1 -Command <command> [options]"
    Write-Output ""
    Write-Output "Commands:"
    Write-Output "  setup                 - Configure environment and start Juice Shop (default)"
    Write-Output "  install-docker        - Install Docker Desktop"
    Write-Output "  enable-virtualization - Enable virtualization features"
    Write-Output "  run-tests            - Run pytest tests"
    Write-Output "  help                 - Show this help"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -Full                - Full setup (virtualization + docker + dependencies)"
    Write-Output "  -Marker <marker>     - Run tests with specific marker (ui, api)"
    Write-Output "  -Verbose             - Verbose output for tests"
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  .\setup.ps1"
    Write-Output "  .\setup.ps1 -Command setup -Full"
    Write-Output "  .\setup.ps1 -Command install-docker"
    Write-Output "  .\setup.ps1 -Command run-tests -Marker ui"
    Write-Output "  .\setup.ps1 -Command run-tests -Verbose"
}

function Enable-Virtualization {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ColorOutput Red "This command requires Administrator privileges!"
        Write-ColorOutput Yellow "Right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }

    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "Windows Virtualization Setup"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""

    Write-ColorOutput Yellow "[1/5] Checking hardware virtualization..."
    $cpuInfo = Get-CimInstance -ClassName Win32_Processor
    $virtualizationEnabled = $cpuInfo.VirtualizationFirmwareEnabled

    if ($virtualizationEnabled) {
        Write-ColorOutput Green "Hardware virtualization: ENABLED"
    } else {
        Write-ColorOutput Red "Hardware virtualization: DISABLED"
        Write-Output ""
        Write-ColorOutput Yellow "Enable virtualization in BIOS/UEFI:"
        Write-Output "1. Restart computer"
        Write-Output "2. Press F2, F10, DEL or ESC during boot"
        Write-Output "3. Look for: VT-x, AMD-V, Virtualization Technology"
        Write-Output "4. ENABLE the option"
        Write-Output "5. Save (F10) and restart"
        exit 1
    }

    $needReboot = $false

    Write-Output ""
    Write-ColorOutput Yellow "[2/5] Checking Hyper-V..."
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

    if ($hyperv.State -eq "Enabled") {
        Write-ColorOutput Green "Hyper-V: ENABLED"
    } else {
        Write-ColorOutput Yellow "Hyper-V: DISABLED - Enabling..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart | Out-Null
        Write-ColorOutput Green "Hyper-V enabled!"
        $needReboot = $true
    }

    Write-Output ""
    Write-ColorOutput Yellow "[3/5] Checking Virtual Machine Platform..."
    $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

    if ($vmp.State -eq "Enabled") {
        Write-ColorOutput Green "Virtual Machine Platform: ENABLED"
    } else {
        Write-ColorOutput Yellow "Virtual Machine Platform: DISABLED - Enabling..."
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null
        Write-ColorOutput Green "Virtual Machine Platform enabled!"
        $needReboot = $true
    }

    Write-Output ""
    Write-ColorOutput Yellow "[4/5] Checking WSL2..."
    $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

    if ($wsl.State -eq "Enabled") {
        Write-ColorOutput Green "WSL: ENABLED"
    } else {
        Write-ColorOutput Yellow "WSL: DISABLED - Enabling..."
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
        Write-ColorOutput Green "WSL enabled!"
        $needReboot = $true
    }

    Write-Output ""
    Write-ColorOutput Yellow "[5/5] Checking Containers..."
    $containers = Get-WindowsOptionalFeature -Online -FeatureName Containers

    if ($containers.State -eq "Enabled") {
        Write-ColorOutput Green "Containers: ENABLED"
    } else {
        Write-ColorOutput Yellow "Containers: DISABLED - Enabling..."
        Enable-WindowsOptionalFeature -Online -FeatureName Containers -NoRestart | Out-Null
        Write-ColorOutput Green "Containers enabled!"
        $needReboot = $true
    }

    Write-Output ""
    if ($needReboot) {
        Write-ColorOutput Green "Virtualization configured successfully!"
        Write-ColorOutput Yellow "RESTART REQUIRED to apply changes."
        Write-Output ""
        $restart = Read-Host "Restart now? (y/n)"
        if ($restart -eq 'y' -or $restart -eq 'Y') {
            Restart-Computer
        }
    } else {
        Write-ColorOutput Green "All virtualization features already enabled!"
    }
}

function Install-Docker {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-ColorOutput Red "This command requires Administrator privileges!"
        exit 1
    }

    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "Docker Desktop Installer"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-ColorOutput Green "Docker already installed!"
        docker --version
        exit 0
    }

    Write-ColorOutput Yellow "Checking system requirements..."
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $version = [System.Environment]::OSVersion.Version

    if ($version.Major -lt 10) {
        Write-ColorOutput Red "ERROR: Windows 10 or higher required."
        exit 1
    }

    Write-ColorOutput Green "OS: $($osInfo.Caption)"

    Write-Output ""
    Write-ColorOutput Yellow "Checking virtualization..."
    $virtualization = (Get-CimInstance -ClassName Win32_Processor).VirtualizationFirmwareEnabled

    if (-not $virtualization) {
        Write-ColorOutput Red "WARNING: Virtualization may not be enabled in BIOS."
        Write-Output ""
        $enableVirt = Read-Host "Run virtualization configurator? (y/n)"
        if ($enableVirt -eq 'y' -or $enableVirt -eq 'Y') {
            Enable-Virtualization
            exit 0
        }
    } else {
        Write-ColorOutput Green "Virtualization: ENABLED"
    }

    $downloadPath = "$env:TEMP\DockerDesktopInstaller.exe"
    $dockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"

    Write-Output ""
    Write-ColorOutput Yellow "Downloading Docker Desktop..."
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $dockerUrl -OutFile $downloadPath -UseBasicParsing
        Write-ColorOutput Green "Download complete!"
    } catch {
        Write-ColorOutput Red "ERROR downloading Docker Desktop: $_"
        exit 1
    }

    Write-Output ""
    Write-ColorOutput Yellow "Installing Docker Desktop..."
    
    try {
        Start-Process -FilePath $downloadPath -ArgumentList "install", "--quiet", "--accept-license" -Wait -NoNewWindow
        Write-ColorOutput Green "Installation complete!"
    } catch {
        Write-ColorOutput Red "ERROR during installation: $_"
        exit 1
    }

    Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
    Write-Output ""
    Write-ColorOutput Green "Docker Desktop installed successfully!"
    Write-ColorOutput Yellow "Please restart your computer to complete the installation."
}

function Setup-Environment {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "SBDD Environment Setup"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""

    if ($Full) {
        Write-ColorOutput Yellow "Running full setup..."
        Write-Output ""
        
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            Write-ColorOutput Yellow "Docker not found. Installing..."
            Install-Docker
            Write-ColorOutput Green "Docker installed! Restart and run this script again."
            exit 0
        }
    }

    Write-ColorOutput Yellow "[1/4] Checking Docker..."
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ColorOutput Red "Docker not found!"
        Write-Output ""
        $install = Read-Host "Install Docker automatically? (y/n)"
        if ($install -eq 'y' -or $install -eq 'Y') {
            Install-Docker
            exit 0
        } else {
            Write-ColorOutput Yellow "Install Docker manually or run: .\setup.ps1 -Command install-docker"
            exit 1
        }
    }
    Write-ColorOutput Green "Docker found!"
    docker --version

    Write-Output ""
    Write-ColorOutput Yellow "[2/4] Checking Python..."
    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } 
                 elseif (Get-Command python -ErrorAction SilentlyContinue) { "python" }
                 else { $null }

    if (-not $pythonCmd) {
        Write-ColorOutput Red "Python not found!"
        Write-ColorOutput Yellow "Download Python: https://www.python.org/downloads/"
        exit 1
    }
    Write-ColorOutput Green "Python found!"
    & $pythonCmd --version

    Write-Output ""
    Write-ColorOutput Yellow "[3/4] Installing Python dependencies..."
    try {
        & $pythonCmd -m pip install --upgrade pip --quiet
        & $pythonCmd -m pip install -r requirements.txt --quiet
        playwright install chromium
        Write-ColorOutput Green "Dependencies installed!"
    } catch {
        Write-ColorOutput Red "ERROR installing dependencies: $_"
    }

    Write-Output ""
    Write-ColorOutput Yellow "[4/4] Starting Docker environment..."
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Yellow "Docker not running. Starting Docker Desktop..."
        $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath -ErrorAction SilentlyContinue
            Write-ColorOutput Yellow "Waiting for Docker to start (60 seconds)..."
            Start-Sleep -Seconds 60
        } else {
            Write-ColorOutput Red "Docker Desktop not found."
            exit 1
        }
    }

    Write-ColorOutput Yellow "Stopping existing containers..."
    docker-compose down 2>$null

    Write-ColorOutput Yellow "Pulling OWASP Juice Shop image..."
    docker pull bkimminich/juice-shop:latest

    Write-ColorOutput Yellow "Starting container..."
    docker-compose up -d

    Write-Output ""
    Write-ColorOutput Yellow "Waiting for Juice Shop to start..."
    $maxRetries = 30
    $retries = 0

    while ($retries -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-ColorOutput Green "Juice Shop is ready!"
                Write-ColorOutput Cyan "Access: http://localhost:3000"
                break
            }
        } catch {
            $retries++
            Start-Sleep -Seconds 2
        }
    }

    if ($retries -eq $maxRetries) {
        Write-ColorOutput Red "Timeout waiting for Juice Shop. Check: docker-compose logs"
        exit 1
    }

    Write-Output ""
    Write-ColorOutput Green "Environment configured successfully!"
    Write-ColorOutput Yellow "To stop: docker-compose down"
    Write-ColorOutput Yellow "To view logs: docker-compose logs -f"
}

function Run-Tests {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "SBDD - Running Tests"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""

    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } 
                 elseif (Get-Command python -ErrorAction SilentlyContinue) { "python" }
                 else { $null }

    if (-not $pythonCmd) {
        Write-ColorOutput Red "Python not found!"
        exit 1
    }

    Write-ColorOutput Yellow "Checking pytest..."
    $pytestVersion = & $pythonCmd -m pytest --version 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "pytest not found!"
        Write-ColorOutput Yellow "Installing pytest..."
        & $pythonCmd -m pip install pytest --quiet
    }

    Write-ColorOutput Green "pytest available!"
    Write-Output ""

    $args = @()

    if ($Verbose) {
        $args += "-v"
    }

    if ($Marker) {
        $args += "-m", $Marker
        Write-ColorOutput Yellow "Running tests with marker: $Marker"
    } else {
        Write-ColorOutput Yellow "Running all tests..."
    }

    Write-Output ""

    try {
        & $pythonCmd -m pytest @args
        
        if ($LASTEXITCODE -eq 0) {
            Write-Output ""
            Write-ColorOutput Green "All tests passed!"
        } else {
            Write-Output ""
            Write-ColorOutput Red "Some tests failed. Check logs above."
        }
    } catch {
        Write-ColorOutput Red "Error running tests: $_"
        exit 1
    }
}

switch ($Command) {
    'help' {
        Show-Help
    }
    'enable-virtualization' {
        Enable-Virtualization
    }
    'install-docker' {
        Install-Docker
    }
    'run-tests' {
        Run-Tests
    }
    'setup' {
        Setup-Environment
    }
    default {
        Setup-Environment
    }
}
