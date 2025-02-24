# Docker 명령어 실행을 위한 함수들

function Get-ComposeFilePath {
    return Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath "DOCKER_COMPOSE_DEPLOY\compose\weather-cctv-docker-compose.yml"
}

function Get-BuildingWindComposePath {
    return Join-Path -Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) -ChildPath "DOCKER_COMPOSE_DEPLOY\compose\buildingwind-docker-compose.yml"
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
    
    # 사용하지 않는 이미지 삭제
    Start-Process "docker" -ArgumentList "image prune -a -f" -NoNewWindow
} 