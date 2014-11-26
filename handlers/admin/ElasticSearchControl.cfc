component output="false" extends="preside.system.base.AdminHandler" {

	property name="elasticSearchEngine" inject="elasticSearchEngine";
	property name="messagebox"          inject="coldbox:plugin:messagebox";

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