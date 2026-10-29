component {
	public void function configure( required struct config ) {
		var conf     = arguments.config;
		var settings = conf.settings ?: {};

		_setupEnvVars( settings );
		_setupAdminUi( settings );
		_setupGlobalFilters( settings );
		_setupInterceptors( conf );
		_setupElasticSearchConfig( settings );
	}

	private void function _setupEnvVars( settings ) {
		settings.env[ "elasticsearch.default_index"               ] = settings.env[ "elasticsearch.default_index"               ] ?: ( settings.env.ELASTICSEARCH_DEFAULT_INDEX               ?: _getDefaultIndexName()  );
		settings.env[ "elasticsearch.endpoint"                    ] = settings.env[ "elasticsearch.endpoint"                    ] ?: ( settings.env.ELASTICSEARCH_ENDPOINT                    ?: "http://localhost:9200" );
		settings.env[ "elasticsearch.charset"                     ] = settings.env[ "elasticsearch.charset"                     ] ?: ( settings.env.ELASTICSEARCH_CHARSET                     ?: "utf-8"                 );
		settings.env[ "elasticsearch.api_call_timeout"            ] = settings.env[ "elasticsearch.api_call_timeout"            ] ?: ( settings.env.ELASTICSEARCH_API_CALL_TIMEOUT            ?: 5                       );
		settings.env[ "elasticsearch.retry_attempts"              ] = settings.env[ "elasticsearch.retry_attempts"              ] ?: ( settings.env.ELASTICSEARCH_RETRY_ATTEMPTS              ?: 1                       );
		settings.env[ "elasticsearch.reindex_child_pages_on_edit" ] = settings.env[ "elasticsearch.reindex_child_pages_on_edit" ] ?: ( settings.env.ELASTICSEARCH_REINDEX_CHILD_PAGES_ON_EDIT ?: true                    );
		settings.env[ "elasticsearch.skip_single_record_indexing" ] = settings.env[ "elasticsearch.skip_single_record_indexing" ] ?: ( settings.env.ELASTICSEARCH_SKIP_SINGLE_RECORD_INDEXING ?: false                   );
	}

	private void function _setupAdminUi( settings ) {
		ArrayAppend( settings.adminConfigurationMenuItems, "elasticsearchControl" );
	}

	private void function _setupGlobalFilters( settings ) {
		settings.filters.elasticSearchPageFilter = {
			filter = "page.internal_search_access is null or page.internal_search_access != 'block'"
		};

		settings.filters.elasticSearchAssetFilter = {
			filter = "asset_folder.internal_search_access = 'allow' and asset.trashed_path is null"
		};
	}

	private void function _setupInterceptors( conf ) {
		ArrayPrepend( conf.interceptors,
			{ class="app.extensions.preside-ext-elasticsearch.interceptors.PresideExtensionElasticSearchEngineInterceptor", properties={} }
		);

		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "preElasticSearchCreateIndex"               );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchCreateIndex"              );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "preElasticSearchRebuildIndex"              );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchRebuildIndex"             );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "onElasticSearchRebuildIndexFailure"        );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchGetIndexSettings"         );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "preElasticSearchIndexDoc"                  );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchIndexDoc"                 );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "preElasticSearchIndexDocs"                 );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchIndexDocs"                );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "onElasticSearchIndexDocsTermination"       );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "preElasticSearchGetObjectDataForIndexing"  );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchGetObjectDataForIndexing" );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "preElasticSearchDeleteRecord"              );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchDeleteRecord"             );
		ArrayAppend( conf.interceptorSettings.customInterceptionPoints, "postElasticSearchGenerateDsl"              );
	}

	private void function _setupElasticSearchConfig( settings ) {
		settings.elasticSearchConfig = settings.elasticSearchConfig ?: {};

		var esConfig = settings.elasticSearchConfig;

		// version of the ElasticSearch engine being used, e.g. "1.7" or "6.3". Determines
		// which dialect is used (see services/ElasticSearchDialectFactory.cfc)
		esConfig.engineVersion       = esConfig.engineVersion       ?: ( settings.env[ "elasticsearch.version" ] ?: ( settings.env.ELASTICSEARCH_VERSION ?: "6.3" ) );
		esConfig.dialects            = esConfig.dialects            ?: {};
		esConfig.dialects[ "1.7" ]   = esConfig.dialects[ "1.7" ]   ?: "Es1Dialect";
		esConfig.dialects[ "6.3" ]   = esConfig.dialects[ "6.3" ]   ?: "Es6Dialect";

		// empty values here mean "use the default" (see ElasticSearchEngine)
		esConfig.indexPageSize       = esConfig.indexPageSize       ?: "";
		esConfig.searchPageSize      = esConfig.searchPageSize      ?: "";
		esConfig.groupByRecordIdOnly = esConfig.groupByRecordIdOnly ?: false;
		esConfig.indexExpiryUnit     = esConfig.indexExpiryUnit     ?: "d";
		esConfig.indexExpiryMeasure  = esConfig.indexExpiryMeasure  ?: 1;
	}

	private string function _getDefaultIndexName() {
		var appSettings = GetApplicationMetadata();

		return ReReplace( appSettings.name ?: CreateUUId(), "\W+", "_", "all" );
	}
}