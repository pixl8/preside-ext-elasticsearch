component output="false" extends="preside.system.base.AdminHandler" {

	function prehandler( event, rc, prc ) output=false {
		super.preHandler( argumentCollection = arguments );

		_checkPermissions( event=event, key="elasticSearchControl.navigate" );

		event.addAdminBreadCrumb(
			  title = translateResource( "cms:elasticSearchControl.page.crumb"  )
			, link  = event.buildAdminLink( linkTo="elasticSearchControl" )
		);
	}

	public void function index() output=false {
		prc.pageTitle    = translateResource( "cms:elasticSearchControl.page.title"    );
		prc.pageSubTitle = translateResource( "cms:elasticSearchControl.page.subtitle" );
		prc.pageIcon     = "search";
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