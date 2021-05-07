node('e2e') {
    stage('checkout') {
        git credentialsId: 'basic-ssh', branch: 'master', url: 'git@github.com:pallavi-kotamraju/Vertex_Base_CRM_Testing.git'
    }
