public with sharing class VertexPostInstall implements InstallHandler{

	public void onInstall(InstallContext context) {

		try {
			//Fresh install
			if (context.previousVersion() == null){
				VertexDataInit init = new VertexDataInit();
				init.CreateVanilla();
			}

			//Upgrade
			else {
				UpgradeCustomSettings();
			}
		} catch (Exception ex){
			VertexLogging.Log('Error', 'An exception was encountered while running the package post-install script:\r\n\r\n' + ex.getMessage());
			System.debug('An exception was encountered while running the package post-install script:\r\n\r\n' + ex.getMessage() + '\r\n\rn' + ex.getStackTraceString());
		}
	}

	/*
		- Rename destination mappings to shorter format
		- Remove address mappings that use dot notation for field relationships (except those associated with extension object settings like Billing and CC)
		- Insert administrative/physical origin addresses for transaction and line levels for the three default object mappings
		- Set defaults for new fields on object mappings
		- Copy the values from VertexSettings__c over to VertexProtectedSettings__c
	*/
	public void UpgradeCustomSettings(){
		//Rename Destination Maps to adhere to new naming convention, and clear out any deprecated "parentObject.fieldName" style mappings
		List<VertexAddress__c> updatedDestMaps = new List<VertexAddress__c>();
		String logMsg = '';
		Set<String> extSettingNames = new Set<String>();	//Billing and CloudCraze mapping names
		for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values()){
			if (objMap.IsExtensionSetting__c == true)
				extSettingNames.add(objMap.Name);
		}

		Schema.DescribeSObjectResult addrDescr = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexAddress__c').getDescribe();
		for (VertexAddress__c addr : VertexAddress__c.getAll().values()){
			if (addr.Name != 'Default Physical Origin Address' && addr.Name != 'Administrative Origin Address'){
				String prevName = addr.Name;
				addr.Name = addr.Name.replace('Transaction Destination Maps', 'Trans Dest Map');
				addr.Name = addr.Name.replace('Line Destination Maps', 'Line Dest Map');

				Boolean isExt = false;
				for (String extName : extSettingNames){
					if (addr.Name.startsWith(extName)){
						isExt = true;
						break;
					}
				}

				Boolean fieldNulled = false;
				if (isExt == false){
					if (addr.Address1__c != null && addr.Address1__c.contains('.')){
						logMsg += addr.Name + ': Address 1 had a mapping of ' + addr.Address1__c + '\n';
						addr.Address1__c = null;
						fieldNulled = true;
					}
					if (addr.Address2__c != null && addr.Address2__c.contains('.')){
						logMsg += addr.Name + ': Address 2 had a mapping of ' + addr.Address2__c + '\n';
						addr.Address2__c = null;
						fieldNulled = true;
					}
					if (addr.City__c != null && addr.City__c.contains('.')){
						logMsg += addr.Name + ': City had a mapping of ' + addr.City__c + '\n';
						addr.City__c = null;
						fieldNulled = true;
					}
					if (addr.Country__c != null && addr.Country__c.contains('.')){
						logMsg += addr.Name + ': Country had a mapping of ' + addr.Country__c + '\n';
						addr.Country__c = null;
						fieldNulled = true;
					}
					if (addr.CustomerClassCode__c != null && addr.CustomerClassCode__c.contains('.')){
						logMsg += addr.Name + ': Customer Class Code had a mapping of ' + addr.CustomerClassCode__c + '\n';
						addr.CustomerClassCode__c = null;
						fieldNulled = true;
					}
					if (addr.CustomerCode__c != null && addr.CustomerCode__c.contains('.')){
						logMsg += addr.Name + ': Customer Code had a mapping of ' + addr.CustomerCode__c + '\n';
						addr.CustomerCode__c = null;
						fieldNulled = true;
					}
					if (addr.PostalCode__c != null && addr.PostalCode__c.contains('.')){
						logMsg += addr.Name + ': Postal Code had a mapping of ' + addr.PostalCode__c + '\n';
						addr.PostalCode__c = null;
						fieldNulled = true;
					}
					if (addr.State__c != null && addr.State__c.contains('.')){
						logMsg += addr.Name + ': State had a mapping of ' + addr.State__c;
						addr.State__c = null;
						fieldNulled = true;
					}
					if (addr.TaxAreaID__c != null && addr.TaxAreaID__c.contains('.')){
						logMsg += addr.Name + ': Tax Area ID had a mapping of ' + addr.TaxAreaID__c + '\n';
						addr.TaxAreaID__c = null;
						fieldNulled = true;
					}
				}

				if (prevName != addr.Name || fieldNulled == true)
					updatedDestMaps.add(addr);
			}
		}
		if (addrDescr.isUpdateable())
			update updatedDestMaps;

		//If we cleared any of the user's old mappings, we log exactly what we deleted so that they can reference it
		if (logMsg != '' && 
			VertexCore.HasCRUDandFLS(VertexCore.NamespaceString + 'VertexLog__c.' + VertexCore.NamespaceString + 'Details__c') && 
			VertexCore.HasCRUDandFLS(VertexCore.NamespaceString + 'VertexLog__c.' + VertexCore.NamespaceString + 'Response__c')){
			VertexLog__c newLog = new VertexLog__c(Details__c = 'Post-Install: Cleared Invalid Destination Mappings', Response__c = logMsg);
			insert newLog;	//Ignore the debug log custom settings; we always want to insert this
		}

		//Insert (blank) origin addresses if none exist
		VertexDataInit vDataInit = new VertexDataInit();
		List<VertexAddress__c> newOriginMappings = new List<VertexAddress__c>();
		for (VertexAddress__c addr : vDataInit.VanillaOriginMappings()){
			if (VertexAddress__c.getInstance(addr.Name) == null)	//No custom setting of this name currently exists
				newOriginMappings.add(addr);
		}
		if (addrDescr.isCreateable() && !newOriginMappings.isEmpty())
			insert newOriginMappings;

		//Set new default fields on existing object mappings
		List<VertexObjectMapping__c> updatedObjMappings = new List<VertexObjectMapping__c>();
		Schema.DescribeSObjectResult objDescr = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexObjectMapping__c').getDescribe();
		for (VertexObjectMapping__c objMap : VertexObjectMapping__c.getAll().values()){
			Boolean isChanged = false;
			if (String.isBlank(objMap.XMLMessage__c)){
				objMap.XMLMessage__c = 'Quote';
				isChanged = true;
			}
			if (String.isBlank(objMap.TransactionType__c)){
				objMap.TransactionType__c = 'SALE';
				isChanged = true;
			}
			if (isChanged)
				updatedObjMappings.add(objMap);
		}
		if (objDescr.isUpdateable())
			update updatedObjMappings;

		//Populate the new custom setting from the old, and then remove the old
		VertexSettings__c oldSettings = VertexSettings__c.getInstance('Active');
		VertexProtectedSettings__c newSettings = VertexProtectedSettings__c.getInstance('Active');
		if (oldSettings != null && newSettings == null){
			Schema.DescribeSObjectResult oldDescr = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexSettings__c').getDescribe();
			Schema.DescribeSObjectResult newDescr = VertexCore.GDMap.get(VertexCore.NamespaceString + 'VertexProtectedSettings__c').getDescribe();

			newSettings = new VertexProtectedSettings__c(Name = 'Active');
			newSettings.AllowAddressValidation__c = oldSettings.AllowAddressValidation__c;
			newSettings.AllowAutocomplete__c = oldSettings.AllowAutocomplete__c;
			newSettings.AllowProcessBuilderRequests__c = oldSettings.AllowProcessBuilderRequests__c;
			newSettings.AsynchronousLogging__c = oldSettings.AsynchronousLogging__c;
			newSettings.CompanyTaxID__c = oldSettings.CompanyTaxID__c;
			newSettings.LoggingLevel__c = oldSettings.LoggingLevel__c;
			newSettings.MaximumLoggingRows__c = oldSettings.MaximumLoggingRows__c;
			newSettings.Password__c = oldSettings.Password__c;
			newSettings.ProcessTaxCalculationsAutomatically__c = oldSettings.ProcessTaxCalculationsAutomatically__c;
			newSettings.TaxAreaLookupURL__c = oldSettings.TaxAreaLookupURL__c;
			newSettings.TaxCalculationURL__c = oldSettings.TaxCalculationURL__c;
			newSettings.CompanyName__c = oldSettings.CompanyName__c;
			newSettings.TrustedID__c = oldSettings.TrustedID__c;
			newSettings.Username__c = oldSettings.Username__c;

			if (newDescr.isCreateable())
				insert newSettings;
			if (oldDescr.isDeletable())
				delete oldSettings;
		}
	}
}