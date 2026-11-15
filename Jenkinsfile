
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        // Nexus
        NEXUS_URL        = 'http://localhost:8081/repository/maven-releases'
        NEXUS_WAR        = 'koddas/web/war/wwp/1.0.0/wwp-1.0.0.war'

        // Tomcat
        TOMCAT_URL       = 'http://localhost:8082'
        TOMCAT_CONTEXT   = '/wwp'
        WAR_FILE         = 'wwp-1.0.0.war'

        // SonarQube
        SONAR_PROJECT    = 'wwp'

        // Docker
        DOCKER_EXE       = 'C:/Users/Bussa/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe'
        DOCKER_IMAGE     = 'bussar/wwp:1.0.0'
        DOCKER_CONTAINER = 'wwp-container'
        DOCKER_PORT      = '8083'
        
        KUBECTL_EXE = 'C:/Users/Bussa/AppData/Local/Programs/DockerDesktop/resources/bin/kubectl.exe'
        KUBECONFIG = 'C:/Users/Bussa/.kube/config'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify Environment') {
            steps {
                bat '''
                    java -version
                    if errorlevel 1 exit /b 1

                    mvn -version
                    if errorlevel 1 exit /b 1

                    if not exist "%DOCKER_EXE%" (
                        echo ERROR: Docker executable not found.
                        exit /b 1
                    )

                    "%DOCKER_EXE%" --version
                    if errorlevel 1 exit /b 1

                    "%DOCKER_EXE%" info >NUL
                    if errorlevel 1 (
                        echo ERROR: Docker Engine is not running.
                        exit /b 1
                    )
                '''
            }
        }

        stage('Build WAR') {
            steps {
                bat 'mvn clean package -DskipTests'

                script {
                    if (!fileExists('target/wwp-1.0.0.war')) {
                        error 'WAR file was not generated!'
                    }

                    echo 'SUCCESS: WAR file generated.'
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    bat '''
                        mvn org.sonarsource.scanner.maven:sonar-maven-plugin:5.8.0.7211:sonar -Dsonar.projectKey=%SONAR_PROJECT%

                        if errorlevel 1 exit /b 1
                    '''
                }
            }
        }

        stage('Upload to Nexus') {
            steps {
                bat '''
                    mvn deploy -DskipTests

                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Archive WAR') {
            steps {
                archiveArtifacts(
                    artifacts: 'target/wwp-1.0.0.war',
                    fingerprint: true
                )
            }
        }

        stage('Download WAR from Nexus') {
            steps {
                bat '''
                    if not exist deployment mkdir deployment

                    curl.exe --fail --location --silent --show-error ^
                        --output "deployment\\%WAR_FILE%" ^
                        "%NEXUS_URL%/%NEXUS_WAR%"

                    if errorlevel 1 (
                        echo ERROR: Nexus download failed.
                        exit /b 1
                    )
                '''
            }
        }

        stage('Deploy to Tomcat') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'tomcat-credentials',
                        usernameVariable: 'TOMCAT_USR',
                        passwordVariable: 'TOMCAT_PSW'
                    )
                ]) {
                    bat '''
                        curl.exe --fail --silent --show-error ^
                            --user "%TOMCAT_USR%:%TOMCAT_PSW%" ^
                            --upload-file "deployment\\%WAR_FILE%" ^
                            "%TOMCAT_URL%/manager/text/deploy?path=%TOMCAT_CONTEXT%&update=true"

                        if errorlevel 1 (
                            echo ERROR: Tomcat deployment failed.
                            exit /b 1
                        )
                    '''
                }
            }
        }

        stage('Tomcat Health Check') {
            steps {
                bat '''
                    powershell -NoProfile -Command "$url='http://localhost:8082/wwp/'; for ($i=1; $i -le 12; $i++) { try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Tomcat application is healthy'; exit 0 } } catch { Write-Host ('Attempt ' + $i + ' failed') }; Start-Sleep -Seconds 5 }; throw 'Tomcat health check failed'"
                '''
            }
        }


        stage('Docker Build') {
            steps {
                bat '''
                    "%DOCKER_EXE%" build --pull -t "%DOCKER_IMAGE%" .
        
                    if errorlevel 1 (
                        echo ERROR: Docker image build failed.
                        exit /b 1
                    )
        
                    echo Docker image built successfully.
                '''
            }
        }



stage('Push to Docker Hub') {
    steps {
        withCredentials([
            usernamePassword(
                credentialsId: 'dockerhub-credentials',
                usernameVariable: 'DOCKERHUB_USER',
                passwordVariable: 'DOCKERHUB_TOKEN'
            )
        ]) {
            bat '''
                @echo off
                echo Logging in to Docker Hub...

                echo(%DOCKERHUB_TOKEN%| "%DOCKER_EXE%" login -u "%DOCKERHUB_USER%" --password-stdin

                if errorlevel 1 (
                    echo ERROR: Docker Hub login failed.
                    exit /b 1
                )

                echo Docker Hub login successful.

                "%DOCKER_EXE%" push "%DOCKER_IMAGE%"

                if errorlevel 1 (
                    echo ERROR: Docker Hub push failed.
                    exit /b 1
                )

                echo Docker image pushed successfully.

                "%DOCKER_EXE%" logout
            '''
        }
    }
}


        stage('Run Docker Container') {
            steps {
                bat '''
                    "%DOCKER_EXE%" pull "%DOCKER_IMAGE%"
                    if errorlevel 1 exit /b 1

                    "%DOCKER_EXE%" rm -f "%DOCKER_CONTAINER%" >NUL 2>&1

                    "%DOCKER_EXE%" run -d ^
                        --name "%DOCKER_CONTAINER%" ^
                        --restart unless-stopped ^
                        -p %DOCKER_PORT%:8080 ^
                        "%DOCKER_IMAGE%"

                    if errorlevel 1 (
                        echo ERROR: Docker container failed to start.
                        exit /b 1
                    )
                '''
            }
        }

        stage('Docker Health Check') {
            steps {
                bat '''
                    powershell -NoProfile -Command "$url='http://localhost:8083/wwp/'; for ($i=1; $i -le 12; $i++) { try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Docker application is healthy'; exit 0 } } catch { Write-Host ('Attempt ' + $i + ' failed') }; Start-Sleep -Seconds 5 }; throw 'Docker health check failed'"
                '''
            }
        }
         
        // 18. Deploy application to Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                echo 'Deploying application to Docker Desktop Kubernetes'

                bat '''
                    echo ===== Verify Kubernetes CLI =====
                    where kubectl

                    if errorlevel 1 (
                        echo ERROR: kubectl is not available to Jenkins.
                        exit /b 1
                    )

                    echo ===== Verify Kubernetes Context =====
                    kubectl config current-context

                    if errorlevel 1 (
                        echo ERROR: Jenkins cannot access Kubernetes configuration.
                        exit /b 1
                    )

                    echo ===== Verify Kubernetes Node =====
                    kubectl get nodes

                    if errorlevel 1 (
                        echo ERROR: Kubernetes cluster is not accessible.
                        exit /b 1
                    )

                    echo ===== Verify Deployment YAML =====
                    if not exist "k8s\\deploy.yml" (
                        echo ERROR: k8s/deploy.yml file not found.
                        exit /b 1
                    )

                    echo ===== Apply Kubernetes Manifest =====
                    kubectl apply -f k8s/deploy.yml

                    if errorlevel 1 (
                        echo ERROR: Kubernetes deployment failed.
                        exit /b 1
                    )

                    echo ===== Wait for Deployment =====
                    kubectl rollout status deployment/mywarweb-deployment --timeout=180s

                    if errorlevel 1 (
                        echo ERROR: Kubernetes rollout failed.
                        kubectl describe deployment mywarweb-deployment
                        kubectl get pods
                        exit /b 1
                    )

                    echo ===== Kubernetes Deployment Status =====
                    kubectl get deployments
                    kubectl get pods
                    kubectl get services

                    echo Kubernetes deployment completed successfully.
                '''
            }
        }

    }

    post {
        success {
            echo 'SUCCESS: CI/CD Pipeline completed successfully.'
            echo 'Tomcat URL: http://localhost:8082/wwp/'
            echo 'Docker URL: http://localhost:8083/wwp/'
            echo 'Docker Image: bussar/wwp:1.0.0'
            echo 'Kubernetes Deployment: SUCCESS'
            echo 'Kubernetes Application: http://localhost:30080/wwp/'
        }

        failure {
            echo 'ERROR: Pipeline failed. Check the failed stage in Console Output.'
        }

        always {
            echo 'Pipeline execution completed.'
        }
    }
}
