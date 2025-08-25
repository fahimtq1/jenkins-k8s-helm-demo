// Jenkinsfile for App Mock Application Upgrade

// Define a separate pipeline for rollback for clarity and safety.
// This prevents accidental rollback and allows it to be triggered with specific permissions.
def generateRollbackPipeline() {
    return """
pipeline {
    agent any // Or specify the same agent as the main pipeline

    parameters {
        string(name: 'CHANGE_REF', description: 'Original Change Reference for which to roll back (e.g., OPSCM-34129)')
        string(name: 'K8S_HELM_RELEASE_NAME', defaultValue: 'simpleapp-release1', description: 'The Helm release name to roll back.')
        string(name: 'K8S_ROLLBACK_REVISION', description: 'The Helm revision number to roll back to. Leave blank to go to previous version.')
        // Add parameters for DTA and DB rollback if needed
    }

    stages {
        stage('Rollback Kubernetes Helm Release') {
            steps {
                script {
                    echo "=== Rolling back Helm Release: \${params.K8S_HELM_RELEASE_NAME} ==="
                    try {
                        def rollbackCommand = "helm rollback \${params.K8S_HELM_RELEASE_NAME}"
                        if (params.K8S_ROLLBACK_REVISION) {
                            rollbackCommand += " \${params.K8S_ROLLBACK_REVISION}"
                        }
                        sh rollbackCommand
                        sh "helm history \${params.K8S_HELM_RELEASE_NAME}"
                        echo "Rollback successful."
                    } catch (Exception e) {
                        error("Helm rollback failed: \${e.getMessage()}")
                    }
                }
            }
        }

        stage('Rollback Database (Manual Intervention Required)') {
            steps {
                script {
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                    echo "DATABASE ROLLBACK REQUIRES MANUAL INTERVENTION."
                    echo "A database backup was created during the initial upgrade pipeline run for change: \${params.CHANGE_REF}"
                    echo "Find the backup file and follow your standard database restore procedures."
                    echo "This pipeline will not automatically restore the database to prevent accidental data loss."
                    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
                }
            }
        }
        
        stage('Rollback DTA Integration (Manual/Future Implementation)') {
            steps {
                script {
                    echo "DTA Rollback: This would involve running a 'dta rollback' command."
                    echo "Example mock command: /opt/test-dta/tools/dta.sh rollback cks"
                }
            }
        }
    }
    post {
        success {
            echo "Rollback pipeline completed."
        }
        failure {
            echo "Rollback pipeline failed to execute correctly."
        }
    }
}
"""
}

// Main Upgrade Pipeline
pipeline {
    agent any // Assumes the Jenkins master's built-in node is the agent and has all tools

    parameters {
        string(name: 'CHANGE_REF', defaultValue: 'CKS-MOCK-001', description: 'The Change Reference ID for this upgrade.')
        string(name: 'UPGRADE_DATE', defaultValue: new Date().format('yyyyMMdd'), description: 'The date folder for file paths (e.g., 20250608).')
        
        // --- System Parameters ---
        string(name: 'K8S_VM_IP', description: 'IP address of the Kubernetes VM (Minikube).', defaultValue: '192.168.50.105') // Example IP, change as needed
        string(name: 'POSTGRES_VM_IP', description: 'IP address of the PostgreSQL VM.', defaultValue: '192.168.50.104') // Example IP, change as needed
        string(name: 'K8S_HELM_RELEASE_NAME', defaultValue: 'simpleapp-release1', description: 'The Helm release name to upgrade.')
        
        // --- Database Parameters ---
        string(name: 'DB_NAME', defaultValue: 'cks_test_db', description: 'Database name.')
        credentials(name: 'DB_CREDENTIALS_ID', description: 'Jenkins Credentials ID for PostgreSQL User/Pass (e.g., cks_test_user/testpass).', required: true)
        
        // --- Mock App File Paths on Agent ---
        string(name: 'MOCK_APP_BASE_PATH', defaultValue: '/opt/mock_apps', description: 'Base path for mock app source files.')
        string(name: 'FILE_SERVER_BASE_PATH', defaultValue: '/srv/mock_fileserver', description: 'Base path for mock file server backups.')
    }

    environment {
        // Construct dynamic paths based on parameters
        BASE_UPLOAD_PATH = "${params.FILE_SERVER_BASE_PATH}/${params.UPGRADE_DATE}/${params.CHANGE_REF}"
        DB_BACKUP_PATH = "${env.BASE_UPLOAD_PATH}/Backups"
        HEALTHCHECK_PATH = "${env.BASE_UPLOAD_PATH}/Healthchecks"
        KUBECONFIG_PATH = "${env.HOME}/.kube/config" // Standard kubeconfig path

        // Path to the v2.0 Helm chart for the upgrade
        HELM_CHART_V2_PATH = "${params.MOCK_APP_BASE_PATH}/simplewebapp_helm_charts/simplewebapp-chart-v2.0/"
        DB_UPGRADE_SCRIPT_PATH = "${params.MOCK_APP_BASE_PATH}/db_scripts/v2.0_upgrade.sql"
        DTA_V2_SOURCE_PATH = "${params.MOCK_APP_BASE_PATH}/dta_source_files/v2.0/CKS Integration/"
        
        // URL for health checks (using NodePort service on the K8s VM IP)
        // Note: You must find the NodePort manually or via a script after deployment
        // Example: kubectl get service simpleapp-release1-simplewebapp -o jsonpath='{.spec.ports[0].nodePort}'
        // For this test, we can hardcode it after finding it once, or construct a placeholder.
        APP_HEALTH_URL = "http://${params.K8S_VM_IP}:<YOUR_NODE_PORT>" // REPLACE <YOUR_NODE_PORT>
    }

    stages {
        stage('Initialize and Create Rollback Job') {
            steps {
                script {
                    echo "=== Initializing Upgrade for ${params.CHANGE_REF} ==="
                    echo "Backup Path: ${env.DB_BACKUP_PATH}"
                    echo "Health Check Path: ${env.HEALTHCHECK_PATH}"
                    
                    // Create directories for this run
                    sh "mkdir -p ${env.DB_BACKUP_PATH}"
                    sh "mkdir -p ${env.HEALTHCHECK_PATH}"

                    // Dynamically create a rollback pipeline job for this specific change
                    def rollbackJobName = "Rollback-${params.CHANGE_REF}"
                    def rollbackPipelineScript = generateRollbackPipeline()

                    def jobDsl = """
                    pipelineJob('${rollbackJobName}') {
                        description('Rollback pipeline for change ${params.CHANGE_REF}. Automatically created by the upgrade pipeline.')
                        definition {
                            cps {
                                script('${rollbackPipelineScript.replaceAll("'", "\\\\'").replaceAll("\\n", "\\\\n")}')
                                sandbox()
                            }
                        }
                    }
                    """
                    // This requires the Job DSL plugin
                    // As a simpler alternative, we just print the rollback instructions.
                    // For a demo, printing is safer. Let's do that.
                    echo "---------------------------------------------------------"
                    echo "ROLLBACK PLAN:"
                    echo "If this pipeline fails, a manual rollback may be required."
                    echo "1. Helm Rollback: Run 'helm rollback ${params.K8S_HELM_RELEASE_NAME}'"
                    echo "2. Database Rollback: Restore the database from the backup that will be created in the next stage."
                    echo "---------------------------------------------------------"
                }
            }
        }

        stage('Pre-Flight Checks & Backups') {
            steps {
                script {
                    echo "--- Running Pre-Upgrade Health Check ---"
                    // We need the NodePort. We can get it with kubectl.
                    def nodePort = sh(script: "kubectl get service ${params.K8S_HELM_RELEASE_NAME}-simplewebapp -o jsonpath='{.spec.ports[0].nodePort}'", returnStdout: true).trim()
                    def healthUrl = "http://${params.K8S_VM_IP}:${nodePort}"
                    echo "Checking URL: ${healthUrl}"
                    sh "curl -f -o '${env.HEALTHCHECK_PATH}/pre_health_v1.html' '${healthUrl}'"
                    echo "Pre-upgrade health check saved."

                    echo "--- Backing Up Database ---"
                    def backupFileName = "cks_db_backup_${params.CHANGE_REF}_${params.UPGRADE_DATE}.bak"
                    // Use withCredentials to securely handle the password
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
                script {
                    echo "=== Applying Database Schema Updates (v2.0) ==="
                    withCredentials([string(credentialsId: params.DB_CREDENTIALS_ID, variable: 'DB_PASSWORD')]) {
                        sh """
                           PGPASSWORD=\$DB_PASSWORD psql -h ${params.POSTGRES_VM_IP} -U cks_test_user -d ${params.DB_NAME} -a -f ${env.DB_UPGRADE_SCRIPT_PATH}
                        """
                    }
                    echo "DB schema updates complete!"
                }
            }
        }

        stage('Upgrade Kubernetes App (Helm)') {
            steps {
                script {
                    echo "=== Upgrading CKS Mock App on Kubernetes to v2.0 ==="
                    sh "helm upgrade ${params.K8S_HELM_RELEASE_NAME} ${env.HELM_CHART_V2_PATH}"
                    echo "Helm upgrade command sent. Waiting for rollout..."
                    // Wait for the deployment to finish updating
                    sh "kubectl rollout status deployment/${params.K8S_HELM_RELEASE_NAME}-simplewebapp --timeout=2m"
                    echo "K8S upgrade complete; deployment is stable."
                }
            }
        }

        stage('Upgrade CKS Integration (DTA Mock)') {
            steps {
                script {
                    echo "=== Upgrading CKS Integration on the Mock DTA Server ==="
                    // This runs the mock script locally on the agent
                    sh "/opt/test-dta/tools/dta.sh stage '${env.DTA_V2_SOURCE_PATH}'"
                    sh "/opt/test-dta/tools/dta.sh commit cks"
                    echo "Mock DTA upgrade commands executed."
                }
            }
        }

        stage('Post-Upgrade Checks') {
            steps {
                script {
                    echo "--- Running Post-Upgrade Health Check ---"
                    def nodePort = sh(script: "kubectl get service ${params.K8S_HELM_RELEASE_NAME}-simplewebapp -o jsonpath='{.spec.ports[0].nodePort}'", returnStdout: true).trim()
                    def healthUrl = "http://${params.K8S_VM_IP}:${nodePort}"
                    // Add a small delay to ensure the service is fully updated
                    sleep 10 
                    echo "Checking URL: ${healthUrl}"
                    sh "curl -f -o '${env.HEALTHCHECK_PATH}/post_health_v2.html' '${healthUrl}'"
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
            echo "Pipeline finished. Cleaning up workspace if needed."
            // Archive the backups and health checks as artifacts of this build
            archiveArtifacts artifacts: "${env.BASE_UPLOAD_PATH}/**/*", allowEmptyArchive: true
        }
        success {
            echo "=== CKS Upgrade Pipeline Completed Successfully! ==="
        }
        failure {
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
            echo "=== App Upgrade Pipeline FAILED! Consider manual rollback. ==="
            echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        }
    }
}
