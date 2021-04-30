public with sharing class VertexCPQPostInstall implements InstallHandler{
	public void onInstall(InstallContext context) {
		try {
			VertexCPQDataInit init = new VertexCPQDataInit();
		} catch (Exception ex){
			System.debug('An exception was encountered while running the package post-install script:\r\n\r\n' + ex.getMessage() + '\r\n\rn' + ex.getStackTraceString());
		}
	}
}