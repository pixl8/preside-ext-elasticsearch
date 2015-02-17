component extends="coldbox.system.Interceptor" output=false {

	property name="elasticSearchEngine" inject="provider:elasticSearchEngine";
	property name="elasticSearchConfig" inject="provider:elasticSearchPresideObjectConfigurationReader";

// PUBLIC
	public void function configure() output=false {}

	public void function preElasticSearchIndexDoc( event, interceptData ) output=false {
		_getSearchEngine().processPageTypeRecordsBeforeIndexing(
			  objectName = interceptData.objectName ?: ""
			, records    = interceptData.doc        ?: []
		);
	}
	public void function preElasticSearchIndexDocs( event, interceptData ) output=false {
		_getSearchEngine().processPageTypeRecordsBeforeIndexing(
			  objectName = interceptData.objectName ?: ""
			, records    = interceptData.docs       ?: []
		);
	}

	public void function postInsertObjectData( event, interceptData ) output=false {
		if ( IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors ) {
			return;
		}
		var id = Len( Trim( interceptData.newId ?: "" ) ) ? interceptData.newId : ( interceptData.data.id ?: "" );

		if ( Len( Trim( id ) ) ) {
			_getSearchEngine().indexRecord(
				  objectName = interceptData.objectName ?: ""
				, id         = id
			);
		}
	}

	public void function postUpdateObjectData( event, interceptData ) output=false {
		if ( IsBoolean( interceptData.skipTrivialInterceptors ?: "" ) && interceptData.skipTrivialInterceptors ) {
			return;
		}

		var objectName = interceptData.objectName ?: "";
		var id         = interceptData.id ?: "";

		if ( Len( Trim( objectName ) ) && Len( Trim( id ) ) ) {
			_getSearchEngine().indexRecord(
				  objectName = objectName
				, id         = id
			);

			if ( _inThread() ) {
				_getSearchEngine().reindexChildPages( objectName, id, interceptData.data ?: {} );
			} else {
				thread name         = CreateUUId()
				       searchEngine = _getSearchEngine()
				       objectName   = objectName
				       id           = id
				       data         = ( interceptData.data ?: {} )
				{
					attributes.searchEngine.reindexChildPages( attributes.objectName, attributes.id, attributes.data );
				}
			}
		}
	}

	public void function preDeleteObjectData( event, interceptData ) output=false {
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
		}
	}


// PRIVATE
	private boolean function _isSearchEnabled( required string objectName ) output=false {
		return Len( Trim( arguments.objectName ) ) && _getElasticSearchConfig().isObjectSearchEnabled( arguments.objectName );
	}
	private any function _getSearchEngine() output=false {
		return elasticSearchEngine.get();
	}
	private any function _getElasticSearchConfig() output=false {
		return elasticSearchConfig.get();
	}
	private boolean function _inThread() output=false {
		return getPageContext().hasFamily();
	}
}