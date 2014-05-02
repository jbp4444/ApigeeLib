--
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

-- the username file just has two global vars defined:
--   apigee_baseurl = "https://foo.bar.com"
--   apigee_orgname = "myorgname"
--   apigee_appname = "myappname"
--   apigee_collection = "mycollection"
--   apigee_username = "foo"
--   apigee_password = "barbaz"
require( "apigeeInfo" )

-- what test-sets to run?
synchr_tests = false
asynchr_tests = false
cmdseq_tests = true
entity_tests = false
collection_tests = false

--
--  --  --  --  --  --  --  --  --  --  --  --  --  --
--

-- run the synchronous (socket.http/ltn12) tests?
if( synchr_tests ) then
	require( "test_synchr" )
end

-- run the asynchronous (network.request) tests?
if( asynchr_tests ) then
	require( "test_asynchr" )
end

-- run the command-sequence helper for asynchronous tests?
if( cmdseq_tests ) then
	require( "test_cmdseq" )
end