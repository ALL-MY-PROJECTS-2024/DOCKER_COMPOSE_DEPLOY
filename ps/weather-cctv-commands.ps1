function Get-ComposeFilePath {
    return Join-Path -Path (Get-ProjectPath) -ChildPath "DOCKER_COMPOSE_DEPLOY\compose\weather-cctv-docker-compose.yml"
}

function Start-WeatherCCTV {
    # BuildingWind가 실행 중이면 중지 및 정리
    $buildingRunning = docker ps -q -f name=building
    if ($buildingRunning) {
        Write-Host "Stopping BuildingWind services..."
        Stop-BuildingWind
        Start-Sleep -Seconds 5
        
        # 모든 BuildingWind 이미지와 컨테이너 정리
        Write-Host "Cleaning up BuildingWind resources..."
        docker container prune -f
        Remove-BuildingWindImages
        docker image prune -f
        Start-Sleep -Seconds 2
        
        Write-Host "BuildingWind cleanup completed."
    }
    
    # Weather-CCTV 시작
    Write-Host "Starting Weather-CCTV services..."
    $composeFilePath = Get-ComposeFilePath
    
    # MySQL과 Redis 먼저 시작
    Write-Host "Starting MySQL and Redis..."
    Start-Process "docker-compose" -ArgumentList "-f `"$composeFilePath`" up -d mysql-container bn_redis-container" -NoNewWindow -Wait
    Start-Sleep -Seconds 10  # MySQL이 완전히 시작될 때까지 대기
    
    # MySQL 상태 확인
    $mysqlHealthy = $false
    $retryCount = 0
    while (-not $mysqlHealthy -and $retryCount -lt 5) {
        $status = docker inspect --format='{{.State.Health.Status}}' mysql-container 2>$null
        if ($status -eq "healthy") {
            $mysqlHealthy = $true
        } else {
            Write-Host "Waiting for MySQL to be healthy... (Attempt $($retryCount + 1))"
            Start-Sleep -Seconds 5
            $retryCount++
        }
    }
    
    if (-not $mysqlHealthy) {
        throw "MySQL failed to become healthy"
    }
    
    # 나머지 서비스 시작
    Write-Host "Starting remaining services..."
    Start-Process "docker-compose" -ArgumentList "-f `"$composeFilePath`" up -d" -NoNewWindow -Wait
    
    # bn_auth 컨테이너 상태 확인
    Start-Sleep -Seconds 5
    $authLogs = docker logs bn_auth-container 2>&1
    if ($authLogs) {
        Write-Host "bn_auth-container logs:"
        Write-Host $authLogs
    }
    
    $containerStatus = docker ps -a --format "{{.Names}}: {{.Status}}" | Select-String "bn_auth-container"
    if ($containerStatus -match "Exited") {
        throw "bn_auth-container failed to start. Please check the logs above."
    }
    
    Write-Host "All services started successfully."
}

function Stop-WeatherCCTV {
    $composeFilePath = Get-ComposeFilePath
    Write-Host "Stopping Weather-CCTV services..."
    
    # Docker Compose 중지
    Start-Process "docker-compose" -ArgumentList "-f `"$composeFilePath`" down" -NoNewWindow -Wait
    
    # 모든 중지된 컨테이너 삭제
    Write-Host "Removing stopped containers..."
    docker container prune -f
    
    # Weather-CCTV 관련 이미지 삭제
    Write-Host "Removing Weather-CCTV images..."
    Remove-WeatherCCTVImages
    
    # 사용하지 않는 이미지 삭제
    Write-Host "Cleaning up unused images..."
    docker image prune -f
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
        Write-Host "Removing image: $image"
        docker rmi $image -f 2>$null
    }
} 