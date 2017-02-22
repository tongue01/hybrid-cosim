/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.tests

import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import com.google.inject.Inject
import org.eclipse.xtext.junit4.InjectWith
import org.eclipse.xtext.junit4.XtextRunner
import org.eclipse.xtext.junit4.util.ParseHelper
import org.junit.runner.RunWith

@RunWith(XtextRunner)
@org.eclipse.xtext.testing.InjectWith(SemanticAdaptationInjectorProvider)
abstract class AbstractSemanticAdaptationParserTest extends AbstractSemanticAdaptationTest {

	@Inject extension ParseHelper<SemanticAdaptation>
	
	/**
	 * parses from an input file
	 */
	def SemanticAdaptation parseInputFile(String filename) {
		return readFile('input/'+filename).parse()
	}

}
