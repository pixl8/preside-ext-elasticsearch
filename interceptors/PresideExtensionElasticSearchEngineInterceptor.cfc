component extends="coldbox.system.Interceptor" {

	property name="elasticSearchEngine"        inject="provider:elasticSearchEngine";
	property name="elasticSearchConfig"        inject="provider:elasticSearchPresideObjectConfigurationReader";
	property name="systemConfigurationService" inject="provider:SystemConfigurationService";
	property name="presideObjectService"       inject="provider:PresideObjectService";

// PUBLIC
	public void function configure() {}

	public void function preElasticSearchIndexDoc( event, interceptData ) {
		_getSearchEngine().processPageTypeRecordsBeforeIndexing(
			  objectName = interceptData.objectName ?: ""
			, records    = interceptData.doc        ?: []
		);
	}
	public void function preElasticSearchIndexDocs( event, interceptData ) {
		_getSearchEngine().processPageTypeRecordsBeforeIndexing(
			  objectName = interceptData.objectName ?: ""
			, records    = interceptData.docs       ?: []
		);
	}

	public void function postInsertObjectData( event, interceptData ) {
		var objectName = interceptData.objectName ?: "";

		var isPageType = presideObjectService.getObjectAttribute( objectName, "isPageType" , false );

		if ( ( IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors ) || isPageType ||  objectName == 'page' ) {
			return;
		}
		var id = Len( Trim( interceptData.newId ?: "" ) ) ? interceptData.newId : ( interceptData.data.id ?: "" );

		if ( Len( Trim( id ) ) ) {
			_getSearchEngine().indexRecord(
				  objectName = objectName
				, id         = id
			);
			_getSearchEngine().queueRecordReindexIfNecessary(
				  objectName = objectName
				, recordId   = id
			);
		}
	}

	public void function postAddSiteTreePage( event, interceptData ) {
		var id = interceptData.id ?: "";

		if ( Len( Trim( id ) ) ) {
			_getSearchEngine().indexRecord(
				  objectName = interceptData.page_type ?: ""
				, id         = id
			);

			_getSearchEngine().queueRecordReindexIfNecessary(
				  objectName = interceptData.page_type ?: ""
				, recordId   = id
			);
		}
	}

	public void function postUpdateObjectData( event, interceptData ) {
		if ( IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id = Len( Trim( interceptData.id ?: "" ) ) ? interceptData.id : ( interceptData.data.id ?: "" );

		if ( Len( Trim( objectName ) ) && Len( Trim( id ) ) ) {
			_getSearchEngine().indexRecord(
				  objectName = objectName
				, id         = id
			);
			_getSearchEngine().queueRecordReindexIfNecessary(
				  objectName = objectName
				, recordId   = id
			);
			var reindexChildPage = systemConfigurationService.getSetting( "elasticsearch", "reindex_child_pages_on_edit", true )
			if( isBoolean( reindexChildPage ?: "" ) && reindexChildPage ){
				if ( _inThread() ) {
					_getSearchEngine().reindexChildPages( objectName, id, interceptData.data ?: {} );
				} else {
					thread name         = CreateUUId()
					       searchEngine = _getSearchEngine()
					       objectName   = objectName
					       id           = id
					       data         = ( interceptData.data ?: {} )
					{
						setting requesttimeout=300;
						attributes.searchEngine.reindexChildPages( attributes.objectName, attributes.id, attributes.data );
					}
				}
			}
		}
	}

	public void function preDeleteObjectData( event, interceptData ) {
		if ( IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id         = interceptData.id ?: "";
		if ( !Len( Trim( id ) ) ) {
			id = interceptData.filter.id ?: ( interceptData.filterParams.id ?: "" );
		}
		if ( IsArray( id ) ) {
			id = id.toList();
		}

		if ( IsSimpleValue( id ) && Len( Trim( id ) ) ) {
			_getSearchEngine().deleteRecord(
				  objectName = objectName
				, id         = id
			);
			_getSearchEngine().queueRecordReindexIfNecessary(
				  objectName = objectName
				, recordId   = id
				, isDeleted  = true
			);
		}
	}


// PRIVATE
	private boolean function _isSearchEnabled( required string objectName ) {
		return Len( Trim( arguments.objectName ) ) && _getElasticSearchConfig().isObjectSearchEnabled( arguments.objectName );
	}
	private any function _getSearchEngine() {
		return elasticSearchEngine.get();
	}
	private any function _getElasticSearchConfig() {
		return elasticSearchConfig.get();
	}
	private boolean function _inThread() {
		return getPageContext().hasFamily();
	}
}