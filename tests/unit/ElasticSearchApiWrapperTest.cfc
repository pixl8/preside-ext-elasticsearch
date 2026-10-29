component extends="testbox.system.BaseSpec" {

	function run() {

		describe( "generateSearchDsl() (ElasticSearch 1.7)", function(){
			it( "should generate a query_string query", function(){
				var wrapper = _getWrapper( "1.7" );

				expect( wrapper.generateSearchDsl( q="foo:bar", queryFields="title,body", defaultOperator="and" ) ).toBe( {
					  from  = 0
					, size  = 10
					, query = { query_string={ query="foo\:bar", default_operator="AND", fields=[ "title", "body" ] } }
				} );
			} );

			it( "should request stored fields, with html encoded highlights by default", function(){
				var wrapper = _getWrapper( "1.7" );
				var dsl     = wrapper.generateSearchDsl( fieldList="title,teaser", highlightFields="title" );

				expect( dsl.fields ).toBe( [ "title", "teaser" ] );
				expect( dsl.highlight ).toBe( { fields={ title={} }, tags_schema="styled", encoder="html" } );
			} );

			it( "should generate top level 'and' filters for basic filters, id lists and excluded id lists", function(){
				var wrapper = _getWrapper( "1.7" );
				var dsl     = wrapper.generateSearchDsl( basicFilter={ site="abc" }, idList="1,2", excludeIdList="3" );

				expect( dsl.filter ).toBe( { "and"=[
					  { term={ site="abc" } }
					, { ids={ values=[ "1", "2" ] } }
					, { "not"={ ids={ values=[ "3" ] } } }
				] } );
			} );

			it( "should ignore arguments that only apply to later versions of ElasticSearch", function(){
				var wrapper = _getWrapper( "1.7" );

				expect( wrapper.generateSearchDsl( q="foo", fuzziness="AUTO", prefixLength=1, objects=[ "page" ] ) ).toBe( wrapper.generateSearchDsl( q="foo" ) );
			} );

			it( "should announce the postElasticSearchGenerateDsl interception point", function(){
				var wrapper = _getWrapper( "1.7" );
				var dsl     = wrapper.generateSearchDsl( q="foo" );

				expect( wrapper.$callLog()[ "$announceInterception" ].len() ).toBe( 1 );
				expect( wrapper.$callLog()[ "$announceInterception" ][ 1 ][ 1 ] ).toBe( "postElasticSearchGenerateDsl" );
			} );
		} );

		describe( "generateSearchDsl() (ElasticSearch 6.3)", function(){
			it( "should generate a bool query with a multi_match", function(){
				var wrapper = _getWrapper( "6.3" );

				expect( wrapper.generateSearchDsl( q="foo:bar", queryFields="title,body", fuzziness="AUTO", prefixLength=2 ) ).toBe( {
					  from  = 0
					, size  = 10
					, query = { bool={
						  filter   = []
						, must_not = []
						, must     = { multi_match={ query="foo\:bar", fuzziness="AUTO", prefix_length=2, operator="OR", fields=[ "title", "body" ] } }
					} }
				} );
			} );

			it( "should request _source fields, plus the type field, with the default highlight encoder by default", function(){
				var wrapper = _getWrapper( "6.3" );
				var dsl     = wrapper.generateSearchDsl( fieldList="title,teaser", highlightFields="title" );

				expect( dsl._source ).toBe( [ "title", "teaser", "type" ] );
				expect( dsl.highlight ).toBe( { fields={ title={} }, tags_schema="styled", encoder="default" } );
			} );

			it( "should use a specified highlight encoder", function(){
				var wrapper = _getWrapper( "6.3" );
				var dsl     = wrapper.generateSearchDsl( highlightFields="title", highlightEncoder="html" );

				expect( dsl.highlight.encoder ).toBe( "html" );
			} );

			it( "should generate bool filters for basic filters, document types and id lists, and must_not for excluded ids", function(){
				var wrapper = _getWrapper( "6.3" );
				var dsl     = wrapper.generateSearchDsl( basicFilter={ site="abc" }, objects=[ "page" ], idList="1,2", excludeIdList="3" );

				expect( dsl.query.bool.filter ).toBe( [
					  { term={ site="abc" } }
					, { term={ type="page" } }
					, { terms={ _id=[ "1", "2" ] } }
				] );
				expect( dsl.query.bool.must_not ).toBe( [ { terms={ _id=[ "3" ] } } ] );
			} );
		} );

		describe( "search()", function(){
			it( "should search against the index and document types when using ElasticSearch 1.7", function(){
				var wrapper = _getWrapper( "1.7" );

				wrapper.search( index="myindex", type="page,news", q="foo" );

				expect( wrapper.$callLog()._call[ 1 ].uri ).toBe( "/myindex/page,news/_search" );
			} );

			it( "should search against the single 'doc' type when using ElasticSearch 6.3", function(){
				var wrapper = _getWrapper( "6.3" );

				wrapper.search( index="myindex", type="page,news", q="foo" );

				expect( wrapper.$callLog()._call[ 1 ].uri ).toBe( "/myindex/doc/_search" );
			} );

			it( "should filter by document type when using ElasticSearch 6.3", function(){
				var wrapper = _getWrapper( "6.3" );

				wrapper.search( index="myindex", type="page,news", q="foo" );

				var dsl = DeserializeJson( wrapper.$callLog()._call[ 1 ].body );
				expect( dsl.query.bool.filter ).toBe( [ { terms={ type=[ "page", "news" ] } } ] );
			} );

			it( "should not filter by document type when no types are specified", function(){
				var wrapper = _getWrapper( "6.3" );

				wrapper.search( index="myindex", q="foo" );

				var dsl = DeserializeJson( wrapper.$callLog()._call[ 1 ].body );
				expect( dsl.query.bool.filter ).toBe( [] );
			} );

			it( "should not add a document type filter when using ElasticSearch 1.7, where types are part of the URI", function(){
				var wrapper = _getWrapper( "1.7" );

				wrapper.search( index="myindex", type="page,news", q="foo" );

				var dsl = DeserializeJson( wrapper.$callLog()._call[ 1 ].body );
				expect( StructKeyExists( dsl, "filter" ) ).toBeFalse();
			} );

			it( "should add the configured API timeout to the search DSL", function(){
				for( var version in [ "1.7", "6.3" ] ) {
					var wrapper = _getWrapper( version );

					wrapper.search( index="myindex", q="foo" );

					expect( DeserializeJson( wrapper.$callLog()._call[ 1 ].body ).timeout ?: "" ).toBe( "5s" );
				}
			} );

			it( "should not override a timeout supplied in a full DSL", function(){
				var wrapper = _getWrapper( "6.3" );

				wrapper.search( index="myindex", fullDsl={ query={ match_all={} }, timeout="20s" } );

				expect( DeserializeJson( wrapper.$callLog()._call[ 1 ].body ) ).toBe( { query={ match_all={} }, timeout="20s" } );
			} );
		} );

		describe( "moreLikeThis()", function(){
			it( "should use the _mlt endpoint, with the generated query removed, when using ElasticSearch 1.7", function(){
				var wrapper = _getWrapper( "1.7" );

				wrapper.moreLikeThis( documentId="abc", index="MyIndex", type="page", basicFilter={ site="x" } );

				var call = wrapper.$callLog()._call[ 1 ];
				var dsl  = DeserializeJson( call.body );

				expect( call.uri ).toBe( "/myindex/page/abc/_mlt" );
				expect( StructKeyExists( dsl, "query" ) ).toBeFalse();
				expect( dsl.filter ).toBe( { "and"=[ { term={ site="x" } } ] } );
			} );

			it( "should use a more_like_this query, keeping filters, when using ElasticSearch 6.3", function(){
				var wrapper = _getWrapper( "6.3" );

				wrapper.moreLikeThis( documentId="abc", index="MyIndex", type="page", basicFilter={ site="x" } );

				var call = wrapper.$callLog()._call[ 1 ];
				var dsl  = DeserializeJson( call.body );

				expect( call.uri ).toBe( "/myindex/doc/_search" );
				expect( dsl.query.bool.must ).toBe( { more_like_this={ like=[ { _index="myindex", _type="doc", _id="abc" } ] } } );
				expect( dsl.query.bool.filter ).toBe( [ { term={ site="x" } }, { terms={ type=[ "page" ] } } ] );
			} );

			it( "should send a full DSL as is", function(){
				var wrapper = _getWrapper( "6.3" );
				var fullDsl = { query={ match_all={} } };

				wrapper.moreLikeThis( documentId="abc", index="myindex", type="page", fullDsl=fullDsl );

				var call = wrapper.$callLog()._call[ 1 ];

				expect( call.uri ).toBe( "/myindex/doc/_search" );
				expect( DeserializeJson( call.body ) ).toBe( fullDsl );
			} );
		} );

		describe( "addDocs()", function(){
			it( "should bulk index documents under their document type when using ElasticSearch 1.7", function(){
				var wrapper = _getWrapper( "1.7" );

				wrapper.addDocs( index="myindex", type="page", docs=[ { id="1", title="test" } ] );

				var call  = wrapper.$callLog()._call[ 1 ];
				var lines = ListToArray( call.body, Chr( 10 ) );

				expect( call.uri ).toBe( "/myindex/page/_bulk" );
				expect( DeserializeJson( lines[ 1 ] ) ).toBe( { index={ _id="1" } } );
				expect( DeserializeJson( lines[ 2 ] ) ).toBe( { id="1", title="test" } );
			} );

			it( "should bulk index documents under the 'doc' type, with a 'type' field, when using ElasticSearch 6.3", function(){
				var wrapper = _getWrapper( "6.3" );

				wrapper.addDocs( index="myindex", type="page", docs=[ { id="1", title="test" } ] );

				var call  = wrapper.$callLog()._call[ 1 ];
				var lines = ListToArray( call.body, Chr( 10 ) );

				expect( call.uri ).toBe( "/myindex/doc/_bulk" );
				expect( DeserializeJson( lines[ 2 ] ) ).toBe( { id="1", title="test", type="page" } );
			} );
		} );

		describe( "error handling", function(){
			it( "should parse string errors returned by ElasticSearch 1.7", function(){
				var wrapper = _getWrapper( "1.7" );

				makePublic( wrapper, "_throwErrorResult" );
				wrapper.$( "_throw" );

				wrapper._throwErrorResult( { error="IndexMissingException[[foo] missing]" }, 404 );

				var thrown = wrapper.$callLog()._throw[ 1 ];
				expect( thrown.type    ).toBe( "cfelasticsearch.IndexMissingException" );
				expect( thrown.message ).toBe( "[foo] missing" );
			} );

			it( "should parse structured errors returned by ElasticSearch 6.3", function(){
				var wrapper = _getWrapper( "6.3" );

				makePublic( wrapper, "_throwErrorResult" );
				wrapper.$( "_throw" );

				wrapper._throwErrorResult( { error={ type="index_not_found_exception", reason="no such index" } }, 404 );

				var thrown = wrapper.$callLog()._throw[ 1 ];
				expect( thrown.type    ).toBe( "cfelasticsearch.index_not_found_exception" );
				expect( thrown.message ).toBe( "no such index" );
			} );
		} );
	}

// HELPERS
	private any function _getWrapper( required string engineVersion ) {
		var mockSystemConfigurationService = getMockBox().createStub();
		var wrapper = getMockBox().createMock( object=new elasticsearch.services.ElasticSearchApiWrapper(
			  systemConfigurationService = mockSystemConfigurationService
			, dialectFactory             = new elasticsearch.services.ElasticSearchDialectFactory( engineVersion=arguments.engineVersion )
		) );

		mockSystemConfigurationService.$( "getSetting" ).$args( "elasticsearch", "api_call_timeout", 30 ).$results( 5 );
		wrapper.$( "$announceInterception" );
		wrapper.$( "_call", { errors=false } );

		return wrapper;
	}
}
