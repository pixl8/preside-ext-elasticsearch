component output=false singleton=true {

// CONSTRUCTOR
	/**
	 * @apiWrapper.inject          ElasticSearchApiWrapper
	 * @configurationReader.inject ElasticSearchPresideObjectConfigurationReader
	 */
	public any function init( required any apiWrapper, required any configurationReader ) output=false {
		_setApiWrapper( arguments.apiWrapper );
		_setConfigurationReader( arguments.configurationReader );

		_checkIndexesExist();

		return this;
	}

// PUBLIC API METHODS
	public void function ensureIndexesExist() output=false {
		var indexes    = _getConfigurationReader().listIndexes();
		var apiWrapper = _getApiWrapper();

		for( var ix in indexes ){
			if ( !apiWrapper.getAliasIndexes( ix ).len() ) {
				createIndex( ix );
			}
		}
		return;
	}

	public void function createIndex( required string indexName ) output=false {
		var settings   = getIndexSettings( arguments.indexName );
		var uniqueId   = createUniqueIndexName( arguments.indexName );
		var apiWrapper = _getApiWrapper();

		apiWrapper.createIndex( index=uniqueId, settings=settings );
		apiWrapper.addAlias( index=uniqueId, alias=arguments.indexName );
	}

	public struct function getIndexSettings( required string indexName ) output=false {
		return {
			  settings = _getDefaultIndexSettings()
			, mappings = getIndexMappings( arguments.indexName )
		};
	}

	public struct function getIndexMappings( required string indexName ) output=false {
		var mappings      = {};
		var configWrapper = _getConfigurationReader();
		var docTypes      = configWrapper.listDocumentTypes( arguments.indexName );

		for( var docType in docTypes ){
			var fields = configWrapper.getFields( arguments.indexName, docType );

			mappings[ docType ] = { properties={} };
			for( var field in fields ){
				mappings[ docType ].properties[ field ] = getElasticSearchMappingFromFieldConfiguration( argumentCollection=fields[ field ] );
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

	public boolean function deleteRecord( required string objectName, required string id ) output=false {
		var objectConfig = _getConfigurationReader().getObjectConfiguration( arguments.objectName );

		return _getApiWrapper().deleteDoc(
			  index = objectConfig.indexName    ?: ""
			, type  = objectConfig.documentType ?: ""
			, id    = arguments.id
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

		analysis.filter = {
			  preside_stemmer   = { type="stemmer", language="English"                 }
			, preside_stopwords = { type="stop"   , stopwords=getConfiguredStopWords() }
			, preside_synonyms  = { type="synonym", synonyms=getConfiguredSynonyms()   }
		};
		analysis.analyzer = {};

		analysis.analyzer.preside_analyzer = {
			  tokenizer   = "standard"
			, filter      = [ "standard", "asciifolding", "lowercase", "preside_stopwords", "preside_synonyms", "preside_stemmer" ]
			, char_filter = [ "html_strip" ]
		};
		analysis.analyzer.preside_sortable = {
			  tokenizer   = "keyword"
			, filter      = [ "lowercase" ]
		};
		analysis.analyzer[ "default" ] = analysis.analyzer.preside_analyzer;

		return settings;
	}

	public array function getConfiguredStopWords() output=false {
		return []; // todo
	}

	public array function getConfiguredSynonyms() output=false {
		return []; // todo
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

}