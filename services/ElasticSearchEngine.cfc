/**
 * @singleton
 * @presideservice
 */
component {

// CONSTRUCTOR
	/**
	 * @apiWrapper.inject                 provider:elasticSearchApiWrapper
	 * @configurationReader.inject        provider:elasticSearchPresideObjectConfigurationReader
	 * @presideObjectService.inject       provider:presideObjectService
	 * @contentRendererService.inject     provider:contentRendererService
	 * @interceptorService.inject         coldbox:InterceptorService
	 * @pageDao.inject                    presidecms:object:page
	 * @siteService.inject                provider:siteService
	 * @siteTreeService.inject            provider:siteTreeService
	 * @resultsFactory.inject             provider:elasticSearchResultsFactory
	 * @statusDao.inject                  presidecms:object:elasticsearch_indexing_status
	 * @systemConfigurationService.inject provider:systemConfigurationService
	 */
	public any function init( required any apiWrapper, required any configurationReader, required any presideObjectService, required any contentRendererService, required any interceptorService, required any pageDao, required any siteService, required any siteTreeService, required any resultsFactory, required any statusDao, required any systemConfigurationService ) {
		_setLocalCache( {} );
		_setApiWrapper( arguments.apiWrapper );
		_setConfigurationReader( arguments.configurationReader );
		_setPresideObjectService( arguments.presideObjectService );
		_setContentRendererService( arguments.contentRendererService );
		_setInterceptorService( arguments.interceptorService );
		_setPageDao( arguments.pageDao );
		_setSiteService( arguments.siteService );
		_setSiteTreeService( arguments.siteTreeService );
		_setResultsFactory( arguments.resultsFactory );
		_setStatusDao( arguments.statusDao );
		_setSystemConfigurationService( arguments.systemConfigurationService );

		_checkIndexesExist();

		return this;
	}

// PUBLIC API METHODS
	public any function search(
		  array   objects         = []
		, string  q               = "*"
		, string  fieldList       = ""
		, string  queryFields     = ""
		, string  sortOrder       = ""
		, numeric page            = 1
		, numeric pageSize        = 10
		, string  defaultOperator = "OR"
		, string  highlightFields = ""
		, numeric minimumScore    = 0
		, struct  basicFilter     = {}
		, struct  directFilter    = {}
		, struct  fullDsl
	) {
		var configReader = _getConfigurationReader();
		var searchArgs   = duplicate( arguments );

		searchArgs.index = "";
		searchArgs.type  = "";
		searchArgs.delete( "objects" );

		for( var objName in arguments.objects ){
			var conf = configReader.getObjectConfiguration( objName );
			if ( !ListFindNoCase( searchArgs.index, conf.indexName ) ) {
				searchArgs.index = ListAppend( searchArgs.index, conf.indexName );
			}
			if ( !ListFindNoCase( searchArgs.type, conf.documentType ) ) {
				searchArgs.type = ListAppend( searchArgs.type, conf.documentType );
			}
		}

		if ( !Len( Trim( searchArgs.index ) ) ) {
			searchArgs.index = configReader.listIndexes().toList();
		}

 		var apiCallResult = _getApiWrapper().search( argumentCollection=searchArgs );

		return _getResultsFactory().newSearchResult(
			  rawResult       = apiCallResult
			, page            = arguments.page
			, pageSize        = arguments.pageSize
			, returnFields    = arguments.fieldList
			, highlightFields = arguments.highlightFields
			, q               = arguments.q
		);
	}

	public void function ensureIndexesExist() {
		var indexes    = _getConfigurationReader().listIndexes();
		var apiWrapper = _getApiWrapper();

		for( var ix in indexes ){
			if ( !apiWrapper.getAliasIndexes( ix ).len() ) {
				var ux = createIndex( ix );

				_createAlias( index=ux, alias=ix );
				cleanupOldIndexes( keepIndex=ux, alias=ix );
			}
		}
		return;
	}

	public string function createIndex( required string indexName ) {
		var settings   = getIndexSettings( arguments.indexName );
		var uniqueId   = createUniqueIndexName( arguments.indexName );
		var apiWrapper = _getApiWrapper();

		_announceInterception( "preElasticSearchCreateIndex", { indexName = uniqueId, settings  = settings } );

		apiWrapper.createIndex( index=uniqueId, settings=settings );

		_announceInterception( "postElasticSearchCreateIndex", { indexName = uniqueId, settings  = settings } );

		return uniqueId;
	}

	public boolean function rebuildIndexes( any logger ) {
		var haveLogger = StructKeyExists( arguments, "logger" );
		var canInfo    = haveLogger && arguments.logger.canInfo();
		var success    = true;

		for( var index in _getConfigurationReader().listIndexes() ) {
			if ( canInfo ) { arguments.logger.info( "Starting to rebuild ElasticSearch index [#index#]" ); }
			success = success && rebuildIndex( index, logger ?: NulLValue() );
			if ( canInfo ) { arguments.logger.info( "Finished rebuilding ElasticSearch index [#index#]" ); }
		}

		return success;
	}

	public boolean function rebuildIndex( required string indexName, any logger  ) {
		var start      = getTickCount();
		var haveLogger = StructKeyExists( arguments, "logger" );
		var canInfo    = haveLogger && arguments.logger.canInfo();
		var canWarn    = haveLogger && arguments.logger.canWarn();
		var canError   = haveLogger && arguments.logger.canError();

		_announceInterception( "preElasticSearchRebuildIndex", { alias = arguments.indexName } );

		transaction {
			if ( isIndexReindexing( arguments.indexName ) ) {
				throw( type="ElasticSearchEngine.indexing.in.progress", message="The index, [#indexName#], is currently being rebuilt. You cannot rebuild an index that is already being built." );
			}

			setIndexingStatus(
				  indexName         = arguments.indexName
				, isIndexing        = true
				, indexingStartedAt = Now()
				, indexingExpiry    = DateAdd( "h", 1, Now() )
			);
		}

		clearReindexingQueue( arguments.indexName );

		try {
			var uniqueIndexName = createIndex( arguments.indexName );
			var objects         = _getConfigurationReader().listObjectsForIndex( arguments.indexName );
			var indexingSuccess = true;

			var event           = $getColdbox().getRequestContext();
			var originalSite    = event.getSite();
			var sites           = _getSiteService().listSites();

			for( var objectName in objects ) {
				if( _isPageType( objectName ) || _objectIsUsingSiteTenancy( objectName ) ) {
					for( var site in sites ) {
						event.setSite( site );

						if ( canInfo ) { arguments.logger.info( "> Site [#site.name#]" ); }

						indexingSuccess = indexAllRecords( objectName, uniqueIndexName, indexName, arguments.logger ?: NullValue() );

						if ( !indexingSuccess ) {
							if ( canWarn ) { arguments.logger.warn( "Indexing of [#objectName#] records returned unsuccessful, aborting index job." ); }
							break;
						}
					}
					event.setSite( originalSite );
				} else {
					indexingSuccess = indexAllRecords( objectName, uniqueIndexName, indexName, arguments.logger ?: NullValue() );

					if ( !indexingSuccess ) {
						if ( canWarn ) { arguments.logger.warn( "Indexing of [#objectName#] records returned unsuccessful, aborting index job." ); }
						break;
					}
				}
			}

			event.setSite( originalSite );

			if ( indexingSuccess ) {
				_createAlias( index=uniqueIndexName, alias=arguments.indexName );

				setIndexingStatus(
					  indexName               = arguments.indexName
					, isIndexing              = false
					, indexingExpiry          = ""
					, lastIndexingSuccess     = true
					, lastIndexingCompletedAt = Now()
					, lastIndexingTimetaken   = GetTickCount() - start
				);

				cleanupOldIndexes( keepIndex=uniqueIndexName, alias=arguments.indexName );

				processReindexingQueue( indexName=indexName, logger=arguments.logger ?: NullValue() );

				_announceInterception( "postElasticSearchRebuildIndex", { alias = arguments.indexName, indexName = uniqueIndexName } );
			} else {
				if ( canError ) { arguments.logger.error( "An error occurred during indexing, aborting the job. Existing search indexes will be left untouched." ); }
				terminateIndexing( arguments.indexName );
				_announceInterception( "onElasticSearchRebuildIndexFailure", { alias = arguments.indexName, indexName = uniqueIndexName } );
				_deleteIndex( uniqueIndexName );
			}

			return indexingSuccess;

		} catch ( any e ) {
			try {
				terminateIndexing( arguments.indexName );
				_announceInterception( "onElasticSearchRebuildIndexFailure", { alias = arguments.indexName, indexName = uniqueIndexName, error = e } );
				_deleteIndex( uniqueIndexName );
				if ( canError ) { arguments.logger.error( "An error occurred during indexing, aborting the job. Existing search indexes will be left untouched." ); }
			} catch ( any e ) {}

			rethrow;
		}
	}

	public void function cleanupOldIndexes( required string keepIndex, required string alias ) {
		var args    = arguments;
		var indexes = _getApiWrapper().getIndexes( filter=function( indexName ){
			var uuidRegex = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{16}";
			return arguments.indexName.startsWith( alias ) && ReFind( "_#uuidRegex#$", arguments.indexName );
		} );

		for( var indexName in indexes ){
			if ( indexName != arguments.keepIndex ) {
				_deleteIndex( indexName );
			}
		}
	}

	public struct function getIndexSettings( required string indexName ) {
		var settings = {
			  settings = _getDefaultIndexSettings()
			, mappings = getIndexMappings( arguments.indexName )
		};

		_announceInterception( "postElasticSearchGetIndexSettings", { settings = settings } );

		return settings;
	}

	public struct function getIndexMappings( required string indexName ) {
		var mappings      = {};
		var configWrapper = _getConfigurationReader();
		var docTypes      = configWrapper.listDocumentTypes( arguments.indexName );

		for( var docType in docTypes ){
			var fields = configWrapper.getFields( arguments.indexName, docType );
			mappings[ docType ] = { properties={} };
			for( var field in fields ){
				var fieldName = fields[ field ].fieldName;
				mappings[ docType ].properties[ fieldName ] = getElasticSearchMappingFromFieldConfiguration( argumentCollection=fields[ field ], name=fieldName );
			}

			mappings[ docType ].properties.append( _getCommonPropertyMappings(), false );
		}

		return mappings;
	}

	public struct function getElasticSearchMappingFromFieldConfiguration( required string name, required string type, boolean searchable=false, boolean sortable=false, string analyzer="", boolean ignoreMalformedDates=false ) {
		var mapping = { type=arguments.type };

		if ( arguments.searchable ) {
			if ( Len( Trim( arguments.analyzer ) ) ) {
				mapping.analyzer = arguments.analyzer;
			}
		} else {
			if ( arguments.sortable ) {
				mapping.analyzer = "preside_sortable";
			} else {
				mapping.index = "not_analyzed";
			}
		}

		if ( arguments.sortable && arguments.searchable ) {
			mapping = {
				  type   = "multi_field"
				, fields = {
					  "#arguments.name#" = Duplicate( mapping )
					, untouched          = Duplicate( mapping )
				}
			};
			mapping.fields.untouched.analyzer = "preside_sortable";
		}

		if ( arguments.type == "date" ){
			mapping.ignore_malformed = arguments.ignoreMalformedDates;
			if ( StructKeyExists( arguments, "dateFormat" ) ) {
				mapping.format = arguments.dateFormat;
			}
		}

		return mapping;
	}

	public string function createUniqueIndexName( required string sourceIndexName ) {
		return sourceIndexName & "_" & LCase( CreateUUId() );
	}

	public boolean function indexRecord( required string objectName, required string id ) {
		var objName = arguments.objectName == "page" ? _getPageTypeForRecord( arguments.id ) : arguments.objectName;

		if ( _getConfigurationReader().isObjectSearchEnabled( objName ) ) {
			var objectConfig = _getConfigurationReader().getObjectConfiguration( objName );
			var object       = _getPresideObjectService().getObject( objName );
			var doc          = "";

			if ( IsBoolean( objectConfig.hasOwnDataGetter ?: "" ) && objectConfig.hasOwnDataGetter ) {
				doc = object.getDataForSearchEngine( arguments.id );
			} else if ( _hasSearchDataSource( arguments.objectName ) ) {
				doc = $getColdbox().runEvent(
					  event          = objectConfig.searchDataSource
					, eventArguments = { id = arguments.id }
					, private        = true
					, prePostExempt  = true
				);
			} else {
				doc = getObjectDataForIndexing( objName, arguments.id );
			}

			_announceInterception( "preElasticSearchIndexDoc", { objectName=objName, id=arguments.id, doc = doc } );

			if ( !IsArray( doc ) || !doc.len() ) {
				return _getApiWrapper().deleteDoc(
					  index = objectConfig.indexName    ?: ""
					, type  = objectConfig.documentType ?: ""
					, id    = arguments.id
				);
			}

			var result = _getApiWrapper().addDoc(
				  index = objectConfig.indexName    ?: ""
				, type  = objectConfig.documentType ?: ""
				, doc   = doc[1]
				, id    = arguments.id
			);

			_announceInterception( "postElasticSearchIndexDoc", { doc = doc[1], result=result } );

			return true;
		}

		return false;
	}

	public boolean function indexAllRecords( required string objectName, required string indexName, required string indexAlias, any logger ) {
		if ( _getConfigurationReader().isObjectSearchEnabled( arguments.objectName ) ) {
			var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
			var esApi     = _getApiWrapper();
			var records   = [];
			var page      = 0;
			var pageSize  = 100;
			var total     = 0;
			var haveLogger = StructKeyExists( arguments, "logger" );
			var canDebug   = haveLogger && arguments.logger.canDebug();
			var canInfo    = haveLogger && arguments.logger.canInfo();
			var canWarn    = haveLogger && arguments.logger.canWarn();
			var canError   = haveLogger && arguments.logger.canError();

			do{
				if ( !isIndexReindexing( arguments.indexAlias ) ) {
					if ( canWarn ) { arguments.logger.warn( "Aborting index of [#objectName#] records - rebuild not running." ); }
					_announceInterception( "onElasticSearchIndexDocsTermination", { objectName = arguments.objectName } );
					return false;
				}

				var records = getPaginatedRecordsForObject(
					  objectName = objectName
					, page       = ++page
					, pageSize   = pageSize
				);

				var recordCount = records.len();

				if ( canDebug ) { arguments.logger.debug( "Fetched #recordCount# #objectName# records ready for indexing." ); }

				_announceInterception( "preElasticSearchIndexDocs", { objectName = arguments.objectName, docs = records } );

				if ( canDebug ) { arguments.logger.debug( "preElasticSearchIndexDocs() interception announced. #records.len()# #objectName# records ready for indexing." ); }

				if ( records.len() ) {
					total += records.len();
					esApi.addDocs(
						  index   = arguments.indexName
						, type    = objConfig.documentType ?: ""
						, docs    = records
						, idField = "id"
					);
					if ( canDebug ) { arguments.logger.debug( "#records.len()# #objectName# records added to the index." ); }
				}
				_announceInterception( "postElasticSearchIndexDocs", { docs = records } );
				if ( canDebug ) { arguments.logger.debug( "postElasticSearchIndexDocs() interception announced." ); }

			} while( recordCount );

			if ( canInfo ) { arguments.logger.info( "Indexed #NumberFormat( total )# #objectName# records." ); }

			return true;
		}

		return false;
	}

	public array function getObjectDataForIndexing( required string objectName, string id, numeric maxRows=100, numeric startRow=1 ) {
		var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
		var selectDataArgs = {
			  objectName   = arguments.objectName
			, selectFields = calculateSelectFieldsForIndexing( arguments.objectName )
			, savedFilters = objConfig.indexFilters ?: []
			, maxRows      = arguments.maxRows
			, startRow     = arguments.startRow
			, groupby      = "#arguments.objectName#.id"
		};

		if ( Len( Trim( arguments.id ?: "" ) ) ) {
			selectDataArgs.filter = { "#arguments.objectName#.id" = arguments.id };
		}

		if ( _isPageType( arguments.objectName ) ) {
			selectDataArgs.extraFilters = [ { filter={ "page.trashed" = false } } ];
		}

		if ( _isAssetObject( arguments.objectName ) ) {
			selectDataArgs.extraFilters = [];
			selectDataArgs.extraFilters.append( { filter="asset_folder.is_system_folder is null or asset_folder.is_system_folder = 0" } );
			selectDataArgs.extraFilters.append( { filter="asset_folder.hidden is null or asset_folder.hidden = 0" } );
		}

		_announceInterception( "preElasticSearchGetObjectDataForIndexing", selectDataArgs );

		var records = _getPresideObjectService().selectData( argumentCollection=selectDataArgs );

		records = convertQueryToArrayOfDocs( arguments.objectName, records );

		var interceptArgs = Duplicate( arguments );
		interceptArgs.records=records
		_announceInterception( "postElasticSearchGetObjectDataForIndexing", interceptArgs );

		return records;
	}

	public array function convertQueryToArrayOfDocs( required string objectName, required query records ) {
		var docs = [];

		for( var record in arguments.records ){
			for( var key in record ){
				if ( !Len( Trim( record[ key ] ) ) ) {
					record.delete( key );
					continue;
				}

				if ( _isManyToManyField( arguments.objectName, key ) ) {
					record[ key ] = ListToArray( record[ key ] );
					continue;
				}

				record[ key ] = _renderField( arguments.objectName, key, record[ key ] );
			}
			docs.append( _convertFieldNames( objectName, record ) );
		}

		return docs;
	}

	public boolean function deleteRecord( required string objectName, required string id ) {
		var objName = arguments.objectName == "page" ? _getPageTypeForRecord( arguments.id ) : arguments.objectName;

		if ( _getConfigurationReader().isObjectSearchEnabled( objName ) ) {
			var objectConfig = _getConfigurationReader().getObjectConfiguration( objName );

			_announceInterception( "preElasticSearchDeleteRecord", arguments );

			var result = _getApiWrapper().deleteDoc(
				  index = objectConfig.indexName    ?: ""
				, type  = objectConfig.documentType ?: ""
				, id    = arguments.id
			);

			_announceInterception( "postElasticSearchDeleteRecord", arguments );

			return result;
		}

		return false;
	}

	public array function calculateSelectFieldsForIndexing( required string objectName ) {
		var args = arguments;

		return _simpleLocalCache( "calculateSelectFieldsForIndexing" & args.objectName, function(){
			var objConfig        = _getConfigurationReader().getObjectConfiguration( args.objectName );
			var configuredFields = objConfig.fields ?: [];
			var selectFields     = [];
			var poService        = _getPresideObjectService();
			var isPageType       = poService.getObjectAttribute( args.objectName, "isPageType" , false );
			var isAssetObject    = _isAssetObject( args.objectName );

			for( var field in configuredFields ){
				if ( poService.isManyToManyProperty( args.objectName, field ) ) {
					selectFields.append( "group_concat( distinct #field#.id ) as #field#" );
				} else {
					selectFields.append( args.objectName & "." & field );
				}
			}

			if ( isPageType ) {
				var pageConfiguredFields = _getConfigurationReader().getObjectConfiguration( "page" ).fields ?: [];

				for( var field in pageConfiguredFields ){
					if ( !configuredFields.find( field ) ) {
						if ( poService.isManyToManyProperty( "page", field ) ) {
							selectFields.append( "group_concat( distinct page$#field#.id ) as #field#" );
						} else {
							selectFields.append( "page." & field );
						}
					}
				}
			}

			if ( isAssetObject ) {
				var assetConfiguredFields = _getConfigurationReader().getObjectConfiguration( "asset" ).fields ?: [];

				for( var field in assetConfiguredFields ){
					if ( !configuredFields.find( field ) ) {
						selectFields.append( "asset." & field );
					}
				}

				selectFields.append( "asset_folder.internal_search_access" );
				selectFields.append( "asset_folder.is_system_folder"       );
				selectFields.append( "asset_folder.hidden"                 );
			}

			return selectFields;
		} );
	}

	public array function getPaginatedRecordsForObject( required string objectName, required numeric page, required numeric pageSize ) {
		var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
		var maxRows   = arguments.pageSize;
		var startRow  = ( ( arguments.page - 1 ) * maxRows ) + 1;

		if ( objConfig.hasOwnDataGetter ) {
			return _getPresideObjectService().getObject( arguments.objectName ).getDataForSearchEngine(
				  maxRows  = maxRows
				, startRow = startRow
			);

		} else if ( _hasSearchDataSource( arguments.objectName ) ){
			return $getColdbox().runEvent(
				  event          = objConfig.searchDataSource
				, eventArguments = { maxRows  = maxRows, startRow = startRow }
				, private        = true
				, prePostExempt  = true
			);
		}

		return getObjectDataForIndexing(
			  objectName = arguments.objectName
			, maxRows    = maxRows
			, startRow   = startRow
		);
	}

	public void function processPageTypeRecordsBeforeIndexing( required string objectName, required array records ) {
		if ( _isPageType( arguments.objectName ) ) {
			for( var i=arguments.records.len(); i > 0; i-- ){
				var hierarchicalPageData = _getHierarchalPageData( arguments.records[i] );

				if ( !hierarchicalPageData.validForSearch ) {
					arguments.records.deleteAt( i );
					continue;
				}

				arguments.records[i].access_restricted = hierarchicalPageData.accessRestricted;
			}
		}
	}

	public void function reindexChildPages( required string objectName, required string recordId, required struct updatedData  ) {
		var objName = arguments.objectName == "page" ? _getPageTypeForRecord( arguments.recordId ) : arguments.objectName;

		if ( _getConfigurationReader().isObjectSearchEnabled( objName ) && _isPageType( objName ) ) {
			var watchProps = [ "active", "embargo_date", "expiry_date", "internal_search_access", "access_restriction" ];

			for ( var prop in watchProps ) {
				if ( arguments.updatedData.keyExists( prop ) ) {
					var children = _getSiteTreeService().getDescendants( id=arguments.recordId, selectFields=[ "id", "page_type" ] );
					for( var child in children ) {
						indexRecord( child.page_type, child.id );
					}
					break;
				}
			}
		}
	}

	public struct function getStats() {
		var stats = {};
		var indexes = _getConfigurationReader().listIndexes();
		var wrapper = _getApiWrapper();

		for( var index in indexes ){
			var indexStats = "";
			var indexingStats = _getStatusDao().selectData( filter={ index_name=index } );

			try {
				indexStats = wrapper.stats( index );
			} catch( any e ) {
			}

			stats[ index ] = {
				  totalDocs                  = indexStats._all.total.docs.count          ?: ""
				, diskSize                   = indexStats._all.total.store.size_in_bytes ?: ""
				, is_indexing                = indexingStats.is_indexing                 ?: ""
				, indexing_started_at        = indexingStats.indexing_started_at         ?: ""
				, indexing_expiry            = indexingStats.indexing_expiry             ?: ""
				, last_indexing_success      = indexingStats.last_indexing_success       ?: ""
				, last_indexing_completed_at = indexingStats.last_indexing_completed_at  ?: ""
				, last_indexing_timetaken    = indexingStats.last_indexing_timetaken     ?: ""
			};
		}

		return stats;
	}

	public boolean function isIndexReindexing( required string indexName ) {
		var statusRecord = _getStatusDao().selectData(
			  selectFields = [ "indexing_expiry" ]
			, filter       = { index_name=arguments.indexName, is_indexing=true }
			, useCache     = false
		);

		if ( statusRecord.recordCount ) {
			if ( IsDate( statusRecord.indexing_expiry ) && Now() < statusRecord.indexing_expiry ) {
				return true;
			}

			terminateIndexing( arguments.indexName, false );
		}
		return false;
	}

	public void function terminateIndexing( required string indexName, boolean checkRunningFirst=true ) {
		transaction {
			if ( !checkRunningFirst || isIndexReindexing( arguments.indexName ) ) {
				setIndexingStatus(
					  indexName               = arguments.indexName
					, isIndexing              = false
					, lastIndexingSuccess     = false
					, indexingStartedAt       = ""
					, indexingExpiry          = ""
					, lastIndexingCompletedAt = ""
					, lastIndexingTimetaken   = ""
				);
			}
		}
	}

	public void function setIndexingStatus(
		  required string  indexName
		, required boolean isIndexing
		,          boolean lastIndexingSuccess
		,          any     indexingStartedAt
		,          any     indexingExpiry
		,          any     lastIndexingCompletedAt
		,          any     lastIndexingTimetaken
	) {
		var data = {
			is_indexing = arguments.isIndexing
		};
		if ( arguments.keyExists( "lastIndexingSuccess" ) ) {
			data.last_indexing_success = arguments.lastIndexingSuccess;
		}
		if ( arguments.keyExists( "indexingStartedAt" ) ) {
			data.indexing_started_at = arguments.indexingStartedAt;
		}
		if ( arguments.keyExists( "indexingExpiry" ) ) {
			data.indexing_expiry = arguments.indexingExpiry;
		}
		if ( arguments.keyExists( "lastIndexingCompletedAt" ) ) {
			data.last_indexing_completed_at = arguments.lastIndexingCompletedAt;
		}
		if ( arguments.keyExists( "lastIndexingTimetaken" ) ) {
			data.last_indexing_timetaken = arguments.lastIndexingTimetaken;
		}

		if ( !_getStatusDao().updateData( filter={ index_name=arguments.indexName }, data=data ) ) {
			data.index_name = arguments.indexName;
			_getStatusDao().insertData( data );
		}
	}

	public array function getConfiguredStopWords() {
		var stopWords = _getSystemConfigurationService().getSetting( "elasticsearch", "stopwords" );

		return ListToArray( stopWords, " ," & Chr(10) & Chr(13) );
	}

	public array function getConfiguredSynonyms() {
		var synonyms = _getSystemConfigurationService().getSetting( "elasticsearch", "synonyms" );

		return ListToArray( synonyms, Chr(10) & Chr(13) );
	}

	public void function queueRecordReindexIfNecessary(
		  required string  objectName
		, required string  recordId
		,          boolean isDeleted = false
	) {
		if ( _getConfigurationReader().isObjectSearchEnabled( arguments.objectName ) ) {
			var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );

			if ( Len( Trim( objConfig.indexName ?: "" ) ) && isIndexReindexing( objConfig.indexName ) ) {
				$getPresideObject( "elasticsearch_index_queue" ).insertData( {
					  index_name  = objConfig.indexName
					, object_name = arguments.objectName
					, record_id   = arguments.recordId
					, is_deleted  = arguments.isDeleted
				} );
			}
		}
	}

	public void function clearReindexingQueue( required string indexName ) {
		$getPresideObject( "elasticsearch_index_queue" ).deleteData( filter={ index_name = arguments.indexName } );
	}

	public query function getQueuedRecordsForReindexing( required string indexName ) {
		return $getPresideObject( "elasticsearch_index_queue" ).selectData(
			  filter       = { index_name = arguments.indexName }
			, selectFields = [ "id", "object_name", "record_id", "is_deleted" ]
		);
	}

	public void function processReindexingQueue( required string indexName, any logger ) {
		var queue    = getQueuedRecordsForReindexing( arguments.indexName );
		var queueDao = $getPresideObject( "elasticsearch_index_queue" );

		if ( queue.recordCount ) {
			var canLog  = StructKeyExists( arguments, "logger" );
			var canInfo = canLog && arguments.logger.canInfo();

			if ( canInfo ) {
				arguments.logger.info( "Processing post-reindex record queue. [#NumberFormat( queue.recordCount )#] records to re-index that were modified during the indexing process" );
			}

			for( var record in queue ) {
				if ( record.is_deleted ) {
					deleteRecord( record.object_name, record.record_id );

				} else {
					indexRecord( record.object_name, record.record_id );
				}

				queueDao.deleteData( record.id );
			}

			if ( canInfo ) {
				arguments.logger.info( "Finished processing [#NumberFormat( queue.recordCount )#] post-reindex queued records." );
			}
		}
	}

// PRIVATE HELPERS
	/**
	 * odd proxy to ensureIndexesExist() - this simply helps us to
	 * test the object and mock out this method
	 *
	 */
	private void function _checkIndexesExist() {
		try {
			return ensureIndexesExist();
		} catch ( any e ) {
			// TODO, log this
		}
	}

	private struct function _getDefaultIndexSettings() {
		var settings = {};

		settings.index = {
			  number_of_shards   = 1
			, number_of_replicas = 1
		};

		var analysis = settings.index.analysis = {};
		analysis.analyzer = {};
		analysis.analyzer.preside_analyzer = {
			  tokenizer   = "standard"
			, filter      = [ "standard", "asciifolding", "lowercase" ]
			, char_filter = [ "html_strip" ]
		};
		analysis.analyzer.preside_sortable = {
			  tokenizer   = "keyword"
			, filter      = [ "lowercase" ]
		};
		analysis.analyzer[ "default" ] = analysis.analyzer.preside_analyzer;

		analysis.filter = { preside_stemmer = { type="stemmer", language="English" } };
		var stopwords = getConfiguredStopWords();
		if ( stopwords.len() ) {
			analysis.filter.preside_stopwords = { type="stop"   , stopwords=stopwords }
			analysis.analyzer.preside_analyzer.filter.append( "preside_stopwords" );
		}
		var synonyms = getConfiguredSynonyms();
		if ( synonyms.len() ) {
			analysis.filter.preside_synonyms = { type="synonym", synonyms=synonyms }
			analysis.analyzer.preside_analyzer.filter.append( "preside_synonyms" );
		}
		analysis.analyzer.preside_analyzer.filter.append( "preside_stemmer" );

		return settings;
	}

	private struct function _getHierarchalPageData( required struct pagerecord ) {
		var cache            = request._getHierarchalPageDataCache = request._getHierarchalPageDataCache ?: {};
		var pageId           = arguments.pageRecord.id ?: "";
		var pageFields       = [ "_hierarchy_id", "_hierarchy_lineage", "active", "internal_search_access", "embargo_date", "expiry_date", "access_restriction" ];
		var page             = _getPageDao().selectData( id=pageId, selectFields=pageFields, useCache=false );
		var accessRestricted = "";
		var isActive   = function( required boolean active, required string embargo_date, required string expiry_date ) {
			return arguments.active && ( !IsDate( arguments.embargo_date ) || Now() >= arguments.embargo_date ) && ( !IsDate( arguments.expiry_date ) || Now() <= arguments.expiry_date );
		};

		if ( !page.recordCount ) {
			return { validForSearch=false };
		}

		for( var p in page ) { cache[ p._hierarchy_id ] = p; }


		if ( !isActive( page.active, page.embargo_date, page.expiry_date ) || page.internal_search_access == "block" ) {
			return { validForSearch=false };
		}

		var internalSearchAccess = page.internal_search_access;
		var lineage              = ListToArray( page._hierarchy_lineage, "/" );

		if ( page.access_restriction != "inherit" ) {
			accessRestricted = page.access_restriction != "none";
		}

		for( var i=lineage.len(); i>0; i-- ){
			if ( !cache.keyExists( lineage[i] ) ){
				var parentPage = _getPageDao().selectData( filter={ _hierarchy_id=lineage[i] }, selectFields=pageFields, useCache=false );
				for( var p in parentPage ) { cache[ p._hierarchy_id ] = p; }
			}
			cache[ lineage[ i ] ] = cache[ lineage[ i ] ] ?: {};

			if ( cache[ lineage[ i ] ].count() ) {
				var parentPage = cache[ lineage[ i ] ];

				if ( !isActive( parentPage.active, parentPage.embargo_date, parentPage.expiry_date ) ) {
					return { validForSearch=false };
				}

				if ( internalSearchAccess != "allow" && parentPage.internal_search_access == "block" ) {
					return { validForSearch=false };
				}

				if ( !IsBoolean( accessRestricted ) ) {
					if ( parentPage.access_restriction != "inherit" ) {
						accessRestricted = parentPage.access_restriction != "none";
					}
				}

				internalSearchAccess = parentPage.internal_search_access;
			}
		}

		return { validForSearch=true, accessRestricted=( IsBoolean( accessRestricted ) && accessRestricted ) };
	}

	private any function _simpleLocalCache( required string cacheKey, required any generator ) {
		var cache = _getLocalCache();

		if ( !cache.keyExists( cacheKey ) ) {
			cache[ cacheKey ] = generator();
		}

		return cache[ cacheKey ] ?: NullValue();
	}

	private boolean function _isManyToManyField( required string objectName, required string fieldName ) {
		var args = arguments;
		return _simpleLocalCache( "_isManyToManyField" & args.objectName & args.fieldName, function(){
			var objConfig = _getConfigurationReader().getObjectConfiguration( args.objectName );

			if ( objConfig.fields.find( args.fieldName ) ) {
				return _getPresideObjectService().isManyToManyProperty( args.objectName, args.fieldName );
			}

			if ( _getPresideObjectService().getObjectAttribute( args.objectName, "isPageType", false ) ) {
				return _isManyToManyField( "page", args.fieldName )
			}

			return false;
		} );
	}

	private string function _renderField( required string objectName, required string fieldName, required any value ) {
		var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );

		if ( objConfig.fields.find( arguments.fieldName ) ) {
			try {
				return _getContentRendererService().renderField(
					  object   = arguments.objectName
					, property = arguments.fieldName
					, data     = arguments.value
					, context  = [ "elasticsearchindex" ]
				);
			} catch( any e ) {
				// TODO log the error
				return arguments.value;
			}
		}

		if ( _getPresideObjectService().getObjectAttribute( arguments.objectName, "isPageType", false ) ) {
			return _renderField( "page", arguments.fieldName, arguments.value );
		}

		return arguments.value;
	}

	private any function _announceInterception( required string state, struct interceptData={} ) {
		_getInterceptorService().processState( argumentCollection=arguments );

		return interceptData.interceptorResult ?: {};
	}

	private boolean function _isPageType( required string objectName ) {
		var isPageType = _getPresideObjectService().getObjectAttribute( arguments.objectName, "isPageType", false );

		return IsBoolean( isPageType ) && isPageType;
	}

	private boolean function _isAssetObject( required string objectName ) {
		return arguments.objectName == "asset";
	}

	private string function _getPageTypeForRecord( required string pageId ) {
		var page = _getPageDao().selectData( id=arguments.pageId, selectFields=[ "page_type" ] );

		return page.page_type ?: "";
	}

	private struct function _convertFieldNames( required string objectName, required struct data ) {
		var mappings  = _getFieldNameMappings( arguments.objectName );
		var converted = arguments.data;

		for( var sourceField in mappings ) {
			if ( converted.keyExists( sourceField ) ) {
				var destinationField = mappings[ sourceField ];

				converted[ destinationField ] = converted[ sourceField ];
				converted.delete( sourceField );
			}
		}

		return converted;
	}

	private struct function _getFieldNameMappings( required string objectName ) {
		var args = arguments;

		return _simpleLocalCache( "_getFieldNameMappings" & args.objectName, function(){
			var objectConfig = _getConfigurationReader().getObjectConfiguration( args.objectName );
			var mappings     = {};

			for( var field in objectConfig.fields ){
				var fieldConfig = _getConfigurationReader().getFieldConfiguration( args.objectName, field );
				if ( fieldConfig.fieldName != field ) {
					mappings[ field ] = fieldConfig.fieldName;
				}
			}

			return mappings;
		} );
	}

	private struct function _getCommonPropertyMappings() {
		return {
			access_restricted = { type="boolean" }
		};
	}

	private boolean function _objectIsUsingSiteTenancy( required string objectName ) {
		if ( !_getPresideObjectService().objectExists( arguments.objectName ) ) {
			return false;
		}

		var usingSiteTenancy = _getPresideObjectService().getObjectAttribute( arguments.objectName, "siteFiltered", false );

		return IsBoolean( usingSiteTenancy ) && usingSiteTenancy;
	}

	private boolean function _hasSearchDataSource( required string objectName ){
		var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );

		if ( len( objConfig.searchDataSource ?: "" ) ) {
			if ( !$getColdbox().handlerExists( objConfig.searchDataSource ) ){
				throw( type="ElasticSearchEngine.indexing.searchDataSource.notFound", message="Defined searchDataSource method '#objConfig.searchDataSource#' for object '#arguments.objectName#' was not found." );
			}
			return true;
		}
		return false;
	}

	private void function _deleteIndex( required string indexName ) {
		try {
			_getApiWrapper().deleteIndex( arguments.indexName );
		} catch( "cfelasticsearch.IndexMissingException" e ) {
			// ignore missing index exceptions - consider deleted
		}
	}

	private void function _createAlias( required string index, required string alias ) {
		try {
			_getApiWrapper().addAlias( argumentCollection=arguments  );
		} catch( "cfelasticsearch.InvalidAliasNameException" e ) {
			_deleteIndex( arguments.alias );
			sleep( 5000 ); // avoid delayed delete subsequently deleting our alias!
			_getApiWrapper().addAlias( argumentCollection=arguments );
		}
	}

// GETTERS AND SETTERS
	private any function _getApiWrapper() {
		return _apiWrapper.get();
	}
	private void function _setApiWrapper( required any apiWrapper ) {
		_apiWrapper = arguments.apiWrapper;
	}

	private any function _getConfigurationReader() {
		return _configurationReader.get();
	}
	private void function _setConfigurationReader( required any configurationReader ) {
		_configurationReader = arguments.configurationReader;
	}

	private any function _getPresideObjectService() {
		return _presideObjectService.get();
	}
	private void function _setPresideObjectService( required any presideObjectService ) {
		_presideObjectService = arguments.presideObjectService;
	}

	private struct function _getLocalCache() {
		return _localCache;
	}
	private void function _setLocalCache( required struct localCache ) {
		_localCache = arguments.localCache;
	}

	private any function _getContentRendererService() {
		return _contentRendererService.get();
	}
	private void function _setContentRendererService( required any contentRendererService ) {
		_contentRendererService = arguments.contentRendererService;
	}

	private any function _getInterceptorService() {
		return _interceptorService;
	}
	private void function _setInterceptorService( required any interceptorService ) {
		_interceptorService = arguments.interceptorService;
	}

	private any function _getPageDao() {
		return _pageDao;
	}
	private void function _setPageDao( required any pageDao ) {
		_pageDao = arguments.pageDao;
	}

	private any function _getSiteService() {
		return _siteService.get();
	}
	private void function _setSiteService( required any siteService ) {
		_siteService = arguments.siteService;
	}

	private any function _getSiteTreeService() {
		return _siteTreeService.get();
	}
	private void function _setSiteTreeService( required any siteTreeService ) {
		_siteTreeService = arguments.siteTreeService;
	}

	private any function _getResultsFactory() {
		return _resultsFactory.get();
	}
	private void function _setResultsFactory( required any resultsFactory ) {
		_resultsFactory = arguments.resultsFactory;
	}

	private any function _getStatusDao() {
		return _statusDao;
	}
	private void function _setStatusDao( required any statusDao ) {
		_statusDao = arguments.statusDao;
	}

	private any function _getSystemConfigurationService() {
		return _systemConfigurationService.get();
	}
	private void function _setSystemConfigurationService( required any systemConfigurationService ) {
		_systemConfigurationService = arguments.systemConfigurationService;
	}
}