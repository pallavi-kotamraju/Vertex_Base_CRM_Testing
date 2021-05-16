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
   def HUB_ORG= 'pallavi_inclass@psl.com'
	   //'VertexUnpackag@vertex.com'
    def SFDC_HOST = 'https://login.salesforce.com'
    def JWT_KEY_CRED_ID = '946f707b-596a-4f47-8959-68b5f4690782'
	    //'c90f4448-cd0a-43d2-8174-a0908a621323'
    def CONNECTED_APP_CONSUMER_KEY= '3MVG92mNMNiWvongF1dlvpthn1iAzke5fE6AKFYIE_QQbdY5w.mvTN9vQ4lBHP0HJebdo8w_I.8TNr4UVDzwn'
	    //'3MVG9fe4g9fhX0E7aM1il19gyONSw_MPAyMErufx1S4.pBcO4XU0PMOrVtQ7VFIuPHuPJnsP_gRzo0l43j747'
 
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
		println '::::checkout01::::'
        checkout scm
		println '::::checkout02::::'
    }
    
   
withCredentials([file(credentialsId: JWT_KEY_CRED_ID, variable: 'jwt_key_file')]) {
	stage('Deploye Code') {
        println 'before sfdx'
	println jwt_key_file
        if (isUnix()) {
		 println 'PP>01'
		 println rc
                rc = sh returnStatus: true, script: "${toolbelt} sfdx force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile ${jwt_key_file} --setdefaultdevhubusername --instanceurl ${SFDC_HOST} --setalias HubOrg"
         	//rc1 = sh returnStatus: true, script: "${toolbelt} force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"
		
	 }else{
		println 'PP>02'
                 rc = bat returnStatus: true, script: "\"${toolbelt}\" force:auth:jwt:grant --clientid ${CONNECTED_APP_CONSUMER_KEY} --username ${HUB_ORG} --jwtkeyfile \"${jwt_key_file}\" --setdefaultdevhubusername --instanceurl ${SFDC_HOST}"
         	println 'PP>03'
		 println rc
	 }
	       
		 if (rc != 0) { error 'Deb Hub Authorization failed' }
			println rc
		
		stage('Create Test Scratch Org') {
			println '******Before Scrtach Rc******* '
			rc = bat returnStatus: true, script: "\"${toolbelt}\" force:org:create --targetdevhubusername ${HUB_ORG} --setdefaultusername --definitionfile config/project-scratch-def.json --setalias ciorg --wait 10 --durationdays 1"
			rrss = bat returnStatus: true, script: "\"${toolbelt}\" force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"	
			rrst = bat returnStatus: true, script: "\"${toolbelt}\" force:mdapi:deploy:report"	
			rrsu = bat returnStatus: true, script: "\"${toolbelt}\" force:apex:test:run -u ${HUB_ORG} --wait 10"
					
			
			println '******After Scrtach Rc******* '
			println 'rc::'
			println rc
			println 'rrss::'
			println rrss
			println 'rrst::'
			println rrst
			println 'rrsu::'
			println rrsu
			if (rc != 0) {
					error 'Salesforce test scratch org creation failed.'
				     }
			if (rrss != 0) {
					error 'Salesforce deploy failed.'
				     }
			if (rrst != 0) {
					error 'Salesforce report failed.'
				     }
			if (rrsu != 0) {
					error 'Salesforce run test class failed.'
				     }
		}
		
		/*stage('Run test class') {   
			println 'Before Test sfdx'  
		 if (isUnix()) {
              		 rmsg  = bat  returnStdout: true, script: "${toolbelt} force:apex:test:run -u ${HUB_ORG} --wait 10"
				}
		println 'rmsg:::' 
		println rmsg 
		println 'After  Test sfdx'  
		if (rmsg  != 0) { error 'Deployment command failed' }
			println rmsg 
    		} */
		
		
		/*
		
		if (isUnix()) {
				rrsg = sh returnStdout: true, script: "${toolbelt} force:apex:test:run -u ${HUB_ORG} --wait 10"
			}else{
			   rrsg = bat returnStdout: true, script: "\"${toolbelt}\" force:mdapi:deploy -d manifest/. -u ${HUB_ORG}"
			}
			  
            printf rrsg
            println('Hello from a running test classes!')
            println(rrsg)
		if (rrsg != 0) { error 'Riun Test command failed' }
		*/	
		
            }
        }
    }
