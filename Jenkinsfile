pipeline {
  agent { label 'built-in' }

  options {
    timeout(time: 30, unit: 'MINUTES')
    timestamps()
    skipDefaultCheckout()
  }

  triggers {
    pollSCM('H/5 * * * *')
  }

  environment {
    BOT_NAME = 'general_bot'
    RELEASE_DIR = "/opt/ergon/releases/${BOT_NAME}"
    GITHUB_REPO = "ergon-automation-labs/ergon-general"
  }

  stages {

    stage('Checkout') {
      steps {
        sh '''
          echo "==============================================="
          echo "Checking out repository via SSH"
          echo "==============================================="

          export HOME=/var/lib/bot_army
          export GIT_SSH_COMMAND="ssh -i /var/lib/bot_army/.ssh/ergon_deploy -F /var/lib/bot_army/.ssh/config -o StrictHostKeyChecking=no -o IdentitiesOnly=yes"

          /opt/bot_army/scripts/jenkins_checkout.sh ${GITHUB_REPO} ${WORKSPACE}

          echo "Current commit: $(git rev-parse HEAD)"
        '''
      }
    }

    stage('Download Build Artifact') {
      steps {
        sh '''
          echo "==============================================="
          echo "Downloading pre-built release from GitHub"
          echo "==============================================="

          LATEST_RELEASE=$(gh api repos/${GITHUB_REPO}/releases \
            -q '.[] | select(.draft==false) | .tag_name' | head -1)

          if [ -z "$LATEST_RELEASE" ]; then
            echo "ERROR: No published release found on GitHub"
            exit 1
          fi

          echo "Latest release: $LATEST_RELEASE"

          mkdir -p ./release-artifact

          gh release download $LATEST_RELEASE \
            --repo ${GITHUB_REPO} \
            --pattern "*.tar.gz" \
            -D ./release-artifact

          echo "✓ Release downloaded successfully"

          cd ./release-artifact
          TARBALL=$(ls -1 *.tar.gz | head -1)
          echo "Extracting: $TARBALL"
          tar -xzf "$TARBALL"
          rm "$TARBALL"
          ls -la
          cd ..
        '''
      }
    }

    stage('Deploy') {
      steps {
        sh '''
          echo "==============================================="
          echo "Deploying release"
          echo "==============================================="
          echo "Start time: $(date)"

          TIMESTAMP=$(date +%Y%m%d%H%M%S)
          DEST="${RELEASE_DIR}/releases/${TIMESTAMP}"

          echo "Creating release directory..."
          mkdir -p "${DEST}"

          echo "Copying release artifacts..."
          cp -r ./release-artifact/* "${DEST}/"

          echo "Updating current symlink..."
          ln -sfn "${DEST}" "${RELEASE_DIR}/current"

          echo "Restarting service..."
          launchctl kickstart -k system/com.botarmy.${BOT_NAME} || launchctl load /Library/LaunchDaemons/com.botarmy.${BOT_NAME}.plist

          echo "Waiting for service to stabilize..."
          sleep 5

          echo "Deploy complete!"
          echo "Completion time: $(date)"
        '''
      }
    }

  }

  post {
    success {
      sh '''
        if [ -f ./release-artifact/general_bot/releases/start_erl.data ]; then
          VERSION=$(awk '{print $2}' ./release-artifact/general_bot/releases/start_erl.data)
        fi
        VERSION=${VERSION:-"0.1.0"}

        PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"success","version":"${VERSION}"}
EOF
)
        echo "📢 Notifying NATS of successful deployment..."
        /opt/bot_army/scripts/nats_publish.sh ops.deploy.complete "$PAYLOAD" || echo "⚠️  NATS notification failed (non-blocking)"
      '''
    }
    failure {
      sh '''
        PAYLOAD=$(cat <<EOF
{"bot":"${BOT_NAME}","node":"air","triggered_by":"jenkins","status":"failed"}
EOF
)
        echo "📢 Notifying NATS of failed deployment..."
        /opt/bot_army/scripts/nats_publish.sh ops.deploy.failed "$PAYLOAD" || echo "⚠️  NATS notification failed (non-blocking)"
      '''
    }
    always {
      cleanWs()
    }
  }
}
