param(
    [ValidateSet('setup', 'install-docker', 'enable-virtualization', 'run-tests', 'setup-robot', 'help')]
    [string]$Command = 'setup',
    [string]$Marker = "",
    [switch]$Verbose,
    [switch]$Full
)

function Write-ColorOutput($ForegroundColor, $Message) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Message
    $host.UI.RawUI.ForegroundColor = $fc
}

# Check and set PowerShell Execution Policy
function Set-ExecutionPolicyIfNeeded {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    
    if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
        Write-ColorOutput Yellow "PowerShell execution policy is restrictive: $currentPolicy"
        Write-ColorOutput Yellow "Changing execution policy to RemoteSigned for CurrentUser..."
        
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
            Write-ColorOutput Green "OK Execution policy changed to RemoteSigned"
            Write-Output ""
        } catch {
            Write-ColorOutput Red ('ERROR Failed to change execution policy: ' + $_)
            Write-ColorOutput Yellow ""
            Write-ColorOutput Yellow "Please run this command manually in PowerShell as Administrator:"
            Write-ColorOutput Cyan "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
            Write-Output ""
            
            $continue = Read-Host "Continue anyway? (y/n)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                exit 1
            }
        }
    }
}

# Set execution policy at script start
Set-ExecutionPolicyIfNeeded

function Show-PythonInstallHelp {
    Write-Output ""
    Write-ColorOutput Red "Python is NOT properly installed!"
    Write-Output ""
    Write-ColorOutput Yellow "You may have the Windows Store alias enabled."
    Write-Output ""
    Write-ColorOutput Cyan "To disable the Windows Store Python alias:"
    Write-Output "  1. Open Windows Settings"
    Write-Output "  2. Go to: Apps > Apps & features > App execution aliases"
    Write-Output "  3. Turn OFF both 'python.exe' and 'python3.exe'"
    Write-Output ""
    Write-ColorOutput Cyan "Then install Python from the official website:"
    Write-Output "  https://www.python.org/downloads/"
    Write-Output ""
    Write-Output "  - Download Python 3.13.7 or higher"
    Write-Output "  - Run the installer"
    Write-Output "  - CHECK 'Add Python to PATH'"
    Write-Output "  - Complete installation"
    Write-Output "  - Restart PowerShell"
    Write-Output ""
}

function Show-Help {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan 'SBDD - Setup & Management Script'
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    Write-Output 'Usage: .\setup.ps1 -Command <command> [options]'
    Write-Output ""
    Write-Output "Commands:"
    Write-Output "  setup                 - Configure environment and start Juice Shop (default)"
    Write-Output "  setup-robot           - Configure Robot Framework environment"
    Write-Output "  install-docker        - Install Docker Desktop"
    Write-Output "  enable-virtualization - Enable virtualization features"
    Write-Output "  run-tests            - Run pytest tests"
    Write-Output "  help                 - Show this help"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -Full                - Full setup (virtualization + docker + dependencies)"
    Write-Output '  -Marker <marker>     - Run tests with specific marker (ui, api)'
    Write-Output "  -Verbose             - Verbose output for tests"
    Write-Output ""
    Write-Output "Examples:"
    Write-Output "  .\setup.ps1"
    Write-Output "  .\setup.ps1 -Command setup -Full"
    Write-Output "  .\setup.ps1 -Command setup-robot"
    Write-Output "  .\setup.ps1 -Command install-docker"
    Write-Output "  .\setup.ps1 -Command run-tests -Marker ui"
    Write-Output "  .\setup.ps1 -Command run-tests -Verbose"
}

function Test-PythonInPath {
    $pythonPath = $null
    
    # Try python3 first
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $testVersion = & python3 --version 2>&1
        if ($testVersion -match "Python \d+\.\d+\.\d+") {
            $pythonPath = (Get-Command python3).Source
            return $pythonPath
        }
    }
    
    # Try python (avoid Windows Store alias)
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $testVersion = & python --version 2>&1
        if ($testVersion -match "Python \d+\.\d+\.\d+") {
            $pythonPath = (Get-Command python).Source
            return $pythonPath
        }
    }
    
    return $null
}

function Get-ChromeVersion {
    $chromePaths = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    
    foreach ($path in $chromePaths) {
        if (Test-Path $path) {
            $version = (Get-Item $path).VersionInfo.ProductVersion
            return $version
        }
    }
    
    return $null
}

function Download-ChromeDriver {
    param(
        [string]$ChromeVersion
    )
    
    Write-ColorOutput Yellow "Downloading ChromeDriver for Chrome version $ChromeVersion..."
    
    # Extract major version (e.g., 120.0.6099.109 -> 120)
    $majorVersion = $ChromeVersion.Split('.')[0]
    
    # Chrome for Testing JSON endpoint
    $jsonUrl = "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
    
    try {
        $response = Invoke-RestMethod -Uri $jsonUrl -UseBasicParsing
        
        # Find matching version
        $matchingVersion = $response.versions | Where-Object { 
            $_.version -like "$majorVersion.*" 
        } | Select-Object -Last 1
        
        if (-not $matchingVersion) {
            Write-ColorOutput Red "Could not find matching ChromeDriver version"
            return $false
        }
        
        $chromeDriverUrl = $matchingVersion.downloads.chromedriver | Where-Object { 
            $_.platform -eq "win64" 
        } | Select-Object -First 1 -ExpandProperty url
        
        if (-not $chromeDriverUrl) {
            Write-ColorOutput Red "Could not find ChromeDriver download URL"
            return $false
        }
        
        $downloadPath = "$env:TEMP\chromedriver-win64.zip"
        
        Write-ColorOutput Yellow "Downloading from: $chromeDriverUrl"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $chromeDriverUrl -OutFile $downloadPath -UseBasicParsing
        
        # Get Python Scripts directory
        $pythonPath = Test-PythonInPath
        if (-not $pythonPath) {
            Write-ColorOutput Red "Python not found in PATH"
            return $false
        }
        
        $pythonDir = Split-Path -Parent $pythonPath
        $scriptsDir = Join-Path $pythonDir "Scripts"
        
        if (-not (Test-Path $scriptsDir)) {
            New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        }
        
        # Extract chromedriver
        Write-ColorOutput Yellow "Extracting ChromeDriver to $scriptsDir..."
        Expand-Archive -Path $downloadPath -DestinationPath "$env:TEMP\chromedriver-temp" -Force
        
        # Move chromedriver.exe to Scripts directory
        $extractedDriver = Get-ChildItem -Path "$env:TEMP\chromedriver-temp" -Recurse -Filter "chromedriver.exe" | Select-Object -First 1
        
        if ($extractedDriver) {
            $destinationPath = Join-Path $scriptsDir "chromedriver.exe"
            Copy-Item -Path $extractedDriver.FullName -Destination $destinationPath -Force
            Write-ColorOutput Green "ChromeDriver installed successfully at: $destinationPath"
        } else {
            Write-ColorOutput Red "Could not find chromedriver.exe in downloaded archive"
            return $false
        }
        
        # Cleanup
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:TEMP\chromedriver-temp" -Recurse -Force -ErrorAction SilentlyContinue
        
        return $true
        
    } catch {
        Write-ColorOutput Red ('Error downloading ChromeDriver: ' + $_)
        return $false
    }
}

function Setup-RobotFramework {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "Robot Framework Environment Setup"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    
    # Step 1: Check Python
    Write-ColorOutput Yellow "[1/5] Checking Python installation..."
    $pythonPath = Test-PythonInPath
    
    if (-not $pythonPath) {
        Show-PythonInstallHelp
        
        $openBrowser = Read-Host "Open download page in browser? (y/n)"
        if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
            Start-Process "https://www.python.org/downloads/"
        }
        exit 1
    }
    
    $pythonCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
    $pythonVersion = & $pythonCmd --version 2>&1
    Write-ColorOutput Green "OK Python found: $pythonVersion"
    Write-ColorOutput Green "  Location: $pythonPath"
    
    # Step 2: Check VS Code
    Write-Output ""
    Write-ColorOutput Yellow "[2/5] Checking Visual Studio Code..."
    $vscodePath = Get-Command code -ErrorAction SilentlyContinue
    
    if ($vscodePath) {
        $vscodeVersion = & code --version 2>&1 | Select-Object -First 1
        Write-ColorOutput Green "OK VS Code found: $vscodeVersion"
    } else {
        Write-ColorOutput Yellow "VS Code not found in PATH"
        Write-Output ""
        Write-ColorOutput Yellow "Download VS Code (recommended):"
        Write-ColorOutput Cyan "https://code.visualstudio.com/download"
        Write-Output ""
        
        $openBrowser = Read-Host "Open download page in browser? (y/n)"
        if ($openBrowser -eq 'y' -or $openBrowser -eq 'Y') {
            Start-Process "https://code.visualstudio.com/download"
        }
    }
    
    # Step 3: Install Robot Framework
    Write-Output ""
    Write-ColorOutput Yellow "[3/5] Installing Robot Framework..."
    Write-Output ""
    
    try {
        Write-ColorOutput Yellow "  -> Upgrading pip..."
        & $pythonCmd -m pip install --upgrade pip --quiet
        
        Write-ColorOutput Yellow "  -> Installing robotframework..."
        & $pythonCmd -m pip install robotframework --quiet
        
        Write-ColorOutput Yellow "  -> Installing robotframework-seleniumlibrary..."
        & $pythonCmd -m pip install robotframework-seleniumlibrary --quiet
        
        Write-ColorOutput Green "OK Robot Framework installed successfully!"
        
    } catch {
        Write-ColorOutput Red ('ERROR Error installing Robot Framework: ' + $_)
        exit 1
    }
    
    # Step 4: Install Robot Framework libraries
    Write-Output ""
    Write-ColorOutput Yellow "[4/5] Installing Robot Framework libraries..."
    Write-Output ""
    
    $libraries = @(
        @{Name="Selenium Library"; Package="robotframework-seleniumlibrary"},
        @{Name="JSON Library"; Package="robotframework-jsonlibrary"},
        @{Name="Requests Library"; Package="robotframework-requests"},
        @{Name="Browser Library"; Package="robotframework-browser"}
    )
    
    foreach ($lib in $libraries) {
        try {
            Write-ColorOutput Yellow "  -> Installing $($lib.Name)..."
            & $pythonCmd -m pip install --upgrade $($lib.Package) --quiet
            Write-ColorOutput Green "    OK $($lib.Name) installed"
        } catch {
            Write-ColorOutput Red ('    ERROR Error installing ' + $lib.Name + ': ' + $_)
        }
    }
    
    Write-Output ""
    Write-ColorOutput Green "OK All libraries installed successfully!"
    
    # Step 5: Setup ChromeDriver
    Write-Output ""
    Write-ColorOutput Yellow "[5/5] Setting up ChromeDriver..."
    Write-Output ""
    
    $chromeVersion = Get-ChromeVersion
    
    if (-not $chromeVersion) {
        Write-ColorOutput Yellow "Google Chrome not found on this system"
        Write-Output ""
        Write-ColorOutput Yellow "To use Selenium with Chrome, you need to:"
        Write-Output "  1. Install Google Chrome"
        Write-Output "  2. Download ChromeDriver manually:"
        Write-ColorOutput Cyan "     https://googlechromelabs.github.io/chrome-for-testing/"
        Write-Output "  3. Extract chromedriver.exe to Python Scripts directory"
        Write-Output ""
    } else {
        Write-ColorOutput Green "OK Google Chrome found: $chromeVersion"
        Write-Output ""
        
        $installDriver = Read-Host "Download and install matching ChromeDriver? (y/n)"
        
        if ($installDriver -eq 'y' -or $installDriver -eq 'Y') {
            $success = Download-ChromeDriver -ChromeVersion $chromeVersion
            
            if (-not $success) {
                Write-Output ""
                Write-ColorOutput Yellow "Manual installation required:"
                Write-ColorOutput Cyan "https://googlechromelabs.github.io/chrome-for-testing/"
                Write-Output ""
                Write-Output "After download:"
                Write-Output "  1. Extract chromedriver.exe"
                Write-Output "  2. Copy to Python Scripts directory"
                $pythonDir = Split-Path -Parent $pythonPath
                Write-Output "     Location: $(Join-Path $pythonDir 'Scripts')"
            }
        } else {
            Write-Output ""
            Write-ColorOutput Yellow "ChromeDriver installation skipped."
            Write-ColorOutput Yellow "Download manually when needed:"
            Write-ColorOutput Cyan "https://googlechromelabs.github.io/chrome-for-testing/"
        }
    }
    
    # Summary
    Write-Output ""
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Green "OK Robot Framework Setup Complete!"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    
    Write-ColorOutput Yellow "Installed components:"
    Write-Output "  OK Robot Framework"
    Write-Output "  OK Selenium Library"
    Write-Output "  OK JSON Library"
    Write-Output "  OK Requests Library"
    Write-Output "  OK Browser Library"
    Write-Output ""
    
    Write-ColorOutput Yellow "Next steps:"
    Write-Output "  1. Open your Robot Framework project in VS Code"
    Write-Output "  2. Install Robot Framework extensions (optional)"
    Write-Output "  3. Start creating your test cases!"
    Write-Output ""
    
    Write-ColorOutput Yellow "Verify installation:"
    Write-Output "  robot --version"
    Write-Output "  pip list | Select-String robot"
    Write-Output ""
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
        Write-ColorOutput Red ('ERROR downloading Docker Desktop: ' + $_)
        exit 1
    }

    Write-Output ""
    Write-ColorOutput Yellow "Installing Docker Desktop..."
    
    try {
        Start-Process -FilePath $downloadPath -ArgumentList "install", "--quiet", "--accept-license" -Wait -NoNewWindow
        Write-ColorOutput Green "Installation complete!"
    } catch {
        Write-ColorOutput Red ('ERROR during installation: ' + $_)
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
    
    # Ensure we're in the project root directory
    $scriptPath = Split-Path -Parent $PSCommandPath
    $projectRoot = Split-Path -Parent $scriptPath
    Set-Location $projectRoot
    Write-ColorOutput Yellow "Working directory: $projectRoot"
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
    
    # Check for real Python installation (not Windows Store alias)
    $pythonCmd = $null
    $pythonValid = $false
    
    # Try python3 first
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $testVersion = & python3 --version 2>&1
        if ($testVersion -match "Python \d+\.\d+\.\d+") {
            $pythonCmd = "python3"
            $pythonValid = $true
        }
    }
    
    # Try python if python3 didn't work
    if (-not $pythonValid -and (Get-Command python -ErrorAction SilentlyContinue)) {
        $testVersion = & python --version 2>&1
        if ($testVersion -match "Python \d+\.\d+\.\d+") {
            $pythonCmd = "python"
            $pythonValid = $true
        }
    }
    
    if (-not $pythonValid) {
        Show-PythonInstallHelp
        exit 1
    }
    
    Write-ColorOutput Green "Python found!"
    & $pythonCmd --version

    Write-Output ""
    Write-ColorOutput Yellow "[3/4] Installing Python dependencies..."
    
    $installSuccess = $true
    
    # Upgrade pip
    Write-ColorOutput Yellow "  -> Upgrading pip..."
    & $pythonCmd -m pip install --upgrade pip --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "  ERROR: Failed to upgrade pip"
        $installSuccess = $false
    }
    
    # Install requirements.txt if exists
    if (Test-Path "requirements.txt") {
        Write-ColorOutput Yellow "  -> Installing requirements.txt..."
        & $pythonCmd -m pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Red "  ERROR: Failed to install requirements.txt"
            $installSuccess = $false
        }
    } else {
        Write-ColorOutput Yellow "  -> requirements.txt not found, skipping..."
    }
    
    # Install playwright browsers
    Write-ColorOutput Yellow "  -> Installing Playwright browsers..."
    & $pythonCmd -m pip install playwright --quiet
    if ($LASTEXITCODE -eq 0) {
        & $pythonCmd -m playwright install chromium
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Red "  ERROR: Failed to install Playwright browsers"
            $installSuccess = $false
        }
    } else {
        Write-ColorOutput Red "  ERROR: Failed to install Playwright"
        $installSuccess = $false
    }
    
    Write-Output ""
    if ($installSuccess) {
        Write-ColorOutput Green "Dependencies installed successfully!"
    } else {
        Write-ColorOutput Red "Some dependencies failed to install. Check errors above."
    }

    Write-Output ""
    Write-ColorOutput Yellow "[4/4] Starting Docker environment..."
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Yellow "Docker not running. Starting Docker Desktop..."
        $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath -ErrorAction SilentlyContinue
            Write-ColorOutput Yellow 'Waiting for Docker to start (60 seconds)...'
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
    
    # Ensure we're in the project root directory
    $scriptPath = Split-Path -Parent $PSCommandPath
    $projectRoot = Split-Path -Parent $scriptPath
    Set-Location $projectRoot
    Write-ColorOutput Yellow "Working directory: $projectRoot"
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
        Write-ColorOutput Red ('Error running tests: ' + $_)
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
    'setup-robot' {
        Setup-RobotFramework
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
