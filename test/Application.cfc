component {

	this.name = "mocktory test";
	this.mappings["/test"] = GetDirectoryFromPath(getCurrentTemplatePath());
	this.mappings["/mocktory"] = GetDirectoryFromPath(getCurrentTemplatePath()) & "../src";

}