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

function Set-ExecutionPolicyIfNeeded {
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "Checking PowerShell Execution Policy"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    
    $currentPolicy = Get-ExecutionPolicy
    Write-ColorOutput Yellow "Current Execution Policy: $currentPolicy"
    
    if ($currentPolicy -eq 'Restricted' -or $currentPolicy -eq 'Undefined') {
        Write-ColorOutput Red "Execution policy is TOO restrictive!"
        Write-ColorOutput Yellow "Setting execution policy to Bypass for this process..."
        Write-Output ""
        
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
            Write-ColorOutput Green "OK Execution policy set to Bypass for current process successfully!"
            Write-ColorOutput Cyan "  (This change applies only to this PowerShell session)"
            Write-Output ""
        }
        catch {
            Write-ColorOutput Red "ERROR Failed to change execution policy: $_"
            Write-Output ""
            Write-ColorOutput Yellow "Manual steps required:"
            Write-ColorOutput Cyan "1. Close this PowerShell window"
            Write-ColorOutput Cyan "2. Open a new PowerShell window"
            Write-ColorOutput Cyan "3. Run: Set-ExecutionPolicy Bypass -Scope Process -Force"
            Write-ColorOutput Cyan "4. Then run this script again: .\scripts\setup.ps1"
            Write-Output ""
            
            $continue = Read-Host "Continue anyway? (y/n)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                Write-ColorOutput Red "Script execution cancelled."
                exit 1
            }
        }
    }
    elseif ($currentPolicy -eq 'AllSigned' -or $currentPolicy -eq 'RemoteSigned' -or $currentPolicy -eq 'Unrestricted' -or $currentPolicy -eq 'Bypass') {
        Write-ColorOutput Green "OK Execution policy is properly configured: $currentPolicy"
        Write-Output ""
    }
    else {
        Write-ColorOutput Yellow "Unknown execution policy: $currentPolicy"
        Write-Output ""
    }
}

Set-ExecutionPolicyIfNeeded

function Show-PythonInstallHelp {
    Write-Output ""
    Write-ColorOutput Red "Python 3.12 is NOT properly installed!"
    Write-Output ""
    Write-ColorOutput Yellow "You may have the Windows Store alias enabled."
    Write-Output ""
    Write-ColorOutput Cyan "To disable the Windows Store Python alias:"
    Write-Output "  1. Open Windows Settings"
    Write-Output "  2. Go to: Apps > Apps & features > App execution aliases"
    Write-Output "  3. Turn OFF both 'python.exe' and 'python3.exe'"
    Write-Output ""
    Write-ColorOutput Cyan "Then install Python 3.12 from the official website:"
    Write-Output "  https://www.python.org/downloads/release/python-3120/"
    Write-Output ""
    Write-Output "  - Download Python 3.12.x (latest 3.12 version)"
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
    $pythonVersion = $null
    
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        $testVersion = & python3 --version 2>&1
        if ($testVersion -match "Python (\d+\.\d+)\.\d+") {
            $pythonPath = (Get-Command python3).Source
            $pythonVersion = $matches[1]
            return @{Path=$pythonPath; Version=$pythonVersion; Command="python3"}
        }
    }
    
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $testVersion = & python --version 2>&1
        if ($testVersion -match "Python (\d+\.\d+)\.\d+") {
            $pythonPath = (Get-Command python).Source
            $pythonVersion = $matches[1]
            return @{Path=$pythonPath; Version=$pythonVersion; Command="python"}
        }
    }
    
    return $null
}

function Get-InstalledPythonVersions {
    $pythonVersions = @()
    
    $paths = @(
        "$env:ProgramFiles\Python*",
        "${env:ProgramFiles(x86)}\Python*",
        "$env:LOCALAPPDATA\Programs\Python\Python*"
    )
    
    foreach ($pathPattern in $paths) {
        $foundPaths = Get-ChildItem -Path $pathPattern -ErrorAction SilentlyContinue
        foreach ($path in $foundPaths) {
            $pythonExe = Join-Path $path.FullName "python.exe"
            if (Test-Path $pythonExe) {
                try {
                    $versionOutput = & $pythonExe --version 2>&1
                    if ($versionOutput -match "Python (\d+\.\d+\.\d+)") {
                        $pythonVersions += @{
                            Path = $path.FullName
                            Version = $matches[1]
                            Executable = $pythonExe
                        }
                    }
                } catch {
                    continue
                }
            }
        }
    }
    
    return $pythonVersions
}

function Uninstall-Python {
    param(
        [string]$PythonPath
    )
    
    Write-ColorOutput Yellow "Attempting to uninstall Python from: $PythonPath"
    
    $uninstallers = @(
        (Join-Path $PythonPath "Uninstall.exe"),
        (Join-Path $PythonPath "python-*.exe")
    )
    
    foreach ($uninstaller in $uninstallers) {
        $found = Get-ChildItem -Path $uninstaller -ErrorAction SilentlyContinue
        if ($found) {
            Write-ColorOutput Yellow "Running uninstaller: $($found.FullName)"
            Start-Process -FilePath $found.FullName -ArgumentList "/uninstall", "/quiet" -Wait -NoNewWindow
            Write-ColorOutput Green "Uninstall completed for: $PythonPath"
            return $true
        }
    }
    
    Write-ColorOutput Yellow "Looking for Python in installed apps..."
    $pythonApps = Get-Package -Name "*Python*" -ErrorAction SilentlyContinue | Where-Object {
        $_.FastPackageReference -like "*$PythonPath*" -or $_.Name -like "*Python 3.*"
    }
    
    foreach ($app in $pythonApps) {
        try {
            Write-ColorOutput Yellow "Uninstalling: $($app.Name)"
            Uninstall-Package -Name $app.Name -Force -ErrorAction Stop
            Write-ColorOutput Green "Successfully uninstalled: $($app.Name)"
            return $true
        } catch {
            Write-ColorOutput Red "Failed to uninstall $($app.Name): $_"
        }
    }
    
    Write-ColorOutput Red "Could not find uninstaller. Please uninstall manually via Windows Settings > Apps."
    return $false
}

function Install-Python312 {
    Set-ExecutionPolicyIfNeeded
    
    Write-ColorOutput Cyan "========================================"
    Write-ColorOutput Cyan "Installing Python 3.12"
    Write-ColorOutput Cyan "========================================"
    Write-Output ""
    
    Write-ColorOutput Yellow "Fetching latest Python 3.12 version..."
    
    $python312Url = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
    $downloadPath = "$env:TEMP\python-3.12.7-amd64.exe"
    
    Write-ColorOutput Yellow "Downloading Python 3.12.7..."
    Write-ColorOutput Cyan "URL: $python312Url"
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $python312Url -OutFile $downloadPath -UseBasicParsing
        Write-ColorOutput Green "Download complete!"
    } catch {
        Write-ColorOutput Red "ERROR downloading Python 3.12: $_"
        Write-Output ""
        Write-ColorOutput Yellow "Please download manually from:"
        Write-ColorOutput Cyan "https://www.python.org/downloads/release/python-3127/"
        return $false
    }
    
    Write-Output ""
    Write-ColorOutput Yellow "Installing Python 3.12.7..."
    Write-ColorOutput Yellow "This may take a few minutes..."
    
    try {
        $installArgs = @(
            "/quiet",
            "InstallAllUsers=1",
            "PrependPath=1",
            "Include_test=0",
            "Include_doc=0"
        )
        
        Start-Process -FilePath $downloadPath -ArgumentList $installArgs -Wait -NoNewWindow
        Write-ColorOutput Green "Installation complete!"
        
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        
        Write-Output ""
        Write-ColorOutput Yellow "IMPORTANT: You must restart PowerShell for changes to take effect!"
        Write-Output ""
        
        return $true
        
    } catch {
        Write-ColorOutput Red "ERROR during installation: $_"
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Verify-Python312 {
    Write-ColorOutput Yellow "Verifying Python installation..."
    
    $pythonInfo = Test-PythonInPath
    
    if (-not $pythonInfo) {
        Write-ColorOutput Red "Python not found in PATH!"
        return $false
    }
    
    if ($pythonInfo.Version -ne "3.12") {
        Write-ColorOutput Red "Wrong Python version detected: $($pythonInfo.Version)"
        Write-ColorOutput Yellow "Required version: 3.12"
        
        $installedVersions = Get-InstalledPythonVersions
        
        if ($installedVersions.Count -gt 0) {
            Write-Output ""
            Write-ColorOutput Yellow "Found installed Python versions:"
            foreach ($ver in $installedVersions) {
                Write-Output "  - Version $($ver.Version) at $($ver.Path)"
            }
            Write-Output ""
            
            $uninstallOthers = Read-Host "Uninstall incompatible Python versions? (y/n)"
            
            if ($uninstallOthers -eq 'y' -or $uninstallOthers -eq 'Y') {
                foreach ($ver in $installedVersions) {
                    if (-not $ver.Version.StartsWith("3.12")) {
                        $success = Uninstall-Python -PythonPath $ver.Path
                        if ($success) {
                            Write-ColorOutput Green "Uninstalled Python $($ver.Version)"
                        }
                    }
                }
            }
        }
        
        Write-Output ""
        $installNew = Read-Host "Install Python 3.12 now? (y/n)"
        
        if ($installNew -eq 'y' -or $installNew -eq 'Y') {
            $success = Install-Python312
            if ($success) {
                Write-Output ""
                Write-ColorOutput Green "Python 3.12 installed successfully!"
                Write-ColorOutput Yellow "Please restart PowerShell and run this script again."
                exit 0
            } else {
                exit 1
            }
        } else {
            Write-ColorOutput Yellow "Python 3.12 is required. Please install it manually."
            Show-PythonInstallHelp
            exit 1
        }
    }
    
    Write-ColorOutput Green "OK Python 3.12 detected: $($pythonInfo.Path)"
    return $true
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

function Get-ChromeDriverVersion {
    param(
        [string]$ChromeDriverPath
    )
    
    if (-not (Test-Path $ChromeDriverPath)) {
        return $null
    }
    
    try {
        $versionOutput = & $ChromeDriverPath --version 2>&1
        if ($versionOutput -match "ChromeDriver (\d+\.\d+\.\d+\.\d+)") {
            return $matches[1]
        }
    } catch {
        return $null
    }
    
    return $null
}

function Test-ChromeDriverCompatibility {
    param(
        [string]$ChromeVersion,
        [string]$ChromeDriverVersion
    )
    
    if (-not $ChromeDriverVersion) {
        return $false
    }
    
    $chromeMajor = $ChromeVersion.Split('.')[0]
    $driverMajor = $ChromeDriverVersion.Split('.')[0]
    
    return $chromeMajor -eq $driverMajor
}

function Download-ChromeDriver {
    param(
        [string]$ChromeVersion,
        [switch]$Force
    )
    
    $pythonInfo = Test-PythonInPath
    if (-not $pythonInfo) {
        Write-ColorOutput Red "Python not found in PATH"
        return $false
    }
    
    $pythonDir = Split-Path -Parent $pythonInfo.Path
    $scriptsDir = Join-Path $pythonDir "Scripts"
    
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    
    $chromeDriverPath = Join-Path $scriptsDir "chromedriver.exe"
    
    if ((Test-Path $chromeDriverPath) -and -not $Force) {
        $existingVersion = Get-ChromeDriverVersion -ChromeDriverPath $chromeDriverPath
        
        if ($existingVersion) {
            Write-ColorOutput Yellow "Existing ChromeDriver found: $existingVersion"
            
            $isCompatible = Test-ChromeDriverCompatibility -ChromeVersion $ChromeVersion -ChromeDriverVersion $existingVersion
            
            if ($isCompatible) {
                Write-ColorOutput Green "ChromeDriver is already compatible with Chrome $ChromeVersion"
                Write-Output ""
                $reinstall = Read-Host "Reinstall ChromeDriver anyway? (y/n)"
                
                if ($reinstall -ne 'y' -and $reinstall -ne 'Y') {
                    Write-ColorOutput Green "Keeping existing ChromeDriver"
                    return $true
                }
            } else {
                Write-ColorOutput Yellow "ChromeDriver version $existingVersion is NOT compatible with Chrome $ChromeVersion"
                Write-ColorOutput Yellow "A compatible version will be installed automatically"
            }
        }
    }
    
    Write-Output ""
    Write-ColorOutput Yellow "Downloading ChromeDriver for Chrome version $ChromeVersion..."
    
    $majorVersion = $ChromeVersion.Split('.')[0]
    
    $jsonUrl = "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
    
    try {
        $response = Invoke-RestMethod -Uri $jsonUrl -UseBasicParsing
        
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
        
        Write-ColorOutput Yellow "Downloading ChromeDriver version: $($matchingVersion.version)"
        Write-ColorOutput Cyan "URL: $chromeDriverUrl"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $chromeDriverUrl -OutFile $downloadPath -UseBasicParsing
        
        if (Test-Path $chromeDriverPath) {
            Write-ColorOutput Yellow "Removing existing ChromeDriver..."
            Remove-Item -Path $chromeDriverPath -Force -ErrorAction SilentlyContinue
        }
        
        Write-ColorOutput Yellow "Extracting ChromeDriver to $scriptsDir..."
        Expand-Archive -Path $downloadPath -DestinationPath "$env:TEMP\chromedriver-temp" -Force
        
        $extractedDriver = Get-ChildItem -Path "$env:TEMP\chromedriver-temp" -Recurse -Filter "chromedriver.exe" | Select-Object -First 1
        
        if ($extractedDriver) {
            Copy-Item -Path $extractedDriver.FullName -Destination $chromeDriverPath -Force
            Write-ColorOutput Green "ChromeDriver $($matchingVersion.version) installed successfully!"
            Write-ColorOutput Green "Location: $chromeDriverPath"
        } else {
            Write-ColorOutput Red "Could not find chromedriver.exe in downloaded archive"
            return $false
        }
        
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$env:TEMP\chromedriver-temp" -Recurse -Force -ErrorAction SilentlyContinue
        
        $newVersion = Get-ChromeDriverVersion -ChromeDriverPath $chromeDriverPath
        if ($newVersion) {
            Write-ColorOutput Green "Verification: ChromeDriver version $newVersion is ready!"
        }
        
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
    
    Write-ColorOutput Yellow "[1/5] Checking Python 3.12 installation..."
    
    if (-not (Verify-Python312)) {
        exit 1
    }
    
    $pythonInfo = Test-PythonInPath
    $pythonCmd = $pythonInfo.Command
    $pythonVersion = & $pythonCmd --version 2>&1
    Write-ColorOutput Green "OK Python found: $pythonVersion"
    Write-ColorOutput Green "  Location: $($pythonInfo.Path)"
    
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
    
    Write-Output ""
    Write-ColorOutput Yellow "[4.1/5] Initializing Browser Library (Playwright)..."
    Write-Output ""
    
    try {
        Write-ColorOutput Yellow "  -> Running rfbrowser init..."
        Write-ColorOutput Cyan "     (This will download Playwright browser binaries - may take a few minutes)"
        Write-Output ""
        
        & $pythonCmd -m Browser.entry init
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput Green "OK Browser Library initialized successfully!"
        } else {
            Write-ColorOutput Red "ERROR Failed to initialize Browser Library"
            Write-ColorOutput Yellow "You may need to run manually: python -m Browser.entry init"
        }
    } catch {
        Write-ColorOutput Red "ERROR Error initializing Browser Library: $_"
        Write-ColorOutput Yellow "Try running manually: python -m Browser.entry init"
    }
    
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
        
        Write-ColorOutput Yellow "Checking ChromeDriver compatibility..."
        $success = Download-ChromeDriver -ChromeVersion $chromeVersion
        
        if (-not $success) {
            Write-Output ""
            Write-ColorOutput Yellow "Manual installation required:"
            Write-ColorOutput Cyan "https://googlechromelabs.github.io/chrome-for-testing/"
            Write-Output ""
            Write-Output "After download:"
            Write-Output "  1. Extract chromedriver.exe"
            Write-Output "  2. Copy to Python Scripts directory"
            $pythonDir = Split-Path -Parent $pythonInfo.Path
            Write-Output "     Location: $(Join-Path $pythonDir 'Scripts')"
        }
    }
    
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
    Set-ExecutionPolicyIfNeeded
    
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
    Set-ExecutionPolicyIfNeeded
    
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
    Write-ColorOutput Yellow "[2/4] Checking Python 3.12..."
    
    if (-not (Verify-Python312)) {
        exit 1
    }
    
    $pythonInfo = Test-PythonInPath
    $pythonCmd = $pythonInfo.Command
    
    Write-ColorOutput Green "Python 3.12 found!"
    & $pythonCmd --version

    Write-Output ""
    Write-ColorOutput Yellow "[3/4] Installing Python dependencies..."
    
    $installSuccess = $true
    
    Write-ColorOutput Yellow "  -> Upgrading pip..."
    & $pythonCmd -m pip install --upgrade pip --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "  ERROR: Failed to upgrade pip"
        $installSuccess = $false
    }
    
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
    
    Write-ColorOutput Yellow "  -> Initializing Browser Library (Playwright)..."
    & $pythonCmd -m pip install robotframework-browser --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput Yellow "  -> Installing Playwright browser binaries..."
        Write-ColorOutput Cyan "     (This may take a few minutes - downloading browser binaries)"
        & $pythonCmd -m Browser.entry init
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Red "  ERROR: Failed to initialize Browser Library"
            $installSuccess = $false
        } else {
            Write-ColorOutput Green "  OK Browser Library initialized!"
        }
    } else {
        Write-ColorOutput Red "  ERROR: Failed to install Browser Library"
        $installSuccess = $false
    }
    
    Write-Output ""
    if ($installSuccess) {
        Write-ColorOutput Green "Dependencies installed successfully!"
    } else {
        Write-ColorOutput Red "Some dependencies failed to install. Check errors above."
    }

    Write-Output ""
    Write-ColorOutput Yellow "[3.1/4] Checking ChromeDriver compatibility..."
    
    $chromeVersion = Get-ChromeVersion
    if ($chromeVersion) {
        Write-ColorOutput Green "Chrome version: $chromeVersion"
        $chromeDriverSuccess = Download-ChromeDriver -ChromeVersion $chromeVersion
        
        if ($chromeDriverSuccess) {
            Write-ColorOutput Green "ChromeDriver is ready!"
        } else {
            Write-ColorOutput Yellow "ChromeDriver setup had issues, but continuing..."
        }
    } else {
        Write-ColorOutput Yellow "Chrome not found. ChromeDriver setup skipped."
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

    if (-not (Test-Path "docker-compose.yml")) {
        Write-ColorOutput Red "ERROR: docker-compose.yml not found!"
        Write-ColorOutput Yellow "Please ensure docker-compose.yml exists in the project root."
        exit 1
    }

    Write-ColorOutput Yellow "Stopping existing containers..."
    docker-compose down 2>&1 | Out-Null

    Write-ColorOutput Yellow "Pulling OWASP Juice Shop image..."
    docker pull bkimminich/juice-shop:latest
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "ERROR: Failed to pull Juice Shop image"
        Write-ColorOutput Yellow "Check your internet connection and Docker status"
        exit 1
    }

    Write-Output ""
    Write-ColorOutput Yellow "Starting Juice Shop container..."
    docker-compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "ERROR: Failed to start container"
        Write-ColorOutput Yellow "Run 'docker-compose logs' to see details"
        exit 1
    }

    Write-Output ""
    Write-ColorOutput Yellow "Waiting for Juice Shop to start..."
    Write-ColorOutput Cyan "  (This may take 30-60 seconds...)"
    
    $maxRetries = 60
    $retries = 0
    $connected = $false

    while ($retries -lt $maxRetries) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                $connected = $true
                Write-Output ""
                Write-ColorOutput Green "OK Juice Shop is ready!"
                Write-ColorOutput Cyan "  Access: http://localhost:3000"
                break
            }
        }
        catch {
            # Check if container is still running
            $containerStatus = docker ps --filter "name=juice-shop" --format "{{.Status}}" 2>&1
            
            if ($containerStatus -match "Up") {
                # Container is running, just waiting for it to be ready
                Write-Host "." -NoNewline
            }
            else {
                Write-Output ""
                Write-ColorOutput Red "ERROR: Container stopped unexpectedly"
                Write-ColorOutput Yellow "Checking logs..."
                docker-compose logs --tail=20
                exit 1
            }
            
            $retries++
            Start-Sleep -Seconds 2
        }
    }

    if (-not $connected) {
        Write-Output ""
        Write-ColorOutput Red "ERROR: Timeout waiting for Juice Shop (2 minutes)"
        Write-Output ""
        Write-ColorOutput Yellow "Diagnostic information:"
        Write-ColorOutput Cyan "Container status:"
        docker ps -a --filter "name=juice-shop"
        Write-Output ""
        Write-ColorOutput Cyan "Last 30 lines of logs:"
        docker-compose logs --tail=30
        Write-Output ""
        Write-ColorOutput Yellow "Troubleshooting steps:"
        Write-ColorOutput Cyan "1. Run: docker-compose logs -f"
        Write-ColorOutput Cyan "2. Check if port 3000 is already in use"
        Write-ColorOutput Cyan "3. Run: docker-compose down && docker-compose up -d"
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
    
    $scriptPath = Split-Path -Parent $PSCommandPath
    $projectRoot = Split-Path -Parent $scriptPath
    Set-Location $projectRoot
    Write-ColorOutput Yellow "Working directory: $projectRoot"
    Write-Output ""

    if (-not (Verify-Python312)) {
        exit 1
    }
    
    $pythonInfo = Test-PythonInPath
    $pythonCmd = $pythonInfo.Command

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
        Write-ColorOutput Cyan "Executing: Enable Virtualization"
        Write-Output ""
        Enable-Virtualization
    }
    'install-docker' {
        Write-ColorOutput Cyan "Executing: Install Docker"
        Write-Output ""
        Install-Docker
    }
    'setup-robot' {
        Write-ColorOutput Cyan "Executing: Setup Robot Framework"
        Write-Output ""
        Setup-RobotFramework
    }
    'run-tests' {
        Write-ColorOutput Cyan "Executing: Run Tests"
        Write-Output ""
        Run-Tests
    }
    'setup' {
        Write-ColorOutput Cyan "Executing: Full Environment Setup"
        Write-Output ""
        Setup-Environment
    }
    default {
        Write-ColorOutput Cyan "Executing: Default Environment Setup"
        Write-Output ""
        Setup-Environment
    }
}