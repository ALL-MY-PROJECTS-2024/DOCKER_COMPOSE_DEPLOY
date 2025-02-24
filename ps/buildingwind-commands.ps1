function Start-BuildingWind {
    # Weather-CCTV가 실행 중이면 중지 및 정리
    $weatherRunning = docker ps -q -f name=weather
    if ($weatherRunning) {
        Write-Host "Stopping Weather-CCTV services..."
        Stop-WeatherCCTV
        Start-Sleep -Seconds 5
        
        # 모든 Weather-CCTV 이미지와 컨테이너 정리
        Write-Host "Cleaning up Weather-CCTV resources..."
        docker container prune -f
        Remove-WeatherCCTVImages
        docker image prune -f
        Start-Sleep -Seconds 2
        
        Write-Host "Weather-CCTV cleanup completed."
    }
    
    # BuildingWind 시작
    Write-Host "Starting BuildingWind services..."
    $composePath = Get-BuildingWindComposePath
    $startArgs = @{
        FilePath = "docker-compose"
        ArgumentList = "-f `"$composePath`" up -d"
        Wait = $true
        NoNewWindow = $true  # 콘솔 창을 새로 열지 않고 현재 창 사용
    }
    Start-Process @startArgs
}

function Stop-BuildingWind {
    $composePath = Get-BuildingWindComposePath
    Write-Host "Stopping BuildingWind services..."
    
    # Docker Compose 중지
    Start-Process "docker-compose" -ArgumentList "-f `"$composePath`" down" -NoNewWindow -Wait
    
    # 모든 중지된 컨테이너 삭제
    Write-Host "Removing stopped containers..."
    docker container prune -f
    
    # BuildingWind 관련 이미지 삭제
    Write-Host "Removing BuildingWind images..."
    Remove-BuildingWindImages
    
    # 사용하지 않는 이미지 삭제
    Write-Host "Cleaning up unused images..."
    docker image prune -f
}

function Get-BuildingWindComposePath {
    return Join-Path -Path (Get-ProjectPath) -ChildPath "DOCKER_COMPOSE_DEPLOY\compose\buildingwind-docker-compose.yml"
}

function Remove-BuildingWindImages {
    # BuildingWind 관련 이미지 삭제
    $images = @(
        "junwoogyun/mysql8-custom:latest",
        "junwoogyun/bn-building:latest"
    )
    
    foreach ($image in $images) {
        Write-Host "Removing image: $image"
        docker rmi $image -f 2>$null
    }
} 