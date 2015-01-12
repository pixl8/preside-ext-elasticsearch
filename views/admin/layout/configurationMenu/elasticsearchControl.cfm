<cfif hasCmsPermission( "elasticsearchControl.navigate" )>
	<cfoutput>
		<li>
			<a href="#event.buildAdminLink( linkTo='elasticsearchControl' )#">
				<i class="fa fa-fw fa-search"></i>
				#translateResource( "cms:elasticsearchControl.navigation.link" )#
			</a>
		</li>
	</cfoutput>
</cfif>