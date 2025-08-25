
// Jenkinsfile for the SimpleWebApp Automated Upgrade

pipeline {
    agent any // Assumes the Jenkins agent has all necessary tools installed

    parameters {
        string(name: 'CHANGE_REF', defaultValue: 'CKS-DEMO-001', description: 'The Change Reference ID for this upgrade.')
        string(name: 'UPGRADE_DATE_OVERRIDE', defaultValue: '', description: 'Optional. Override date folder (e.g., 20250825). Leave blank to use today.')
        
        // --- System Parameters ---
        string(name: 'K8S_VM_IP', description: 'IP address of the Kubernetes VM (Minikube).', defaultValue: '192.168.50.105')
        string(name: 'POSTGRES_VM_IP', description: 'IP address of the PostgreSQL VM.', defaultValue: '192.168.50.104')
        string(name: 'K8S_HELM_RELEASE_NAME', defaultValue: 'simpleapp-release1', description: 'The Helm release name to upgrade.')
        
        // --- Database Parameters ---
        string(name: 'DB_NAME', defaultValue: 'cks_test_db', description: 'Database name.')
        credentials(name: 'DB_CREDENTIALS_ID', description: 'Jenkins Credentials ID for PostgreSQL User/Pass (e.g., cks-test-db-password).', required: true)
    }

    environment {
        // Static environment variables are defined here.
        // Dynamic ones, like paths based on the date, will be set in the first stage.
        KUBECONFIG_PATH = "${env.HOME}/.kube/config"
        HELM_CHART_V2_PATH = "helm/simplewebapp-chart-v2.0/"
        DB_UPGRADE_SCRIPT_PATH = "sql/v2.0_upgrade.sql"
        DTA_MOCK_SCRIPT_PATH = "/opt/test-dta/tools/dta.sh" // Path on the agent machine
        DTA_V2_SOURCE_PATH = "/opt/mock_apps/dta_source_files/v2.0/CKS Integration/" // Path on the agent machine
        FILE_SERVER_BASE_PATH = "/srv/mock_fileserver" // Path on the agent machine
    }

    stages {
        stage('Prepare Environment') {
            steps {
                script {
                    // --- Dynamic Environment Variable Setup ---
                    def effectiveUpgradeDate = params.UPGRADE_DATE_OVERRIDE ? params.UPGRADE_DATE_OVERRIDE : new Date().format('yyyyMMdd')
                    echo "Using Upgrade Date: ${effectiveUpgradeDate}"

                    env.UPGRADE_DATE = effectiveUpgradeDate
                    env.BASE_UPLOAD_PATH = "${env.FILE_SERVER_BASE_PATH}/${effectiveUpgradeDate}/${params.CHANGE_REF}"
                    env.DB_BACKUP_PATH = "${env.BASE_UPLOAD_PATH}/Backups"
                    env.HEALTHCHECK_PATH = "${env.BASE_UPLOAD_PATH}/Healthchecks"
                    
                    echo "=== Initializing Upgrade for ${params.CHANGE_REF} ==="
                    echo "Backup Path: ${env.DB_BACKUP_PATH}"
                    echo "Health Check Path: ${env.HEALTHCHECK_PATH}"
                    
                    sh "mkdir -p ${env.DB_BACKUP_PATH}"
                    sh "mkdir -p ${env.HEALTHCHECK_PATH}"
                }
            }
        }
        
        stage('Pre-Flight Checks & Backups') {
            steps {
                script {
                    echo "--- Running Pre-Upgrade Health Check ---"
                    def nodePort = sh(script: "kubectl get service ${params.K8S_HELM_RELEASE_NAME}-simplewebapp -o jsonpath='{.spec.ports[0].nodePort}'", returnStdout: true).trim()
                    def healthUrl = "http://${params.K8S_VM_IP}:${nodePort}"
                    echo "Checking URL: ${healthUrl}"
                    sh "curl -s -f -o '${env.HEALTHCHECK_PATH}/pre_health_v1.html' '${healthUrl}'"
                    echo "Pre-upgrade health check saved."

                    echo "--- Backing Up Database ---"
                    def backupFileName = "cks_db_backup_${params.CHANGE_REF}_${env.UPGRADE_DATE}.bak"
                    withCredentials([string(credentialsId: params.DB_CREDENTIALS_ID, variable: 'DB_PASSWORD')]) {
                        sh """
                           PGPASSWORD=\$DB_PASSWORD pg_dump -h ${params.POSTGRES_VM_IP} -U cks_test_user -d ${params.DB_NAME} -F c -f "${env.DB_BACKUP_PATH}/${backupFileName}"
                        """
                    }
                    echo "Database backup complete: ${env.DB_BACKUP_PATH}/${backupFileName}"

                    echo "--- Exporting K8S Helm Configuration ---"
                    def helmValuesFileName = "helm_values_${params.K8S_HELM_RELEASE_NAME}_v1.yaml"
                    sh "helm get values ${params.K8S_HELM_RELEASE_NAME} > '${env.DB_BACKUP_PATH}/${helmValuesFileName}'"
                    echo "Helm values saved: ${env.DB_BACKUP_PATH}/${helmValuesFileName}"
                }
            }
        }

        stage('Apply Database Changes') {
            steps {
                withCredentials([string(credentialsId: params.DB_CREDENTIALS_ID, variable: 'DB_PASSWORD')]) {
                    sh """
                       PGPASSWORD=\$DB_PASSWORD psql -h ${params.POSTGRES_VM_IP} -U cks_test_user -d ${params.DB_NAME} -a -f ${env.DB_UPGRADE_SCRIPT_PATH}
                    """
                }
            }
        }

        stage('Upgrade Kubernetes App (Helm)') {
            steps {
                sh "helm upgrade ${params.K8S_HELM_RELEASE_NAME} ${env.HELM_CHART_V2_PATH}"
                sh "kubectl rollout status deployment/${params.K8S_HELM_RELEASE_NAME}-simplewebapp --timeout=2m"
            }
        }

        stage('Upgrade CKS Integration (DTA Mock)') {
            steps {
                sh "${env.DTA_MOCK_SCRIPT_PATH} stage '${env.DTA_V2_SOURCE_PATH}'"
                sh "${env.DTA_MOCK_SCRIPT_PATH} commit cks"
            }
        }

        stage('Post-Upgrade Checks') {
            steps {
                script {
                    echo "--- Running Post-Upgrade Health Check ---"
                    def nodePort = sh(script: "kubectl get service ${params.K8S_HELM_RELEASE_NAME}-simplewebapp -o jsonpath='{.spec.ports[0].nodePort}'", returnStdout: true).trim()
                    def healthUrl = "http://${params.K8S_VM_IP}:${nodePort}"
                    sleep 10 // Give service time to update
                    echo "Checking URL: ${healthUrl}"
                    sh "curl -s -f -o '${env.HEALTHCHECK_PATH}/post_health_v2.html' '${healthUrl}'"
                    echo "Post-upgrade health check saved."
                    echo "--- Verifying content of post-upgrade page ---"
                    sh "grep 'Version 2.0 (Upgraded!)' '${env.HEALTHCHECK_PATH}/post_health_v2.html'"
                    echo "Content verification successful!"
                }
            }
        }
    }

    post {
        always {
            echo "Pipeline finished."
            archiveArtifacts artifacts: "${env.BASE_UPLOAD_PATH}/**/*", allowEmptyArchive: true
        }
        success {
            echo "=== CKS Upgrade Pipeline Completed Successfully! ==="
        }
        failure {
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            echo "=== CKS Upgrade Pipeline FAILED! Consider manual rollback. ==="
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        }
    }
}