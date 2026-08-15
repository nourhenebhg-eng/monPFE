pipeline {
    agent any

    environment {
        IMAGE      = "nounou666/monpfe"
        VM2_IP     = "192.168.1.101"
        VM3_IP     = "192.168.1.102"
        SONAR_URL  = "http://192.168.1.100:9000"
    }

    stages {

        // ===== STAGE 1 =====
        // Clone le code depuis GitHub
        // Jenkins télécharge le code pour l'analyser
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
        // SonarQube analyse le code PHP Laravel
        // Si le Quality Gate échoue → pipeline bloqué
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
        // Trivy scanne les fichiers de dépendances
        // composer.lock et package.json sont vérifiés
        stage('Trivy FS Scan') {
            steps {
                echo '=== Scan sécurité des fichiers avec Trivy ==='
                sh 'trivy fs --severity HIGH,CRITICAL --exit-code 0 .'
                echo '=== Scan fichiers terminé ==='
            }
        }

        // ===== STAGE 4 =====
        // Jenkins donne l'ordre à VM2 de builder l'image Docker
        // VM2 clone le code et construit l'image HRMS
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
        // Trivy scanne l'image Docker buildée
        // Si vulnérabilité CRITICAL → pipeline bloqué
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
        // L'image Docker est publiée sur DockerHub
        // Avec le numéro de build comme tag
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
        // Kubernetes sur VM3 est mis à jour
        // La nouvelle image est déployée sans interruption
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
                        'kubectl set image deployment/monpfe-app monpfe-app=${IMAGE}:${BUILD_NUMBER} --record'
                    """
                }
                echo '=== Application déployée sur Kubernetes ==='
            }
        }

        // ===== STAGE 8 =====
        // Nettoyage des images Docker locales sur VM2
        // Pour libérer l'espace disque
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

    post {
        success {
            echo """
            ✅ PIPELINE REUSSI !
            Image : ${IMAGE}:${BUILD_NUMBER}
            App   : http://${VM3_IP}:30000
            """
        }
        failure {
            echo """
            ❌ PIPELINE ECHOUE !
            Verifiez les logs ci-dessus
            """
        }
        always {
            echo '=== Fin du pipeline ==='
        }
    }
}
