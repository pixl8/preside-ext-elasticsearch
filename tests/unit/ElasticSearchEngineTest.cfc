component extends="testbox.system.BaseSpec" {

	function run() {

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

				engine.$( "_createAlias", {} );
				engine.$( "createIndex", CreateUUId() );
				engine.$( "rebuildIndex", true );
				engine.$( "cleanupOldIndexes" );

				engine.ensureIndexesExist();

				expect( engine.$callLog().createIndex.len() ).toBe( 4 );
				expect( engine.$callLog().createIndex[1] ).toBe( [ "ix_1" ] );
				expect( engine.$callLog().createIndex[2] ).toBe( [ "ix_3" ] );
				expect( engine.$callLog().createIndex[3] ).toBe( [ "ix_4" ] );
				expect( engine.$callLog().createIndex[4] ).toBe( [ "ix_6" ] );

			} );

			it( "should alias each new created index with the index name", function(){
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

				uniqueIndexes = [ "ux1", "ux2", "ux3", "ux4" ];
				engine.$( "createIndex" ).$results( uniqueIndexes[1], uniqueIndexes[2], uniqueIndexes[3], uniqueIndexes[4] );
				engine.$( "rebuildIndex", true );
				engine.$( "_createAlias", {} );
				engine.$( "cleanupOldIndexes" );

				engine.ensureIndexesExist();

				expect( engine.$callLog()._createAlias.len() ).toBe( 4 );
				expect( engine.$callLog()._createAlias[1] ).toBe( { index=uniqueIndexes[1], alias="ix_1" } );
				expect( engine.$callLog()._createAlias[2] ).toBe( { index=uniqueIndexes[2], alias="ix_3" } );
				expect( engine.$callLog()._createAlias[3] ).toBe( { index=uniqueIndexes[3], alias="ix_4" } );
				expect( engine.$callLog()._createAlias[4] ).toBe( { index=uniqueIndexes[4], alias="ix_6" } );
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

				expect( engine.createIndex( indexName ) ).toBe( uniqueIndexName );

				expect( mockApiWrapper.$callLog().createIndex.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().createIndex[1].index ?: "" ).toBe( uniqueIndexName );
			} );

			it( "should pass configured index settings to the elasticsearch server", function(){
				var engine             = _getSearchEngine();
				var indexName       = "My index";
				var uniqueIndexName = CreateUUId();
				var settings        = { test=true, settings=245 };

				engine.$( "createUniqueIndexName" ).$args( indexName ).$results( uniqueIndexName );
				engine.$( "getIndexSettings" ).$args( indexName ).$results( settings);
				mockApiWrapper.$( "createIndex", {} );

				engine.createIndex( indexName );

				expect( mockApiWrapper.$callLog().createIndex.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().createIndex[1].settings ?: {} ).toBe( settings );
			} );
		} );

		describe( "rebuildIndex()", function(){
			it( "should create a new version of the index with a unique name", function(){
				var engine          = _getSearchEngine();
				var indexName       = "myindex";
				var uniqueIndexName = CreateUUId();


				mockApiWrapper.$( "addAlias", {} );
				mockApiWrapper.$( "deleteIndex", {} );
				engine.$( "isIndexReindexing", false );
				engine.$( "_objectIsUsingSiteTenancy", false );
				engine.$( "setIndexingStatus" );
				engine.$( "createIndex" ).$args( indexName ).$results( uniqueIndexName );
				mockConfigReader.$( "listObjectsForIndex", [] );
				engine.$( "indexAllRecords", true );
				engine.$( "cleanupOldIndexes" );

				engine.rebuildIndex( indexName );

				expect( engine.$callLog().createIndex.len() ).toBe( 1 );
				expect( engine.$callLog().createIndex[1] ).toBe( [ indexName ] );
			} );

			it( "should loop over the objects configured for the index and index all their docs", function(){
				var engine          = _getSearchEngine();
				var indexName       = "myindex";
				var uniqueIndexName = CreateUUId();
				var objects         = [ "obj1", "obj2", "obj3", "obj4" ];

				mockApiWrapper.$( "addAlias", {} );
				mockApiWrapper.$( "deleteIndex", {} );
				engine.$( "isIndexReindexing", false );
				engine.$( "_objectIsUsingSiteTenancy", false );
				engine.$( "_isPageType", false );
				engine.$( "setIndexingStatus" );
				engine.$( "createIndex" ).$args( indexName ).$results( uniqueIndexName );
				mockConfigReader.$( "listObjectsForIndex" ).$args( indexName ).$results( objects );
				for( var objName in objects ){
					engine.$( "indexAllRecords" ).$args( objName, uniqueIndexName, indexName ).$results( true );
				}
				engine.$( "cleanupOldIndexes" );

				engine.rebuildIndex( indexName );

				expect( engine.$callLog().indexAllRecords.len() ).toBe( objects.len() );
				var i=0;
				for( var objName in objects ){
					expect( engine.$callLog().indexAllRecords[++i] ).toBe( [ objName, uniqueIndexName, indexName, NullValue() ] );
				}
			} );

			it( "should repoint the index alias to the newly created index", function(){
				var engine          = _getSearchEngine();
				var indexName       = "myindex";
				var uniqueIndexName = CreateUUId();

				mockApiWrapper.$( "addAlias", {} );
				mockApiWrapper.$( "deleteIndex", {} );
				engine.$( "isIndexReindexing", false );
				engine.$( "_objectIsUsingSiteTenancy", false );
				engine.$( "_isPageType", false );
				engine.$( "setIndexingStatus" );
				engine.$( "createIndex" ).$args( indexName ).$results( uniqueIndexName );
				mockConfigReader.$( "listObjectsForIndex", [ "someobject "] );
				engine.$( "indexAllRecords", true );
				engine.$( "cleanupOldIndexes" );

				engine.rebuildIndex( indexName );

				expect( mockApiWrapper.$callLog().addAlias.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().addAlias[1] ).toBe( { index=uniqueIndexName, alias=indexName } );
			} );

			it( "should delete old unused indexes", function(){
				var engine          = _getSearchEngine();
				var indexName       = "myindex";
				var uniqueIndexName = CreateUUId();

				mockApiWrapper.$( "addAlias", {} );
				mockApiWrapper.$( "deleteIndex", {} );
				engine.$( "isIndexReindexing", false );
				engine.$( "_objectIsUsingSiteTenancy", false );
				engine.$( "_isPageType", false );
				engine.$( "setIndexingStatus" );
				engine.$( "createIndex" ).$args( indexName ).$results( uniqueIndexName );
				mockConfigReader.$( "listObjectsForIndex", [ "someobject" ] );
				engine.$( "indexAllRecords", true );
				engine.$( "cleanupOldIndexes" );

				engine.rebuildIndex( indexName );

				expect( engine.$callLog().cleanupOldIndexes.len() ).toBe( 1 );
				expect( engine.$callLog().cleanupOldIndexes[1] ).toBe( { keepIndex=uniqueIndexName, alias=indexName } );
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
					  type_a = { field_x={ fieldName="field_1", type="string", searchable=true, sortable=true }, field_2={ fieldName="field_2", type="date", searchable=false, ignoreMalformedDates=true, dateFormat="yyyy-mm-dd", sortable=true }, field_3={ fieldName="field_3", type="boolean", searchable=false, sortable=true } }
					, type_b = { field_x={ fieldName="field_4", type="string", searchable=false, sortable=true }, field_5={ fieldName="field_5", type="number", sortable=true }, field_6={ fieldName="field_6", type="string", analyzer="test", searchable=true, sortable=false } }
				};
				var expectedMappings = {
					type_a = { properties={
						  field_1 = { test="field_1" }
						, field_2 = { test="field_2" }
						, field_3 = { test="field_3" }
						, access_restricted = { type="boolean" }
					} },
					type_b = { properties={
						  field_4 = { test="field_4" }
						, field_5 = { test="field_5" }
						, field_6 = { test="field_6" }
						, access_restricted = { type="boolean" }
					} }
				};

				mockConfigReader.$( "listDocumentTypes" ).$args( indexName ).$results( docTypes.keyArray() );
				for( var dt in docTypes ){
					mockConfigReader.$( "getFields" ).$args( indexName, dt ).$results( docTypes[ dt ] );
					for( var field in docTypes[ dt ] ) {
						engine.$( "getElasticSearchMappingFromFieldConfiguration" ).$args( argumentCollection=docTypes[ dt ][ field ], name=docTypes[ dt ][ field ].fieldName ).$results( { test=docTypes[ dt ][ field ].fieldName } );
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

		describe( "deleteRecord()", function(){
			it( "should calculate the index and document type based on the passed object name", function(){
				var engine       = _getSearchEngine();
				var recordId     = CreateUUId();
				var object       = "some_object";
				var indexName    = "myindex";
				var documentType = "somedoctype";

				mockConfigReader.$( "isObjectSearchEnabled" ).$args( object ).$results( true );
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

		describe( "indexRecord()", function(){
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
				mockConfigReader.$( "isObjectSearchEnabled" ).$args( objectName ).$results( true );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					  indexName        = indexName
					, documentType     = documentType
					, hasOwnDataGetter = true
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
				var indexName    = "myindex";
				var documentType = "somedoctype";

				object.$( "getDataForSearchEngine" ).$args( recordId ).$results( [] );
				mockApiWrapper.$( "addDoc", {} );
				mockApiWrapper.$( "deleteDoc", true );
				mockPresideObjectService.$( "getObject" ).$args( objectName ).$results( object );
				mockConfigReader.$( "isObjectSearchEnabled" ).$args( objectName ).$results( true );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					  indexName        = indexName
					, documentType     = documentType
					, hasOwnDataGetter = true
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

			it( "should automatically get the record's data itself when the object does not provide a getDataForSearchEngine() method", function(){
				var engine       = _getSearchEngine();
				var recordId     = CreateUUId();
				var objectName   = "some_object";
				var object       = getMockbox().createStub();
				var data         = { id=recordId, test="this" };
				var indexName    = "myindex";
				var documentType = "somedoctype";

				mockApiWrapper.$( "addDoc", {} );
				mockPresideObjectService.$( "getObject" ).$args( objectName ).$results( object );
				mockConfigReader.$( "isObjectSearchEnabled" ).$args( objectName ).$results( true );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					  indexName        = indexName
					, documentType     = documentType
					, hasOwnDataGetter = false
				} );
				engine.$( "getObjectDataForIndexing" ).$args( objectName, recordId ).$results( [ data ] );

				engine.indexRecord( objectName, recordId );

				expect( mockApiWrapper.$callLog().addDoc.len() ).toBe( 1 );
				expect( mockApiWrapper.$callLog().addDoc[1] ).toBe( {
					  index = indexName
					, type  = documentType
					, doc   = data
					, id    = recordId
				} );
			} );
		} );

		describe( "indexAllRecords()", function(){
			it( "should pump 100 records at a time into the elasticsearch server until the getPaginatedRecordsForObject() method returns no more data", function(){
				var engine            = _getSearchEngine();
				var oneHundredRecords = [];
				var objectName        = "testObject";
				var indexName         = "someindex" & CreateUUId();
				var indexAlias        = "someindex";
				var documentType      = "somedoctype";

				engine.$( "isIndexReindexing" ).$args( indexAlias ).$results( true );
				mockConfigReader.$( "isObjectSearchEnabled" ).$args( objectName ).$results( true );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					documentType = documentType
				} );
				for( var i=1; i < 100; i++ ){
					oneHundredRecords.append( { id=CreateUUId(), test=i } );
				}
				for( var i=1; i < 5; i++ ){
					engine.$( "getPaginatedRecordsForObject" ).$args(
						  objectName = objectName
						, pageSize   = 100
						, page       = i
					).$results( i == 4 ? [] : oneHundredRecords );
				}

				mockApiWrapper.$( "addDocs", {} );

				engine.indexAllRecords( objectName, indexName, indexAlias );

				expect( mockApiWrapper.$callLog().addDocs.len() ).toBe( 3 );
				for( var i=1; i < 4; i++ ){
					expect( mockApiWrapper.$callLog().addDocs[i] ).toBe( {
						  index   = indexName
						, type    = documentType
						, docs    = oneHundredRecords
						, idField = "id"
					} );
				}
			} );
		} );

		describe( "calculateSelectFieldsForIndexing()", function(){
			it( "should return an array of field names that are configured for search on the object", function(){
				var engine           = _getSearchEngine();
				var objectName       = "myobj";
				var configuredFields = [ "id", "field1", "field2" ];

				mockPresideObjectService.$( "getObjectAttribute", false );
				mockPresideObjectService.$( "isManyToManyProperty", false );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ fields = configuredFields } );

				expect( engine.calculateSelectFieldsForIndexing( objectName) ).toBe( [ "myobj.id", "myobj.field1", "myobj.field2" ] );
			} );

			it( "should return a group_concat call for fields that have a many-to-many relationship", function(){
				var engine           = _getSearchEngine();
				var objectName       = "myobj";
				var configuredFields = [ "id", "field1", "field2", "field3", "field4" ];

				mockPresideObjectService.$( "getObjectAttribute", false );
				mockPresideObjectService.$( "isManyToManyProperty" ).$args( objectName, "field1" ).$results( true );
				mockPresideObjectService.$( "isManyToManyProperty" ).$args( objectName, "field3" ).$results( true );
				mockPresideObjectService.$( "isManyToManyProperty", false );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ fields = configuredFields } );

				expect( engine.calculateSelectFieldsForIndexing( objectName) ).toBe( [ "myobj.id", "group_concat( distinct field1.id ) as field1", "myobj.field2", "group_concat( distinct field3.id ) as field3", "myobj.field4" ] );
			} );

			it( "should return additional field selections from the page object when the object is a page type", function(){
				var engine           = _getSearchEngine();
				var objectName       = "myobj";
				var configuredFields = [ "id", "field1", "field2", "field3", "field4" ];
				var pageFields = [ "id", "pageField1", "pageField2", "field3", "field4" ];

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "isPageType", false ).$results( true );
				mockPresideObjectService.$( "isManyToManyProperty" ).$args( "page", "pageField2" ).$results( true );
				mockPresideObjectService.$( "isManyToManyProperty", false );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ fields = configuredFields } );
				mockConfigReader.$( "getObjectConfiguration" ).$args( "page" ).$results({ fields = pageFields } );

				expect( engine.calculateSelectFieldsForIndexing( objectName) ).toBe( [ "myobj.id", "myobj.field1", "myobj.field2", "myobj.field3", "myobj.field4", "page.pageField1", "group_concat( distinct page$pageField2.id ) as pageField2" ] );
			} );
		} );

		describe( "getObjectDataForIndexing()", function(){
			it( "should select data from the object using any configured filters", function(){
				var engine       = _getSearchEngine();
				var objectName   = "myobj";
				var selectFields = [ "myobj.id", "myobj.field1", "myobj.field2" ];
				var filters      = [ "filterx", "filtery" ];

				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ indexFilters = filters } );
				mockPresideObjectService.$( "selectData", QueryNew('') );
				engine.$( "calculateSelectFieldsForIndexing" ).$args( objectName ).$results( selectFields );
				engine.$( "convertQueryToArrayOfDocs", [] );
				engine.$( "_isPageType", false );

				engine.getObjectDataForIndexing( objectName );

				expect( mockPresideObjectService.$callLog().selectData.len() ).toBe( 1 );
				expect( mockPresideObjectService.$callLog().selectData[1] ).toBe( {
					  objectName   = objectName
					, selectFields = selectFields
					, savedFilters = filters
					, groupBy      = objectName & ".id"
					, maxRows      = 100
					, startRow     = 1
				} );
			} );

			it( "should filter data by id when id passed", function(){
				var engine       = _getSearchEngine();
				var objectName   = "myobj";
				var selectFields = [ "myobj.id", "myobj.field1", "myobj.field2" ];
				var filters      = [ "filterx", "filtery" ];
				var id           = CreateUUId();

				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ indexFilters = filters } );
				mockPresideObjectService.$( "selectData", QueryNew('') );
				engine.$( "calculateSelectFieldsForIndexing" ).$args( objectName ).$results( selectFields );
				engine.$( "convertQueryToArrayOfDocs", [] );
				engine.$( "_isPageType", false );

				engine.getObjectDataForIndexing( objectName=objectName, id=id );

				expect( mockPresideObjectService.$callLog().selectData.len() ).toBe( 1 );
				expect( mockPresideObjectService.$callLog().selectData[1] ).toBe( {
					  objectName   = objectName
					, selectFields = selectFields
					, filter       = { "#objectName#.id" = id }
					, savedFilters = filters
					, groupBy      = objectName & ".id"
					, maxRows      = 100
					, startRow     = 1
				} );
			} );

			it( "should use maxRows and startRow values when passed", function(){
				var engine       = _getSearchEngine();
				var objectName   = "myobj";
				var selectFields = [ "myobj.id", "myobj.field1", "myobj.field2" ];
				var filters      = [ "filterx", "filtery" ];
				var startRow     = 501;
				var maxRows      = 500;

				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ indexFilters = filters } );
				mockPresideObjectService.$( "selectData", QueryNew('') );
				engine.$( "calculateSelectFieldsForIndexing" ).$args( objectName ).$results( selectFields );
				engine.$( "convertQueryToArrayOfDocs", [] );
				engine.$( "_isPageType", false );

				engine.getObjectDataForIndexing( objectName=objectName, startRow=startRow, maxRows=maxRows );

				expect( mockPresideObjectService.$callLog().selectData.len() ).toBe( 1 );
				expect( mockPresideObjectService.$callLog().selectData[1] ).toBe( {
					  objectName   = objectName
					, selectFields = selectFields
					, savedFilters = filters
					, groupBy      = objectName & ".id"
					, maxRows      = maxRows
					, startRow     = startRow
				} );
			} );

			it( "should convert recordset to array of structs", function(){
				var engine       = _getSearchEngine();
				var objectName   = "myobj";
				var selectFields = [ "myobj.id", "myobj.field1", "myobj.field2" ];
				var filters      = [ "filterx", "filtery" ];
				var records      = QueryNew( 'id,field1,field2' );
				var docs         = [ { test=true }, { another="test" } ];

				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({ indexFilters = filters } );
				mockPresideObjectService.$( "selectData", records );
				engine.$( "calculateSelectFieldsForIndexing" ).$args( objectName ).$results( selectFields );
				engine.$( "convertQueryToArrayOfDocs" ).$args( objectName, records ).$results( docs );
				engine.$( "_isPageType", false );

				expect( engine.getObjectDataForIndexing( objectName=objectName ) ).toBe( docs );
			} );
		} );

		describe( "getPaginatedRecordsForObject()", function(){
			it( "should fetch records from object's own data getter method when object has it's own data getter method", function(){
				var engine       = _getSearchEngine();
				var objectName   = "some_object";
				var object       = getMockbox().createStub();

				object.$( "getDataForSearchEngine", [] );
				mockPresideObjectService.$( "getObject" ).$args( objectName ).$results( object );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					hasOwnDataGetter = true
				} );

				engine.getPaginatedRecordsForObject( objectName=objectName, page=1, pageSize=100 );

				expect( object.$callLog().getDataForSearchEngine.len() ).toBe( 1 );
				expect( object.$callLog().getDataForSearchEngine[1] ).toBe( {
					  startRow = 1
					, maxRows  = 100
				} );
			} );

			it( "should fetch records from auto data getter when object does not have its own data getter", function(){
				var engine       = _getSearchEngine();
				var objectName   = "some_object";

				engine.$( "getObjectDataForIndexing", [] );
				mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results({
					hasOwnDataGetter = false
				} );

				engine.getPaginatedRecordsForObject( objectName=objectName, page=3, pageSize=50 );

				expect( engine.$callLog().getObjectDataForIndexing.len() ).toBe( 1 );
				expect( engine.$callLog().getObjectDataForIndexing[1] ).toBe( {
					  objectName = objectName
					, startRow   = 101
					, maxRows    = 50
				} );
			} );
		} );

		describe( "search()", function(){
			it( "should search with all specified indexes and no types when no objects specified", function(){
				var engine = _getSearchEngine();

				mockApiWrapper.$( "search", {} );
				mockResultsFactory.$( "newSearchResult", {} );
				mockConfigReader.$( "listIndexes", [ "test", "indexes", "here" ] );

				engine.search();

				var callLog = mockApiWrapper.$callLog().search;

				expect( callLog.len() ).toBe( 1 );
				expect( callLog[1].index ?: "" ).toBe( "test,indexes,here" );
				expect( callLog[1].type ?: "" ).toBe( "" );
			} );

			it( "should calculate the indexes and document types to search against based on the passed in object names", function(){
				var engine = _getSearchEngine();
				var objects = {
					  object1 = { indexName="index1", documentType="obj1" }
					, object2 = { indexName="index1", documentType="obj2" }
					, object3 = { indexName="index2", documentType="obj3" }
				};

				mockApiWrapper.$( "search", {} );
				mockResultsFactory.$( "newSearchResult", {} );
				for( var objectName in objects ){
					mockConfigReader.$( "getObjectConfiguration" ).$args( objectName ).$results( objects[ objectName ] );
				}

				engine.search( objects=objects.keyArray().sort( "text" ) );

				var callLog = mockApiWrapper.$callLog().search;

				expect( callLog.len() ).toBe( 1 );
				expect( callLog[1].index ?: "" ).toBe( "index1,index2" );
				expect( callLog[1].type ?: "" ).toBe( "obj1,obj2,obj3" );
			} );

			it( "should pass default search options through to the API", function(){
				var engine = _getSearchEngine();
				var defaults = {
					  q               = "*"
					, fieldList       = ""
					, queryFields     = ""
					, sortOrder       = ""
					, page            = 1
					, pageSize        = 10
					, defaultOperator = "OR"
					, highlightFields = ""
					, minimumScore    = 0
					, basicFilter     = {}
				};

				mockApiWrapper.$( "search", {} );
				mockResultsFactory.$( "newSearchResult", {} );
				mockConfigReader.$( "listIndexes", [ "test", "indexes", "here" ] );

				engine.search();

				var callLog = mockApiWrapper.$callLog().search;

				expect( callLog.len() ).toBe( 1 );

				for( var def in defaults ){
					expect( callLog[1][def] ?: "" ).toBe( defaults[def] );
				}
			} );

			it( "should pass supplied search options through to the API", function(){
				var engine = _getSearchEngine();
				var args = {
					  q               = "my query"
					, fieldList       = "fiel1,field2"
					, queryFields     = "field1,field2"
					, sortOrder       = "somesort order"
					, page            = 2
					, pageSize        = 11
					, defaultOperator = "AND"
					, highlightFields = "field1,field2"
					, minimumScore    = 0.002
					, basicFilter     = { x="y" }
				};

				mockApiWrapper.$( "search", {} );
				mockResultsFactory.$( "newSearchResult", {} );
				mockConfigReader.$( "listIndexes", [ "test", "indexes", "here" ] );

				engine.search( argumentCollection=args );

				var callLog = mockApiWrapper.$callLog().search;

				expect( callLog.len() ).toBe( 1 );

				for( var arg in args ){
					expect( callLog[1][arg] ?: "" ).toBe( args[arg] );
				}
			} );

			it( "should return a search results object translated from the raw response", function(){
				var engine      = _getSearchEngine();
				var rawResponse = { test="response" };
				var converted   = { converted="response", is=true, it="is" };
				var args        = {
					  q               = "test q"
					, fieldList       = "fiel1,field2"
					, queryFields     = "field1,field2"
					, page            = 2
					, pageSize        = 11
					, highlightFields = "field1,field2"
				};

				mockConfigReader.$( "listIndexes", [ "test", "indexes", "here" ] );
				mockApiWrapper.$( "search", rawResponse );
				mockResultsFactory.$( "newSearchResult" ).$args(
					  rawResult       = rawResponse
					, page            = args.page
					, pageSize        = args.pageSize
					, returnFields    = args.fieldList
					, highlightFields = args.highlightFields
					, q               = args.q
				).$results( converted );

				expect( engine.search( argumentCollection=args ) ).toBe( converted );
			} );
		} );

		describe( "isIndexReindexing()", function(){
			it( "should return false when no status db record exists for the index that is flagged as currently indexing", function(){
				var engine    = _getSearchEngine();
				var indexName = "myIndex";

				mockStatusDao.$( "selectData" ).$args(
					  selectFields = [ "indexing_expiry" ]
					, filter       = { index_name=indexName, is_indexing=true }
					, useCache     = false
				).$results( QueryNew( "indexing_expiry" ) );

				expect( engine.isIndexReindexing( indexName ) ).toBeFalse();
			} );

			it( "should return true when record exists and expiry date has not passed", function(){
				var engine       = _getSearchEngine();
				var indexName    = "myIndex";
				var statusRecord = QueryNew( "indexing_expiry", "varchar", [ [ DateAdd( "d", 1, Now() ) ] ] );

				mockStatusDao.$( "selectData" ).$args(
					  selectFields = [ "indexing_expiry" ]
					, filter       = { index_name=indexName, is_indexing=true }
					, useCache     = false
				).$results( statusRecord );

				expect( engine.isIndexReindexing( indexName ) ).toBeTrue();
			} );

			it( "should return false when indexing status record exists but expiry date has expired", function(){
				var engine       = _getSearchEngine();
				var indexName    = "myIndex";
				var statusRecord = QueryNew( "indexing_expiry", "varchar", [ [ DateAdd( "d", -1, Now() ) ] ] );

				engine.$( "setIndexingStatus" );

				mockStatusDao.$( "selectData" ).$args(
					  selectFields = [ "indexing_expiry" ]
					, filter       = { index_name=indexName, is_indexing=true }
					, useCache     = false
				).$results( statusRecord );

				expect( engine.isIndexReindexing( indexName ) ).toBeFalse();
			} );

			it( "should clear the indexing status when indexing status record exists but expiry date has expired", function(){
				var engine       = _getSearchEngine();
				var indexName    = "myIndex";
				var statusRecord = QueryNew( "indexing_expiry", "varchar", [ [ DateAdd( "d", -1, Now() ) ] ] );

				engine.$( "setIndexingStatus" );

				mockStatusDao.$( "selectData" ).$args(
					  selectFields = [ "indexing_expiry" ]
					, filter       = { index_name=indexName, is_indexing=true }
					, useCache     = false
				).$results( statusRecord );

				engine.isIndexReindexing( indexName );

				expect( engine.$callLog().setIndexingStatus.len() ).toBe( 1 );
				expect( engine.$callLog().setIndexingStatus[1] ).toBe( {
					  indexName               = indexName
					, isIndexing              = false
					, lastIndexingSuccess     = false
					, indexingStartedAt       = ""
					, indexingExpiry          = ""
					, lastIndexingCompletedAt = ""
					, lastIndexingTimetaken   = ""
				} );
			} );
		} );
	}

// PRIVATE HELPERS
	private function _getSearchEngine() {
		mockConfigReader               = getMockBox().createEmptyMock( "elasticsearch.services.ElasticSearchPresideObjectConfigurationReader" );
		mockApiWrapper                 = getMockBox().createEmptyMock( "elasticsearch.services.ElasticSearchApiWrapper" );
		mockResultsFactory             = getMockBox().createEmptyMock( "elasticsearch.services.ElasticSearchResultsFactory" );
		mockPresideObjectService       = getMockBox().createStub();
		mockContentRenderer            = getMockBox().createStub();
		mockInterceptorService         = getMockBox().createStub();
		mockPageDao                    = getMockBox().createStub();
		mockSiteService                = getMockBox().createStub();
		mockSiteTreeService            = getMockBox().createStub();
		mockStatusDao                  = getMockBox().createStub();
		mockSystemConfigurationService = getMockBox().createStub();

		mockColdbox                    = getMockBox().createStub();
		mockRequestContext             = getMockBox().createStub();
		mockSite                       = getMockBox().createStub();
		mockSites                      = [ { id=CreateUUId(), name="test site" } ];

		var engine      = getMockBox().createMock( object=CreateObject( "elasticsearch.services.ElasticSearchEngine" ) );

		engine.$( "_checkIndexesExist" );
		engine.$( "_announceInterception", {} );
		engine.$( "_getConfigurationReader"       , mockConfigReader               );
		engine.$( "_getApiWrapper"                , mockApiWrapper                 );
		engine.$( "_getPresideObjectService"      , mockPresideObjectService       );
		engine.$( "_getContentRendererService"    , mockContentRenderer            );
		engine.$( "_getInterceptorService"        , mockInterceptorService         );
		engine.$( "_getPageDao"                   , mockPageDao                    );
		engine.$( "_getSiteService"               , mockSiteService                );
		engine.$( "_getSiteTreeService"           , mockSiteTreeService            );
		engine.$( "_getResultsFactory"            , mockResultsFactory             );
		engine.$( "_getStatusDao"                 , mockStatusDao                  );
		engine.$( "_getSystemConfigurationService", mockSystemConfigurationService );

		engine.$( "$getColdbox"                   , mockColdbox                    );
		mockColdbox.$( "getRequestContext"        , mockRequestContext             );
		engine.$( "getSite"                       , mockSite                       );
		engine.$( "setSite"                                                        );
		engine.$( "listSites"                     , mockSites                      );

		mockRequestContext.$( "getSite", mockSites[ 1 ] );
		mockRequestContext.$( "setSite" );
		mockSiteService.$( "listSites", mockSites );

		engine.$( "clearReindexingQueue" );
		engine.$( "processReindexingQueue" );

		return engine.init(
			  configurationReader        = mockConfigReader
			, apiWrapper                 = mockApiWrapper
			, presideObjectService       = mockPresideObjectService
			, contentRendererService     = mockContentRenderer
			, interceptorService         = mockInterceptorService
			, pageDao                    = mockPageDao
			, siteService                = mockSiteService
			, siteTreeService            = mockSiteTreeService
			, resultsFactory             = mockResultsFactory
			, statusDao                  = mockStatusDao
			, systemConfigurationService = mockSystemConfigurationService
		);
	}

}