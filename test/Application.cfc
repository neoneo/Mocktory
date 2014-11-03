component {

	this.name = "mocktorytest";
	this.mappings["/mocktorytest"] = GetDirectoryFromPath(getCurrentTemplatePath());
	this.mappings["/mocktory"] = GetDirectoryFromPath(getCurrentTemplatePath()) & "../src";

}