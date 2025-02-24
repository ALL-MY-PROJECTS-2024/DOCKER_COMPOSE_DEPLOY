Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Docker 명령어 스크립트 로드
. (Join-Path -Path $PSScriptRoot -ChildPath "docker-commands.ps1")

# Form 생성
$form = New-Object System.Windows.Forms.Form
$form.Text = "Weather-CCTV Controller"
$form.Size = New-Object System.Drawing.Size(300,350)
$form.StartPosition = "CenterScreen"

# Weather-CCTV GroupBox 생성
$weatherGroupBox = New-Object System.Windows.Forms.GroupBox
$weatherGroupBox.Location = New-Object System.Drawing.Point(20,20)
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
$buildingGroupBox.Location = New-Object System.Drawing.Point(20,160)
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
$weatherGroupBox.Controls.Add($weatherStartButton)
$weatherGroupBox.Controls.Add($weatherStopButton)
$buildingGroupBox.Controls.Add($buildingStartButton)
$buildingGroupBox.Controls.Add($buildingStopButton)

# GroupBox를 폼에 추가
$form.Controls.Add($weatherGroupBox)
$form.Controls.Add($buildingGroupBox)

# 폼 표시
$form.ShowDialog() 