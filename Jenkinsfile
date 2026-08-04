pipeline {

    agent any

    tools {
        maven 'Maven'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'master',
                    url: 'https://github.com/ramanbussa/war-web-project.git'
            }
        }


        stage('Build') {
            steps {
                sh 'mvn clean package'
            }
        }


        stage('SonarQube Analysis') {

            steps {

                withSonarQubeEnv('sonarqube') {

                    sh '''
                    mvn org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                    -Dsonar.projectKey=wwp \
                    -Dsonar.projectName=wwp \
                    -Dsonar.host.url=http://172.31.22.165:9000
                    '''

                }

            }
        }


        stage('Quality Gate') {

            steps {

                timeout(time: 5, unit: 'MINUTES') {

                    waitForQualityGate abortPipeline: true

                }

            }

        }


        stage('Upload WAR to Nexus') {

            steps {

                nexusArtifactUploader(

                    nexusVersion: 'nexus3',

                    protocol: 'http',

                    nexusUrl: '172.31.13.59:8081',

                    repository: 'wwp-release',

                    credentialsId: 'nexus-creds',

                    groupId: 'com.example',

                    version: "${BUILD_NUMBER}",

                    artifacts: [

                        [
                            artifactId: 'wwp',

                            classifier: '',

                            file: 'target/wwp-1.0.0.war',

                            type: 'war'
                        ]

                    ]

                )

            }

        }


        stage('Deploy Tomcat') {

            steps {

                deploy(

                    adapters: [

                        tomcat9(

                            credentialsId:'tomcat_creds',

                            url:'http://172.31.5.9:8080'

                        )

                    ],

                    contextPath:'wwp',

                    war:'target/wwp-1.0.0.war'

                )

            }

        }

    }


    post {

        success {

            echo 'CI/CD Pipeline Completed Successfully'

        }

        failure {

            echo 'Pipeline Failed'

        }

    }

}
