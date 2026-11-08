
pipeline {
    agent any

    // Check GitHub for changes approximately every 2 minutes
    triggers {
        pollSCM('H/2 * * * *')
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        NEXUS_URL = 'http://localhost:8081/repository/maven-releases'
        NEXUS_WAR = 'koddas/web/war/wwp/1.0.0/wwp-1.0.0.war'

        TOMCAT_URL = 'http://localhost:8082'
        TOMCAT_CONTEXT = '/wwp'

        WAR_FILE = 'wwp-1.0.0.war'
        SONAR_PROJECT = 'wwp'
    }

    stages {

        // 1. Checkout source code
        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub'
                checkout scm
            }
        }

        // 2. Clean previous build
        stage('Maven Clean') {
            steps {
                echo 'Cleaning previous build files'
                bat 'mvn clean'
            }
        }

        // 3. Compile Java code
        stage('Compile') {
            steps {
                echo 'Compiling Java source code'
                bat 'mvn compile'
            }
        }

        // 4. Execute unit tests
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

        // 5. Package WAR file
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

        // 6. SonarQube code analysis
        stage('SonarQube Analysis') {
            steps {
                echo 'Starting SonarQube code analysis'

                // Must match the configured installation name:
                // SonarQube-Server
                withSonarQubeEnv('SonarQube-Server') {
                    bat '''
                        mvn org.sonarsource.scanner.maven:sonar-maven-plugin:5.8.0.7211:sonar

                        if errorlevel 1 exit /b 1
                    '''
                }
            }
        }

        // 7. Wait for SonarQube Quality Gate
        stage('Quality Gate') {
            steps {
                echo 'Waiting for SonarQube Quality Gate result'

                timeout(time: 5, unit: 'MINUTES') {
                    script {
                        def qualityGate = waitForQualityGate(
                            abortPipeline: false
                        )

                        echo "Quality Gate Status: ${qualityGate.status}"
                    }
                }
            }
        }

        // 8. Upload WAR to Nexus
        stage('Upload to Nexus') {
            steps {
                echo 'Uploading WAR file to Nexus Repository'

                bat '''
                    mvn deploy -DskipTests

                    if errorlevel 1 exit /b 1
                '''
            }
        }

        // 9. Archive WAR in Jenkins
        stage('Archive WAR') {
            steps {
                echo 'Archiving WAR file in Jenkins'

                archiveArtifacts(
                    artifacts: 'target/wwp-1.0.0.war',
                    fingerprint: true
                )
            }
        }

        // 10. Download WAR from Nexus
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

        // 11. Deploy WAR to Tomcat
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

        // 12. Application health check
        stage('Health Check') {
            steps {
                echo 'Checking deployed application'

                bat '''
                    powershell -NoProfile -Command "$url='http://localhost:8082/wwp/'; for ($i=1; $i -le 10; $i++) { try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Application is healthy. HTTP 200'; exit 0 } } catch { Write-Host ('Attempt ' + $i + ' failed') }; Start-Sleep -Seconds 5 }; Write-Host 'Health check failed'; exit 1"
                '''
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Complete CI/CD Pipeline executed successfully.'
            echo 'Application URL: http://localhost:8082/wwp/'
        }

        failure {
            echo 'ERROR: Pipeline failed. Check the failed stage in Console Output.'
        }

        always {
            echo 'Pipeline execution completed.'
        }
    }
}
