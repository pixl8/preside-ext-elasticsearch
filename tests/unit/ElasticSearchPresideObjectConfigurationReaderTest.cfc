component extends="testbox.system.BaseSpec" {

	function run() output=false {
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


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.documentType ?: "" ).toBe( objectName );
			} );

			it( "should return array of fields that are configured for the index, always including 'id'", function(){
				var svc        = _getService();
				var objectName = "some_object";
				var props      = [];

				for( var i=1; i<=5; i++ ){
					var prop = getMockBox().createStub();
					prop.$( "getAttribute" ).$args( "name" ).$results( "prop_" & i );
					mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, "prop_" & i, "searchEnabled" ).$results( i mod 2 );

					props.append( prop );
				}

				mockPresideObjectService.$( "getObjectProperties" ).$args( objectName ).$results( props );
				mockPresideObjectService.$( "getObjectAttribute", "dummy" );


				var configuration = svc.getObjectConfiguration( objectName );
				expect( configuration.fields ?: [] ).toBe( [ "prop_1", "prop_3", "prop_5", "id" ] );
			} );
		} );

		describe( "getFieldConfiguration()", function(){
			it( "should return searchable flag that has been set on the field", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.searchable ?: "" ).toBe( false );
			} );

			it( "should return searchable flag as true when field is a string and no searchable attribute is set", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.searchable ?: "" ).toBe( true );
			} );

			it( "should always return searchable flag as false when field is not a string", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSearchable" ).$results( true );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.searchable ?: "" ).toBe( false );
			} );

			it( "should return sortable flag as false when not configured", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSortable" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.sortable ?: "" ).toBe( false );
			} );

			it( "should return sortable flag as true when explicitly set", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchSortable" ).$results( true );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

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
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

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
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

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
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

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
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.keyExists( "dateFormat" ) ).toBeFalse();
			} );

			it( "should return ignoreMalformedDates property when attribute set and property type is date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchIgnoreMalformed" ).$results( false );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.ignoreMalformedDates ?: "" ).toBe( false );
			} );

			it( "should return ignoreMalformedDates as true when attribute not set and property type is date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "searchIgnoreMalformed" ).$results( "" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.ignoreMalformedDates ?: "" ).toBe( true );
			} );

			it( "it should return 'string' type when property is a string", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "string" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "string" );
			} );

			it( "it should return 'boolean' type when property is a boolean", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "boolean" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "boolean" );
			} );

			it( "it should return 'date' type when property is a date", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "date" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "date" );
			} );

			it( "it should return 'number' type when property is numeric", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "numeric" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "number" );
			} );

			it( "should return string for types other tyan date, boolean, string and numeric", function(){
				var svc        = _getService();
				var objectName = "someobject";
				var fieldName  = "somefield";

				mockPresideObjectService.$( "getObjectPropertyAttribute" ).$args( objectName, fieldName, "type" ).$results( "jazz" );
				mockPresideObjectService.$( "getObjectPropertyAttribute", "dummy" );

				var configuration = svc.getFieldConfiguration( objectName, fieldName );

				expect( configuration.type ?: "" ).toBe( "string" );
			} );
		} );
	}



// HELPERS
	private any function _getService() output=false {
		mockPresideObjectService = getMockBox().createStub();
		mockConfigurationService = getMockBox().createStub();

		return new elasticsearch.services.ElasticSearchPresideObjectConfigurationReader(
			  presideObjectService       = mockPresideObjectService
			, systemConfigurationService = mockConfigurationService
		);
	}

}