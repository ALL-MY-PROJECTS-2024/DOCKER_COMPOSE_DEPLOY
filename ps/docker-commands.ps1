# Docker 명령어 실행을 위한 함수들

function Get-ProjectPath {
    return Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}

function Get-ComposeFilePath {
    return Join-Path -Path (Get-ProjectPath) -ChildPath "DOCKER_COMPOSE_DEPLOY\compose\weather-cctv-docker-compose.yml"
}

function Get-BuildingWindComposePath {
    return Join-Path -Path (Get-ProjectPath) -ChildPath "DOCKER_COMPOSE_DEPLOY\compose\buildingwind-docker-compose.yml"
}

function Update-Project {
    $projectPath = Get-ProjectPath
    
    # Git 저장소 확인 및 설정
    if (Test-Path (Join-Path $projectPath ".git")) {
        # 기존 remote 제거 후 새로운 remote 추가
        Start-Process "git" -ArgumentList "remote remove origin" -NoNewWindow -Wait -WorkingDirectory $projectPath
        Start-Process "git" -ArgumentList "remote add origin https://github.com/ALL-MY-PROJECTS-2024/DOCKER_COMPOSE_DEPLOY.git" -NoNewWindow -Wait -WorkingDirectory $projectPath
    } else {
        # Git 저장소가 없으면 초기화
        Start-Process "git" -ArgumentList "init" -NoNewWindow -Wait -WorkingDirectory $projectPath
        Start-Process "git" -ArgumentList "remote add origin https://github.com/ALL-MY-PROJECTS-2024/DOCKER_COMPOSE_DEPLOY.git" -NoNewWindow -Wait -WorkingDirectory $projectPath
    }
    
    # Git fetch 및 main 브랜치 설정
    Start-Process "git" -ArgumentList "fetch" -NoNewWindow -Wait -WorkingDirectory $projectPath
    Start-Process "git" -ArgumentList "checkout main" -NoNewWindow -Wait -WorkingDirectory $projectPath
    
    # Git pull 실행
    Start-Process "git" -ArgumentList "pull origin main" -NoNewWindow -Wait -WorkingDirectory $projectPath
    
    # 현재 실행 중인 컨테이너 확인
    $weatherRunning = docker ps -q -f name=weather
    $buildingRunning = docker ps -q -f name=building
    
    # Weather-CCTV가 실행 중이면 재시작
    if ($weatherRunning) {
        Stop-WeatherCCTV
        Start-Sleep -Seconds 5
        Start-WeatherCCTV
    }
    
    # BuildingWind가 실행 중이면 재시작
    if ($buildingRunning) {
        Stop-BuildingWind
        Start-Sleep -Seconds 5
        Start-BuildingWind
    }
}

function Remove-WeatherCCTVImages {
    # Weather-CCTV 관련 이미지 삭제
    $images = @(
        "junwoogyun/mysql-custom:1.0",
        "junwoogyun/bn_redis:latest",
        "junwoogyun/flask-opencv-app:latest",
        "junwoogyun/flask-opencv-app2:latest",
        "junwoogyun/bn_auth:latest",
        "junwoogyun/react-docker-app:latest"
    )
    
    foreach ($image in $images) {
        Start-Process "docker" -ArgumentList "rmi $image -f" -NoNewWindow
    }
}

function Remove-BuildingWindImages {
    # BuildingWind 관련 이미지 삭제
    $images = @(
        "junwoogyun/mysql8-custom:latest",
        "junwoogyun/bn-building:latest"
    )
    
    foreach ($image in $images) {
        Start-Process "docker" -ArgumentList "rmi $image -f" -NoNewWindow
    }
}

function Start-WeatherCCTV {
    $composeFilePath = Get-ComposeFilePath
    Start-Process "docker-compose" -ArgumentList "-f `"$composeFilePath`" up -d" -NoNewWindow
}

function Stop-WeatherCCTV {
    $composeFilePath = Get-ComposeFilePath
    # Docker Compose 중지
    Start-Process "docker-compose" -ArgumentList "-f `"$composeFilePath`" down" -NoNewWindow
    
    # 모든 중지된 컨테이너 삭제
    Start-Process "docker" -ArgumentList "container prune -f" -NoNewWindow
    
    # Weather-CCTV 관련 이미지 삭제
    Remove-WeatherCCTVImages
    
    # 사용하지 않는 이미지 삭제
    Start-Process "docker" -ArgumentList "image prune -a -f" -NoNewWindow
}

function Start-BuildingWind {
    $composePath = Get-BuildingWindComposePath
    Start-Process "docker-compose" -ArgumentList "-f `"$composePath`" up -d" -NoNewWindow
}

function Stop-BuildingWind {
    $composePath = Get-BuildingWindComposePath
    # Docker Compose 중지
    Start-Process "docker-compose" -ArgumentList "-f `"$composePath`" down" -NoNewWindow
    
    # 모든 중지된 컨테이너 삭제
    Start-Process "docker" -ArgumentList "container prune -f" -NoNewWindow
    
    # BuildingWind 관련 이미지 삭제
    Remove-BuildingWindImages
    
    # 사용하지 않는 이미지 삭제
    Start-Process "docker" -ArgumentList "image prune -a -f" -NoNewWindow
} 