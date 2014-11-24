component output=false singleton=true {

// CONSTRUCTOR
	/**
	 * @apiWrapper.inject             elasticSearchApiWrapper
	 * @configurationReader.inject    elasticSearchPresideObjectConfigurationReader
	 * @presideObjectService.inject   presideObjectService
	 * @contentRendererService.inject contentRendererService
	 * @interceptorService.inject     interceptorService
	 */
	public any function init( required any apiWrapper, required any configurationReader, required any presideObjectService, required any contentRendererService, required any interceptorService ) output=false {
		_setLocalCache( {} );
		_setApiWrapper( arguments.apiWrapper );
		_setConfigurationReader( arguments.configurationReader );
		_setPresideObjectService( arguments.presideObjectService );
		_setContentRendererService( arguments.contentRendererService );
		_setInterceptorService( arguments.interceptorService );

		_checkIndexesExist();

		return this;
	}

// PUBLIC API METHODS
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
		_announceInterception( "preElasticSearchRebuildIndex", { alias = arguments.indexName } );

		var uniqueIndexName = createIndex( arguments.indexName );
		var objects         = _getConfigurationReader().listObjectsForIndex( arguments.indexName );

		for( var objectName in objects ){
			indexAllRecords( objectName, uniqueIndexName );
		}

		_getApiWrapper().addAlias( index=uniqueIndexName, alias=arguments.indexName );

		cleanupOldIndexes( keepIndex=uniqueIndexName, alias=arguments.indexName );

		_announceInterception( "postElasticSearchRebuildIndex", { alias = arguments.indexName, indexName = uniqueIndexName } );

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
		var objectConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
		var object       = _getPresideObjectService().getObject( arguments.objectName );
		var doc          = "";

		if ( IsBoolean( objectConfig.hasOwnDataGetter ?: "" ) && objectConfig.hasOwnDataGetter ) {
			doc = object.getDataForSearchEngine( arguments.id );
		} else {
			doc = getObjectDataForIndexing( arguments.objectName, arguments.id );
		}

		_announceInterception( "preElasticSearchIndexDoc", { doc = doc[1] ?: {} } );

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

	public boolean function indexAllRecords( required string objectName, required string indexName ) output=false {
		var objConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );
		var esApi     = _getApiWrapper();
		var records   = [];
		var page      = 0;
		var pageSize  = 100;

		do{
			var records = getPaginatedRecordsForObject(
				  objectName = objectName
				, page       = ++page
				, pageSize   = pageSize
			);
			_announceInterception( "preElasticSearchIndexDocs", { docs = records } );
			if ( records.len() ) {
				esApi.addDocs(
					  index   = arguments.indexName
					, type    = objConfig.documentType ?: ""
					, docs    = records
					, idField = "id"
				);
			}
			_announceInterception( "postElasticSearchIndexDocs", { docs = records } );
		} while( records.len() );

		return true;
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
		var objectConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );

		_announceInterception( "preElasticSearchDeleteRecord", arguments );

		var result = _getApiWrapper().deleteDoc(
			  index = objectConfig.indexName    ?: ""
			, type  = objectConfig.documentType ?: ""
			, id    = arguments.id
		);

		_announceInterception( "postElasticSearchDeleteRecord", arguments );

		return result;
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

	public array function getConfiguredStopWords() output=false {
		return []; // todo
	}

	public array function getConfiguredSynonyms() output=false {
		return []; // todo
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
				return _getContentRendererService().renderField(
					  object   = arguments.objectName
					, property = arguments.fieldName
					, data     = arguments.value
					, context  = [ "elasticsearchindex" ]
				);
			try {
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
}