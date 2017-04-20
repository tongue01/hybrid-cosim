/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.cg.cpp.tests

import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.generation.BuildUtilities
import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.generation.CppGenerator
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import be.uantwerpen.ansymo.semanticadaptation.tests.AbstractSemanticAdaptationTest
import be.uantwerpen.ansymo.semanticadaptation.tests.SemanticAdaptationInjectorProvider
import com.google.inject.Inject
import java.io.File
import java.io.FileWriter
import java.nio.file.Files
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Test
import org.junit.runner.RunWith
import be.uantwerpen.ansymo.semanticadaptation.testframework.StaticGenerators
import org.junit.Ignore

@RunWith(XtextRunner)
@InjectWith(SemanticAdaptationInjectorProvider)
class CgCppBasicTest extends AbstractSemanticAdaptationTest {

// @Inject CppGenerator underTest
	@Inject extension ParseHelper<SemanticAdaptation>
	@Inject extension  ValidationTestHelper

	@Ignore
	@Test def window_sa_canonical() {
		__parseNoErrors('test_input/single_folder_spec/window/window_sa_canonical.BASE.sa', 'generated', "powerwindow");
//		__parseNoErrorsWithValidation('test_input/single_folder_spec/window',
//			'test_input/single_folder_spec/window/window_sa_canonical.BASE.sa');
	}
	
	@Test def window_sa_canonical_new() {
		__parseNoErrors('test_input/single_folder_spec/window/window_sa_canonical_new.BASE.sa', 'generated', "powerwindow");
	}
	
	@Test def lazy_sa_canonical() {
		__parseNoErrors('test_input/single_folder_spec/lazy/lazy.sa', 'generated', "lazy");
	}

	def __parseNoErrorsWithValidation(String directory, String filename) {
		val model = __parse(filename);
		__assertNoParseErrors(model, filename);

		val correctFileDirectory = new File(directory + File.separator + "correct");

		val fsa = new InMemoryFileSystemAccess()
		val IGeneratorContext ctxt = null;
		val cppGen = new CppGenerator();
		cppGen.doGenerate(model.eResource, fsa, ctxt);

		for (files : fsa.allFiles.entrySet) {
			val filename2 = files.key.substring(14);
			val file = new File(correctFileDirectory, filename2);
			val correctFileContent = Files.readAllLines(file.toPath);

			var path = new File("generated");
			if (path.exists)
				path.delete
			else
				path.mkdir;

			path = new File(path, files.key.substring(14))

			val FileWriter writer = new FileWriter(path);
			writer.write(files.value.toString);
			writer.close;

			val testFileContent = Files.readAllLines(path.toPath);

			if (correctFileContent.size != testFileContent.size) {
				System.out.println("Error: Lines are of different length in file: " + filename2);
			} else {
				val error = false;
				for (var i = 0; i < testFileContent.size; i++) {
					val testLine = testFileContent.get(i);
					val correctLine = correctFileContent.get(i);
					if (testLine.compareTo(correctLine) != 0) {
						if (!testLine.contains("guid")) {
							System.out.println("ERROR: The following lines are not equal: \n" + testLine + "\n" +
								correctLine);
						}
					}
				}
			}
		}

	}


	def __parseNoErrors(String filename, String directory, String projectName) {
		val saRootDir = new File(directory + File.separatorChar + projectName);
		val srcGenPath = new File(saRootDir, "sources")
		val resourcesPath = new File(saRootDir, "resources");
		val saFrameworkPath = new File(saRootDir, "framework")

		System.out.println("Rootdir: " + saRootDir.absolutePath)

		val model = __parse(filename)
		__assertNoParseErrors(model, filename)

		val fsa = new InMemoryFileSystemAccess();
		val IGeneratorContext ctxt = null;
		val cppGen = new CppGenerator();
		cppGen.doGenerate(model.eResource, fsa, ctxt);
		
		if (saRootDir.exists) {
			BuildUtilities.deleteFolder(saRootDir);
		}
				
		saRootDir.mkdirs();
		srcGenPath.mkdirs();
		resourcesPath.mkdirs();
		saFrameworkPath.mkdirs();

		for (files : fsa.allFiles.entrySet) {
			val fName = files.key.substring(14);
			
			var File fp;
			if(fName.equals("modelDescription.xml"))
			{
				fp = new File(saRootDir, fName);
			}
			else
			{
				fp = new File(srcGenPath, fName);
			}
			
			BuildUtilities.writeToFile(fp, files.value.toString);	
		}
		
		val mainCpp = StaticGenerators.generateMainCppFile(saRootDir.absolutePath.replace("\\","\\\\"));
		BuildUtilities.writeToFile(new File(srcGenPath,"main.cpp"), mainCpp);
		
		
		for(rf : cppGen.resourcePaths)
		{
			val sinkFile = new File(resourcesPath, rf.name);
			System.out.println("Copied file to: " + sinkFile);
			BuildUtilities.copyFile(rf, sinkFile);	
		}			
		
		
		BuildUtilities.writeToFile(new File(saRootDir,"CMakeLists.txt"), StaticGenerators.generateCMakeLists(projectName, "framework"));
		
		(new BuildUtilities()).copyNativeLibFiles(saFrameworkPath);
		System.out.println("Stored framework at: " + saFrameworkPath);
		
				
	}

	def __parseNoErrorsPrint(String filename) {
		val root = __parse(filename)
		print_ast(root)
		__assertNoParseErrors(root, filename)
	}

	def __parse(String filename) {
		return readFile(filename).parse
	}

	def __parse(
		String filename,
		ResourceSet resourceSetToUse
	) {

		return readFile(filename).parse(resourceSetToUse)
	}

	def __assertNoParseErrors(EObject root, String filename) {
		try {
			root.assertNoErrors
		} catch (AssertionError e) {
			val p = Pattern.compile(".*, offset (?<offset>[0-9]+), length (?<length>[0-9]+)")
			val code = readFile(filename)
			for (String line : e.message.split("\n")) {
				val m = p.matcher(line)
				m.matches()
				val count = __occurrencesInString(code.subSequence(0, Integer.valueOf(m.group("offset"))).toString(),
					"\n")
				print(filename + " at line " + (count + 1) + ": ")
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
