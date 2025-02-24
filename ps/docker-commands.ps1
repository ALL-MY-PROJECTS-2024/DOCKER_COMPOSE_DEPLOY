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
    Start-Process "docker-compose" -ArgumentList "-f `"$composeFilePath`" up -d" -NoNewWindow -Wait
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
    Start-Process "docker-compose" -ArgumentList "-f `"$composePath`" up -d" -NoNewWindow -Wait
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