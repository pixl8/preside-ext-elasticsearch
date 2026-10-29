/**
 * Dialect for ElasticSearch 6.x (tested against 6.3)
 *
 * ElasticSearch 6 only allows a single mapping type per index. All documents
 * are indexed under the "doc" type, with the Preside document type stored in a
 * "type" keyword field.
 *
 * @nowirebox
 */
component extends="BaseDialect" {

// URIS
	public string function getTypeUriSegment( required string type ) {
		return "/doc";
	}

// DOCUMENTS
	public void function prepareDocForIndexing( required struct doc, required string type ) {
		arguments.doc.type = arguments.type;
	}

// FIELD CONFIGURATION AND MAPPINGS
	public string function getDefaultFieldType() {
		return "text";
	}

	public string function getStringFieldType() {
		return "text";
	}

	public struct function buildIndexMappings( required array docTypeMappings ) {
		var mappings = {};

		mappings.doc = { properties={} };
		mappings.doc.properties.append( getCommonPropertyMappings(), false );

		for( var docTypeMapping in arguments.docTypeMappings ){
			mappings.doc.properties.append( Duplicate( docTypeMapping.properties ) );
		}

		return mappings;
	}

	public struct function getCommonPropertyMappings() {
		var mappings = super.getCommonPropertyMappings();

		mappings.type = { type="keyword" };

		return mappings;
	}

// SEARCH
	public struct function generateSearchDsl(
		  string  q                = "*"
		, string  type             = ""
		, string  fieldList        = ""
		, string  queryFields      = ""
		, string  sortOrder        = ""
		, numeric page             = 1
		, numeric pageOffset       = 0
		, numeric pageSize         = 10
		, string  defaultOperator  = "OR"
		, string  highlightFields  = ""
		, string  highlightEncoder = ""
		, string  fuzziness        = "0"
		, numeric prefixLength     = 3
		, numeric minimumScore     = 0
		, struct  basicFilter      = {}
		, struct  directFilter     = {}
		, string  idList           = ""
		, string  excludeIdList    = ""
		, array   objects          = []
	) {
		var body = StructNew();

		body['from'] = _calculateStartRecordFromPageInfo( arguments.page, arguments.pageOffset, arguments.pageSize );
		body['size'] = pageSize;
		if (Len(Trim(arguments.fieldList))) {
			body['_source'] = ListToArray(arguments.fieldList);
			// the type field is always needed in order to report each hit's document type
			if ( !ArrayFindNoCase( body['_source'], "type" ) ) {
				body['_source'].append( "type" );
			}
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
			body['highlight'] = _generateHighlightsDsl( arguments.highlightFields, _resolveHighlightEncoder( arguments.highlightEncoder ) );
		}
		if ( arguments.minimumScore ) {
			body['min_score'] = arguments.minimumScore;
		}

		if ( not StructIsEmpty( arguments.basicFilter ) ) {
			body['query']['bool']['filter'] = _generateBasicFilterClauses( arguments.basicFilter );
		}

		if ( not StructIsEmpty( arguments.directFilter ) ) {
			body['query']['bool']['filter'] = _generateDirectFilterClauses( arguments.directFilter );
		}

		// all document types share the single "doc" mapping, so restrict to the requested types with a filter
		if ( Len( Trim( arguments.type ) ) ) {
			body['query']['bool']['filter'].append( { terms={ type=ListToArray( arguments.type ) } } );
		}

		if ( arguments.objects.len() > 0 ){
			for ( var object in arguments.objects ){
				body['query']['bool']['filter'].append( { term = { type = object } } );
			}
		}

		if ( Len( Trim( arguments.idList ) ) ) {
			body['query']['bool']['filter'].append( { terms={ _id=ListToArray( arguments.idList ) } } );
		}
		if ( Len( Trim( arguments.excludeIdList ) ) ) {
			body['query']['bool']['must_not'].append( { terms={ _id=ListToArray( arguments.excludeIdList ) } } );
		}

		return body;
	}

	public struct function getMoreLikeThisRequest(
		  required string  baseUri
		, required string  index
		, required string  documentId
		, required struct  dsl
		,          boolean isFullDsl = false
	) {
		var body = arguments.dsl;

		if ( !arguments.isFullDsl ) {
			// the _mlt endpoint was removed in ElasticSearch 2.0: use a more_like_this query,
			// keeping any filters generated from the search arguments
			body['query']['bool']['must'] = { more_like_this = {
				like = [ { _index=arguments.index, _type="doc", _id=arguments.documentId } ]
			} };
		}

		return {
			  uri  = arguments.baseUri & "/_search"
			, body = body
		};
	}

// RESPONSES
	public struct function getHitFields( required struct hit ) {
		return arguments.hit._source ?: {};
	}

	public string function getHitType( required struct hit ) {
		return arguments.hit._source.type ?: ( arguments.hit._type ?: "" );
	}

	public struct function parseError( required any error ) {
		return {
			  type    = arguments.error.type   ?: "UnknownError"
			, message = arguments.error.reason ?: ""
		};
	}

// PRIVATE HELPERS
	private struct function _getBaseFieldMapping( required string type, boolean searchable=false, boolean sortable=false, string analyzer="" ) {
		// "string" no longer exists as a field type
		var fieldType = arguments.type == "string" ? "text" : arguments.type;
		var mapping   = { type=fieldType };

		// analyzers and fielddata only apply to text fields. Other types
		// (keyword, date, numeric, boolean) can be sorted on as they are
		if ( fieldType != "text" ) {
			mapping.index = true;
		} else if ( arguments.searchable ) {
			if ( Len( Trim( arguments.analyzer ) ) ) {
				mapping.analyzer = arguments.analyzer;
				mapping.fielddata = true;
				mapping.index = true;
			}
		} else {
			if ( arguments.sortable ) {
				mapping.analyzer  = "preside_sortable";
				mapping.fielddata = true;
			} else {
				mapping.index = true;
			}
		}

		return mapping;
	}

	/**
	 * The multi_field type no longer exists: use a "fields" sub-field instead. The
	 * sortable version of the field is still available as [fieldname].untouched
	 */
	private struct function _getSortableSearchableFieldMapping( required string name, required struct mapping ) {
		var sortableMapping = Duplicate( arguments.mapping );

		if ( sortableMapping.type == "text" ) {
			sortableMapping.fields = {
				untouched = { type="text", analyzer="preside_sortable", fielddata=true }
			};
		}

		return sortableMapping;
	}
}
