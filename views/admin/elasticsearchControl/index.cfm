<cfscript>
	stats = prc.stats ?: {};

	errorStatus = translateResource( "cms:elasticSearchControl.statstable.stats.error" );

	canRebuild        = hasCmsPermission( "elasticsearchcontrol.rebuild" );
	showActionsColumn = canRebuild;
</cfscript>

<cfoutput>
	<div class="top-right-button-group">
		<cfif hasCmsPermission( "elasticsearchcontrol.configure" )>
			<a class="pull-right inline" href="#event.buildAdminLink( linkTo="elasticsearchcontrol.configure" )#" data-global-key="c">
				<button class="btn btn-default btn-sm">
					<i class="fa fa-cogs"></i>
					#translateResource( uri="cms:elasticsearchcontrol.configure.btn" )#
				</button>
			</a>
		</cfif>
	</div>

	<div class="table-responsive">
		<table class="table table-striped table-hover">
			<thead>
				<tr>
					<th>#translateResource( "cms:elasticSearchControl.statstable.header.index" )#</th>
					<th>#translateResource( "cms:elasticSearchControl.statstable.header.doccount" )#</th>
					<th>#translateResource( "cms:elasticSearchControl.statstable.header.state" )#</th>
					<cfif showActionsColumn>
						<th>#translateResource( "cms:elasticSearchControl.statstable.header.actions" )#</th>
					</cfif>
				</tr>
			</thead>
			<tbody data-nav-list="1" data-nav-list-child-selector="> tr">
				<cfloop collection="#stats#" index="index">
					<tr data-context-container="1">
						<td>#index#</td>
						<td>
							<cfif IsNumeric( stats[ index ].totalDocs ?: "" )>
								#NumberFormat( stats[ index ].totalDocs )#
							<cfelse>
								<em>#errorStatus#</em>
							</cfif>
						</td>
						<td>
							<cfif IsTrue( stats[index].is_indexing )>
								<i class="fa fa-fw grey fa-rotate-right"></i>
								#translateResource(
									  uri  = "cms:elasticSearchControl.statstable.indexingStatus"
									, data = [ RenderContent( "datetime", stats[index].indexing_started_at, [ "admin", "admindatatable" ] ) ]
								)#
							<cfelseif IsTrue( stats[index].last_indexing_success )>
								#renderContent( "boolean", true, [ "admindatatable", "admin" ] )#
								#translateResource(
									  uri  = "cms:elasticSearchControl.statstable.completeStatus"
									, data = [ RenderContent( "datetime", stats[index].last_indexing_completed_at, [ "admin", "admindatatable" ] ) ]
								)#
							<cfelseif IsBoolean( stats[index].last_indexing_success )>
								#renderContent( "boolean", true, [ "admindatatable", "admin" ] )#
								#translateResource(
									  uri  = "cms:elasticSearchControl.statstable.lastIndexFailed"
								)#
							<cfelse>
								<i class="fa fa-fw grey fa-question"></i>
								#translateResource(
									  uri  = "cms:elasticSearchControl.statstable.unknown"
								)#
							</cfif>
						</td>
						<cfif showActionsColumn>
							<td>
								<div class="action-buttons btn-group">
									<cfif canRebuild>
										<cfif IsTrue( stats[index].is_indexing )>
											<a href="#event.buildAdminLink( linkTo='elasticSearchControl.terminateRebuildAction', queryString='index=' & index )#" data-context-key="t" class="confirmation-prompt" title="#translateResource( uri='cms:elasticsearchcontrol.terminateRebuildIndex.prompt', data=[index] )#">
												<i class="fa fa-stop red"></i>
											</a>
										<cfelse>
											<a href="#event.buildAdminLink( linkTo='elasticSearchControl.rebuildAction', queryString='index=' & index )#" data-context-key="r" class="confirmation-prompt" title="#translateResource( uri='cms:elasticsearchcontrol.rebuildIndex.prompt', data=[index] )#">
												<i class="fa fa-rotate-right blue"></i>
											</a>
										</cfif>
									</cfif>
								</div>
							</td>
						</cfif>
					</tr>
				</cfloop>
			</tbody>
		</table>
	</div>
</cfoutput>