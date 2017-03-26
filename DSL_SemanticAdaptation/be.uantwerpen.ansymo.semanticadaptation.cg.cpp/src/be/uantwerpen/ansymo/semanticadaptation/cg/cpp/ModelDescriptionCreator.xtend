package be.uantwerpen.ansymo.semanticadaptation.cg.cpp;

import java.util.List;
import java.util.Vector;
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Adaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.InnerFMU
import java.io.File
import org.w3c.dom.Document
import java.util.zip.ZipFile
import java.util.Enumeration
import java.util.zip.ZipEntry
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.parsers.DocumentBuilder
import java.util.HashMap
import java.util.Map
import javax.xml.xpath.XPathFactory
import javax.xml.xpath.XPath
import javax.xml.xpath.XPathExpression
import org.w3c.dom.Node
import javax.xml.xpath.XPathConstants
import java.util.UUID

public class ModelDescriptionCreator {
	private List<ScalarVariable> sVars = new Vector<ScalarVariable>();
	private ModelDescriptionBuilder mdBuilder = new ModelDescriptionBuilder();
	private String mdName;
	private String guid;

	def String getModelDescription() {
		if (mdName === null) {
			throw new IllegalStateException("Model Description name is missing");
		}
		mdBuilder.CreateTemplate(mdName, UUID.randomUUID().toString);
		for (sVar : sVars) {
			mdBuilder.addScalarVariable(sVar);
		}

		return mdBuilder.toString();
	}

	def void setName(String name) {
		mdName = name;
	}

	public def List<ScalarVariable> getScalars() {
		return this.sVars;
	}

	private def Document getModelDescription(File path) {
		var ZipFile fmu = new ZipFile(path);
		var Enumeration<? extends ZipEntry> entries = fmu.entries();
		var boolean entryFound = false;
		var ZipEntry locatedEntry;

		while (!entryFound && entries.hasMoreElements()) {
			var ZipEntry entry = entries.nextElement();
			if (entry.name.equalsIgnoreCase("modelDescription.xml"))
				locatedEntry = entry;
		}
		var DocumentBuilderFactory fac = DocumentBuilderFactory.newInstance();
		var DocumentBuilder builder = fac.newDocumentBuilder();
		val is = fmu.getInputStream(locatedEntry)
		var Document doc = builder.parse(is);
		is.close();
		return doc;
	}

	def void CalcContent(ModelDescription md) {
		sVars.addAll(md.getSv().values);
	}

}
