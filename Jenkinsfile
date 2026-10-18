pipeline {
    agent any

    // ============================================================
    // DECLENCHEMENT AUTOMATIQUE
    // Vérification de GitHub toutes les 5 minutes
    // ============================================================
    triggers {
        pollSCM('H/5 * * * *')
    }

    // ============================================================
    // VARIABLES
    // ============================================================
    environment {
        IMAGE      = "nounou666/monpfe"
        VM2_IP     = "192.168.1.101"
        VM3_IP     = "192.168.1.102"
        SONAR_URL  = "http://192.168.1.100:9000"
        APP_URL    = "http://192.168.1.102:30000"
    }

    stages {

        // ========================================================
        // STAGE 1 : GIT CHECKOUT
        // ========================================================
        stage('Git Checkout') {
            steps {
                echo '=== Clonage du code depuis GitHub ==='

                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: 'https://github.com/nourhenebhg-eng/monPFE.git'

                echo '=== Code cloné avec succès ==='
            }
        }

        // ========================================================
        // STAGE 2 : SONARQUBE (CORRIGÉ)
        // JS/CSS/HTML exclus pour éviter le timeout du bridge Node.js
        // ========================================================
        stage('SonarQube Analysis') {
            steps {
                echo '=== Analyse qualité du code avec SonarQube ==='

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

                echo '=== Analyse SonarQube terminée ==='
            }
        }

        // ========================================================
        // STAGE 3 : TRIVY FILESYSTEM
        // ========================================================
        stage('Trivy FS Scan') {
            steps {
                echo '=== Scan sécurité des fichiers avec Trivy ==='

                sh '''
                    trivy --cache-dir /var/lib/jenkins/.cache/trivy \
                      fs --skip-db-update --timeout 15m \
                      --scanners vuln \
                      --severity HIGH,CRITICAL \
                      --exit-code 0 .
                '''

                echo '=== Scan fichiers terminé ==='
            }
        }

        // ========================================================
        // STAGE 4 : BUILD DOCKER SUR VM2
        // ========================================================
        stage('Docker Build on VM2') {
            steps {
                echo '=== Construction image Docker sur VM2 ==='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'vm2-ssh',
                        usernameVariable: 'VM2_USER',
                        passwordVariable: 'VM2_PASS'
                    )
                ]) {
                    sh '''
                        sshpass -p "$VM2_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM2_USER@$VM2_IP" \
                        "cd /opt/monPFE && \
                         git pull origin main && \
                         docker build -t $IMAGE:$BUILD_NUMBER ."
                    '''
                }

                echo '=== Image Docker construite avec succès ==='
            }
        }

        // ========================================================
        // STAGE 5 : TRIVY IMAGE (CORRIGÉ)
        // Utilise la base en cache (pas de re-téléchargement)
        // ========================================================
        stage('Trivy Image Scan') {
            steps {
                echo '=== Scan sécurité de l image Docker avec Trivy ==='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'vm2-ssh',
                        usernameVariable: 'VM2_USER',
                        passwordVariable: 'VM2_PASS'
                    )
                ]) {
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
                         $IMAGE:$BUILD_NUMBER"
                    '''
                }

                echo '=== Scan image Docker terminé ==='
            }
        }

        // ========================================================
        // STAGE 6 : PUSH DOCKER HUB
        // ========================================================
        stage('Docker Push to DockerHub') {
            steps {
                echo '=== Publication image sur DockerHub ==='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'vm2-ssh',
                        usernameVariable: 'VM2_USER',
                        passwordVariable: 'VM2_PASS'
                    )
                ]) {
                    sh '''
                        sshpass -p "$VM2_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM2_USER@$VM2_IP" \
                        "docker push $IMAGE:$BUILD_NUMBER"
                    '''
                }

                echo '=== Image publiée sur DockerHub ==='
            }
        }

        // ========================================================
        // STAGE 7 : DEPLOIEMENT KUBERNETES
        // ========================================================
        stage('Deploy to Kubernetes') {
            steps {
                echo '=== Déploiement sur Kubernetes VM3 ==='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'vm3-ssh',
                        usernameVariable: 'VM3_USER',
                        passwordVariable: 'VM3_PASS'
                    )
                ]) {
                    sh '''
                        sshpass -p "$VM3_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM3_USER@$VM3_IP" \
                        "kubectl set image deployment/monpfe-app \
                         monpfe-app=$IMAGE:$BUILD_NUMBER"
                    '''
                }

                echo '=== Nouvelle image déployée ==='
            }
        }

        // ========================================================
        // STAGE 8 : ROLLOUT KUBERNETES
        // ========================================================
        stage('Wait for Kubernetes Rollout') {
            steps {
                echo '=== Attente du déploiement Kubernetes ==='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'vm3-ssh',
                        usernameVariable: 'VM3_USER',
                        passwordVariable: 'VM3_PASS'
                    )
                ]) {
                    sh '''
                        sshpass -p "$VM3_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM3_USER@$VM3_IP" \
                        "kubectl rollout status \
                         deployment/monpfe-app \
                         --timeout=180s"
                    '''
                }

                echo '=== Déploiement Kubernetes terminé ==='
            }
        }

        // ========================================================
        // STAGE 9 : VERIFICATION APPLICATION
        // ========================================================
        stage('Wait for Application') {
            steps {
                echo '=== Vérification de disponibilité de l application ==='

                sh '''
                    for i in {1..30}; do

                        HTTP_CODE=$(curl -s -o /dev/null \
                            -w "%{http_code}" \
                            "$APP_URL")

                        echo "Tentative $i/30 - HTTP $HTTP_CODE"

                        if echo "$HTTP_CODE" | grep -qE "200|302|401|403"; then
                            echo "=== Application accessible : HTTP $HTTP_CODE ==="
                            exit 0
                        fi

                        sleep 10
                    done

                    echo "ERREUR : l'application n'est pas accessible."
                    exit 1
                '''
            }
        }

        // ========================================================
        // STAGE 10 : OWASP ZAP
        // ========================================================
        stage('OWASP ZAP Security Scan') {
            steps {
                echo '=== Démarrage du scan OWASP ZAP ==='

                sh '''
                    # Nettoyage du répertoire précédent
                    rm -rf zap-reports

                    # Création du répertoire de rapport
                    mkdir -p zap-reports

                    # Autoriser le conteneur ZAP à écrire le rapport
                    chmod -R 777 zap-reports

                    echo "=== Lancement OWASP ZAP ==="

                    docker run --rm \
                        --user 0:0 \
                        -v "$WORKSPACE/zap-reports:/zap/wrk:rw" \
                        ghcr.io/zaproxy/zaproxy:stable \
                        zap-baseline.py \
                        -t "$APP_URL" \
                        -r zap-report.html \
                        -I

                    echo "=== Scan OWASP ZAP terminé ==="

                    # Vérification du rapport
                    if [ -f "zap-reports/zap-report.html" ]; then
                        echo "=== Rapport ZAP généré avec succès ==="
                        ls -lh zap-reports/zap-report.html
                    else
                        echo "ERREUR : rapport ZAP non généré."
                        exit 1
                    fi
                '''
            }

            post {
                always {
                    echo '=== Archivage du rapport OWASP ZAP ==='

                    archiveArtifacts(
                        artifacts: 'zap-reports/zap-report.html',
                        allowEmptyArchive: true
                    )
                }
            }
        }

        // ========================================================
        // STAGE 11 : NETTOYAGE VM2
        // ========================================================
        stage('Cleanup VM2') {
            steps {
                echo '=== Nettoyage images Docker sur VM2 ==='

                withCredentials([
                    usernamePassword(
                        credentialsId: 'vm2-ssh',
                        usernameVariable: 'VM2_USER',
                        passwordVariable: 'VM2_PASS'
                    )
                ]) {
                    sh '''
                        sshpass -p "$VM2_PASS" ssh \
                        -o StrictHostKeyChecking=no \
                        "$VM2_USER@$VM2_IP" \
                        "docker rmi $IMAGE:$BUILD_NUMBER || true && \
                         docker system prune -f"
                    '''
                }

                echo '=== Nettoyage terminé ==='
            }
        }
    }

    // ============================================================
    // RESULTAT FINAL
    // ============================================================
    post {

        success {
            echo """
            ==========================================
                 PIPELINE REUSSI !
            ==========================================
            Image : ${IMAGE}:${BUILD_NUMBER}
            App   : ${APP_URL}
            ZAP   : Rapport disponible dans les artifacts
            ==========================================
            """
        }

        failure {
            echo """
            ==========================================
                 PIPELINE ECHOUE !
            ==========================================
            Verifiez les logs ci-dessus
            ==========================================
            """
        }

        always {
            echo '=== Fin du pipeline ==='
        }
    }
}
