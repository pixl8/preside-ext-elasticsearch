component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "listSearchEnabledObjects()", function(){
			it( "should return an array of objects who have 'searchEnabled' flag set to true", function(){
				var svc = _getService();
				var objects = {
					  object_a = true
					, object_b = false
					, object_c = false
					, object_d = true
					, object_e = true
					, object_f = false
					, object_g = true
				};
				var objNameArray = objects.keyArray().sort( "textnocase" );

				mockPresideObjectService.$( "listObjects", objNameArray );
				for( objectname in objects ){
					mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchEnabled", false ).$results( objects[ objectName ] );
					mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "isPageType", false ).$results( false );
				}

				expect( svc.listSearchEnabledObjects() ).toBe( [ "object_a", "object_d", "object_e", "object_g" ] );
			} );

			it( "should ignore the 'page' object", function(){
				var svc = _getService();
				var objects = {
					  object_a = true
					, page     = true
					, object_c = false
					, object_d = true
				};
				var objNameArray = objects.keyArray().sort( "textnocase" );

				mockPresideObjectService.$( "listObjects", objNameArray );
				for( objectname in objects ){
					mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchEnabled", false ).$results( objects[ objectName ] );
					mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "isPageType", false ).$results( false );
				}

				expect( svc.listSearchEnabledObjects() ).toBe( [ "object_a", "object_d" ] );
			} );
		} );

		describe( "getObjectConfiguration()", function(){
			it( "should return index name configured on object", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var indexName  = "testdefaultindex";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchIndex" ).$results( indexName );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.indexName ?: "" ).toBe( indexName );
			} );

			it( "should return default index name when object does not define its own", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var defaultIndex = "testdefaultindex";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchIndex" ).$results( "" );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );

				mockConfigurationService.$( "getSetting" ).$args( "elasticsearch", "default_index" ).$results( defaultIndex );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.indexName ?: "" ).toBe( defaultIndex );
			} );

			it( "should return document type configured on the object", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var documentType = "testtype";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchDocumentType" ).$results( documentType );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.documentType ?: "" ).toBe( documentType );
			} );

			it( "should return object name for the document type when document type not specifically configured", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var documentType = "";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchDocumentType" ).$results( documentType );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.documentType ?: "" ).toBe( objectName );
			} );

			it( "should return array of fields that are configured for the index, always including 'id'", function(){
				var svc        = _getService();
				var objectName = "some_object";
				var props      = {};

				for( var i=1; i<=5; i++ ){
					props[ "prop_" & i ] = { searchEnabled = ( i mod 2 ) };
				}

				mockPresideObjectService.$( "getObjectProperties" ).$args( objectName ).$results( props );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );

				svc.$( "doesObjectHaveDataGetterMethod", false );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( ( configuration.fields ?: [] ).sort( "textnocase" ) ).toBe( [ "id", "prop_1", "prop_3", "prop_5" ] );
			} );

			it( "should set hasOwnDataGetter to true when the object supplies its own getDataForSearchEngine() method", function(){
				var svc        = _getService();
				var objectName = "some_object";
				var props      = [];

				mockPresideObjectService.$( "getObjectProperties" ).$args( objectName ).$results( props );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				svc.$( "doesObjectHaveDataGetterMethod" ).$args( objectName ).$results( true );

				var configuration = svc.getObjectConfiguration( objectName );

				expect( configuration.hasOwnDataGetter ?: "" ).toBe( true );
			} );

			it( "should set hasOwnDataGetter to false when the object does not supply its own getDataForSearchEngine() method", function(){
				var svc        = _getService();
				var objectName = "some_object";
				var props      = [];

				mockPresideObjectService.$( "getObjectProperties" ).$args( objectName ).$results( props );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				svc.$( "doesObjectHaveDataGetterMethod" ).$args( objectName ).$results( false );

				var configuration = svc.getObjectConfiguration( objectName );

				expect( configuration.hasOwnDataGetter ?: "" ).toBe( false );
			} );

			it( "should return searchDataSource configured on the object", function(){
				var svc              = _getService();
				var objectName       = "someobject";
				var searchDataSource = "testsearchDataSource";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "seachDataSource" ).$results( searchDataSource );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.searchDataSource ?: "" ).toBe( searchDataSource );
			} );

			it( "should return an array of saved filters to use when retrieving data for indexing", function(){
				var svc          = _getService();
				var objectName   = "someobject";
				var filters      = "filter1,filter2,filter3";

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchIndexFilters" ).$results( filters );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.indexFilters ?:[] ).toBe( ListToArray( filters ) );
			} );

			it( "should return the default site search page filter when object is a page type and no filters set", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var expected   = [ "elasticSearchPageFilter", "livepages" ];

				mockPresideObjectService.$( "getObjectAttribute" ).$args( objectName, "searchIndexFilters" ).$results( "" );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );
				mockPresideObjectService.$( "getObjectProperties", [] );
				svc.$( "doesObjectHaveDataGetterMethod", false );
				svc.$( "_isPageType" ).$args( objectname ).$results( true );

				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.indexFilters ?: [] ).toBe( expected );
			} );
		} );

		describe( "getFieldConfiguration()", function(){
			it( "should return the property name as the name of the field by default", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchField", fieldName ).$results( fieldName );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.fieldName ?: "" ).toBe( fieldName );
			} );

			it( "should return configured search field name when property has a defined 'searchField' attribute that differs from the name of the property", function(){
				var svc           = _getService();
				var objectName    = "someobject";
				var fieldName     = "somefield";
				var diffFieldName = "aDifferentFieldName";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchField", fieldName ).$results( diffFieldName );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.fieldName ?: "" ).toBe( diffFieldName );
			} );

			it( "should return searchable flag that has been set on the field", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.searchable ?: "" ).toBe( false );
			} );

			it( "should return searchable flag as true when field is a string and no searchable attribute is set", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.searchable ?: "" ).toBe( true );
			} );

			it( "should always return searchable flag as false when field is not a string", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( true );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.searchable ?: "" ).toBe( false );
			} );

			it( "should return sortable flag as false when not configured", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSortable" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.sortable ?: "" ).toBe( false );
			} );

			it( "should return sortable flag as true when explicitly set", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSortable" ).$results( true );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.sortable ?: "" ).toBe( true );
			} );

			it( "should return configured analyzer when field is searchable", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";
				var analyzer   = "someAnalyzer";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchAnalyzer" ).$results( analyzer );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.analyzer ?: "" ).toBe( analyzer );
			} );

			it( "should return default analyzer when field is searchable and no analyzer configured", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";
				var analyzer   = "";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchAnalyzer" ).$results( analyzer );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.analyzer ?: "" ).toBe( "default" );
			} );

			it( "should return dateFormat property when attribute set and property type is date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";
				var dateFormat = "yyyy-mm-dd";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchDateFormat" ).$results( dateFormat );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.dateFormat ?: "" ).toBe( dateFormat );
			} );

			it( "should not return a dateFormat property when not configured", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";
				var dateFormat = "";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchDateFormat" ).$results( dateFormat );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.keyExists( "dateFormat" ) ).toBeFalse();
			} );

			it( "should return ignoreMalformedDates property when attribute set and property type is date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchIgnoreMalformed" ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.ignoreMalformedDates ?: "" ).toBe( false );
			} );

			it( "should return ignoreMalformedDates as true when attribute not set and property type is date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchIgnoreMalformed" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.ignoreMalformedDates ?: "" ).toBe( true );
			} );

			it( "it should return 'string' type when property is a string", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "string" );
			} );

			it( "it should return 'boolean' type when property is a boolean", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "boolean" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "boolean" );
			} );

			it( "it should return 'date' type when property is a date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "date" );
			} );

			it( "it should return 'integer' type when property is numeric", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "integer" );
			} );

			it( "should return string for types other tyan date, boolean, string and numeric", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "jazz" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "pk", false ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "string" );
			} );
		} );

		describe( "listIndexes()", function(){
			it( "should return an array of unique index names defined across all the objects", function(){
				var svc     = _getService();
				var objects = {
					  object_1 = { indexName="default_index" }
					, object_2 = { indexName="another_index" }
					, object_3 = { indexName="default_index" }
					, object_4 = { indexName="some_index" }
				};

				svc.$( "listSearchEnabledObjects", objects.keyArray() );
				for( var obj in objects ){
					svc.$( "getObjectConfiguration" ).$args( obj ).$results( objects[obj] );
				}

				expect( svc.listIndexes().sort( "textnocase" ) ).toBe( [ "another_index", "default_index", "some_index" ] );
			} );
		} );

		describe( "listDocumentTypes()", function(){
			it( "should return a unique array of document types for the given index", function(){
				var svc     = _getService();
				var objects = {
					  object_1 = { indexName="default_index", documentType="doctype_1" }
					, object_2 = { indexName="another_index", documentType="doctype_3" }
					, object_3 = { indexName="default_index", documentType="doctype_1" }
					, object_4 = { indexName="some_index"   , documentType="doctype_2" }
					, object_5 = { indexName="default_index", documentType="doctype_1" }
					, object_6 = { indexName="default_index", documentType="doctype_4" }
					, object_7 = { indexName="default_index", documentType="doctype_2" }
				};

				svc.$( "listSearchEnabledObjects", objects.keyArray() );
				for( var obj in objects ){
					svc.$( "getObjectConfiguration" ).$args( obj ).$results( objects[obj] );
				}

				expect( svc.listDocumentTypes( "default_index" ).sort( "textnocase" ) ).toBe( [ "doctype_1", "doctype_2", "doctype_4" ] );
			} );
		} );

		describe( "getFields()", function(){
			it( "should return field configurations for the given index and doc type", function(){
				var svc     = _getService();
				var objects = {
					  object_1 = { indexName="default_index", documentType="doctype_1", fields=[ "title", "body", "date", "object_1_field" ] }
					, object_2 = { indexName="another_index", documentType="doctype_3", fields=[ "title", "body", "date", "object_2_field" ] }
					, object_3 = { indexName="default_index", documentType="doctype_1", fields=[ "title", "body", "date", "object_3_field" ] }
					, object_4 = { indexName="some_index"   , documentType="doctype_2", fields=[ "title", "body", "date", "object_4_field" ] }
					, object_5 = { indexName="default_index", documentType="doctype_1", fields=[ "title", "body", "date", "object_5_field" ] }
					, object_6 = { indexName="default_index", documentType="doctype_4", fields=[ "title", "body", "date", "object_6_field" ] }
					, object_7 = { indexName="default_index", documentType="doctype_2", fields=[ "title", "body", "date", "object_7_field" ] }
				};


				svc.$( "listSearchEnabledObjects", objects.keyArray() );
				for( var obj in objects ){
					svc.$( "getObjectConfiguration" ).$args( obj ).$results( objects[obj] );
				}

				svc.$( "getFieldConfiguration" ).$args( "object_4", "title"          ).$results( { title          = "title"          } );
				svc.$( "getFieldConfiguration" ).$args( "object_4", "body"           ).$results( { body           = "body"           } );
				svc.$( "getFieldConfiguration" ).$args( "object_4", "date"           ).$results( { date           = "date"           } );
				svc.$( "getFieldConfiguration" ).$args( "object_4", "object_4_field" ).$results( { object_4_field = "object_4_field" } );
				svc.$( "getFieldConfiguration", { dummy="configuration" } );
				mockPresideObjectService.$( "getObjectAttribute", false );

				var fields = svc.getFields( "some_index", "doctype_2" );

				expect( fields ).toBe( {
					  title          = { title          = "title"          }
					, body           = { body           = "body"           }
					, date           = { date           = "date"           }
					, object_4_field = { object_4_field = "object_4_field" }
				} );
			} );

			it( "should merge fields from 'page' object when object is a page type", function(){
				var svc     = _getService();
				var objects = {
					object_1 = { indexName="default_index", documentType="doctype_1", fields=[ "title", "body" ] }
				};
				var pageObject = { fields=[ "main_body", "title", "test" ] };

				svc.$( "listSearchEnabledObjects", objects.keyArray() );
				for( var obj in objects ){
					svc.$( "getObjectConfiguration" ).$args( obj ).$results( objects[obj] );
				}

				svc.$( "_isPageType" ).$args( "object_1" ).$results( true );
				svc.$( "getObjectConfiguration" ).$args( "page" ).$results( pageObject );

				svc.$( "getFieldConfiguration" ).$args( "object_1", "title"     ).$results( { title     = "title"     } );
				svc.$( "getFieldConfiguration" ).$args( "object_1", "body"      ).$results( { body      = "body"      } );
				svc.$( "getFieldConfiguration" ).$args( "page"    , "main_body" ).$results( { main_body = "main_body" } );
				svc.$( "getFieldConfiguration" ).$args( "page"    , "test"      ).$results( { test      = "test"      } );
				svc.$( "getFieldConfiguration", { dummy="configuration" } );

				var fields = svc.getFields( "default_index", "doctype_1" );

				expect( fields ).toBe( {
					  title     = { title     = "title"     }
					, body      = { body      = "body"      }
					, main_body = { main_body = "main_body" }
					, test      = { test      = "test"      }
				} );
			} );
		} );

		describe( "doesObjectHaveDataGetterMethod()", function(){
			it( "should return true when object has getDataForSearchEngine() method", function(){
				var svc        = _getService();
				var object     = getMockBox().createStub();
				var objectName = "myObject";

				object.$( "getDataForSearchEngine", [] );

				mockPresideObjectService.$( "getObject" ).$args( objectName ).$results( object );

				expect(  svc.doesObjectHaveDataGetterMethod( objectName ) ).toBeTrue(  );
			} );
		} );

		describe( "listObjectsForIndex()", function(){
			it( "should return an array of object names who's object uses the given index", function(){
				var svc        = _getService();
				var indexName  = "myindex";
				var allObjects = {
					  obj1 = { indexName=CreateUUId() }
					, obj2 = { indexName=indexName }
					, obj3 = { indexName=indexName }
					, obj4 = { indexName=CreateUUId() }
					, obj5 = { indexName=CreateUUId() }
					, obj6 = { indexName=indexName }
				};

				svc.$( "listSearchEnabledObjects", allObjects.keyArray() );

				for( var objName in allObjects ) {
					svc.$( "getObjectConfiguration" ).$args( objName ).$results( allObjects[ objName ] );
				}

				var objectsForIndex = svc.listObjectsForIndex( indexName ).sort( "textnocase" );

				expect( objectsForIndex ).toBe( [ "obj2", "obj3", "obj6" ] );

			} );
		} );
	}

// HELPERS
	private any function _getService() {
		mockPresideObjectService = getMockBox().createStub();
		mockConfigurationService = getMockBox().createStub();

		var svc = new elasticsearch.services.ElasticSearchPresideObjectConfigurationReader(
			  presideObjectService       = mockPresideObjectService
			, systemConfigurationService = mockConfigurationService
		);

		return getMockBox().createMock( object=svc );
	}

}