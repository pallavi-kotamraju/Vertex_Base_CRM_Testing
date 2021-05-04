#!groovy
import groovy.json.JsonSlurperClassic
node {

    def BUILD_NUMBER=env.BUILD_NUMBER
    def RUN_ARTIFACT_DIR="tests/${BUILD_NUMBER}"
    def SFDC_USERNAME

     def HUB_ORG='VertexUnpackag@vertex.com'
    def SFDC_HOST = 'https://login.salesforce.com'
    def JWT_KEY_CRED_ID = '26253946-1ae8-46ed-916b-b945207d94de'
    def CONNECTED_APP_CONSUMER_KEY='3MVG9fe4g9fhX0E7aM1il19gyOLjsfMnkPZzySQaBQa0jug1i2zmugbB9q_e6KH2z5MLEiN4cGwG0mj8P1n2N'

    println 'KEY IS' 
    println JWT_KEY_CRED_ID
    println HUB_ORG
    println SFDC_HOST
    println CONNECTED_APP_CONSUMER_KEY
    def toolbelt = tool 'toolbelt'

   stage('checkout source') {
        // when running in multi-branch job, one must issue this command
        checkout scm
    }
    withEnv(["HOME=${env.WORKSPACE}"]) {

        withCredentials([file(credentialsId: JWT_KEY_CRED_ID, variable: 'jwt_key_file')]) {      
            

            stage('Authorize Dev Hub') {
                /*
                rccc = bat returnStatus: true, script: "sfdx auth:logout -u ${HUB_ORG} -p"
                if (rccc != 0) { error 'Log out failed' }
                */

                //rct1 = bat returnStatus: true, script: "sfdx update"
                rct1 = bat returnStatus: true, script: "sfdx plugins --core"
                println 'rct1::'
                 println rct1
                //rct = bat returnStatus: true, script: "\"${toolbelt}/sfdx\" plugins --core"
                

                if (isUnix()) {
                     println '****Is UNix True ****'
                    rc = sh returnStatus: true, script: "${toolbelt}/sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile ${jwt_key_file} --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
                }else{
                     println '**** is Unix False****'
                    rc = bat returnStatus: true, script: "\"${toolbelt}/sfdx\" auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile \"${jwt_key_file}\" --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
                }
                if (rc != 0) { println '**** Rac is not 0****'
                              error 'hub org authorization failed' }

                println rc
            
            
            }

            stage('List Org'){
                rcc = bat returnStatus: true, script: "\"${toolbelt}/sfdx\" force:org:list"
                if (rcc != 0) { error 'Org List failed' }
            }

            stage('Deploye Code'){
                // Deploy code
                println('Deploying code to the Org from Repository')
                if (isUnix()) {
                    rmsg = sh returnStdout: true, script: "${toolbelt}/sfdx force:source:deploy -p force-app/. -u ${HUB_ORG}"
                }else{
                rmsg = bat returnStdout: true, script: "\"${toolbelt}/sfdx\" force:source:deploy -p force-app/. -u ${HUB_ORG}"
                }
                
                printf rmsg
                println('Check deployment status')
                println(rmsg)

            }

            stage('Check Deployment Status'){
                //Check status
                if (isUnix()) {
                    rmsg1 = sh returnStdout: true, script: "${toolbelt}/sfdx force:mdapi:deploy:report -u ${HUB_ORG}"
                }else{
                rmsg1 = bat returnStdout: true, script: "\"${toolbelt}/sfdx\" force:mdapi:deploy:report -u ${HUB_ORG}"
                }

                println('Deployment report is -- ')
                println(rmsg1)

            }
        }
    }
}

def command(script) {
    if (isUnix()) {
        return sh(returnStatus: true, script: script);
    } else {
        return bat(returnStatus: true, script: script);
    }
}
