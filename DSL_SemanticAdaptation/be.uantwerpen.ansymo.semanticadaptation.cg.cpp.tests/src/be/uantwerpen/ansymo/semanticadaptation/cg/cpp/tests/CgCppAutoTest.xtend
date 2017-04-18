/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.cg.cpp.tests

import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import be.uantwerpen.ansymo.semanticadaptation.testframework.XtextParametersRunnerFactory
import be.uantwerpen.ansymo.semanticadaptation.tests.AbstractSemanticAdaptationTest
import be.uantwerpen.ansymo.semanticadaptation.tests.SemanticAdaptationInjectorProvider
import com.google.inject.Inject
import java.io.File
import java.util.ArrayList
import java.util.Arrays
import java.util.Collection
import java.util.List
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import org.junit.runners.Parameterized.Parameters
import org.junit.Ignore
import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.generation.CppGenerator

@RunWith(typeof(Parameterized))
@InjectWith(SemanticAdaptationInjectorProvider)
@Parameterized.UseParametersRunnerFactory(XtextParametersRunnerFactory)
class CgCppAutoTest extends AbstractSemanticAdaptationTest {

	new (List<File> files)
	{
		f = files;
	}

	@Inject extension ParseHelper<SemanticAdaptation>
	@Inject extension  ValidationTestHelper

	@Parameters(name = "{index}")
	def static Collection<Object[]> data() {
		val files = new ArrayList<List<File>>();
		listf("test_input/single_folder_spec", files);
		val test = new ArrayList();
		test.add(files.get(0));
		//val test2 = new ArrayList();
		//test2.add(files.get(1));
		return Arrays.asList(test.toArray());
	}

	def static void listf(String directoryName, List<List<File>> files) {
		val File directory = new File(directoryName);
		val filesInDir = new ArrayList<File>();
		// get all the files from a directory
		val File[] fList = directory.listFiles();
		var boolean added = false;
		for (File file : fList) {
			if (file.isFile()) {
				filesInDir.add(file);
			} else if (file.isDirectory()) {
				if (filesInDir.length > 0) {
					added = true;
					files.add(filesInDir);
				}
				listf(file.getAbsolutePath(), files);
			}
		}
		if (!added) {
			if (filesInDir.length > 0) {
				files.add(filesInDir);
			}
		}
	}

	var List<File> f;

	@Ignore
	@Test def allSemanticAdaptations() {
		//assertTrue(false);
		__parseNoErrors(f);
	}

	def __parseNoErrors(List<File> files) {
		val hdFile = files.get(0);
		files.remove(0);
		val tailFiles = files;
		val model = __parse(hdFile, tailFiles)
		__assertNoParseErrors(model, hdFile)

		val fsa = new InMemoryFileSystemAccess()
		val IGeneratorContext ctxt = null;
		new CppGenerator().doGenerate(model.eResource, fsa, ctxt)

		System.out.println(fsa.allFiles)
	}

	def __parse(File hdFile, Iterable<File> tailFiles) {
		var prevModel = readFile(hdFile).parse;
		for (File file : tailFiles) {
			val model = __parse(file, prevModel.eResource.resourceSet);
			prevModel = model;
		}

		return prevModel;
	}

	def __parse(String filename, ResourceSet resourceSetToUse) {

		return readFile(filename).parse(resourceSetToUse)
	}

	def __parse(File file, ResourceSet resourceSetToUse) {

		return readFile(file).parse(resourceSetToUse)
	}

	def __assertNoParseErrors(EObject root, File file) {
		try {
			root.assertNoErrors
		} catch (AssertionError e) {
			val p = Pattern.compile(".*, offset (?<offset>[0-9]+), length (?<length>[0-9]+)")
			val code = readFile(file)
			for (String line : e.message.split("\n")) {
				val m = p.matcher(line)
				m.matches()
				val count = __occurrencesInString(code.subSequence(0, Integer.valueOf(m.group("offset"))).toString(),
					"\n")
				print(file.getName() + " at line " + (count + 1) + ": ")
				println(line)
			}
			throw e
		}
	}

	def __occurrencesInString(String str, String findstr) {
		var lastIndex = 0
		var count = 0
		while (lastIndex != -1) {
			lastIndex = str.indexOf(findstr, lastIndex)
			if (lastIndex != -1) {
				count++
				lastIndex += findstr.length()
			}
		}
		return count
	}

}
