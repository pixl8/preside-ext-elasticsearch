<cfif hasCmsPermission( "elasticsearchControl.navigate" )>
	<cfoutput>
		<li<cfif listLast( event.getCurrentHandler(), ".") EQ "elasticsearchControl"> class="active"</cfif>>
			<a href="#event.buildAdminLink( linkTo='elasticsearchControl' )#">
				<i class="fa fa-search"></i>
				<span class="menu-text">#translateResource( "cms:elasticsearchControl.navigation.link" )#</span>
			</a>
		</li>
	</cfoutput>
</cfif>