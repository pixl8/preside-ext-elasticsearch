component extends="testbox.system.BaseSpec" {

	function run() output=false {

		describe( "init()", function(){
			it( "should check all configured indexes exist", function(){
				var engine = _getSearchEngine();

				expect( engine.$callLog()._checkIndexesExist.len() ).toBe( 1 );
			} );
		} );

		describe( "ensureIndexesExist()", function(){
			it( "should call createIndex for each configured index that has no registered aliases with the elasticsearch server", function(){
				var engine     = _getSearchEngine();
				var indexes = {
					  ix_1 = []
					, ix_2 = [ CreateUUId() ]
					, ix_3 = []
					, ix_4 = []
					, ix_5 = [ CreateUUId() ]
					, ix_6 = []
				};

				mockConfigReader.$( "listIndexes", indexes.keyArray().sort( "textnocase" ) );

				for( var ix in indexes ){
					mockApiWrapper.$( "getAliasIndexes" ).$args( ix ).$results( indexes[ ix ] );
				}

				engine.$( "createIndex" );

				engine.ensureIndexesExist();

				expect( engine.$callLog().createIndex.len() ).toBe( 4 );
				expect( engine.$callLog().createIndex[1] ).toBe( [ "ix_1" ] );
				expect( engine.$callLog().createIndex[2] ).toBe( [ "ix_3" ] );
				expect( engine.$callLog().createIndex[3] ).toBe( [ "ix_4" ] );
				expect( engine.$callLog().createIndex[4] ).toBe( [ "ix_6" ] );

			} );
		} );

		describe( "createIndex()", function() {
			it( "should create a new index with a unique name", function(){
				var engine             = _getSearchEngine();
				var indexName       = "My index";
				var uniqueIndexName = CreateUUId();

				engine.$( "createUniqueIndexName" ).$args( indexName ).$results( uniqueIndexName );
				engine.$( "getIndexSettings" ).$args( indexName ).$results( {} );
				mockApiWrapper.$( "createIndex", {} );
				mockApiWrapper.$( "addAlias", {} );

				engine.createIndex( indexName );

				expect( mockApiWrapper.$callLog().createIndex.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().createIndex[1].index ?: "" ).toBe( uniqueIndexName );
			} );

			it( "should alias the unique index name with the configured index name", function(){
				var engine             = _getSearchEngine();
				var indexName       = "My index";
				var uniqueIndexName = CreateUUId();

				engine.$( "createUniqueIndexName" ).$args( indexName ).$results( uniqueIndexName );
				engine.$( "getIndexSettings" ).$args( indexName ).$results( {} );
				mockApiWrapper.$( "createIndex", {} );
				mockApiWrapper.$( "addAlias", {} );

				engine.createIndex( indexName );

				expect( mockApiWrapper.$callLog().addAlias.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().addAlias[1].index ?: "" ).toBe( uniqueIndexName );
				expect( mockApiWrapper.$callLog().addAlias[1].alias ?: "" ).toBe( indexName );
			} );

			it( "should pass configured index settings to the elasticsearch server", function(){
				var engine             = _getSearchEngine();
				var indexName       = "My index";
				var uniqueIndexName = CreateUUId();
				var settings        = { test=true, settings=245 };

				engine.$( "createUniqueIndexName" ).$args( indexName ).$results( uniqueIndexName );
				engine.$( "getIndexSettings" ).$args( indexName ).$results( settings);
				mockApiWrapper.$( "createIndex", {} );
				mockApiWrapper.$( "addAlias", {} );

				engine.createIndex( indexName );

				expect( mockApiWrapper.$callLog().createIndex.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().createIndex[1].settings ?: {} ).toBe( settings );
			} );
		} );

		describe( "createUniqueIndexName()", function(){
			it( "should include the original index name so that someone examining the ES server can see which indexes are associated with which alias and which old dead indexes can be cleared out", function(){
				var engine        = _getSearchEngine();
				var index      = "myindex";
				var uniqueName = engine.createUniqueIndexName( index );

				expect( uniqueName.contains( index ) ).toBeTrue();
				expect( uniqueName == index ).toBeFalse();
			} );
		} );

		describe( "getIndexSettings()", function(){
			it( "should bring back default index and analyzer settings", function(){
				var engine = _getSearchEngine();
				var configuredStopWords = [ "these", "are", "mystopwords" ];
				var configuredSynonyms  = [ "i-pod, i pod => ipod", "universe, cosmos" ];
				var expectedSettings = {
					index = {
						  number_of_shards   : 1
						, number_of_replicas : 1
						, analysis = {
							analyzer = {
								preside_analyzer = {
									  tokenizer   = "standard"
									, filter      = [ "standard", "asciifolding", "lowercase", "preside_stopwords", "preside_synonyms", "preside_stemmer" ]
									, char_filter = [ "html_strip" ]
								},
								preside_sortable = {
									  tokenizer = "keyword"
									, filter    = [ "lowercase" ]
								}
							},
							filter = {
								  preside_stemmer   = { type="stemmer", language="English" }
								, preside_stopwords = { type="stop", stopwords=configuredStopWords }
								, preside_synonyms  = { type="synonym", synonyms=configuredSynonyms }
							}
						  }
					}
				};

				expectedSettings.index.analysis.analyzer[ "default" ] = expectedSettings.index.analysis.analyzer.preside_analyzer;

				engine.$( "getConfiguredStopwords", configuredStopWords );
				engine.$( "getConfiguredSynonyms", configuredSynonyms );
				engine.$( "getIndexMappings", {} );

				var settings = engine.getIndexSettings( "someIndex" );

				expect( settings.settings ?: {} ).toBe( expectedSettings );
			} );

			it( "should return mappings for the index", function(){
				var engine       = _getSearchEngine();
				var mappings  = { test="mapping settings" };
				var indexName = "my-index";

				engine.$( "_getDefaultIndexSettings", {} );
				engine.$( "getIndexMappings" ).$args( indexName ).$results( mappings );

				var settings = engine.getIndexSettings( indexName );

				expect( settings.mappings ?: {} ).toBe( mappings );

			} );
		} );

		describe( "getIndexMappings()", function(){
			it( "should create mappings based on the configured fields and document types for the index", function(){
				var engine    = _getSearchEngine();
				var indexName = "some_index";
				var docTypes  = {
					  type_a = { field_1={ type="string", searchable=true, sortable=true }, field_2={ type="date", searchable=false, ignoreMalformedDates=true, dateFormat="yyyy-mm-dd", sortable=true }, field_3={ type="boolean", searchable=false, sortable=true } }
					, type_b = { field_4={ type="string", searchable=false, sortable=true }, field_5={ type="number", sortable=true }, field_6={ type="string", analyzer="test", searchable=true, sortable=false } }
				};
				var expectedMappings = {
					type_a = { properties={
						  field_1 = { test="field_1" }
						, field_2 = { test="field_2" }
						, field_3 = { test="field_3" }
					} },
					type_b = { properties={
						  field_4 = { test="field_4" }
						, field_5 = { test="field_5" }
						, field_6 = { test="field_6" }
					} }
				};


				mockConfigReader.$( "listDocumentTypes" ).$args( indexName ).$results( docTypes.keyArray() );
				for( var dt in docTypes ){
					mockConfigReader.$( "getFields" ).$args( indexName, dt ).$results( docTypes[ dt ] );
					for( var field in docTypes[ dt ] ) {
						engine.$( "getElasticSearchMappingFromFieldConfiguration" ).$args( argumentCollection=docTypes[ dt ][ field ] ).$results( { test=field } );
					}
				}

				expect( engine.getIndexMappings( indexName ) ).toBe( expectedMappings );
			} );
		} );

		describe( "getElasticSearchMappingFromFieldConfiguration()", function(){
			it( "should return configured type", function(){
				var engine = _getSearchEngine();
				var field = { name="myfield", type="boolean" };

				var mapping = engine.getElasticSearchMappingFromFieldConfiguration( argumentCollection=field );

				expect( mapping.type ).toBe( field.type );
			} );

			it( "should return index='not_analyzed' when field is not searchable or sortable", function(){
				var engine = _getSearchEngine();
				var field = { name="myfield", type="boolean", searchable=false, sortable=false };

				var mapping = engine.getElasticSearchMappingFromFieldConfiguration( argumentCollection=field );

				expect( mapping.index ?: '' ).toBe( 'not_analyzed' );
			} );

			it( "should return analyzer when field is searchable and analyzer supplied", function(){
				var engine = _getSearchEngine();
				var field = { name="myfield", type="string", searchable=true, sortable=false, analyzer="someanalyzer" };

				var mapping = engine.getElasticSearchMappingFromFieldConfiguration( argumentCollection=field );

				expect( mapping.analyzer ?: '' ).toBe( 'someanalyzer' );
			} );

			it( "should return 'preside_sortable' analyzer when field is sortable but not searchable", function(){
				var engine = _getSearchEngine();
				var field = { name="myfield", type="string", searchable=false, sortable=true };

				var mapping = engine.getElasticSearchMappingFromFieldConfiguration( argumentCollection=field );

				expect( mapping.analyzer ?: '' ).toBe( 'preside_sortable' );
			} );

			it( "should return split definition when field is both searchable and sortable", function(){
				var engine = _getSearchEngine();
				var field = { name="myfield", type="string", searchable=true, sortable=true, analyzer="anotheranalyzer" };

				var mapping = engine.getElasticSearchMappingFromFieldConfiguration( argumentCollection=field );

				expect( mapping.type ?: '' ).toBe( "multi_field" );
				expect( mapping.fields.myfield   ?: {} ).toBe( { type="string", analyzer="anotheranalyzer" } );
				expect( mapping.fields.untouched ?: {} ).toBe( { type="string", analyzer="preside_sortable" } );
			} );

			it( "should return dateformat and ignore malformed options when type is date", function(){
				var engine = _getSearchEngine();
				var field = { name="myfield", type="date", searchable=false, sortable=true, analyzer="anotheranalyzer", dateFormat="yyyy-MM-d", ignoreMalformedDates=true };

				var mapping = engine.getElasticSearchMappingFromFieldConfiguration( argumentCollection=field );

				expect( mapping ).toBe( { type="date", analyzer="preside_sortable", format="yyyy-MM-d", ignore_malformed=true } );
			} );
		} );

		describe( "deleteRecord", function(){
			it( "should calculate the index and document type based on the passed object name", function(){
				var engine       = _getSearchEngine();
				var recordId     = CreateUUId();
				var object       = "some_object";
				var indexName    = "myindex";
				var documentType = "somedoctype";

				mockConfigReader.$( "getObjectConfiguration" ).$args( object ).$results({
					  indexName    = indexName
					, documentType = documentType
				} );

				mockApiWrapper.$( "deleteDoc", true );

				engine.deleteRecord( objectName=object, id=recordId );

				expect( mockApiWrapper.$callLog().deleteDoc.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().deleteDoc[1] ).toBe( {
					  index = indexName
					, type  = documentType
					, id    = recordId
				} );
			} );
		} );

		describe( "indexRecord", function(){
			it( "should fectch record's data from getDataForSearchEngine() method on the record's object", function(){
				var engine       = _getSearchEngine();
				var recordId     = CreateUUId();
				var objectName   = "some_object";
				var object       = getMockbox().createStub();
				var data         = { id=recordId, test="this" };
				var indexName    = "myindex";
				var documentType = "somedoctype";

				object.$( "getDataForSearchEngine" ).$args( recordId ).$results( [ data ] );
				mockApiWrapper.$( "addDoc", {} );
				mockPresideObjectService.$( "getObject" ).$args( objectName ).$results( object );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					  indexName    = indexName
					, documentType = documentType
				} );

				engine.indexRecord( objectName, recordId );

				expect( mockApiWrapper.$callLog().addDoc.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().addDoc[1] ).toBe( {
					  index = indexName
					, type  = documentType
					, doc   = data
					, id    = recordId
				} );
			} );

			it( "should delete the record from the index when no records returned from the getDataForSearchEngine() method", function(){
				var engine       = _getSearchEngine();
				var recordId     = CreateUUId();
				var objectName   = "some_object";
				var object       = getMockbox().createStub();
				var data         = { id=recordId, test="this" };
				var indexName    = "myindex";
				var documentType = "somedoctype";

				object.$( "getDataForSearchEngine" ).$args( recordId ).$results( [] );
				mockApiWrapper.$( "addDoc", {} );
				mockApiWrapper.$( "deleteDoc", true );
				mockPresideObjectService.$( "getObject" ).$args( objectName ).$results( object );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					  indexName    = indexName
					, documentType = documentType
				} );

				engine.indexRecord( objectName, recordId );

				expect( mockApiWrapper.$callLog().addDoc.len() ).toBe( 0 );
				expect( mockApiWrapper.$callLog().deleteDoc.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().deleteDoc[1] ).toBe( {
					  index = indexName
					, type  = documentType
					, id    = recordId
				} );
			} );
		} );
	}

// PRIVATE HELPERS
	private function _getSearchEngine() output=false {
		mockConfigReader         = getMockBox().createEmptyMock( "elasticsearch.services.ElasticSearchPresideObjectConfigurationReader" );
		mockApiWrapper           = getMockBox().createEmptyMock( "elasticsearch.services.ElasticSearchApiWrapper" );
		mockPresideObjectService = getMockBox().createStub();

		var engine = getMockBox().createMock( object=CreateObject( "elasticsearch.services.ElasticSearchEngine" ) );

		engine.$( "_checkIndexesExist" );

		return engine.init(
			  configurationReader  = mockConfigReader
			, apiWrapper           = mockApiWrapper
			, presideObjectService = mockPresideObjectService
		);
	}

}