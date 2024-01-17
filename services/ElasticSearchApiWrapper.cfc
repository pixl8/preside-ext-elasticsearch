/**
 * @singleton
 * @presideservice
 *
 */
component {

// CONSTRUCTOR
	/**
	 * @systemConfigurationService.inject systemConfigurationService
	 *
	 */
	public any function init(
		required any  systemConfigurationService
	) {
		_setSystemConfigurationService( arguments.systemConfigurationService );

		return this;
	}

	public struct function ping() {
		return _call( uri="/", method="GET" );
	}

	public struct function stats( string index="" ) {
		return _call(
			  uri    = _getIndexAndTypeUri( args=arguments, typeAllowed=false ) & "/_stats"
			, method = "GET"
		);
	}

	public struct function createIndex( required string index, struct settings ) {
		var args = StructNew();
		args.uri =_getIndexAndTypeUri( args=arguments, typeAllowed=false );
		args.method = "PUT";

		if ( StructKeyExists( arguments, 'settings' ) ) {
			args.body = SerializeJson( arguments.settings );
		}

		return _call( argumentCollection = args );
	}

	public struct function deleteIndex( required string index ) {
		return _call(
			  uri    = _getIndexAndTypeUri( args=arguments, typeAllowed=false )
			, method = "DELETE"
		);
	}

	public struct function addAlias( required string index, required string alias ) {
		var body = StructNew();
		var add  = StructNew();

		body.actions = ArrayNew(1);

		add.add = StructNew();
		add.add.index = _safeIndexName( arguments.index );
		add.add.alias = _safeIndexName( arguments.alias );

		ArrayAppend( body.actions, add );

		return _call(
			  uri    = "/_aliases"
			, method = "POST"
			, body   = SerializeJson( body )
		);
	}

	public struct function removeAlias( required string index, required string alias ) {
		var body   = StructNew();
		var remove = StructNew();

		body.actions = ArrayNew(1);

		remove.remove = StructNew();
		remove.remove.index = _safeIndexName( arguments.index );
		remove.remove.alias = arguments.alias;

		ArrayAppend( body.actions, remove );

		return _call(
			  uri    = "/_aliases"
			, method = "POST"
			, body   = SerializeJson( body )
		);
	}

	public array function getAliasIndexes( required string alias ) {
		var callResult    = _call( uri = "/_aliases", method = "GET" );
		var indexes       = [];

		for( var indexName in callResult ) {
			var indexHasAlias = callResult[ indexName ].keyExists( 'aliases' ) and callResult[ indexName ].aliases.keyExists( arguments.alias );

			if ( indexHasAlias ) {
				indexes.append( indexName );
			}
		}

		return indexes;
	}

	public array function getIndexes( any filter ) {
		var callResult    = _call( uri = "/_aliases", method = "GET" );
		var indexes       = [];

		for( var indexName in callResult ) {
			if ( arguments.keyExists( "filter" ) ) {
				if ( arguments.filter( indexName ) ) {
					indexes.append( indexName );
				}
			} else {
				indexes.append( indexName );
			}
		}

		return indexes;
	}

	public struct function addDoc( required string index, required string type, required struct doc, string id ) {
		var uri    = _getIndexAndTypeUri( args=arguments );
		var method = "POST";

		if ( StructKeyExists( arguments, 'id' ) and Len( Trim( id ) ) ) {
			uri    = uri & "/#id#";
			method = "PUT";
		}

		return _call(
			  uri    = uri
			, method = method
			, body   = SerializeJson( doc )
		);
	}

	public any function addDocs( required string index, required string type, required array docs, string idField="id" ) {
		var uri  = _getIndexAndTypeUri( args=arguments ) & "/_bulk";
		var body = CreateObject( "java", "java.lang.StringBuffer" );
		var i    = 0;

		if ( not ArrayLen( docs ) ){
			_throw(
				  type    = "cfelasticsearch.addDocs.noDocs"
				, message = "No documents to index."
				, detail  = "An empty array was passed to the addDocs() method."
			);
		}

		for( i=1; i LTE ArrayLen( docs ); i=i+1 ){
			if ( not IsStruct( docs[i] ) ) {
				_throw(
					  type    = "cfelasticsearch.addDocs.badDoc"
					, message = "The document at index #i# was not of type struct. All docs passed to the addDocs() method must be of type Struct."
				);
			}

			if ( StructKeyExists( docs[i], idField ) ) {
				body.append( '{"index":{"_id":"#docs[i][idField]#"}}' & chr(10) );
			} else {
				body.append( '{"index":{}}' & chr(10) );
			}
			docs[i].type = arguments.type;
			body.append( SerializeJson( docs[i] ) & chr(10) );
		}

		return _call(
			  uri    = uri
			, method = "PUT"
			, body   = body.toString()
		);
	}

	public boolean function deleteDoc( required string index, required string type, required string id ) {
		var uri = _getIndexAndTypeUri( args=arguments ) & "/#arguments.id#";
		var result = "";

		try {
			result =  _call(
				  uri = uri
				, method = "DELETE"
			);
		} catch ( "cfelasticsearch.UnknownError" e ) {
			if( e.errorCode EQ 404 ) {
				return true; // not found, same as deleted
			}

			_throw(argumentCollection=e);
		}

		return IsDefined( 'result.ok') and IsBoolean( result.ok ) and result.ok;
	}

	public struct function search(
		  struct  fullDsl
		, string  index
		, string  type
		, string  q                  = "*"
		, string  fieldList          = ""
		, string  queryFields        = ""
		, string  sortOrder          = ""
		, numeric page               = 1
		, numeric pageSize           = 10
		, string  defaultOperator    = "OR"
		, string  highlightFields    = ""
		, string  highlightEncoder   = "default"
		, string  fuzziness          = "0"
		, numeric prefixLength       = 3
		, numeric minimumScore       = 0
		, struct  basicFilter        = {}
	) {
		var uri  = _getIndexAndTypeUri( args=arguments ) & "/_search";
		var body = "";

		if ( StructKeyExists( arguments, "fullDsl" ) ) {
			body = arguments.fullDsl;
		} else {
			body = generateSearchDsl( argumentCollection = arguments );
		}

		return _call(
			  uri    = uri
			, method = "POST"
			, body   = SerializeJson( body )
		);
	}

	public struct function moreLikeThis(
		  required string  documentId
		, required string  index
		, required string  type
		,          string  fieldList   = ""
		,          string  sortOrder   = ""
		,          numeric page        = 1
		,          numeric pageSize    = 10
		,          struct  basicFilter = {}
		,          struct  fullDsl
	) {
		var uri  = _getIndexAndTypeUri( args=arguments ) & "/#arguments.documentId#/_mlt";
		var body = "";

		if ( StructKeyExists( arguments, "fullDsl" ) ) {
			body = arguments.fullDsl;
		} else {
			body = generateSearchDsl( argumentCollection = arguments );
			StructDelete( body, 'query' ); // this will be auto generated by the More Like this engine
		}

		return _call(
			  uri    = uri
			, method = "POST"
			, body   = SerializeJson( body )
		);
	}

	public struct function generateSearchDsl(
		  string  q                = "*"
		, string  fieldList        = ""
		, string  queryFields      = ""
		, string  sortOrder        = ""
		, numeric page             = 1
		, numeric pageOffset       = 0
		, numeric pageSize         = 10
		, string  defaultOperator  = "OR"
		, string  highlightFields  = ""
		, string  highlightEncoder = "default"
		, string  fuzziness        = "0"
		, numeric prefixLength     = 3
		, numeric minimumScore     = 0
		, struct  basicFilter      = {}
		, struct  directFilter     = {}
		, string  idList           = ""
		, string  excludeIdList    = ""
		, array   objects		   = []

	) {
		var body = StructNew();
		var idList = "";

		body['from'] = _calculateStartRecordFromPageInfo( arguments.page, arguments.pageOffset, arguments.pageSize );
		body['size'] = pageSize;
		if (Len(Trim(arguments.fieldList))) {
			body['_source'] = ListToArray(arguments.fieldList);
		}
		body['query'] = StructNew();
		body['query']['bool'] = StructNew();
		body['query']['bool']['filter'] = arrayNew();
		body['query']['bool']['must_not'] = arrayNew();
		body['query']['bool']['must'] = StructNew();
		body['query']['bool']['must']['multi_match'] = StructNew();

		body['query']['bool']['must']['multi_match']['query'] = escapeSpecialChars( arguments.q );
		body['query']['bool']['must']['multi_match']['fuzziness'] = arguments.fuzziness;
		body['query']['bool']['must']['multi_match']['prefix_length'] = arguments.prefixLength;
		body['query']['bool']['must']['multi_match']['operator'] = UCase( arguments.defaultOperator );

		if ( Len( Trim( arguments.queryFields ) ) ) {
			body['query']['bool']['must']['multi_match']['fields'] = ListToArray(arguments.queryFields);
		}

		if ( Len( Trim( arguments.sortOrder ) ) ) {
			body['sort'] = _generateSortOrder( arguments.sortOrder );
		}

		if ( Len( Trim( arguments.highlightFields ) ) ) {
			body['highlight'] = _generateHighlightsDsl( arguments.highlightFields, arguments.highlightEncoder );
		}
		if ( arguments.minimumScore ) {
			body['min_score'] = arguments.minimumScore;
		}

		if ( not StructIsEmpty( arguments.basicFilter ) ) {
			body['query']['bool']['filter'] = _generateBasicFilter( arguments.basicFilter );
		}

		if ( not StructIsEmpty( arguments.directFilter ) ) {
			body['query']['bool']['filter'] = _generateDirectFilter( arguments.directFilter );
		}

		if ( objects.len() > 0 ){
			var term = {};
			for ( var object in objects ){
				term = { type = object };
				body['query']['bool']['filter'].append( { term = term } );
			}
		}

		if ( Len( Trim( arguments.idList ) ) ) {
			body['query']['bool']['filter'].append( { terms={ _id=ListToArray( arguments.idList ) } } );
		}
		if ( Len( Trim( arguments.excludeIdList ) ) ) {
			body['query']['bool']['must_not'].append( { terms={ _id=ListToArray( arguments.excludeIdList ) } } );
		}

		$announceInterception( "postElasticSearchGenerateDsl", { dsl=body } );

		return body;
	}

	public struct function refresh( required string index ) {
		var uri = _getIndexAndTypeUri( args=arguments, typeAllowed=false ) & "/_refresh";

		return _call(
			  uri = uri
			, method = "POST"
		);
	}

	public boolean function indexExists( required string index ) {
		try {
			_call(
				  uri = _getIndexAndTypeUri( args=arguments, typeAllowed=false )
				, method = "HEAD"
			);

			return true;

		} catch ( "cfelasticsearch.UnknownError" e ) {
			if( e.errorCode EQ 404 ) {
				return false;
			}

			_throw( argumentCollection=e );
		}
	}

	public string function escapeSpecialChars( required string q ) {
		var specialCharsRegex = '([\+\-!\(\)\{\}\[\]\^\"~\?:\/\\])';

		return ReReplace( arguments.q, specialCharsRegex, "\\1", "all" );
	}

	public string function safeIndexName( required string indexName ){
		return _safeIndexName( arguments.indexName );
	}

// PRIVATE HELPERS
	private any function _call( required string uri, required string method, string body ) {
		var result        = "";
		var success       = false;
		var attempts      = 0;
		var maxAttempts   = _getNullResponseRetryAttempts();
		var endpoints     = _getEndpoint();
		var endpointIndex = 1;

		while( !success && attempts < maxAttempts ) {
			try {
				http url=endpoints[ endpointIndex ] & arguments.uri method=arguments.method result="result" getAsBinary="false" timeout=_getRequestTimeoutInSeconds() {
					if ( StructKeyExists( arguments, "body" ) ) {
						httpparam type="body" value=arguments.body;
						httpparam type="header" name="Content-Type" value="application/json; charset=#_getCharset()#";
					}
				};
				success =  Len( Trim( result.responseHeader.status_code ?: "" ) );
			} catch( any e ) {
				success = false;
			}

			if ( !success ) {
				attempts++;
				endpointIndex++;
				if ( endpointIndex > endpoints.len() ) {
					endpointIndex = 1;
				}
			}
		}

		if ( !success ) {
			_throw(
				  type      = "cfelasticsearch.communicationError"
				, message   = "Made #attempts# attempts to contact ElasticSearch server but none returned a response"
			)
		}
		return _processResult( result );
	}

	private any function _processResult( required struct result ) {
		var deserialized = "";

		try {
			deserialized = DeserializeJson( result.filecontent );
		} catch ( any e ) {
			_throw(
				  type    = "cfelasticsearch.api.Wrapper"
				, message = "Could not parse result from Elastic Search Server. #e.message#."
				, detail  = result.filecontent
			);
		}
		if ( left( result.responseHeader.status_code ?: 500, 1 ) EQ "2" ) {
			return deserialized;
		}

		_throwErrorResult( deserialized, result.responseHeader.status_code ?: 500 );
	}

	private void function _throwErrorResult( required any result, required numeric statusCode ) {
		var errorMessage = "An unexpected error occurred";
		var errorType    = "UnknownError";
		var errorDetail  = SerializeJson( result );

		if ( IsStruct( result ) and StructKeyExists( result, "error" ) ) {
			errorType    = result.error.type;
			errorMessage = result.error.reason;
			if ( Len( Trim( errorMessage ) ) gt 2 ) {
				errorMessage = mid( errorMessage, 2, Len( errorMessage) - 2 );
			}
		}

		_throw(
			  type      = "cfelasticsearch." & errorType
			, message   = errorMessage
			, detail    = errorDetail
			, errorCode = statusCode
		);
	}

	private string function _safeIndexName( required string indexName ) {
		return Trim( LCase( indexName ) );
	}

	private string function _getIndexAndTypeUri( required struct args, boolean typeAllowed=true ) {
		var uri = "";

		if ( Len( Trim( args.index ?: "" ) ) ) {
			uri = "/#_safeIndexName( args.index )#";
		}

		if ( typeAllowed and Len( Trim( args.type ?: "" ) ) ) {
			if ( uri EQ "" ) {
				uri = "/_all";
			}
			uri = uri & "/doc";
		}

		return uri;
	}

	private numeric function _calculateStartRecordFromPageInfo( required numeric page, required numeric pageOffset, required numeric pageSize ) {
		if ( page lte 0 ) {
			_throw(
				  type    = "cfelasticsearch.search.invalidPage"
				, message = "Page number must be greater than zero. Page number supplied was '#page#'."
			);
		}

		return ((page-1) * pageSize) + pageOffset;
	}

	private void function _throw(
		  string type      = "ElasticSearchWrapper.unknown"
		, string message   = ""
		, string detail    = ""
		, string errorCode = ""
	) {

		throw( type=arguments.type, message=arguments.message, detail=arguments.detail, errorcode=arguments.errorCode );
	}

	private struct function _generateHighlightsDsl( required string highlightFields, string highlightEncoder="default" ) {
		var highlights = StructNew();
		var i          = "";
		var field      = "";

		highlights.fields      = StructNew();
		highlights.tags_schema = "styled";
		highlights.encoder     = arguments.highlightEncoder;

		for( i=1; i lte ListLen( arguments.highlightFields ); i=i+1 ){
			field = ListGetAt( arguments.highlightFields, i );
			highlights.fields[field] = StructNew();
		}

		return highlights;
	}

	private array function _generateBasicFilter ( required struct filters ) {
		var filter     = ArrayNew();
		var fields     = StructKeyArray( arguments.filters );
		var i          = 0;
		var termFilter = "";

		for( i=1; i lte ArrayLen( fields ); i=i+1 ){
			termFilter = StructNew();
			if ( IsArray( arguments.filters[ fields[i] ] ) ) {
				termFilter['terms'] = StructNew();
				termFilter['terms'][fields[i]] = arguments.filters[ fields[i] ];
			} else if ( IsSimpleValue( arguments.filters[ fields[i] ] ) ) {
				if ( Len( Trim( arguments.filters[ fields[i] ] ) ) ) {
					termFilter['term'] = StructNew();
					termFilter['term'][fields[i]] = arguments.filters[ fields[i] ];
				} else {
					termFilter['exists'] = StructNew();
					termFilter['exists']['field'] = fields[i];
				}
			}
			ArrayAppend( filter, termFilter );
		}

		return filter;
	}

	private array function _generateDirectFilter( required struct filters ) {
		var filter     = ArrayNew();
		var fields     = StructKeyArray( arguments.filters );
		var i          = 0;
		var directFilter = "";

		for( i=1; i lte ArrayLen( fields ); i=i+1 ){
			directFilter = StructNew();

			if ( Len( Trim( arguments.filters[ fields[i] ] ) ) ) {
				directFilter[fields[i]] = StructNew();
				directFilter[fields[i]]['value'] = arguments.filters[ fields[i] ];
			}

			ArrayAppend( filter, directFilter );
		}

		return filter;
	}

	private array function _generateSortOrder( required string sortorder ) {
		var so = ListToArray( arguments.sortOrder );
		var field = "";
		var fieldName = "";
		var order = "";
		var i = 0;

		for( i=1; i lte ArrayLen( so ); i=i+1 ){
			field = StructNew();
			fieldName = ListFirst( so[i], ' ' );

			field[ fieldName ] = StructNew();
			if ( ListLen( so[i], ' ' ) eq 1 ) {
				field[ fieldName ][ 'order' ] = 'asc';
			} else {
				order = Trim( ListGetAt( so[i], 2, ' ') );
				field[ fieldName ][ 'order' ] = iif( order eq 'desc', DE('desc'), DE('asc') );
			}

			so[i] = field;
		}

		return so;
	}

// GETTERS AND SETTERS
	private any function _getSystemConfigurationService() {
		return _systemConfigurationService;
	}
	private void function _setSystemConfigurationService( required any systemConfigurationService ) {
		_systemConfigurationService = arguments.systemConfigurationService;
	}

	private array function _getEndpoint() {
		return ListToArray( _getSystemConfigurationService().getSetting( "elasticsearch", "endpoint", "http://localhost:9200" ) );
	}

	private string function _getCharset() {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "charset", "UTF-8" );
	}

	private numeric function _getRequestTimeoutInSeconds() {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "api_call_timeout", 30 );
	}

	private numeric function _getNullResponseRetryAttempts() {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "retry_attempts", 3 );
	}
}