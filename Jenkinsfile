#!groovy
import groovy.json.JsonSlurperClassic
node {

    def BUILD_NUMBER=env.BUILD_NUMBER
    def RUN_ARTIFACT_DIR="tests/${BUILD_NUMBER}"
    def SFDC_USERNAME

            def HUB_ORG=env.HUB_ORG_DH
    def SFDC_HOST = env.SFDC_HOST_DH
    def JWT_KEY_CRED_ID = env.JWT_CRED_ID_DH
    def CONNECTED_APP_CONSUMER_KEY=env.CONNECTED_APP_CONSUMER_KEY_DH
    
  /*   def HUB_ORG='VertexUnpackag@vertex.com'
    def SFDC_HOST = 'https://login.salesforce.com'
    def JWT_KEY_CRED_ID = '64640a69-0d33-4169-954c-559944e70b25'
        //'fcc07193-aff5-4b02-9590-10cc42f4d8ee'
      //  '26253946-1ae8-46ed-916b-b945207d94de'
    
    def CONNECTED_APP_CONSUMER_KEY='3MVG9fe4g9fhX0E7aM1il19gyOLjsfMnkPZzySQaBQa0jug1i2zmugbB9q_e6KH2z5MLEiN4cGwG0mj8P1n2N'
*/
    println 'KEY IS' 
    println JWT_KEY_CRED_ID
    println HUB_ORG
    println SFDC_HOST
    println CONNECTED_APP_CONSUMER_KEY
    def toolbelt = tool 'toolbelt'

  
}
