/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.tests

import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import com.google.inject.Inject
import java.util.regex.Pattern
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.testing.InjectWith
import org.eclipse.xtext.testing.XtextRunner
import org.eclipse.xtext.testing.util.ParseHelper
import org.eclipse.xtext.testing.validation.ValidationTestHelper
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(XtextRunner)
@InjectWith(SemanticAdaptationInjectorProvider)
class SemanticAdaptationParsingTest extends AbstractSemanticAdaptationTest{
	
	@Inject extension ParseHelper<SemanticAdaptation>
	@Inject extension ValidationTestHelper

//	@Test 
//	def void loadModule() {
//		//val root = this.parseInputFile('test1.sa')
//		val root = readFile('input/test1.sa').parse
//		root.assertNoErrors
//		Assert.assertNotNull(root.adaptations.get(0))
//		Assert.assertNotNull(root.adaptations.get(0).extractsensitivity)
//		Assert.assertTrue(root.adaptations.get(0).extractsensitivity.length > 0)
//		Assert.assertTrue(root.adaptations.get(0).inports.length > 0)
//		Assert.assertEquals(root.adaptations.get(0).inports.get(0).name, 'x')
//		print_ast(root)
//	}

	@Test def powerwindow_model_only() { __parseNoErrors('input/powerwindow_model_only.sa') }
	@Test def powerwindow_algebraic_loop_delay_BASE() { __parseNoErrors('input/powerwindow_algebraic_loop_delay_BASE.sa') }
	@Test def powerwindow_algebraic_loop_delay() { __parseNoErrors('input/powerwindow_algebraic_loop_delay.sa') }
	@Test def powerwindow_algebraic_loop_iteration_BASE() { __parseNoErrors('input/powerwindow_algebraic_loop_iteration_BASE.sa') }
	@Test def powerwindow_algebraic_loop_iteration() { __parseNoErrors('input/powerwindow_algebraic_loop_iteration.sa') }
	@Test def powerwindow_controller_delay() { __parseNoErrors('input/powerwindow_controller_delay.sa') }
	@Test def powerwindow_controller_delay_BASE() { __parseNoErrors('input/powerwindow_controller_delay_BASE.sa') }
	@Test def powerwindow_multi_rate() { __parseNoErrors('input/powerwindow_multi_rate.sa') }
	@Test def powerwindow_multi_rate_BASE() { __parseNoErrors('input/powerwindow_multi_rate_BASE.sa') }
	@Test def powerwindow() { __parseNoErrors('input/powerwindow.sa') }
	@Test def powerwindow_inline() { __parseNoErrors('input/powerwindow_inline.sa') }
	
	def __parseNoErrors(String filename) {
		val root = __parse(filename)
		__assertNoParseErrors(root, filename)
	}
	
	def __parseNoErrorsPrint(String filename) {
		val root = __parse(filename)
		print_ast(root)
		__assertNoParseErrors(root, filename)
	}
	
	def __parse(String filename) {
		val model = readFile('input/powerwindow_controller_delay.sa').parse
		val controller = readFile('input/powerwindow_model_only.sa').parse(model.eResource.resourceSet)
		val algebraicloop = readFile('input/powerwindow_algebraic_loop_delay.sa').parse(controller.eResource.resourceSet)
		return readFile(filename).parse(algebraicloop.eResource.resourceSet)
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
				val count = __occurrencesInString(code.subSequence(0, Integer.valueOf(m.group("offset"))).toString(), "\n")
				print(filename + " at line " + (count+1) + ": ")
				println(line)
			}
			throw e
		}
	}
	
	def __occurrencesInString(String str, String findstr) {
		var lastIndex = 0
		var count = 0
		while (lastIndex != -1) {
			lastIndex = str.indexOf(findstr,lastIndex)
			if (lastIndex != -1) {
		        count ++
		        lastIndex += findstr.length()
		    }
		}
		return count
	}

}
