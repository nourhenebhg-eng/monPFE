pipeline {
    agent any

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        IMAGE      = "nounou666/monpfe"
        VM2_IP     = "192.168.1.101"
        VM3_IP     = "192.168.1.102"
        SONAR_URL  = "http://192.168.1.100:9000"
        APP_URL    = "http://192.168.1.102:30000"
    }

    stages {

        stage('Git Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: 'https://github.com/nourhenebhg-eng/monPFE.git'
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=monPFE \
                        -Dsonar.projectName=monPFE \
                        -Dsonar.sources=app,resources \
                        -Dsonar.exclusions=vendor/**,node_modules/**,public/**,storage/**,**/*.js,**/*.css,**/*.html,**/*.ts \
                        -Dsonar.php.version=8.1
                    '''
                }
            }
        }

        stage('Trivy FS Scan') {
            steps {
                sh '''
                    trivy --cache-dir /var/lib/jenkins/.cache/trivy \
                      fs --skip-db-update --timeout 15m \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 .
                '''
            }
        }

        // Build on VM2: tag with the build number AND latest.
        // public/hot is removed so Laravel never points to the Vite dev server.
        stage('Docker Build on VM2') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS')]) {
                    sh '''
                        sshpass -p "$VM2_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM2_USER@$VM2_IP" \
                        "cd /opt/monPFE && \
                         git pull origin main && \
                         rm -f public/hot && \
                         docker build -t $IMAGE:latest ."
                    '''
                }
            }
        }

stage('Trivy Image Scan') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: 'vm2-ssh',
            usernameVariable: 'VM2_USER',
            passwordVariable: 'VM2_PASS')]) {
            sh '''
                sshpass -p "$VM2_PASS" ssh \
                -o StrictHostKeyChecking=no \
                "$VM2_USER@$VM2_IP" \
                "trivy --cache-dir /home/nourhene/.cache/trivy image \
                 --skip-db-update \
                 --skip-java-db-update \
                 --scanners vuln \
                 --severity HIGH,CRITICAL \
                 --timeout 15m \
                 --exit-code 0 \
                 $IMAGE:latest"
            '''
        }
    }
}

        stage('Docker Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS')]) {
                    sh '''
                        sshpass -p "$VM2_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM2_USER@$VM2_IP" \
                        "docker push $IMAGE:latest"
                    '''
                }
            }
        }

        // The manifest in Git says :latest and never changes, so ArgoCD
        // has nothing to revert. A rollout restart makes pods pull the new
        // :latest (imagePullPolicy: Always).
        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'vm3-ssh',
                    usernameVariable: 'VM3_USER',
                    passwordVariable: 'VM3_PASS')]) {
                    sh '''
                        sshpass -p "$VM3_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM3_USER@$VM3_IP" \
                        "kubectl rollout restart deployment/monpfe-app"
                    '''
                }
            }
        }

        stage('Wait for Kubernetes Rollout') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'vm3-ssh',
                    usernameVariable: 'VM3_USER',
                    passwordVariable: 'VM3_PASS')]) {
                    sh '''
                        sshpass -p "$VM3_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM3_USER@$VM3_IP" \
                        "kubectl rollout status deployment/monpfe-app --timeout=300s"
                    '''
                }
            }
        }

        // Checks the app AND that the CSS asset really loads.
 stage('Wait for Application') {
            steps {
                sh '''
                    for i in $(seq 1 30); do
                        HTTP_CODE=$(curl -s -o /tmp/monpfe-login.html \
                            -w "%{http_code}" "$APP_URL/login")

                        echo "Attempt $i/30 - HTTP $HTTP_CODE"

                        if [ "$HTTP_CODE" = "200" ]; then
                            CSS=$(grep -Eo 'href="[^"]*\\.css([^"]*)?"' \
                                /tmp/monpfe-login.html \
                                | head -1 \
                                | sed 's/^href="//; s/"$//')

                            if [ -z "$CSS" ]; then
                                echo "ERROR: no CSS link found in the page"
                                exit 1
                            fi

                            # Accepte les URL absolues et relatives.
                            case "$CSS" in
                                http://*|https://*) CSS_URL="$CSS" ;;
                                /*) CSS_URL="$APP_URL$CSS" ;;
                                *) CSS_URL="$APP_URL/$CSS" ;;
                            esac

                            echo "CSS detected: $CSS_URL"

                            curl -sf -o /dev/null "$CSS_URL" || {
                                echo "ERROR: CSS not reachable: $CSS_URL"
                                exit 1
                            }

                            echo "=== Application OK, CSS reachable: $CSS_URL ==="
                            exit 0
                        fi

                        sleep 10
                    done

                    echo "ERROR: application not reachable."
                    exit 1
                '''
            }
        }

        stage('OWASP ZAP Security Scan') {
            steps {
                sh '''
                    rm -rf zap-reports
                    mkdir -p zap-reports
                    chmod -R 777 zap-reports

                    docker run --rm \
                        --user 0:0 \
                        -v "$WORKSPACE/zap-reports:/zap/wrk:rw" \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py \
                        -t "$APP_URL" \
                        -r zap-report.html \
                        -I

                    if [ -f "zap-reports/zap-report.html" ]; then
                        ls -lh zap-reports/zap-report.html
                    else
                        echo "ERROR: ZAP report not generated."
                        exit 1
                    fi
                '''
            }
            post {
                always {
                    archiveArtifacts(
                        artifacts: 'zap-reports/zap-report.html',
                        allowEmptyArchive: true
                    )
                }
            }
        }

        stage('Cleanup VM2') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS')]) {
                    sh '''
                        sshpass -p "$VM2_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM2_USER@$VM2_IP" \
                        "docker rmi $IMAGE:$BUILD_NUMBER $IMAGE:latest || true && \
                         docker system prune -f"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "PIPELINE OK - Image: ${IMAGE}:${BUILD_NUMBER} (also :latest) - App: ${APP_URL}"
        }
        failure {
            echo "PIPELINE FAILED - check the logs above"
        }
        always {
            echo '=== End of pipeline ==='
        }
    }
}