-- test code for running Corona against apigee cloud resources
--
--
--   Copyright 2014 John Pormann, Duke University
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License.
--

local apigee = require( "scripts.ApigeeAsynchr" )
local cmdseq = require( "scripts.CommandSeq" )
local json = require( "json" )

for i=1,5 do
	print( " " )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- handle the return-result and go to next command in sequence
function printResult( e )
	print( "apigee result caught:" )
	print( "  isError = "..tostring(e.isError) )
	print( "  status = "..e.status )
	print( "  response = ["..e.response.."]" )
end

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- configure the connection to apigee
local apobj = apigee.new({
	baseurl = apigee_baseurl,
	orgname = apigee_orgname,
	appname = apigee_appname,
	collection = apigee_collection,
	username = apigee_username,
	password = apigee_password,
	-- onComplete will be overwritten by CommandSeq
	onComplete = printResult,
})

-- sequence of commands to run
local commandSeq = cmdseq.new( apobj, {
	onComplete = printResult,
})

commandSeq.add( "login", apobj.userLogin, {
	onComplete = printResult,
})

if( entity_tests ) then
	commandSeq.add({
		-- retrieve a known data-object
		{ "dataobj-retrieve", apobj.retrieveDataObject, {
			uuid = "7b6ef8fa-b686-11e3-b523-29a1e08cd3ce",
		} },
	
		-- create a new object, retrieve it, then delete it
		{ "dataobj-create", apobj.createDataObject, {
			data = {
				foofoo = "foo",
				barbar = "bar",
				bazbaz = "baz",
			},
		} },
		{ "dataobj-retrieve", apobj.retrieveDataObject, {
			uuid = "LAST",
		} },
		{ "dataobj-update", apobj.updateDataObject, {
			uuid = "LAST",
			data = {
				barbar = "newnewnewnew"
			},
		} },
		{ "dataobj-delete", apobj.deleteDataObject, {
			uuid = "LAST",
		} },
	})
end

commandSeq.add( "logout", apobj.userLogout, {
	onComplete = printResult,
})

commandSeq.exec()
