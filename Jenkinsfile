pipeline {
    agent any

    // Optional: Check GitHub for changes approximately every 2 minutes
    // Uncomment only if SCM polling is required.
    // triggers {
    //     pollSCM('H/2 * * * *')
    // }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        // Nexus Configuration
        NEXUS_URL = 'http://localhost:8081/repository/maven-releases'
        NEXUS_WAR = 'koddas/web/war/wwp/1.0.0/wwp-1.0.0.war'

        // Tomcat Configuration
        TOMCAT_URL = 'http://localhost:8082'
        TOMCAT_CONTEXT = '/wwp'

        // Application Configuration
        WAR_FILE = 'wwp-1.0.0.war'
        SONAR_PROJECT = 'wwp'

        // Docker Desktop executable on this Windows machine
        DOCKER_EXE = 'C:/Users/Bussa/AppData/Local/Programs/DockerDesktop/resources/bin/docker.exe'
        DOCKER_IMAGE = 'bussar/wwp:1.0.0'
        DOCKER_CONTAINER = 'wwp-container'
        DOCKER_PORT = '8083'
    }

    stages {

        // 1. Checkout source code
        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub'
                checkout scm
            }
        }

        // 2. Verify required tools and Docker Engine connectivity
        stage('Verify Environment') {
            steps {
                bat '''
                    echo ===== Verify Java =====
                    java -version
                    if errorlevel 1 exit /b 1

                    echo ===== Verify Maven =====
                    mvn -version
                    if errorlevel 1 exit /b 1

                    echo ===== Verify Docker CLI =====
                    if not exist "%DOCKER_EXE%" (
                        echo ERROR: Docker executable not found: %DOCKER_EXE%
                        exit /b 1
                    )

                    "%DOCKER_EXE%" --version
                    if errorlevel 1 exit /b 1

                    echo ===== Verify Docker Engine =====
                    "%DOCKER_EXE%" info
                    if errorlevel 1 (
                        echo ERROR: Jenkins cannot connect to Docker Engine.
                        echo Check Docker Desktop status and Jenkins service account.
                        exit /b 1
                    )

                    echo Environment verification successful.
                '''
            }
        }

        // 3. Clean previous build
        stage('Maven Clean') {
            steps {
                echo 'Cleaning previous build files'
                bat 'mvn clean'
            }
        }

        // 4. Compile Java code
        stage('Compile') {
            steps {
                echo 'Compiling Java source code'
                bat 'mvn compile'
            }
        }

        // 5. Execute unit tests
        stage('Unit Tests') {
            steps {
                echo 'Running unit tests'
                bat 'mvn test'
            }
            post {
                always {
                    junit(
                        allowEmptyResults: true,
                        testResults: '**/surefire-reports/TEST-*.xml'
                    )
                }
            }
        }

        // 6. Package WAR file
        stage('Package WAR') {
            steps {
                echo 'Packaging application into WAR file'
                bat 'mvn package -DskipTests'

                script {
                    if (!fileExists('target/wwp-1.0.0.war')) {
                        error 'WAR file was not generated!'
                    }
                }
            }
        }

        // 7. SonarQube code analysis
        stage('SonarQube Analysis') {
            steps {
                echo 'Starting SonarQube code analysis'

                withSonarQubeEnv('SonarQube-Server') {
                    bat '''
                        mvn org.sonarsource.scanner.maven:sonar-maven-plugin:5.8.0.7211:sonar
                        if errorlevel 1 exit /b 1
                    '''
                }
            }
        }

        // 8. Optional Quality Gate
        // Enable after configuring the SonarQube webhook in Jenkins.
        // stage('Quality Gate') {
        //     steps {
        //         timeout(time: 5, unit: 'MINUTES') {
        //             script {
        //                 def qualityGate = waitForQualityGate(abortPipeline: false)
        //                 echo "Quality Gate Status: ${qualityGate.status}"
        //             }
        //         }
        //     }
        // }

        // 9. Upload WAR to Nexus
        stage('Upload to Nexus') {
            steps {
                echo 'Uploading WAR file to Nexus Repository'
                bat '''
                    mvn deploy -DskipTests
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        // 10. Archive WAR in Jenkins
        stage('Archive WAR') {
            steps {
                echo 'Archiving WAR file in Jenkins'
                archiveArtifacts(
                    artifacts: 'target/wwp-1.0.0.war',
                    fingerprint: true
                )
            }
        }

        // 11. Download WAR from Nexus
        stage('Download from Nexus') {
            steps {
                echo 'Downloading WAR file from Nexus'

                bat '''
                    if not exist deployment mkdir deployment

                    curl.exe --fail --location --silent --show-error ^
                      --output deployment\\wwp-1.0.0.war ^
                      "%NEXUS_URL%/%NEXUS_WAR%"

                    if errorlevel 1 (
                        echo ERROR: Nexus download failed.
                        exit /b 1
                    )

                    if not exist deployment\\wwp-1.0.0.war (
                        echo ERROR: WAR file not found.
                        exit /b 1
                    )

                    echo WAR downloaded successfully from Nexus.
                '''
            }
        }

        // 12. Deploy WAR to Tomcat
        stage('Deploy to Tomcat') {
            steps {
                echo 'Deploying WAR file to Tomcat'

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
                          --upload-file "deployment\\wwp-1.0.0.war" ^
                          "%TOMCAT_URL%/manager/text/deploy?path=%TOMCAT_CONTEXT%&update=true"

                        if errorlevel 1 (
                            echo ERROR: Tomcat deployment failed.
                            exit /b 1
                        )

                        echo Tomcat deployment successful.
                    '''
                }
            }
        }

        // 13. Tomcat application health check
        stage('Tomcat Health Check') {
            steps {
                echo 'Checking deployed Tomcat application'

                bat '''
                    powershell -NoProfile -Command "$url='http://localhost:8082/wwp/'; for ($i=1; $i -le 10; $i++) { try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Tomcat application is healthy. HTTP 200'; exit 0 } } catch { Write-Host ('Attempt ' + $i + ' failed') }; Start-Sleep -Seconds 5 }; Write-Host 'Tomcat health check failed'; exit 1"
                '''
            }
        }

        // 14. Build Docker Image
        stage('Docker Build') {
            steps {
                echo 'Building Docker image'

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

        // 15. Push Docker Image to Docker Hub
        stage('Push to Docker Hub') {
    steps {
        echo 'Pushing Docker image to Docker Hub'

        withCredentials([
            usernamePassword(
                credentialsId: 'dockerhub-credentials',
                usernameVariable: 'DOCKERHUB_USER',
                passwordVariable: 'DOCKERHUB_TOKEN'
            )
        ]) {
            bat '''
                echo %DOCKERHUB_TOKEN% | "%DOCKER_EXE%" login -u "%DOCKERHUB_USER%" --password-stdin

                if errorlevel 1 (
                    echo ERROR: Docker Hub login failed.
                    exit /b 1
                )

                "%DOCKER_EXE%" push "%DOCKER_IMAGE%"

                if errorlevel 1 (
                    echo ERROR: Docker image push failed.
                    exit /b 1
                )

                "%DOCKER_EXE%" logout
            '''
        }
    }
}

        // 16. Pull image and create Docker container
        stage('Run Docker Container') {
            steps {
                echo 'Pulling Docker image from Docker Hub'

                bat '''
                    "%DOCKER_EXE%" pull "%DOCKER_IMAGE%"

                    if errorlevel 1 (
                        echo ERROR: Docker image pull failed.
                        exit /b 1
                    )

                    echo Docker image downloaded successfully.

                    "%DOCKER_EXE%" rm -f "%DOCKER_CONTAINER%" >NUL 2>&1

                    "%DOCKER_EXE%" run -d ^
                        --name "%DOCKER_CONTAINER%" ^
                        --restart unless-stopped ^
                        -p %DOCKER_PORT%:8080 ^
                        "%DOCKER_IMAGE%"

                    if errorlevel 1 (
                        echo ERROR: Docker container creation failed.
                        exit /b 1
                    )

                    echo Docker container started successfully.
                '''
            }
        }

        // 17. Docker application health check
        stage('Docker Health Check') {
            steps {
                echo 'Checking Docker application'

                bat '''
                    powershell -NoProfile -Command "$url='http://localhost:8083/wwp/'; for ($i=1; $i -le 12; $i++) { try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Docker application is healthy. HTTP 200'; exit 0 } } catch { Write-Host ('Attempt ' + $i + ' failed') }; Start-Sleep -Seconds 5 }; Write-Host 'Docker health check failed'; exit 1"
                '''
            }
        }
    }

    // Post build actions
    post {
        success {
            echo 'SUCCESS: Complete CI/CD Pipeline executed successfully.'
            echo 'Tomcat Application: http://localhost:8082/wwp/'
            echo 'Docker Application: http://localhost:8083/wwp/'
            echo 'Docker Image: bussar/wwp:1.0.0'
        }

        failure {
            echo 'ERROR: Pipeline failed. Check the failed stage in Console Output.'
        }

        always {
            echo 'Pipeline execution completed.'
        }
    }
}
