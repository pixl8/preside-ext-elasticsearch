component output="false" extends="preside.system.base.AdminHandler" {

	property name="elasticSearchEngine"        inject="elasticSearchEngine";
	property name="systemConfigurationService" inject="systemConfigurationService";
	property name="messagebox"                 inject="coldbox:plugin:messagebox";

	function prehandler( event, rc, prc ) output=false {
		super.preHandler( argumentCollection = arguments );

		_checkPermissions( event=event, key="elasticSearchControl.navigate" );

		event.addAdminBreadCrumb(
			  title = translateResource( "cms:elasticSearchControl.page.crumb"  )
			, link  = event.buildAdminLink( linkTo="elasticSearchControl" )
		);
	}

	public void function index( event, rc, prc ) output=false {
		prc.pageTitle    = translateResource( "cms:elasticSearchControl.page.title"    );
		prc.pageSubTitle = translateResource( "cms:elasticSearchControl.page.subtitle" );
		prc.pageIcon     = "search";

		prc.stats = elasticSearchEngine.getStats();
	}

	public void function rebuildAction( event, rc, prc ) output=false {
		var indexName = rc.index ?: "";

		_checkPermissions( event, "rebuild" );

		thread name="rebuildSearchIndex#indexName##CreateUUId()#" timeout=1200 engine=elasticSearchEngine indexName=indexName {
			attributes.engine.rebuildIndex( attributes.indexName );
		}

		messageBox.info( translateResource( uri="cms:elasticSearchControl.rebuildstarted.confirmation", data=[ indexName ] ) );

		setNextEvent( url=event.buildAdminLink( linkTo="elasticSearchControl" ) );

	}

	public void function terminateRebuildAction( event, rc, prc ) output=false {
		var indexName = rc.index ?: "";

		_checkPermissions( event, "rebuild" );

		elasticSearchEngine.terminateIndexing( indexName );

		messageBox.info( translateResource( uri="cms:elasticSearchControl.rebuildterminated.confirmation", data=[ indexName ] ) );

		setNextEvent( url=event.buildAdminLink( linkTo="elasticSearchControl" ) );
	}

	public void function configure( event, rc, prc ) output=false {
		_checkPermissions( event, "configure" );

		prc.configuration = systemConfigurationService.getCategorySettings( "elasticsearch" );

		prc.pageTitle    = translateResource( "cms:elasticSearchControl.configure.page.title"    );
		prc.pageSubTitle = translateResource( "cms:elasticSearchControl.configure.page.subtitle" );

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:elasticSearchControl.configure.page.crumbtrail" )
			, link  = event.buildAdminLink( linkTo="elasticSearchControl.configure" )
		);
	}

	public void function saveConfigurationAction( event, rc, prc ) output=false {
		_checkPermissions( event, "configure" );

		var formData = event.getCollectionForForm( "elasticsearch.config" );

		for( var setting in formData ){
			systemConfigurationService.saveSetting(
				  category = "elasticsearch"
				, setting  = setting
				, value    = formData[ setting ]
			);
		}

		messageBox.info( translateResource( uri="cms:elasticSearchControl.configuration.saved" ) );

		setNextEvent( url=event.buildAdminLink( linkTo="elasticSearchControl" ) );
	}


// PRIVATE HELPERS
	private void function _checkPermissions( required any event, required string key ) output=false {
		var permitted = true;
		var context   = "elasticSearchControl";
		var permKey   = context & "." & arguments.key;

		permitted = hasCmsPermission( permissionKey=permKey, context=context );

		if ( !permitted ) {
			event.adminAccessDenied();
		}
	}

}