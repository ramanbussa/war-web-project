
pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
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

        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub'
                checkout scm
            }
        }

        stage('Build, SonarQube Analysis and Nexus Upload') {
            steps {
                echo 'Building application, analyzing code and uploading WAR'

                bat '''
                    mvn clean verify org.sonarsource.scanner.maven:sonar-maven-plugin:5.8.0.7211:sonar deploy
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('Archive WAR') {
            steps {
                archiveArtifacts artifacts: 'target/wwp-1.0.0.war',
                                 fingerprint: true
            }
        }

        stage('Download WAR from Nexus') {
            steps {
                bat '''
                    if not exist deployment mkdir deployment

                    curl.exe --fail --location --silent --show-error ^
                      --output deployment\\wwp-1.0.0.war ^
                      "%NEXUS_URL%/%NEXUS_WAR%"

                    if errorlevel 1 (
                        echo ERROR: WAR download from Nexus failed.
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
                        echo Starting Tomcat WAR deployment...

                        curl.exe --fail --silent --show-error ^
                          --user "%TOMCAT_USR%:%TOMCAT_PSW%" ^
                          --upload-file "deployment\\wwp-1.0.0.war" ^
                          "%TOMCAT_URL%/manager/text/deploy?path=%TOMCAT_CONTEXT%&update=true"

                        if errorlevel 1 (
                            echo ERROR: Tomcat deployment failed.
                            exit /b 1
                        )

                        echo WAR deployment completed successfully!
                    '''
                }
            }
        }

        stage('Application Health Check') {
            steps {
                echo 'Checking deployed application'

                bat '''
                    powershell -NoProfile -Command "$url='http://localhost:8082/wwp/'; for ($i=1; $i -le 10; $i++) { try { $r=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10; if ($r.StatusCode -eq 200) { Write-Host 'Application is healthy. HTTP 200'; exit 0 } } catch { Write-Host ('Attempt ' + $i + ' failed') }; Start-Sleep -Seconds 5 }; Write-Host 'Application health check failed'; exit 1"
                '''
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Complete CI/CD pipeline finished.'
            echo 'Application deployed at http://localhost:8082/wwp/'
        }

        failure {
            echo 'ERROR: Pipeline failed. Check the failed stage in Console Output.'
        }

        always {
            echo 'Pipeline execution completed.'
        }
    }
}
