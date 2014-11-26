component output=false singleton=true {

// CONSTRUCTOR
	/**
	 * @apiWrapper.inject                 elasticSearchApiWrapper
	 * @configurationReader.inject        elasticSearchPresideObjectConfigurationReader
	 * @presideObjectService.inject       presideObjectService
	 * @contentRendererService.inject     contentRendererService
	 * @interceptorService.inject         coldbox:InterceptorService
	 * @pageDao.inject                    presidecms:object:page
	 * @siteTreeService.inject            siteTreeService
	 * @resultsFactory.inject             elasticSearchResultsFactory
	 * @statusDao.inject                  presidecms:object:elasticsearch_indexing_status
	 * @systemConfigurationService.inject systemConfigurationService
	 */
	public any function init( required any apiWrapper, required any configurationReader, required any presideObjectService, required any contentRendererService, required any interceptorService, required any pageDao, required any siteTreeService, required any resultsFactory, required any statusDao, required any systemConfigurationService ) output=false {
		_setLocalCache( {} );
		_setApiWrapper( arguments.apiWrapper );
		_setConfigurationReader( arguments.configurationReader );
		_setPresideObjectService( arguments.presideObjectService );
		_setContentRendererService( arguments.contentRendererService );
		_setInterceptorService( arguments.interceptorService );
		_setPageDao( arguments.pageDao );
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
		, struct  fullDsl
	) output=false {
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

	public void function ensureIndexesExist() output=false {
		var indexes    = _getConfigurationReader().listIndexes();
		var apiWrapper = _getApiWrapper();

		for( var ix in indexes ){
			if ( !apiWrapper.getAliasIndexes( ix ).len() ) {
				var ux = createIndex( ix );
				apiWrapper.addAlias( index=ux, alias=ix );
				rebuildIndex( ix );
			}
		}
		return;
	}

	public string function createIndex( required string indexName ) output=false {
		var settings   = getIndexSettings( arguments.indexName );
		var uniqueId   = createUniqueIndexName( arguments.indexName );
		var apiWrapper = _getApiWrapper();

		_announceInterception( "preElasticSearchCreateIndex", { indexName = uniqueId, settings  = settings } );

		apiWrapper.createIndex( index=uniqueId, settings=settings );

		_announceInterception( "postElasticSearchCreateIndex", { indexName = uniqueId, settings  = settings } );

		return uniqueId;
	}

	public void function rebuildIndex( required string indexName ) output=false {
		var start = getTickCount();

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

		try {

			var uniqueIndexName = createIndex( arguments.indexName );
			var objects         = _getConfigurationReader().listObjectsForIndex( arguments.indexName );
			var indexingSuccess = true;

			for( var objectName in objects ){
				indexingSuccess = indexAllRecords( objectName, uniqueIndexName, indexName );
				if ( !indexingSuccess ) {
					break;
				}
			}


			if ( indexingSuccess ) {
				_getApiWrapper().addAlias( index=uniqueIndexName, alias=arguments.indexName );

				setIndexingStatus(
					  indexName               = arguments.indexName
					, isIndexing              = false
					, indexingExpiry          = ""
					, lastIndexingSuccess     = true
					, lastIndexingCompletedAt = Now()
					, lastIndexingTimetaken   = GetTickCount() - start
				);


				cleanupOldIndexes( keepIndex=uniqueIndexName, alias=arguments.indexName );

				_announceInterception( "postElasticSearchRebuildIndex", { alias = arguments.indexName, indexName = uniqueIndexName } );
			} else {
				terminateIndexing( arguments.indexName );
				_announceInterception( "onElasticSearchRebuildIndexFailure", { alias = arguments.indexName, indexName = uniqueIndexName } );
				_getApiWrapper().deleteIndex( uniqueIndexName );
			}

		} catch ( any e ) {
			try {
				terminateIndexing( arguments.indexName );
				_announceInterception( "onElasticSearchRebuildIndexFailure", { alias = arguments.indexName, indexName = uniqueIndexName, error = e } );
				_getApiWrapper().deleteIndex( uniqueIndexName );
			} catch ( any e ) {}

			rethrow;
		}

		return;
	}

	public void function cleanupOldIndexes( required string keepIndex, required string alias ) output=false {
		var indexes = _getApiWrapper().getAliasIndexes( arguments.alias );

		for( var indexName in indexes ){
			if ( indexName != arguments.keepIndex ) {
				_getApiWrapper().deleteIndex( indexName );
			}
		}
	}

	public struct function getIndexSettings( required string indexName ) output=false {
		var settings = {
			  settings = _getDefaultIndexSettings()
			, mappings = getIndexMappings( arguments.indexName )
		};

		_announceInterception( "postElasticSearchGetIndexSettings", { settings = settings } );

		return settings;
	}

	public struct function getIndexMappings( required string indexName ) output=false {
		var mappings      = {};
		var configWrapper = _getConfigurationReader();
		var docTypes      = configWrapper.listDocumentTypes( arguments.indexName );

		for( var docType in docTypes ){
			var fields = configWrapper.getFields( arguments.indexName, docType );
			mappings[ docType ] = { properties={} };
			for( var field in fields ){
				mappings[ docType ].properties[ field ] = getElasticSearchMappingFromFieldConfiguration( argumentCollection=fields[ field ], name=field );
			}
		}

		return mappings;
	}

	public struct function getElasticSearchMappingFromFieldConfiguration( required string name, required string type, boolean searchable=false, boolean sortable=false, string analyzer="", boolean ignoreMalformedDates=false ) output=false {
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

	public string function createUniqueIndexName( required string sourceIndexName ) output=false {
		return sourceIndexName & "_" & LCase( CreateUUId() );
	}

	public boolean function indexRecord( required string objectName, required string id ) output=false {
		var objName = arguments.objectName == "page" ? _getPageTypeForRecord( arguments.id ) : arguments.objectName;

		if ( _getConfigurationReader().isObjectSearchEnabled( objName ) ) {
			var objectConfig = _getConfigurationReader().getObjectConfiguration( objName );
			var object       = _getPresideObjectService().getObject( objName );
			var doc          = "";

			if ( IsBoolean( objectConfig.hasOwnDataGetter ?: "" ) && objectConfig.hasOwnDataGetter ) {
				doc = object.getDataForSearchEngine( arguments.id );
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

	public boolean function indexAllRecords( required string objectName, required string indexName, required string indexAlias ) output=false {
		if ( _getConfigurationReader().isObjectSearchEnabled( arguments.objectName ) ) {
			var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
			var esApi     = _getApiWrapper();
			var records   = [];
			var page      = 0;
			var pageSize  = 100;

			do{
				if ( !isIndexReindexing( arguments.indexAlias ) ) {
					_announceInterception( "onElasticSearchIndexDocsTermination", { objectName = arguments.objectName } );
					return false;
				}

				var records = getPaginatedRecordsForObject(
					  objectName = objectName
					, page       = ++page
					, pageSize   = pageSize
				);
				var recordCount = records.len();

				_announceInterception( "preElasticSearchIndexDocs", { objectName = arguments.objectName, docs = records } );

				if ( records.len() ) {
					esApi.addDocs(
						  index   = arguments.indexName
						, type    = objConfig.documentType ?: ""
						, docs    = records
						, idField = "id"
					);
				}
				_announceInterception( "postElasticSearchIndexDocs", { docs = records } );

			} while( recordCount );

			return true;
		}

		return false;
	}

	public array function getObjectDataForIndexing( required string objectName, string id, numeric maxRows=100, numeric startRow=1 ) output=false {
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

		_announceInterception( "preElasticSearchGetObjectDataForIndexing", selectDataArgs );

		var records = _getPresideObjectService().selectData( argumentCollection=selectDataArgs );

		_announceInterception( "postElasticSearchGetObjectDataForIndexing", { records=records } );

		return convertQueryToArrayOfDocs( arguments.objectName, records );
	}

	public array function convertQueryToArrayOfDocs( required string objectName, required query records ) output=false {
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
			docs.append( record );
		}

		return docs;
	}

	public boolean function deleteRecord( required string objectName, required string id ) output=false {
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

	public array function calculateSelectFieldsForIndexing( required string objectName ) output=false {
		var args = arguments;

		return _simpleLocalCache( "calculateSelectFieldsForIndexing" & args.objectName, function(){
			var objConfig        = _getConfigurationReader().getObjectConfiguration( args.objectName );
			var configuredFields = objConfig.fields ?: [];
			var selectFields     = [];
			var poService        = _getPresideObjectService();
			var isPageType       = poService.getObjectAttribute( args.objectName, "isPageType", false );

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

			return selectFields;
		} );
	}

	public array function getPaginatedRecordsForObject( required string objectName, required numeric page, required numeric pageSize ) output=false {
		var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
		var maxRows   = arguments.pageSize;
		var startRow  = ( ( arguments.page - 1 ) * maxRows ) + 1;

		if ( objConfig.hasOwnDataGetter ) {
			return _getPresideObjectService().getObject( arguments.objectName ).getDataForSearchEngine(
				  maxRows  = maxRows
				, startRow = startRow
			);
		}

		return getObjectDataForIndexing(
			  objectName = arguments.objectName
			, maxRows    = maxRows
			, startRow   = startRow
		);
	}

	public void function filterPageTypeRecords( required string objectName, required array records ) output=false {
		if ( _isPageType( arguments.objectName ) ) {
			for( var i=arguments.records.len(); i > 0; i-- ){
				if ( !_isPageRecordValidForSearch( arguments.records[i] ) ) {
					arguments.records.deleteAt( i );
				}
			}
		}
	}

	public void function reindexChildPages( required string objectName, required string recordId, required struct updatedData  ) output=false {
		var objName = arguments.objectName == "page" ? _getPageTypeForRecord( arguments.recordId ) : arguments.objectName;

		if ( _getConfigurationReader().isObjectSearchEnabled( objName ) && _isPageType( objName ) ) {
			var watchProps = [ "active", "embargo_date", "expiry_date", "internal_search_access" ];

			for ( var prop in watchProps ) {
				if ( arguments.updatedData.keyExists( prop ) ) {
					var children = _getSiteTreeService().getDescendants( id=arguments.recordId, selectFields=[ "id" ] );
					for( var child in children ) {
						indexRecord( objName, child.id );
					}
				}
			}
		}
	}

	public struct function getStats() output=false {
		var stats = {};
		var indexes = _getConfigurationReader().listIndexes();
		var wrapper = _getApiWrapper();

		for( var index in indexes ){
			var indexStats = "";
			var indexingStats = _getStatusDao().selectData( filter={ index_name=index } );

			try {
				indexStats = wrapper.stats( index );
			} catch( "cfelasticsearch.IndexMissingException" e ) {
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

	public boolean function isIndexReindexing( required string indexName ) output=false {
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

	public void function terminateIndexing( required string indexName, boolean checkRunningFirst=true ) output=false {
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
	) output=false {
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

	public array function getConfiguredStopWords() output=false {
		var stopWords = _getSystemConfigurationService().getSetting( "elasticsearch", "stopwords" );

		return ListToArray( stopWords, " ," & Chr(10) & Chr(13) );
	}

	public array function getConfiguredSynonyms() output=false {
		var synonyms = _getSystemConfigurationService().getSetting( "elasticsearch", "synonyms" );

		return ListToArray( synonyms, Chr(10) & Chr(13) );
	}

// PRIVATE HELPERS
	/**
	 * odd proxy to ensureIndexesExist() - this simply helps us to
	 * test the object and mock out this method
	 *
	 */
	private void function _checkIndexesExist() output=false {
		return ensureIndexesExist();
	}

	private struct function _getDefaultIndexSettings() output=false {
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

	private boolean function _isPageRecordValidForSearch( required struct pagerecord ) output=false {
		var cache      = request._isPageRecordValidForSearchCache = request._isPageRecordValidForSearchCache ?: {};
		var pageId     = arguments.pageRecord.id ?: "";
		var pageFields = [ "_hierarchy_id", "_hierarchy_lineage", "active", "internal_search_access", "embargo_date", "expiry_date" ];
		var page       = _getPageDao().selectData( id=pageId, selectFields=pageFields );
		var isActive   = function( required boolean active, required string embargo_date, required string expiry_date ) {
			return arguments.active && ( !IsDate( arguments.embargo_date ) || Now() >= arguments.embargo_date ) && ( !IsDate( arguments.expiry_date ) || Now() <= arguments.expiry_date );
		};

		if ( !page.recordCount ) {
			return false;
		}

		for( var p in page ) { cache[ p._hierarchy_id ] = p; }

		if ( !isActive( page.active, page.embargo_date, page.expiry_date ) || page.internal_search_access == "block" ) {
			return false;
		}

		var internalSearchAccess = page.internal_search_access;
		var lineage              = ListToArray( page._hierarchy_lineage, "/" );

		for( var i=lineage.len(); i>0; i-- ){
			if ( !cache.keyExists( lineage[i] ) ){
				var parentPage = _getPageDao().selectData( filter={ _hierarchy_id=lineage[i] }, selectFields=pageFields );
				for( var p in parentPage ) { cache[ p._hierarchy_id ] = p; }
			}

			var parentPage = cache[ lineage[ i ] ];

			if ( !isActive( parentPage.active, parentPage.embargo_date, parentPage.expiry_date ) ) {
				return false;
			}

			if ( internalSearchAccess != "allow" && parentPage.internal_search_access == "block" ) {
				return false;
			}

			internalSearchAccess = parentPage.internal_search_access;
		}

		return true;
	}

	private any function _simpleLocalCache( required string cacheKey, required any generator ) output=false {
		var cache = _getLocalCache();

		if ( !cache.keyExists( cacheKey ) ) {
			cache[ cacheKey ] = generator();
		}

		return cache[ cacheKey ] ?: NullValue();
	}

	private boolean function _isManyToManyField( required string objectName, required string fieldName ) output=false {
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

	private string function _renderField( required string objectName, required string fieldName, required any value ) output=false {
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

	private any function _announceInterception( required string state, struct interceptData={} ) output=false {
		_getInterceptorService().processState( argumentCollection=arguments );

		return interceptData.interceptorResult ?: {};
	}

	private boolean function _isPageType( required string objectName ) output=false {
		var isPageType = _getPresideObjectService().getObjectAttribute( arguments.objectName, "isPageType", false );

		return IsBoolean( isPageType ) && isPageType;
	}

	private string function _getPageTypeForRecord( required string pageId ) output=false {
		var page = _getPageDao().selectData( id=arguments.pageId, selectFields=[ "page_type" ] );

		return page.page_type ?: "";
	}

// GETTERS AND SETTERS
	private any function _getApiWrapper() output=false {
		return _apiWrapper;
	}
	private void function _setApiWrapper( required any apiWrapper ) output=false {
		_apiWrapper = arguments.apiWrapper;
	}

	private any function _getConfigurationReader() output=false {
		return _configurationReader;
	}
	private void function _setConfigurationReader( required any configurationReader ) output=false {
		_configurationReader = arguments.configurationReader;
	}

	private any function _getPresideObjectService() output=false {
		return _presideObjectService;
	}
	private void function _setPresideObjectService( required any presideObjectService ) output=false {
		_presideObjectService = arguments.presideObjectService;
	}

	private struct function _getLocalCache() output=false {
		return _localCache;
	}
	private void function _setLocalCache( required struct localCache ) output=false {
		_localCache = arguments.localCache;
	}

	private any function _getContentRendererService() output=false {
		return _contentRendererService;
	}
	private void function _setContentRendererService( required any contentRendererService ) output=false {
		_contentRendererService = arguments.contentRendererService;
	}

	private any function _getInterceptorService() output=false {
		return _interceptorService;
	}
	private void function _setInterceptorService( required any interceptorService ) output=false {
		_interceptorService = arguments.interceptorService;
	}

	private any function _getPageDao() output=false {
		return _pageDao;
	}
	private void function _setPageDao( required any pageDao ) output=false {
		_pageDao = arguments.pageDao;
	}

	private any function _getSiteTreeService() output=false {
		return _siteTreeService;
	}
	private void function _setSiteTreeService( required any siteTreeService ) output=false {
		_siteTreeService = arguments.siteTreeService;
	}

	private any function _getResultsFactory() output=false {
		return _resultsFactory;
	}
	private void function _setResultsFactory( required any resultsFactory ) output=false {
		_resultsFactory = arguments.resultsFactory;
	}

	private any function _getStatusDao() output=false {
		return _statusDao;
	}
	private void function _setStatusDao( required any statusDao ) output=false {
		_statusDao = arguments.statusDao;
	}

	private any function _getSystemConfigurationService() output=false {
		return _systemConfigurationService;
	}
	private void function _setSystemConfigurationService( required any systemConfigurationService ) output=false {
		_systemConfigurationService = arguments.systemConfigurationService;
	}
}