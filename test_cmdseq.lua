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
print( "onComplete func is "..tostring(printResult) )

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
local commandSeq = cmdseq.new( apobj, nil )

commandSeq.add( "login", apobj.userLogin, nil )

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

if( collection_tests ) then
	commandSeq.add({
		-- retrieve a known data-object
		{ "collobj-retrieve", apobj.retrieveCollectionObject, {
			collection = "lotsofstuffs",
		} },
	
		-- create a new object, retrieve it, then delete it
		{ "collobj-create", apobj.createCollectionObject, {
			collection = "newcolls",
		} },
		{ "collobj-retrieve", apobj.retrieveCollectionObject, {
			collection = "newcolls",
		} },
		{ "collobj-update", apobj.updateCollectionObject, {
			collection = "newcolls",
		} },
		{ "collobj-delete", apobj.deleteCollectionObject, {
			collection = "newcolls",
		} },
	})
end

if( file_tests ) then
	commandSeq.add({
		-- create a new object, retrieve it, then delete it
		{ "fileobj-create", apobj.createFileObject, {
			collection = "assets",
			data = {
				name = "data.txt",
				path = "/data.txt",
			},
		} },
		{ "fileobj-retrieve", apobj.retrieveFileObject, {
			collection = "assets",
			uuid = "LAST",
		} },
		{ "fileobj-update", apobj.updateFileObject, {
			collection = "assets",
			data = {
				myextradata = "foobarbaz",
			},
			uuid = "LAST",
		} },
		{ "fileobj-upload", apobj.uploadFileObject, {
			collection = "assets",
			data = {
				filename = "data.txt",
				baseDirectory = system.CachesDirectory,
			},
			uuid = "LAST",
		} },
		{ "fileobj-download", apobj.downloadFileObject, {
			collection = "assets",
			data = {
				filename = "data_dn.txt",
				baseDirectory = system.CachesDirectory,
			},
			uuid = "LAST",
		} },
		{ "fileobj-delete", apobj.deleteFileObject, {
			collection = "assets",
			uuid = "LAST",
		} },
	
	})
end

if( activity_tests ) then
	commandSeq.add({
		-- create an activity
		{ "act-create", apobj.createActivityObject, {
			data = {
				verb = "post",
				content = "new user content"
			},
		} },
		{ "act-create", apobj.createActivityObject, {
			data = {
				group = "onebiggroup",
				verb = "post",
				content = "new group content"
			},
		} },
		-- retrieve some activities
		{ "act-retrieve", apobj.retrieveActivityObject, nil },
		{ "act-retrieve", apobj.retrieveActivityObject, {
			data = {
				group = "onebiggroup",
			}
		} },
	})
end

if( event_tests ) then
	commandSeq.add({
		-- create an event
		{ "evt-create", apobj.createEventObject, {
			data = {
				category = "mycategory",
			},
		} },
		
		-- retrieve some events
		{ "evt-retrive", apobj.retrieveEventObject, nil },
		
		-- retrieve some counters
		{ "cnt-retrive", apobj.retrieveCounterObject, {
			data = {
				counter = "default"
			},
		} },
	})
end

commandSeq.add( "logout", apobj.userLogout, nil )

commandSeq.exec()
