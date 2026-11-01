pipeline {
    agent { label 'infra-agent' }
    options { 
        disableConcurrentBuilds()
        timeout(time: 120, unit: 'MINUTES')
    }
    triggers { cron('H * * * *') }
    stages {
        stage('apply terraform1') {
            steps {
                script {
                    dir('terraform1') {
                        withCredentials ([
                            string (credentialsId: 'DB_ADMIN_USERNAME', variable: 'TF_VAR_db_admin_username'),
                            string (credentialsId: 'DB_ADMIN_PASSWORD', variable: 'TF_VAR_db_admin_password'),
                            string (credentialsId: 'JENKINS_INFRA_AGENT_SG', variable: 'TF_VAR_jenkins_infra_agent_sg')
                        ]) {
                            sh 'terraform init'
                            def code = sh(script: 'terraform plan -detailed-exitcode -out=tfplan', returnStatus: true)
                            if (code == 0) {
                                echo 'Infrastructure matches desired state. No changes needed.'
                            } else if (code == 2) {
                                sh 'terraform show tfplan'
                                slackSend(
                                    channel: '#jenkins-approvals',
                                    color: 'warning',
                                    message: ":warning: *Stage: Apply Terraform1*\n" +
                                            "Infrastructure drift detected.\n" +
                                            "Approval is required before applying changes.\n" +
                                            "Review and approve here: ${env.BUILD_URL}input"
                                )
                                timeout(time: 15, unit: 'MINUTES') {
                                    input(
                                        message: 'Infrastructure drift detected. Approve Terraform apply?',
                                        ok: 'Approve'
                                    )
                                }
                                sh 'terraform apply -auto-approve tfplan'
                            } else {
                                slackSend(
                                    channel: '#jenkins-errors',
                                    color: 'danger',
                                    message: ":x: *Stage: Apply Terraform1*\n" +
                                            "Terraform plan failed with exit code ${code}.\n" +
                                            "Please review the build logs to identify and fix the error.\n" +
                                            "Build details: ${env.BUILD_URL}console"
                                )
                                error('Terraform plan failed. Stopping pipeline.')
                            }
                        }
                    }
                }
            }
        }
        stage('database account') {
            steps {
                script {
                    dir('terraform1') {
                        def services = [
                            'CUSTOMERS_SERVICE',
                            'VETS_SERVICE',
                            'VISITS_SERVICE'
                        ]
                        def dbAddress = sh(
                            script: "terraform output -raw aws_db_instance_main_address",
                            returnStdout: true
                        ).trim()
                        def missingUsers = []
                        services.each { s ->
                            withEnv ([
                                "DB_ADDRESS=${dbAddress}"
                            ]) {
                                withCredentials([
                                    string (credentialsId: 'DB_ADMIN_USERNAME', variable: 'DB_ADMIN_USERNAME'),
                                    string (credentialsId: 'DB_ADMIN_PASSWORD', variable: 'DB_ADMIN_PASSWORD'),
                                    string (credentialsId: "DB_${s}_USERNAME", variable: "DB_SERVICE_USERNAME"),
                                    string (credentialsId: "DB_${s}_PASSWORD", variable: "DB_SERVICE_PASSWORD")
                                ]) {
                                    def existingUser = sh(
                                        script: '''
                                            mysql \
                                                -h "$DB_ADDRESS" \
                                                -u "$DB_ADMIN_USERNAME" \
                                                -p"$DB_ADMIN_PASSWORD" \
                                                -NB \
                                                -e "SELECT EXISTS ( 
                                                        SELECT 1 
                                                        FROM mysql.user 
                                                        WHERE User = '$DB_SERVICE_USERNAME' 
                                                    );"
                                        ''',
                                        returnStdout: true
                                    ).trim()
                                    if (existingUser == '0') {
                                        missingUsers.add(s)
                                    }
                                }
                            }
                        }
                        if (!missingUsers) {
                            echo "No database accounts need to be created."
                        } else {
                            echo "Services needing database accounts: ${missingUsers.join(', ')}"
                            slackSend(
                                channel: '#jenkins-approvals',
                                color: 'warning',
                                message: ":warning: *Stage: Database Account*\n" +
                                         "Some database accounts need to be created.\n" +
                                         "Approval is required before proceeding with the changes.\n" +
                                         "Review and approve here: ${env.BUILD_URL}input"
                            )
                            timeout(time: 15, unit: 'MINUTES') {
                                input(
                                    message: 'Some database accounts need to be created. Do you approve their creation?',
                                    ok: 'Approve'
                                )
                            }
                            missingUsers.each { m ->
                                withEnv ([
                                    "DB_ADDRESS=${dbAddress}"
                                ]) {
                                    withCredentials([
                                        string (credentialsId: 'DB_ADMIN_USERNAME', variable: 'DB_ADMIN_USERNAME'),
                                        string (credentialsId: 'DB_ADMIN_PASSWORD', variable: 'DB_ADMIN_PASSWORD'),
                                        string (credentialsId: "DB_${m}_USERNAME", variable: "DB_SERVICE_USERNAME"),
                                        string (credentialsId: "DB_${m}_PASSWORD", variable: "DB_SERVICE_PASSWORD"),
                                        string (credentialsId: "DB_${m}_SECRET_ID", variable: "DB_SERVICE_SECRET_ID")
                                    ]) {
                                        sh '''
                                            if error=$(aws secretsmanager describe-secret --secret-id "$DB_SERVICE_SECRET_ID" 2>&1); then
                                                aws secretsmanager put-secret-value \
                                                    --secret-id "$DB_SERVICE_SECRET_ID" \
                                                    --secret-string "$(jq -n --arg u "$DB_SERVICE_USERNAME" --arg p "$DB_SERVICE_PASSWORD" '{username: $u, password: $p}')" || exit 1
                                            else
                                                case "$error" in
                                                    *"ResourceNotFoundException"*)
                                                        aws secretsmanager create-secret \
                                                            --name "$DB_SERVICE_SECRET_ID" \
                                                            --secret-string "$(jq -n --arg u "$DB_SERVICE_USERNAME" --arg p "$DB_SERVICE_PASSWORD" '{username: $u, password: $p}')" || exit 1
                                                        ;;
                                                    *)
                                                        echo "Error while checking secret: $error" >&2
                                                        exit 1
                                                        ;;
                                                esac
                                            fi
                                            mysql \
                                                -h "$DB_ADDRESS" \
                                                -u "$DB_ADMIN_USERNAME" \
                                                -p"$DB_ADMIN_PASSWORD" \
                                                -e "CREATE USER '${DB_SERVICE_USERNAME}'@'%' IDENTIFIED BY '${DB_SERVICE_PASSWORD}';
                                                    GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, REFERENCES ON petclinic.* TO '${DB_SERVICE_USERNAME}'@'%';
                                                    FLUSH PRIVILEGES;"
                                        '''
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('apply terraform2') {
            steps {
                script {
                    dir('terraform2') {
                        sh 'terraform init'
                        def code = sh(script: 'terraform plan -detailed-exitcode -out=tfplan', returnStatus: true)
                        if (code == 0) {
                            echo 'Infrastructure matches desired state. No changes needed.'
                        } else if (code == 2) {
                            sh 'terraform show tfplan'
                            slackSend(
                                channel: '#jenkins-approvals',
                                color: 'warning',
                                message: ":warning: *Stage: Apply Terraform2*\n" +
                                         "Infrastructure drift detected.\n" +
                                         "Approval is required before applying changes.\n" +
                                         "Review and approve here: ${env.BUILD_URL}input"
                            )
                            timeout(time: 15, unit: 'MINUTES') {
                                input(
                                    message: 'Infrastructure drift detected. Approve Terraform apply?',
                                    ok: 'Approve'
                                )
                            }
                            sh 'terraform apply -auto-approve tfplan'
                        } else {
                            slackSend(
                                channel: '#jenkins-errors',
                                color: 'danger',
                                message: ":x: *Stage: Apply Terraform2*\n" +
                                         "Terraform plan failed with exit code ${code}.\n" +
                                         "Please review the build logs to identify and fix the error.\n" +
                                         "Build details: ${env.BUILD_URL}console"
                            )
                            error('Terraform plan failed. Stopping pipeline.')
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            sh '''
                rm -f terraform1/tfplan
                rm -f terraform2/tfplan
            '''
        }
    }
}