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
   def HUB_ORG='test-dwb9l2gn5usn@example.com'
    def SFDC_HOST = 'https://login.salesforce.com'
    def JWT_KEY_CRED_ID = '941f2402-1a4e-4ad3-9bd5-fa37d53b9220'
    def CONNECTED_APP_CONSUMER_KEY='3MVG9e2mBbZnmM6mBquZb6AU3G9JkVdhVyYWdlutBPutIFnpFiZ7qx3Rs5rgA1OYxMsZ4Pvfw9_8qcsxfw03C'
 
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
   
  
   
   
  stage('checkout source') {
        // when running in multi-branch job, one must issue this command
        checkout scm
    }
	  
	
	
	
withCredentials([file(credentialsId: JWT_KEY_CRED_ID, variable: 'jwt_key_file')]) {
        println 'before sfdx'
	rc = script = "${toolbelt} force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile ${JWT_KEY_CRED_ID} --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
        println 'After sfdx'         
	//rc =  sh returnStdout: true, script: "${SFDX_HOME}/sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile ${jwt_key_file} --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
                
	}
	 if (rc != 0) { error 'hub org authorization failed: BUt why ot failed' }
	println rc
			
    
			
			// need to pull out assigned username
			if (isUnix()) {
				rmsg = sh returnStdout: true, script: "${toolbelt} force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"
			}else{
			   rmsg = bat returnStdout: true, script: "\"${toolbelt}\" force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"
			}
			  
            printf rmsg
            println('Hello from a Job DSL script!')
            println(rmsg)
    
}
