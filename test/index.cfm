<cfscript>
	testbox = new testbox.system.TestBox(bundles = ["test.UnitTest", "test.IntegrationTest"]);

	WriteOutput(testbox.run());
</cfscript>