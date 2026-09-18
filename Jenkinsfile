pipeline {
    agent any

    // ===== DECLENCHEMENT AUTOMATIQUE =====
    // Jenkins vérifie GitHub toutes les 5 minutes
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

        // ===== STAGE 1 =====
        // Clone le code depuis GitHub
        stage('Git Checkout') {
            steps {
                echo '=== Clonage du code depuis GitHub ==='

                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: 'https://github.com/nourhenebhg-eng/monPFE.git'

                echo '=== Code cloné avec succès ==='
            }
        }

        // ===== STAGE 2 =====
        // Analyse qualité du code avec SonarQube
        stage('SonarQube Analysis') {
            steps {
                echo '=== Analyse qualité du code avec SonarQube ==='

                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=monPFE \
                        -Dsonar.projectName=monPFE \
                        -Dsonar.sources=app,resources \
                        -Dsonar.exclusions=vendor/**,node_modules/**,public/**,storage/** \
                        -Dsonar.php.version=8.1
                    '''
                }

                echo '=== Analyse SonarQube terminée ==='
            }
        }

        // ===== STAGE 3 =====
        // Scan des fichiers et dépendances avec Trivy
        stage('Trivy FS Scan') {
            steps {
                echo '=== Scan sécurité des fichiers avec Trivy ==='

                sh 'trivy fs --severity HIGH,CRITICAL --exit-code 0 .'

                echo '=== Scan fichiers terminé ==='
            }
        }

        // ===== STAGE 4 =====
        // Construction de l'image Docker sur VM2
        stage('Docker Build on VM2') {
            steps {
                echo '=== Construction image Docker sur VM2 ==='

                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS'
                )]) {
                    sh """
                        sshpass -p '${VM2_PASS}' ssh \
                        -o StrictHostKeyChecking=no \
                        ${VM2_USER}@${VM2_IP} \
                        'cd /opt/monPFE && git pull origin main && docker build -t ${IMAGE}:${BUILD_NUMBER} .'
                    """
                }

                echo '=== Image Docker construite avec succès ==='
            }
        }

        // ===== STAGE 5 =====
        // Scan de l'image Docker avec Trivy
        stage('Trivy Image Scan') {
            steps {
                echo '=== Scan sécurité de l image Docker avec Trivy ==='

                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS'
                )]) {
                    sh """
                        sshpass -p '${VM2_PASS}' ssh \
                        -o StrictHostKeyChecking=no \
                        ${VM2_USER}@${VM2_IP} \
                        'trivy image --severity HIGH,CRITICAL --exit-code 0 ${IMAGE}:${BUILD_NUMBER}'
                    """
                }

                echo '=== Scan image Docker terminé ==='
            }
        }

        // ===== STAGE 6 =====
        // Publication de l'image sur DockerHub
        stage('Docker Push to DockerHub') {
            steps {
                echo '=== Publication image sur DockerHub ==='

                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS'
                )]) {
                    sh """
                        sshpass -p '${VM2_PASS}' ssh \
                        -o StrictHostKeyChecking=no \
                        ${VM2_USER}@${VM2_IP} \
                        'docker push ${IMAGE}:${BUILD_NUMBER}'
                    """
                }

                echo '=== Image publiée sur DockerHub ==='
            }
        }

        // ===== STAGE 7 =====
        // Déploiement de la nouvelle image sur Kubernetes
        stage('Deploy to Kubernetes') {
            steps {
                echo '=== Déploiement sur Kubernetes VM3 ==='

                withCredentials([usernamePassword(
                    credentialsId: 'vm3-ssh',
                    usernameVariable: 'VM3_USER',
                    passwordVariable: 'VM3_PASS'
                )]) {
                    sh """
                        sshpass -p '${VM3_PASS}' ssh \
                        -o StrictHostKeyChecking=no \
                        ${VM3_USER}@${VM3_IP} \
                        'kubectl set image deployment/monpfe-app monpfe-app=${IMAGE}:${BUILD_NUMBER}'
                    """
                }

                echo '=== Nouvelle image déployée ==='
            }
        }

        // ===== STAGE 8 =====
        // Attendre que le nouveau déploiement Kubernetes soit prêt
        stage('Wait for Kubernetes Rollout') {
            steps {
                echo '=== Attente du déploiement Kubernetes ==='

                withCredentials([usernamePassword(
                    credentialsId: 'vm3-ssh',
                    usernameVariable: 'VM3_USER',
                    passwordVariable: 'VM3_PASS'
                )]) {
                    sh """
                        sshpass -p '${VM3_PASS}' ssh \
                        -o StrictHostKeyChecking=no \
                        ${VM3_USER}@${VM3_IP} \
                        'kubectl rollout status deployment/monpfe-app --timeout=180s'
                    """
                }

                echo '=== Déploiement Kubernetes terminé ==='
            }
        }

        // ===== STAGE 9 =====
        // Vérifier que l'application répond
        stage('Wait for Application') {
            steps {
                echo '=== Vérification de disponibilité de l application ==='

                sh '''
                    for i in {1..30}; do

                        HTTP_CODE=$(curl -s -o /dev/null \
                            -w "%{http_code}" \
                            ${APP_URL})

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

        // ===== STAGE 10 =====
        // Analyse DAST de l'application avec OWASP ZAP
        stage('OWASP ZAP Security Scan') {
            steps {
                echo '=== Démarrage du scan OWASP ZAP ==='

                sh '''
                    rm -rf zap-reports
                    mkdir -p zap-reports

                    docker run --rm \
                      -t \
                      -v "$WORKSPACE/zap-reports:/zap/wrk/:rw" \
                      ghcr.io/zaproxy/zaproxy:stable \
                      zap-baseline.py \
                      -t ${APP_URL} \
                      -r zap-report.html

                    echo "=== Scan OWASP ZAP terminé ==="
                '''
            }

            post {
                always {
                    echo '=== Archivage du rapport OWASP ZAP ==='

                    archiveArtifacts artifacts: 'zap-reports/zap-report.html',
                                     allowEmptyArchive: true
                }
            }
        }

        // ===== STAGE 11 =====
        // Nettoyage de VM2
        stage('Cleanup VM2') {
            steps {
                echo '=== Nettoyage images Docker sur VM2 ==='

                withCredentials([usernamePassword(
                    credentialsId: 'vm2-ssh',
                    usernameVariable: 'VM2_USER',
                    passwordVariable: 'VM2_PASS'
                )]) {
                    sh """
                        sshpass -p '${VM2_PASS}' ssh \
                        -o StrictHostKeyChecking=no \
                        ${VM2_USER}@${VM2_IP} \
                        'docker rmi ${IMAGE}:${BUILD_NUMBER} || true && docker system prune -f'
                    """
                }

                echo '=== Nettoyage terminé ==='
            }
        }
    }

    // ===== RESULTAT FINAL =====
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
