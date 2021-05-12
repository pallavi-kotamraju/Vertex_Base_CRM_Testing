#!groovy
import groovy.json.JsonSlurperClassic
node {

 /*   def BUILD_NUMBER=env.BUILD_NUMBER
    def RUN_ARTIFACT_DIR="tests/${BUILD_NUMBER}"
    def SFDC_USERNAME
          def HUB_ORG=env.HUB_ORG_DH
    def SFDC_HOST = env.SFDC_HOST_DH
    def JWT_KEY_CRED_ID = env.JWT_CRED_ID_DH
    def CONNECTED_APP_CONSUMER_KEY=env.CONNECTED_APP_CONSUMER_KEY_DH
 */
   def HUB_ORG='VertexUnpackag@vertex.com'
    def SFDC_HOST = 'https://login.salesforce.com'
    def JWT_KEY_CRED_ID = 'c90f4448-cd0a-43d2-8174-a0908a621323'
    def CONNECTED_APP_CONSUMER_KEY='3MVG9fe4g9fhX0E7aM1il19gyONSw_MPAyMErufx1S4.pBcO4XU0PMOrVtQ7VFIuPHuPJnsP_gRzo0l43j747'
 
	    //'3MVG9fe4g9fhX0E7aM1il19gyOEJCdRIBn5Hd8O8K.NZfkI2RxzfYqTySAw89vJx.H8zMUoUYv3dNM7YwYXET'
	    //'3MVG9fe4g9fhX0E7aM1il19gyONSw_MPAyMErufx1S4.pBcO4XU0PMOrVtQ7VFIuPHuPJnsP_gRzo0l43j747'
  //  dev SFDX_HOME = 'sfdx/bin'

    println 'KEY IS' 
    println JWT_KEY_CRED_ID
    println HUB_ORG
    println SFDC_HOST
    println CONNECTED_APP_CONSUMER_KEY
  //  println SFDX_HOME
    println 'Multiple branch 1' 
    def toolbelt = tool 'toolbelt'
	println 'toolblet****'
	//println toolbelt
   
  
   
   
  stage('checkout source') {
        // when running in multi-branch job, one must issue this command
        checkout scm
    }
	  
	
	
withCredentials([file(credentialsId: JWT_KEY_CRED_ID, variable: 'jwt_key_file')]) {
	stage('Deploye Code') {
        println 'before sfdx'
	println jwt_key_file
	 if (isUnix()) {
                rc = sh returnStatus: true, script: "${toolbelt} sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile ${jwt_key_file} --setdefaultdevhubusername --instanceurl ${SFDC_HOST} --setalias HubOrg"
            }else{
                 rc = bat returnStatus: true, script: "\"${toolbelt}\" force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile \"${jwt_key_file}\" --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
            }
		println 'After sfdx'         
	       
		 if (rc != 0) { error 'Above command failed' }
			println rc
			
			// need to pull out assigned username
			if (isUnix()) {
				rmsg = sh returnStdout: true, script: "${toolbelt} force:mdapi:deploy -d manifest/. -u ${HUB_ORG} --wait 10"
			}else{
			   rmsg = bat returnStdout: true, script: "\"${toolbelt}\" force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"
			}
			  
            printf rmsg
            println('Hello from a Job DSL script!')
            println(rmsg)
		println rmsg
		
		if (isUnix()) {
				rrsg = sh returnStdout: true, script: "${toolbelt} force:apex:test:run -u ${HUB_ORG} --wait 10"
			}else{
			   rrsg = bat returnStdout: true, script: "\"${toolbelt}\" force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"
			}
			  
            printf rrsg
            println('Hello from a running test classes!')
            println(rrsg)
		if (rrsg != 0) { error 'Above command failed' }
			
		
            }
        }
    }
