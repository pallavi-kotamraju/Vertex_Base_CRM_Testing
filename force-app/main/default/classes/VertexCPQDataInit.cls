public with sharing class VertexCPQDataInit {
    public VertexCPQDataInit() {
		string jsNameSpace = '';
		if (VertexCPQCore.NamespaceString!='') jsNameSpace = VertexCPQCore.NamespaceString.replace('__','/');
		String jsCode = '';
		jsCode += 'export function onAfterCalculate(quote, lineModels, conn) {\n';
		jsCode += '	// body payload structure is depending to the Apex REST method interface.\n';
		jsCode += ' var quoteRecord = JSON.stringify(quote.record);\n';
		jsCode += ' var lineItems = [];\n';
		jsCode += ' if(lineModels != null){\n';
		jsCode += ' 	lineModels.forEach(function (line) {\n';
		jsCode += '			    lineItems.push(line.record);\n';
		jsCode += '		});\n';
		jsCode += '	}\n';
		jsCode += ' let i = 1;\n';
		jsCode += ' for(let j = 0; j < lineItems.length; j++){\n';
		jsCode += ' 	if(!lineItems[j].Id){\n';
		jsCode += '			lineItems[j].Id = "new" + i;\n';
		jsCode += ' 	}\n';
		jsCode += ' 	i++\n';
		jsCode += ' }\n';
		jsCode += ' var lineItemsString = JSON.stringify(lineItems);\n';
		jsCode += '	var body = { quote : quoteRecord, lineModels : lineItemsString, type : "Quote" };\n';
		jsCode += '	var taxObj;\n';
		jsCode += '	return new Promise(function(resolve, reject){\n';
		jsCode += '		conn.apex.post("/'+jsNameSpace+'VertexCPQAllFields/getTaxAllFields", body, function(err, res) {\n';
		jsCode += '			if (err) { return console.error(err); }\n';
		jsCode += '			console.log("response: ", res);\n';
		jsCode += '			// the response object structure depends on the definition of apex class\n';
		jsCode += '			taxObj = JSON.parse(res);\n';
		jsCode += '			if (typeof taxObj != "undefined" && Object.keys(taxObj).includes(quote.record["Id"])){\n';
		jsCode += '            if(taxObj[quote.record["Id"]] === "async"){\n';
		jsCode += '                quote.record["'+VertexCPQCore.NamespaceString+'Tax_Amount__c"] = null;\n';
		jsCode += '                quote.record["'+VertexCPQCore.NamespaceString+'Tax_Status__c"] = "Pending";\n';
		jsCode += '             } else if (taxObj[quote.record["Id"]] === "sbqq_nettotal__cNull"){\n';
        jsCode += '   			   quote.record["'+VertexCPQCore.NamespaceString+'Tax_Amount__c"] = null\n';
        jsCode += '    			   quote.record["'+VertexCPQCore.NamespaceString+'Tax_Status__c"] = ""\n';  
		jsCode += ' 			} else {\n';
		jsCode += '                quote.record["'+VertexCPQCore.NamespaceString+'Tax_Amount__c"] = taxObj[quote.record["Id"]];\n';
		jsCode += '                quote.record["'+VertexCPQCore.NamespaceString+'Tax_Status__c"] = "Completed";\n';
		jsCode += '			   }\n';
		jsCode += '			}\n';
		jsCode += '			if (lineModels != null) {\n';
		jsCode += '				lineModels.forEach(function (line) {\n';
		jsCode += '					if (typeof taxObj != "undefined" && Object.keys(taxObj).includes(line.record["Id"])){\n';
		jsCode += '                     if(taxObj[quote.record["Id"]] == "async"){\n';
		jsCode += '                         line.record["'+VertexCPQCore.NamespaceString+'Tax_Amount__c"] = null;\n';
		jsCode += '                         line.record["'+VertexCPQCore.NamespaceString+'Tax_Status__c"] = "Pending";\n';
		jsCode += '                     } else if (taxObj[quote.record["Id"]] === "sbqq_nettotal__cNull"){\n';
		jsCode += '                         line.record["'+VertexCPQCore.NamespaceString+'Tax_Amount__c"] = null\n';
		jsCode += '							line.record["'+VertexCPQCore.NamespaceString+'Tax_Status__c"] = ""\n'; 
		jsCode += '                     } else { \n';
		jsCode += '                         line.record["'+VertexCPQCore.NamespaceString+'Tax_Amount__c"] = taxObj[line.record["Id"]];\n';
		jsCode += '                         line.record["'+VertexCPQCore.NamespaceString+'Tax_Status__c"] = "Completed";\n';
		jsCode += '                     }\n';
		jsCode += '					}\n';
		jsCode += '					if(line.record["Id"].startsWith("new")){\n';
		jsCode += '						line.record["Id"] = null;\n';
		jsCode += '					}\n';
		jsCode += '				});\n';
		jsCode += '			}\n';
		jsCode += '			resolve();\n';
		jsCode += '		});\n';
		jsCode += '	});\n';
		jsCode += '}\n';
		jsCode += 'export function isFieldEditable(fieldName, quoteLineModelRecord) { \n';
		jsCode += '	if (fieldName == "'+VertexCPQCore.NamespaceString+'Tax_Amount__c") { \n';
		jsCode += '		return false; \n';
		jsCode += '	} \n';
		jsCode += '	return true; \n';
		jsCode += '}\n';

        Map<String, Map<String, String>> objectMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();

		Map<String, String> tempMap = new Map<String, String>();

		//check if there is an existing custom script, and update it with the current javascript
		//if no script exists, create a new one
		List<SBQQ__CustomScript__c> scripts = [SELECT Id FROM SBQQ__CustomScript__c WHERE Name='VertexQCP' LIMIT 1];
		SBQQ__CustomScript__c script = new SBQQ__CustomScript__c();
		if(!scripts.isEmpty()){
			script = scripts[0];
		}
		script.SBQQ__Code__c = jsCode;
		script.name='VertexQCP';
		script.SBQQ__QuoteFields__c = VertexCPQCore.NamespaceString+'Tax_Amount__c'+'\n'+VertexCPQCore.NamespaceString+'Tax_Status__c';
		script.SBQQ__QuoteLineFields__c = VertexCPQCore.NamespaceString+'Tax_Amount__c'+'\n'+VertexCPQCore.NamespaceString+'Tax_Status__c';
		upsert script;

		objectMappingNameToFieldValuePairs.put('CPQ', new Map<String, String>());
		tempMap = objectMappingNameToFieldValuePairs.get('CPQ');
		tempMap.put('ParentSObject__c', 'SBQQ__Quote__c');
		tempMap.put('ChildSObject__c', 'SBQQ__QuoteLine__c');
		tempMap.put('ParentLookup__c', 'SBQQ__Quote__c');
		tempMap.put('ChildSObjectRelationshipName__c', 'SBQQ__LineItems__r');
		tempMap.put('ItemPriceField__c', 'SBQQ__NetTotal__c');
		tempMap.put('TransactionNumber__c', 'Name');
		tempMap.put('TransactionDate__c', 'CreatedDate');
		tempMap.put('ItemTaxField__c', VertexCPQCore.NamespaceString+'Tax_Amount__c');
		tempMap.put('ItemQuantityField__c', 'SBQQ__Quantity__c');
		tempMap.put('IsExtensionSetting__c', 'true');
		tempMap.put('XMLMessage__c','Quote');
        
		tempMap.put('TransactionType__c', 'SALE');
		VertexGlobal.GlobalHelper(new list<object>{'saveObjMap', objectMappingNameToFieldValuePairs});


        Map<String, Map<String, String>> addressMappingNameToFieldValuePairs = new Map<String, Map<String, String>>();

		Map<String, String> addyTempMap = new Map<String, String>();
		Map<String, String> physTempMap = new Map<String, String>();
		Map<String, String> origTempMap = new Map<String, String>();

		addressMappingNameToFieldValuePairs.put('CPQ Trans Dest Map', new Map<String, String>());
		addyTempMap = addressMappingNameToFieldValuePairs.get('CPQ Trans Dest Map');
		addyTempMap.put('Address1__c', 'SBQQ__ShippingStreet__c');
		addyTempMap.put('City__c', 'SBQQ__ShippingCity__c');
		addyTempMap.put('Country__c', 'SBQQ__ShippingCountry__c');
		addyTempMap.put('PostalCode__c', 'SBQQ__ShippingPostalCode__c');
		addyTempMap.put('State__c', 'SBQQ__ShippingState__c');
		tempMap.put('CustomerCode__c', 'blng__Account__r.AccountNumber');
		tempMap.put('CustomerClassCode__c', 'blng__Account__r.Id');

        VertexGlobal.GlobalHelper(new list<object>{'saveAddyMap', addressMappingNameToFieldValuePairs});

		// Create Custom Object for the Asynchronous Flag to be saved
		VertexCPQSettings__c vtxConfig = VertexCPQSettings__c.getOrgDefaults();
		vtxConfig.AsynchronousCPQCallout__c= false;
		upsert vtxConfig;
	}

}