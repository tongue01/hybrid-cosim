/*
 * generated by Xtext 2.11.0
 */
package be.uantwerpen.ansymo.semanticadaptation.formatting2

import be.uantwerpen.ansymo.semanticadaptation.generator.Log
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Adaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.CompositeOutputFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.CustomControlRule
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.DataRule
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.StateTransitionFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Statement
import org.eclipse.xtext.formatting2.AbstractFormatter2
import org.eclipse.xtext.formatting2.IFormattableDocument

class SemanticAdaptationFormatter extends AbstractFormatter2 {
	
	//@Inject extension SemanticAdaptationGrammarAccess

	def dispatch void format(SemanticAdaptation semanticAdaptation, extension IFormattableDocument document) {
		Log.push("Formatting document")
		
		val adaptations = semanticAdaptation.elements.filter(Adaptation)
		if (adaptations.size == 0){
			Log.println("Warning: document has no adaptation declared. This is not supported yet.")
			return
		}
		
		val sa = adaptations.head
		
		Log.println("Adaptation: " + sa)
		sa.format
		
		Log.pop("Formatting document")	
	}
	
	def dispatch void format(Adaptation sa, extension IFormattableDocument document){
		Log.push("Formatting adaptation")
		
		sa.regionFor.keyword('input').prepend[newLine]
		sa.regionFor.keyword('output').prepend[newLine]
		
		if (sa.params.size > 0){
			for (paramDecls : sa.params){
				paramDecls.prepend[newLine]
			}
		}
		
		if (sa.in !== null){
			sa.in.regionFor.keyword('in').prepend[newLine]
			
			for (rule : sa.in.rules){
				rule.format
			}
		}
		
		if (sa.out !== null){
			sa.out.regionFor.keyword('out').prepend[newLine]
			
			for (rule : sa.out.rules){
				rule.format
			}
		}
		
		if (sa.control !== null){
			sa.control.prepend[newLine]
			
			sa.control.rule.format
		}
		
		
		/*
		for (inPort : sa.inports){
			Log.push("Formatting inPort " + inPort.name)
			
			inPort.regionFor.feature(SemanticAdaptationPackage.Literals.PORT__TYPE).prepend[newLine]
			
			Log.pop("Formatting inPort " + inPort.name)	
		}
		 */
		
		Log.pop("Formatting adaptation")	
	}
	
	def dispatch void format(DataRule rule, extension IFormattableDocument document){
		Log.push("Formatting DataRule")
		
		rule.prepend[newLine]
		
		rule.statetransitionfunction.format
		
		rule.outputfunction.format
		
		Log.pop("Formatting DataRule")	
	}
	
	def dispatch void format(CustomControlRule rule, extension IFormattableDocument document){
		Log.push("Formatting CustomControlRule")
		
		rule.prepend[newLine]
		
		for (statement : rule.controlRulestatements){
			statement.format
		}
		
		rule.returnstatement.prepend[newLine]
		
		Log.pop("Formatting CustomControlRule")	
	}
	
	def dispatch void format(StateTransitionFunction function, extension IFormattableDocument document){
		Log.push("Formatting StateTransitionFunction")
		
		for (statement : function.statements){
			statement.format
		}
		
		Log.pop("Formatting StateTransitionFunction")	
	}
	
	def dispatch void format(CompositeOutputFunction function, extension IFormattableDocument document){
		Log.push("Formatting CompositeOutputFunction")
		
		for (statement : function.statements){
			statement.format
		}
		
		Log.pop("Formatting CompositeOutputFunction")	
	}
	
	def dispatch void format(Statement statement, extension IFormattableDocument document){
		Log.push("Formatting Statement")
		
		statement.prepend[newLine]
		
		Log.pop("Formatting Statement")	
	}
}
