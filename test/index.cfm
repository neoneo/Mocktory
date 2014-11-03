<cfscript>
	testbox = new testbox.system.TestBox(bundles = ["mocktorytest.UnitTest", "mocktorytest.IntegrationTest"]);

	WriteOutput(testbox.run());
</cfscript>