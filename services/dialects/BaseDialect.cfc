/**
 * Base class for ElasticSearch engine "dialects". A dialect holds everything that
 * differs between ElasticSearch engine versions: document type URIs, index mappings,
 * field types, search DSL generation and the parsing of responses.
 *
 * To support a new ElasticSearch version, extend the closest existing dialect,
 * override only what has changed and register it in
 * settings.elasticSearchConfig.dialects (see config/Config.cfc).
 *
 * @nowirebox
 */
component {

// CONSTRUCTOR
	public any function init( string version="" ) {
		_setVersion( arguments.version );

		return this;
	}

// VERSION
	public string function getVersion() {
		return _getVersion();
	}

	public numeric function getMajorVersion() {
		var major = ListFirst( _getVersion(), "." );

		return IsNumeric( major ) ? major : 0;
	}

// URIS
	/**
	 * Returns the URI segment, e.g. "/mytype", used to address documents of the given
	 * document type within an index
	 */
	public string function getTypeUriSegment( required string type ) {
		_notImplemented( "getTypeUriSegment" );
	}

// DOCUMENTS
	/**
	 * Gives the dialect the chance to modify a document before it is sent to the index
	 */
	public void function prepareDocForIndexing( required struct doc, required string type ) {}

// FIELD CONFIGURATION AND MAPPINGS
	/**
	 * Field type to use for properties whose Preside type has no specific mapping
	 */
	public string function getDefaultFieldType() {
		_notImplemented( "getDefaultFieldType" );
	}

	/**
	 * Translates a configured field type (e.g. from a searchType attribute) into one
	 * that the engine version understands
	 */
	public string function translateFieldType( required string type ) {
		return arguments.type;
	}

	/**
	 * Field type to use for full-text, analyzed string fields
	 */
	public string function getStringFieldType() {
		_notImplemented( "getStringFieldType" );
	}

	public struct function getFieldMapping(
		  required string  name
		, required string  type
		,          boolean searchable           = false
		,          boolean sortable             = false
		,          string  analyzer             = ""
		,          boolean ignoreMalformedDates = false
	) {
		var mapping = _getBaseFieldMapping( argumentCollection=arguments );

		if ( arguments.sortable && arguments.searchable ) {
			mapping = _getSortableSearchableFieldMapping( name=arguments.name, mapping=mapping );
		}

		if ( arguments.type == "date" ){
			mapping.ignore_malformed = arguments.ignoreMalformedDates;
			if ( StructKeyExists( arguments, "dateFormat" ) ) {
				mapping.format = arguments.dateFormat;
			}
		}

		return mapping;
	}

	/**
	 * Builds the "mappings" part of the index settings.
	 *
	 * @docTypeMappings Array of structs with keys "docType" and "properties" (struct of field name -> field mapping), in document type order
	 */
	public struct function buildIndexMappings( required array docTypeMappings ) {
		_notImplemented( "buildIndexMappings" );
	}

	public struct function getCommonPropertyMappings() {
		return {
			access_restricted = { type="boolean" }
		};
	}

// SEARCH
	public struct function generateSearchDsl() {
		_notImplemented( "generateSearchDsl" );
	}

	/**
	 * Returns a struct with "uri" and "body" keys for a "more like this" search
	 * for the given document.
	 *
	 * @baseUri   URI of the index and document type, e.g. "/myindex/mytype"
	 * @dsl       Search DSL generated from the search arguments, or a full DSL supplied by the caller
	 * @isFullDsl Whether or not the DSL was supplied in full by the caller (in which case it is sent as is)
	 */
	public struct function getMoreLikeThisRequest(
		  required string  baseUri
		, required string  index
		, required string  documentId
		, required struct  dsl
		,          boolean isFullDsl = false
	) {
		_notImplemented( "getMoreLikeThisRequest" );
	}

	public string function getDefaultHighlightEncoder() {
		return "default";
	}

	public string function escapeSpecialChars( required string q ) {
		var specialCharsRegex = '([\+\-!\(\)\{\}\[\]\^\"~\?:\/\\])';

		return ReReplace( arguments.q, specialCharsRegex, "\\1", "all" );
	}

// RESPONSES
	/**
	 * Returns the struct of stored field values for a single search hit
	 */
	public struct function getHitFields( required struct hit ) {
		_notImplemented( "getHitFields" );
	}

	/**
	 * Returns the Preside document type of a single search hit
	 */
	public string function getHitType( required struct hit ) {
		return arguments.hit._type ?: "";
	}

	/**
	 * Returns a struct with "type" and "message" keys, parsed from the "error"
	 * element of an error response
	 */
	public struct function parseError( required any error ) {
		_notImplemented( "parseError" );
	}

// PRIVATE HELPERS
	private struct function _getBaseFieldMapping() {
		_notImplemented( "_getBaseFieldMapping" );
	}

	/**
	 * Mapping for a field that is both searchable (analyzed) and sortable. The
	 * sortable version of the field is available as [fieldname].untouched
	 */
	private struct function _getSortableSearchableFieldMapping( required string name, required struct mapping ) {
		var multiFieldMapping = {
			  type   = "multi_field"
			, fields = {
				  "#arguments.name#" = Duplicate( arguments.mapping )
				, untouched          = Duplicate( arguments.mapping )
			}
		};
		multiFieldMapping.fields.untouched.analyzer = "preside_sortable";

		return multiFieldMapping;
	}

	private numeric function _calculateStartRecordFromPageInfo( required numeric page, required numeric pageOffset, required numeric pageSize ) {
		if ( page lte 0 ) {
			throw(
				  type    = "cfelasticsearch.search.invalidPage"
				, message = "Page number must be greater than zero. Page number supplied was '#page#'."
			);
		}

		return ((page-1) * pageSize) + pageOffset;
	}

	private string function _resolveHighlightEncoder( string highlightEncoder="" ) {
		return Len( Trim( arguments.highlightEncoder ) ) ? arguments.highlightEncoder : getDefaultHighlightEncoder();
	}

	private struct function _generateHighlightsDsl( required string highlightFields, required string highlightEncoder ) {
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

	private array function _generateBasicFilterClauses( required struct filters ) {
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
			// empty clauses are rejected by ElasticSearch
			if ( !StructIsEmpty( termFilter ) ) {
				ArrayAppend( filter, termFilter );
			}
		}

		return filter;
	}

	private array function _generateDirectFilterClauses( required struct filters ) {
		var filter       = ArrayNew();
		var fields       = StructKeyArray( arguments.filters );
		var i            = 0;
		var directFilter = "";

		// exact (term) matches on each field's value. Fields with empty values are ignored
		for( i=1; i lte ArrayLen( fields ); i=i+1 ){
			if ( Len( Trim( arguments.filters[ fields[i] ] ) ) ) {
				directFilter = StructNew();
				directFilter['term'] = StructNew();
				directFilter['term'][fields[i]] = StructNew();
				directFilter['term'][fields[i]]['value'] = arguments.filters[ fields[i] ];

				ArrayAppend( filter, directFilter );
			}
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

	private void function _notImplemented( required string methodName ) {
		throw(
			  type    = "elasticsearch.dialect.notImplemented"
			, message = "The ElasticSearch dialect [#GetMetadata( this ).name#] does not implement [#arguments.methodName#()]."
		);
	}

// GETTERS AND SETTERS
	private string function _getVersion() {
		return _version;
	}
	private void function _setVersion( required string version ) {
		_version = arguments.version;
	}
}
