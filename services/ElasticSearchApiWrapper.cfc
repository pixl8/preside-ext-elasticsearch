component output=false singleton=true {

// CONSTRUCTOR
	/**
	 * @systemConfigurationService.inject systemConfigurationService
	 *
	 */
	public any function init(
		required any  systemConfigurationService
	) output=false {
		_setSystemConfigurationService( arguments.systemConfigurationService );

		return this;
	}

	public struct function ping() output=false {
		return _call( uri="/", method="GET" );
	}

	public struct function createIndex( required string index, struct settings ) output=false {
		var args = StructNew();
		args.uri =_getIndexAndTypeUri( args=arguments, typeAllowed=false );
		args.method = "PUT";

		if ( StructKeyExists( arguments, 'settings' ) ) {
			args.body = SerializeJson( arguments.settings );
		}

		return _call( argumentCollection = args );
	}

	public struct function deleteIndex( required string index ) output=false {
		return _call(
			  uri    = _getIndexAndTypeUri( args=arguments, typeAllowed=false )
			, method = "DELETE"
		);
	}

	public struct function addAlias( required string index, required string alias ) output=false {
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

	public struct function removeAlias( required string index, required string alias ) output=false {
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

	public array function getAliasIndexes( required string alias ) output=false {
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

	public struct function addDoc( required string index, required string type, required struct doc, string id ) output=false {
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
			body.append( SerializeJson( docs[i] ) & chr(10) );
		}

		return _call(
			  uri    = uri
			, method = "PUT"
			, body   = body.toString()
		);
	}

	public boolean function deleteDoc( required string index, required string type, required string id ) output=false {
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
		, numeric minimumScore       = 0
		, struct  basicFilter        = {}
	) output=false {
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
	) output=false {
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
		, numeric minimumScore     = 0
		, struct  basicFilter      = {}
		, string  idList           = ""
		, string  excludeIdList    = ""
	) output=false {
		var body = StructNew();
		var idList = "";

		body['from'] = _calculateStartRecordFromPageInfo( arguments.page, arguments.pageOffset, arguments.pageSize );
		body['size'] = pageSize;
		if (Len(Trim(arguments.fieldList))) {
			body['fields'] = ListToArray(arguments.fieldList);
		}
		body['query'] = StructNew();
		body['query']['query_string'] = StructNew();
		body['query']['query_string']['query'] = escapeSpecialChars( arguments.q );
		body['query']['query_string']['default_operator'] = UCase( arguments.defaultOperator );
		if ( Len( Trim( arguments.queryFields ) ) ) {
			body['query']['query_string']['fields'] = ListToArray(arguments.queryFields);
		}

		if ( Len( Trim( arguments.sortOrder ) ) ) {
			body['sort'] = _generateSortOrder( arguments.sortOrder );
		}

		if ( Len( Trim( arguments.highlightFields ) ) ) {
			body['highlight'] = _generateHighlightsDsl( arguments.highlightFields );
		}
		if ( arguments.minimumScore ) {
			body['min_score'] = arguments.minimumScore;
		}

		if ( not StructIsEmpty( arguments.basicFilter ) ) {
			body['filter'] = _generateBasicFilter( arguments.basicFilter );
		}
		if ( Len( Trim( arguments.idList ) ) ) {
			if ( not StructKeyExists( body, 'filter' ) ) {
				body['filter'] = StructNew();
				body['filter']['and'] = ArrayNew(1);
			}

			idList = StructNew();
			idList['ids'] = StructNew();
			idList['ids']['values'] = ListToArray( arguments.idList );

			ArrayAppend( body.filter['and'], idList );
		}
		if ( Len( Trim( arguments.excludeIdList ) ) ) {
			if ( not StructKeyExists( body, 'filter' ) ) {
				body['filter'] = StructNew();
				body['filter']['and'] = ArrayNew(1);
			}

			idList = StructNew();
			idList['not'] = StructNew();
			idList['not']['ids'] = StructNew();
			idList['not']['ids']['values'] = ListToArray( arguments.excludeIdList );

			ArrayAppend( body.filter['and'], idList );
		}

		return body;
	}

	public struct function refresh( required string index ) output=false {
		var uri = _getIndexAndTypeUri( args=arguments, typeAllowed=false ) & "/_refresh";

		return _call(
			  uri = uri
			, method = "POST"
		);
	}

	public boolean function indexExists( required string index ) output=false {
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

	public string function escapeSpecialChars( required string q ) output=false {
		var specialCharsRegex = '([\+\-!\(\)\{\}\[\]\^\"~\?:\\])';

		return ReReplace( arguments.q, specialCharsRegex, "\\1", "all" );
	}

// PRIVATE HELPERS
	private any function _call( required string uri, required string method, string body ) output=false {
		var result        = "";
		var success       = false;
		var attempts      = 0;
		var maxAttempts   = _getNullResponseRetryAttempts();
		var endpoints     = _getEndpoint();
		var endpointIndex = 1;

		while( !success && attempts < maxAttempts ) {
			try {
				http url=endpoints[ endpointIndex ] & arguments.uri method=arguments.method result="result" charset=_getCharset() getAsBinary="yes" timeout=_getRequestTimeoutInSeconds() {
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

	private any function _processResult( required struct result ) output=false {
		var deserialized = "";
		var errorMessage = "";
		var jsonResponse = "";;

		try {
			if ( StructKeyExists( result, 'filecontent' ) and IsBinary( result.filecontent ) ) {
				jsonResponse = CharsetEncode( result.filecontent, _getCharset() );

				if ( Len( Trim( jsonResponse ) ) ) {
					deserialized = DeserializeJson( jsonResponse );
				}
			}
		} catch ( any e ) {
			_throw(
				  type    = "cfelasticsearch.api.Wrapper"
				, message = "Could not parse result from Elastic Search Server. See detail for response."
				, detail  = jsonResponse
			);
		}
		if ( left( result.responseHeader.status_code ?: 500, 1 ) EQ "2" ) {
			return deserialized;
		}

		_throwErrorResult( deserialized, result.responseHeader.status_code ?: 500 );
	}

	private void function _throwErrorResult( required any result, required numeric statusCode ) output=false {
		var errorMessage = "An unexpected error occurred";
		var errorType    = "UnknownError";
		var errorDetail  = SerializeJson( result );

		if ( IsStruct( result ) and StructKeyExists( result, "error" ) ) {
			errorType    = ListFirst( result.error, "[" );
			errorMessage = Replace( result.error, errorType, "" );
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

	private string function _safeIndexName( required string indexName ) output=false {
		return Trim( LCase( indexName ) );
	}

	private string function _getIndexAndTypeUri( required struct args, boolean typeAllowed=true ) output=false {
		var uri = "";

		if ( Len( Trim( args.index ?: "" ) ) ) {
			uri = "/#_safeIndexName( args.index )#";
		}

		if ( typeAllowed and Len( Trim( args.type ?: "" ) ) ) {
			if ( uri EQ "" ) {
				uri = "/_all";
			}
			uri = uri & "/#Trim( args.type )#";
		}

		return uri;
	}

	private numeric function _calculateStartRecordFromPageInfo( required numeric page, required numeric pageOffset, required numeric pageSize ) output=false {
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
	) output=false {

		throw( type=arguments.type, message=arguments.message, detail=arguments.detail, errorcode=arguments.errorCode );
	}

	private struct function _generateHighlightsDsl( required string highlightFields ) output=false {
		var highlights = StructNew();
		var i = "";
		var field = "";

		highlights.fields = StructNew();
		highlights.tags_schema = "styled";
		highlights.encoder = "html";

		for( i=1; i lte ListLen( arguments.highlightFields ); i=i+1 ){
			field = ListGetAt( arguments.highlightFields, i );
			highlights.fields[field] = StructNew();
		}

		return highlights;
	}

	private struct function _generateBasicFilter ( required struct filters ) output=false {
		var filter     = StructNew();
		var fields     = StructKeyArray( arguments.filters );
		var i          = 0;
		var termFilter = "";

		filter['and'] = ArrayNew(1);

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
			ArrayAppend( filter['and'], termFilter );
		}

		return filter;
	}

	private array function _generateSortOrder( required string sortorder ) output=false {
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
	private any function _getSystemConfigurationService() output=false {
		return _systemConfigurationService;
	}
	private void function _setSystemConfigurationService( required any systemConfigurationService ) output=false {
		_systemConfigurationService = arguments.systemConfigurationService;
	}

	private array function _getEndpoint() output=false {
		return ListToArray( _getSystemConfigurationService().getSetting( "elasticsearch", "endpoint", "http://localhost:9200" ) );
	}

	private string function _getCharset() output=false {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "charset", "UTF-8" );
	}

	private numeric function _getRequestTimeoutInSeconds() output=false {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "api_call_timeout", 30 );
	}

	private numeric function _getNullResponseRetryAttempts() output=false {
		return _getSystemConfigurationService().getSetting( "elasticsearch", "retry_attempts", 3 );
	}
}