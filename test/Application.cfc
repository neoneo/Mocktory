component {

	this.name = "mocktory test";
	this.mappings["/test"] = GetDirectoryFromPath(GetCurrentTemplatePath());
	this.mappings["/mocktory"] = GetDirectoryFromPath(GetCurrentTemplatePath()) & "../src";

}