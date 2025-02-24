# 인코딩 설정
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 공통 함수들
function Get-ProjectPath {
    return Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

function Update-Project {
    $projectPath = Get-ProjectPath
    
    try {
        # 현재 디렉토리로 이동
        Set-Location -Path $projectPath
        
        # Git 저장소 확인 및 설정
        if (-not (Test-Path ".git")) {
            # Git 저장소가 없으면 초기화
            git init
            git remote add origin "https://github.com/ALL-MY-PROJECTS-2024/DOCKER_COMPOSE_DEPLOY.git"
            $beforeHash = "no-commit"
        } else {
            # 기존 remote 확인 및 업데이트
            $remotes = git remote
            if ($remotes -contains "origin") {
                git remote set-url origin "https://github.com/ALL-MY-PROJECTS-2024/DOCKER_COMPOSE_DEPLOY.git"
            } else {
                git remote add origin "https://github.com/ALL-MY-PROJECTS-2024/DOCKER_COMPOSE_DEPLOY.git"
            }
            
            # 현재 커밋 해시 저장 (에러 무시)
            $beforeHash = git rev-parse HEAD 2>$null
            if ($LASTEXITCODE -ne 0) {
                $beforeHash = "no-commit"
            }
        }
        
        # Git fetch 실행
        git fetch origin
        
        # 브랜치 처리
        $currentBranch = git branch --show-current 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $currentBranch) {
            # 브랜치가 없는 경우 main 브랜치 생성
            git checkout -b main
        } elseif ($currentBranch -ne "main") {
            # main 브랜치로 전환
            git checkout main 2>$null
            if ($LASTEXITCODE -ne 0) {
                git checkout -b main
            }
        }
        
        # Git pull 실행 (에러 무시)
        $pullOutput = git pull origin main 2>&1
        
        # 현재 커밋 해시 확인
        $afterHash = git rev-parse HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            $afterHash = "no-commit"
        }
        
        # 변경사항이 있는지 확인 (Already up to date 메시지 확인)
        $hasChanges = -not ($pullOutput -match "Already up to date")
        
        # 현재 실행 중인 컨테이너 확인 및 재시작 (변경사항이 있을 때만)
        if ($hasChanges) {
            $weatherRunning = docker ps -q -f name=weather
            $buildingRunning = docker ps -q -f name=building
            
            if ($weatherRunning) {
                Stop-WeatherCCTV
                Start-Sleep -Seconds 5
                Start-WeatherCCTV
            }
            
            if ($buildingRunning) {
                Stop-BuildingWind
                Start-Sleep -Seconds 5
                Start-BuildingWind
            }
        }
        
        return $hasChanges
    }
    catch {
        throw "Git operation failed: $($_.Exception.Message)"
    }
    finally {
        # 원래 위치로 돌아가기
        if ($PSScriptRoot) {
            Set-Location -Path $PSScriptRoot
        }
    }
}

# Weather-CCTV와 BuildingWind 스크립트 로드
. (Join-Path -Path $PSScriptRoot -ChildPath "weather-cctv-commands.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "buildingwind-commands.ps1")

# Form 생성
$form = New-Object System.Windows.Forms.Form
$form.Text = "DOCKER MANAGER"
$form.Size = New-Object System.Drawing.Size(300,600)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("맑은 고딕", 9)

# Update GroupBox 생성
$updateGroupBox = New-Object System.Windows.Forms.GroupBox
$updateGroupBox.Location = New-Object System.Drawing.Point(20,20)
$updateGroupBox.Size = New-Object System.Drawing.Size(240,80)
$updateGroupBox.Text = "Update"

# Update 버튼 생성
$updateButton = New-Object System.Windows.Forms.Button
$updateButton.Location = New-Object System.Drawing.Point(30,30)
$updateButton.Size = New-Object System.Drawing.Size(180,30)
$updateButton.Text = "GITHUB UPDATE"
$updateButton.Add_Click({
    $updateButton.Enabled = $false
    $updateButton.Text = "UPDATING..."
    try {
        $hasChanges = Update-Project
        if ($hasChanges) {
            [System.Windows.Forms.MessageBox]::Show("Updates found. The application will restart.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            
            # 현재 스크립트 경로 가져오기
            $scriptPath = $PSCommandPath
            if ($scriptPath) {
                $batchPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $scriptPath)) -ChildPath "start-gui.bat"
                if (Test-Path $batchPath) {
                    # 새 프로세스 시작
                    Start-Process "cmd.exe" -ArgumentList "/c `"$batchPath`"" -NoNewWindow
                    
                    # 현재 폼 종료
                    $form.Close()
                } else {
                    throw "Could not find start-gui.bat"
                }
            } else {
                throw "Could not determine script path"
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("No updates found.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Update failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $updateButton.Enabled = $true
        $updateButton.Text = "GITHUB UPDATE"
    }
})

# Show Console Window 체크박스
$showConsoleCheckbox = New-Object System.Windows.Forms.CheckBox
$showConsoleCheckbox.Location = New-Object System.Drawing.Point(30,120)
$showConsoleCheckbox.Size = New-Object System.Drawing.Size(180,20)
$showConsoleCheckbox.Text = "Show Console Window"
$showConsoleCheckbox.Checked = $false

# Weather-CCTV GroupBox 생성
$weatherGroupBox = New-Object System.Windows.Forms.GroupBox
$weatherGroupBox.Location = New-Object System.Drawing.Point(20,150)
$weatherGroupBox.Size = New-Object System.Drawing.Size(240,120)
$weatherGroupBox.Text = "Weather-CCTV"
$weatherGroupBox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$weatherGroupBox.Font = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)

# Weather-CCTV 버튼들
$weatherStartButton = New-Object System.Windows.Forms.Button
$weatherStartButton.Location = New-Object System.Drawing.Point(30,30)
$weatherStartButton.Size = New-Object System.Drawing.Size(180,30)
$weatherStartButton.Text = "START"

$weatherStopButton = New-Object System.Windows.Forms.Button
$weatherStopButton.Location = New-Object System.Drawing.Point(30,70)
$weatherStopButton.Size = New-Object System.Drawing.Size(180,30)
$weatherStopButton.Text = "STOP"

# Weather-CCTV URL 링크 생성
$weatherUrlLink = New-Object System.Windows.Forms.LinkLabel
$weatherUrlLink.Location = New-Object System.Drawing.Point(30,30)
$weatherUrlLink.Size = New-Object System.Drawing.Size(180,20)
$weatherUrlLink.Text = ""
$weatherUrlLink.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$weatherUrlLink.ForeColor = [System.Drawing.Color]::DarkBlue
$weatherUrlLink.Add_Click({
    if ($weatherUrlLink.Text) {
        Start-Process "http://localhost:3000"
    }
})

# Building-Wind GroupBox 생성
$buildingGroupBox = New-Object System.Windows.Forms.GroupBox
$buildingGroupBox.Location = New-Object System.Drawing.Point(20,290)
$buildingGroupBox.Size = New-Object System.Drawing.Size(240,120)
$buildingGroupBox.Text = "Building-Wind"
$buildingGroupBox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$buildingGroupBox.Font = New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)

# Building-Wind 버튼들
$buildingStartButton = New-Object System.Windows.Forms.Button
$buildingStartButton.Location = New-Object System.Drawing.Point(30,30)
$buildingStartButton.Size = New-Object System.Drawing.Size(180,30)
$buildingStartButton.Text = "START"

$buildingStopButton = New-Object System.Windows.Forms.Button
$buildingStopButton.Location = New-Object System.Drawing.Point(30,70)
$buildingStopButton.Size = New-Object System.Drawing.Size(180,30)
$buildingStopButton.Text = "STOP"

# Building-Wind URL 링크 생성
$buildingUrlLink = New-Object System.Windows.Forms.LinkLabel
$buildingUrlLink.Location = New-Object System.Drawing.Point(30,50)
$buildingUrlLink.Size = New-Object System.Drawing.Size(180,20)
$buildingUrlLink.Text = ""
$buildingUrlLink.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$buildingUrlLink.ForeColor = [System.Drawing.Color]::DarkGreen
$buildingUrlLink.Add_Click({
    if ($buildingUrlLink.Text) {
        Start-Process "http://localhost:8080"
    }
})

# 컨트롤들을 GroupBox에 추가
$updateGroupBox.Controls.Add($updateButton)

$weatherGroupBox.Controls.Add($weatherStartButton)
$weatherGroupBox.Controls.Add($weatherStopButton)

$buildingGroupBox.Controls.Add($buildingStartButton)
$buildingGroupBox.Controls.Add($buildingStopButton)

# URL 표시용 GroupBox 생성
$urlGroupBox = New-Object System.Windows.Forms.GroupBox
$urlGroupBox.Location = New-Object System.Drawing.Point(20,430)  # 위치 조정
$urlGroupBox.Size = New-Object System.Drawing.Size(240,80)
$urlGroupBox.Text = "Service URLs"
$urlGroupBox.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat

# URL GroupBox에 링크 추가
$urlGroupBox.Controls.Add($weatherUrlLink)
$urlGroupBox.Controls.Add($buildingUrlLink)

# 저작권 레이블 생성
$copyrightLabel = New-Object System.Windows.Forms.Label
$copyrightLabel.Location = New-Object System.Drawing.Point(20, 530)
$copyrightLabel.Size = New-Object System.Drawing.Size(240, 25)
$copyrightLabel.Text = "Copyright 2025 JungWooGyun. All rights reserved."
$copyrightLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$copyrightLabel.ForeColor = [System.Drawing.Color]::Gray
$copyrightLabel.Font = New-Object System.Drawing.Font("맑은 고딕", 8)

# GroupBox들을 폼에 추가
$form.Controls.Add($updateGroupBox)
$form.Controls.Add($showConsoleCheckbox)
$form.Controls.Add($weatherGroupBox)
$form.Controls.Add($buildingGroupBox)
$form.Controls.Add($urlGroupBox)  # URL GroupBox 추가
$form.Controls.Add($copyrightLabel)

# Weather-CCTV Start 버튼 클릭 이벤트
$weatherStartButton.Add_Click({
    $weatherStartButton.Enabled = $false
    $weatherStartButton.Text = "STARTING..."
    try {
        if ($showConsoleCheckbox.Checked) {
            # 콘솔 창 표시 모드로 실행
            $scriptPath = $PSScriptRoot
            $command = @"
                Set-Location '$scriptPath'
                . './weather-cctv-commands.ps1'
                . './buildingwind-commands.ps1'
                `$projectPath = Split-Path -Parent (Split-Path -Parent '$scriptPath')
                function Get-ProjectPath { return `$projectPath }
                Start-WeatherCCTV
                exit `$LASTEXITCODE
"@
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = "powershell.exe"
            $startInfo.Arguments = "-Command `"$command`""
            $startInfo.UseShellExecute = $true
            $startInfo.WindowStyle = 'Normal'
            $process = [System.Diagnostics.Process]::Start($startInfo)
            $process.WaitForExit()
            
            if ($process.ExitCode -ne 0) {
                throw "Failed to start services"
            }
        } else {
            Start-WeatherCCTV
        }
        
        # Building-Wind 버튼들 비활성화
        $buildingStartButton.Enabled = $false
        $buildingStopButton.Enabled = $false
        
        # Success 메시지 표시
        [System.Windows.Forms.MessageBox]::Show("Weather-CCTV services started successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Success 메시지 후 URL 링크 표시
        $weatherUrlLink.Text = "localhost:3000"
        
        # PowerShell 프로세스 종료
        if ($showConsoleCheckbox.Checked -and $process -and -not $process.HasExited) {
            $process.Kill()
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start Weather-CCTV services: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $weatherStartButton.Enabled = $true
    }
    finally {
        $weatherStartButton.Text = "START"
    }
})

# Weather-CCTV Stop 버튼 클릭 이벤트
$weatherStopButton.Add_Click({
    $weatherStopButton.Enabled = $false
    $weatherStopButton.Text = "STOPPING..."
    try {
        Stop-WeatherCCTV
        
        # URL 링크 숨김
        $weatherUrlLink.Text = ""
        
        # 모든 버튼 활성화
        $weatherStartButton.Enabled = $true
        $weatherStopButton.Enabled = $true
        $buildingStartButton.Enabled = $true
        $buildingStopButton.Enabled = $true
        
        [System.Windows.Forms.MessageBox]::Show("Weather-CCTV services stopped successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to stop Weather-CCTV services: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $weatherStopButton.Text = "STOP"
    }
})

# Building-Wind Start 버튼 클릭 이벤트
$buildingStartButton.Add_Click({
    $buildingStartButton.Enabled = $false
    $buildingStartButton.Text = "STARTING..."
    try {
        if ($showConsoleCheckbox.Checked) {
            # 콘솔 창 표시 모드로 실행
            $scriptPath = $PSScriptRoot
            $command = @"
                Set-Location '$scriptPath'
                . './weather-cctv-commands.ps1'
                . './buildingwind-commands.ps1'
                `$projectPath = Split-Path -Parent (Split-Path -Parent '$scriptPath')
                function Get-ProjectPath { return `$projectPath }
                Start-BuildingWind
                exit `$LASTEXITCODE
"@
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = "powershell.exe"
            $startInfo.Arguments = "-Command `"$command`""
            $startInfo.UseShellExecute = $true
            $startInfo.WindowStyle = 'Normal'
            $process = [System.Diagnostics.Process]::Start($startInfo)
            $process.WaitForExit()
            
            if ($process.ExitCode -ne 0) {
                throw "Failed to start services"
            }
        } else {
            # 콘솔 창 숨김 모드로 실행
            Start-BuildingWind
        }
        
        # Success 메시지 표시
        [System.Windows.Forms.MessageBox]::Show("Building-Wind services started successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        
        # Success 메시지 후 URL 링크 표시
        $buildingUrlLink.Text = "localhost:8080"
        
        # Weather-CCTV 버튼들 비활성화
        $weatherStartButton.Enabled = $false
        $weatherStopButton.Enabled = $false
        
        # PowerShell 프로세스 종료
        if ($showConsoleCheckbox.Checked -and $process -and -not $process.HasExited) {
            $process.Kill()
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start Building-Wind services: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $buildingStartButton.Enabled = $true
    }
    finally {
        $buildingStartButton.Text = "START"
    }
})

# Building-Wind Stop 버튼 클릭 이벤트
$buildingStopButton.Add_Click({
    $buildingStopButton.Enabled = $false
    $buildingStopButton.Text = "STOPPING..."
    try {
        Stop-BuildingWind
        
        # URL 링크 숨김
        $buildingUrlLink.Text = ""
        
        # 모든 버튼 활성화
        $weatherStartButton.Enabled = $true
        $weatherStopButton.Enabled = $true
        $buildingStartButton.Enabled = $true
        $buildingStopButton.Enabled = $true
        
        [System.Windows.Forms.MessageBox]::Show("Building-Wind services stopped successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to stop Building-Wind services: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $buildingStopButton.Text = "STOP"
    }
})

# 폼 표시
$form.ShowDialog() 