component extends="coldbox.system.Interceptor" output=false {

	property name="elasticSearchEngine"  inject="provider:elasticSearchEngine";

// PUBLIC
	public void function configure() output=false {}

	public void function preElasticSearchIndexDoc( event, interceptData ) output=false {
		_getSearchEngine().filterPageTypeRecords(
			  objectName = interceptData.objectName ?: ""
			, records    = interceptData.doc        ?: []
		);
	}
	public void function preElasticSearchIndexDocs( event, interceptData ) output=false {
		_getSearchEngine().filterPageTypeRecords(
			  objectName = interceptData.objectName ?: ""
			, records    = interceptData.docs       ?: []
		);
	}


// PRIVATE
	private any function _getSearchEngine() output=false {
		return elasticSearchEngine.get();
	}
	private any function _getPresideObjectService() output=false {
		return presideObjectService.get();
	}
}