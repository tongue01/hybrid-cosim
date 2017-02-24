/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.cg.cpp.tests

import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import be.uantwerpen.ansymo.semanticadaptation.tests.AbstractSemanticAdaptationTest
import be.uantwerpen.ansymo.semanticadaptation.tests.SemanticAdaptationInjectorProvider
import com.google.inject.Inject
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Test
import org.junit.runner.RunWith
import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.CppGenerator
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import org.eclipse.xtext.generator.IGeneratorContext
import org.eclipse.emf.ecore.resource.ResourceSet

@RunWith(XtextRunner)
@InjectWith(SemanticAdaptationInjectorProvider)
class CgCppBasicTest2 extends AbstractSemanticAdaptationTest {

	// @Inject CppGenerator underTest
	@Inject extension ParseHelper<SemanticAdaptation>
	@Inject extension  ValidationTestHelper

	@Test def powerwindow_model_only() { __parseNoErrors('test_input/window/window_sa_canonical.BASE.sa') }

	def __parseNoErrors(String filename) {
		val model = __parse(filename)
		__assertNoParseErrors(model, filename)

		val fsa = new InMemoryFileSystemAccess()
		val IGeneratorContext ctxt = null;
		new CppGenerator().doGenerate(model.eResource, fsa, ctxt)

		System.out.println(fsa.allFiles)
	}

	def __parseNoErrorsPrint(String filename) {
		val root = __parse(filename)
		print_ast(root)
		__assertNoParseErrors(root, filename)
	}

	def __parse(String filename) {
		val model = readFile(filename).parse
		return model;
	}

	def __parse(String filename, ResourceSet resourceSetToUse) {

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
