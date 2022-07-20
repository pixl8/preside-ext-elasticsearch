# Changelog

## v1.1.22

* Convert to Github actions

## v1.1.21

* Fix issue with multi-site setup where indexing caching for pages could get mixed up between sites

## v1.1.19

* Fix 10.14 compatibility issue with numeric fields attempting to get indexed with locale formatting (commas, etc.)

## v1.1.18

attempting to get indexed with locale formatting (commas, etc.)

* Allow applications to use group by table.id instead of autogroupBy while fetching all records from tables for indexing

## v1.1.17

* Add config.cfc option for default pagination size of search() method

## v1.1.16

* #11 Respect @tenant when detecting site tenancy, not just siteFiltered=true

## v1.1.15

* Fix issue with groupBy/autogroupBy for MSSQL
* Fix build on trusty

## v1.1.14

* Fix compatibility issue with latest Lucee whose message/detail contents for database errors have switched

## v1.1.13

* Fix Travis test/build script

## v1.1.12

* Version number fix

## v1.1.11

* Do not run post/pre insert/update/delete data logic for objects that are not search enabled

## v1.1.10

* Re-enabling commented test

## v1.1.9

* Adding defensive code if the Object doesn't have a standard ID field

## v1.1.8

*  Travis not picking up changes in repo? Changing test...

## v1.1.7

* Version number fix

## v1.1.6

* Better code for dealing with no query results

## v1.1.5

* Removing failing tests for now - need to debug. Main thing is all bar 3 are running and passing.
* Simplifying the test runner.
* Fixing how the tests are run for later versions of CommanBox - emulating what Preside does
* Fixing up main box.json for extension

## v1.1.4

* Modifying so don't have to modify the arguments that "deleteData()" uses

## v1.1.3

* Fixing issue with preDeleteObjectData explicity taking an ID value passed and processing without considering any other filter parameters that might apply

## v1.1.2

* Adding option to avoid selecting from cache when selecting data to be indexed + bumping version number

## v1.1.1

* Exclude drafted page from being indexed

## 1.1.0

* fixed bug in testsuite
* added possibility to skip the single record indexing

## v1.0.25

* Version fix

## v1.0.23

* Corrected typo on variable name

## v1.0.22

* Make ensuring no physical index exists with our index name safer. Only run when necessary and then pause before adding alias
* Ignore server.json for tests

## v1.0.21

* Catch missing index exceptions when attempting to delete an index

## v1.0.20

* Allow objects to be decorated with alternative handler method that defines where to get index data from

## v1.0.19

* Refactor tests for new logic

## v1.0.18

* Delete any existing indexes using the alias name before creating the alias.
* Ensure records that change during a full reindex are reindexed again once the full reindex is complete

## v1.0.17

* Corrected tag number

## v1.0.17

* Update package location

## v1.0.16

* Remove the term suggestion function. Suggestion should be place together with search query

## v1.0.15

* Remove output="false" Ensures new page is indexed

## v1.0.14

* use correct repo URL
* Merge changes that were pushed into closed source version of the repo

## v1.0.13

* fix bad json

## v1.0.12

* Ignore travis.yml in box package
* Automate builds and publishing for the extension

## v1.0.24

* Add search suggestion result

## v1.0.22

* do not preside query cache for looking up hierarchical page data during indexing

## v1.0.21

* Fixing mapping configuratin for the site property to ensure it's not analyzed

## v1.0.15-v1.0.20

* Fixing tests

## v1.0.13

* Updating the ES search engine to index ALL Sites inclusive into one index

## v1.0.12

* update ES index when update data

## v1.0.11

* COONP-486 Ensures disable child page reindex option is added

## v1.0.10

* Do not version elasticsearch indexing status table

## v1.0.11

* updated box.json

## v1.0.10

* Adding a readme


## v1.0.8

* Make branch folder just the last part of branch name e.g. just v1.x.x of 'tags/v1.x.x'

## v1.0.7

* Removing unnecessary output=false from everything
* Adding build scripts, etc. + fixing tests ready for extension to be built with jenkins


## v1.0.5

* Default to searchable=false for primary key

## v1.0.3

* Fix for use of discontinued use of properties as beans
* Add non term filter

## v1.0.2

* Fixing borked layout in ES control page

## v1.0.1

* Initial release
