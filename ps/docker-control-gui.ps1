Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Docker 명령어 스크립트 로드
. (Join-Path -Path $PSScriptRoot -ChildPath "docker-commands.ps1")

# Form 생성
$form = New-Object System.Windows.Forms.Form
$form.Text = "Docker Manager"
$form.Size = New-Object System.Drawing.Size(300,450)
$form.StartPosition = "CenterScreen"

# Update GroupBox 생성
$updateGroupBox = New-Object System.Windows.Forms.GroupBox
$updateGroupBox.Location = New-Object System.Drawing.Point(20,20)
$updateGroupBox.Size = New-Object System.Drawing.Size(240,80)
$updateGroupBox.Text = "Update"

# Update 버튼 생성
$updateButton = New-Object System.Windows.Forms.Button
$updateButton.Location = New-Object System.Drawing.Point(30,30)
$updateButton.Size = New-Object System.Drawing.Size(180,30)
$updateButton.Text = "Update & Restart"
$updateButton.Add_Click({
    $updateButton.Enabled = $false
    $updateButton.Text = "Updating..."
    try {
        $hasChanges = Update-Project
        if ($hasChanges) {
            [System.Windows.Forms.MessageBox]::Show("Updates found. The application will restart.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            # 현재 프로세스의 경로와 인수를 가져옴
            $scriptPath = $MyInvocation.MyCommand.Path
            $batchPath = Join-Path -Path (Split-Path -Parent (Split-Path -Parent $scriptPath)) -ChildPath "start-gui.bat"
            
            # 새 프로세스 시작
            Start-Process "cmd.exe" -ArgumentList "/c `"$batchPath`"" -NoNewWindow
            
            # 현재 폼 종료
            $form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("No updates found.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $updateButton.Enabled = $true
            $updateButton.Text = "Update & Restart"
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Update failed: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $updateButton.Enabled = $true
        $updateButton.Text = "Update & Restart"
    }
})

# Weather-CCTV GroupBox 생성
$weatherGroupBox = New-Object System.Windows.Forms.GroupBox
$weatherGroupBox.Location = New-Object System.Drawing.Point(20,120)
$weatherGroupBox.Size = New-Object System.Drawing.Size(240,120)
$weatherGroupBox.Text = "Weather-CCTV"

# Weather-CCTV Start 버튼 생성
$weatherStartButton = New-Object System.Windows.Forms.Button
$weatherStartButton.Location = New-Object System.Drawing.Point(30,40)
$weatherStartButton.Size = New-Object System.Drawing.Size(180,30)
$weatherStartButton.Text = "Start"
$weatherStartButton.Add_Click({
    Start-WeatherCCTV
})

# Weather-CCTV Stop 버튼 생성
$weatherStopButton = New-Object System.Windows.Forms.Button
$weatherStopButton.Location = New-Object System.Drawing.Point(30,80)
$weatherStopButton.Size = New-Object System.Drawing.Size(180,30)
$weatherStopButton.Text = "Stop"
$weatherStopButton.Add_Click({
    Stop-WeatherCCTV
})

# BuildingWind GroupBox 생성
$buildingGroupBox = New-Object System.Windows.Forms.GroupBox
$buildingGroupBox.Location = New-Object System.Drawing.Point(20,260)
$buildingGroupBox.Size = New-Object System.Drawing.Size(240,120)
$buildingGroupBox.Text = "BuildingWind"

# BuildingWind Start 버튼 생성
$buildingStartButton = New-Object System.Windows.Forms.Button
$buildingStartButton.Location = New-Object System.Drawing.Point(30,40)
$buildingStartButton.Size = New-Object System.Drawing.Size(180,30)
$buildingStartButton.Text = "Start"
$buildingStartButton.Add_Click({
    Start-BuildingWind
})

# BuildingWind Stop 버튼 생성
$buildingStopButton = New-Object System.Windows.Forms.Button
$buildingStopButton.Location = New-Object System.Drawing.Point(30,80)
$buildingStopButton.Size = New-Object System.Drawing.Size(180,30)
$buildingStopButton.Text = "Stop"
$buildingStopButton.Add_Click({
    Stop-BuildingWind
})

# 컨트롤들을 GroupBox에 추가
$updateGroupBox.Controls.Add($updateButton)
$weatherGroupBox.Controls.Add($weatherStartButton)
$weatherGroupBox.Controls.Add($weatherStopButton)
$buildingGroupBox.Controls.Add($buildingStartButton)
$buildingGroupBox.Controls.Add($buildingStopButton)

# GroupBox를 폼에 추가
$form.Controls.Add($updateGroupBox)
$form.Controls.Add($weatherGroupBox)
$form.Controls.Add($buildingGroupBox)

# 폼 표시
$form.ShowDialog() 