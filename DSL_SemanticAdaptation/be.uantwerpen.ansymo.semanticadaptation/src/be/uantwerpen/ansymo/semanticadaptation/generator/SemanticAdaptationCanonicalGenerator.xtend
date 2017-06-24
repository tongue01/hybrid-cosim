/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.generator

import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Adaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.BoolLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.BuiltinFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Close
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Connection
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.DeclaredParameter
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Expression
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.InnerFMUDeclarationFull
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.IntLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.IsSet
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Port
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.RealLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptationFactory
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SingleParamDeclaration
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SingleVarDeclaration
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.StringLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Variable
import java.io.ByteArrayOutputStream
import java.util.HashMap
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class SemanticAdaptationCanonicalGenerator extends AbstractGenerator {
	
	String CANONICAL_EXT = ".BASE.sa"
	String NAME_SUFFIX = "_BASE"
	
	override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		println("Generating canonical semantic adaptation for file " + resource.URI.toFileString() + "...")
		
		println("Resource URI information:")
		println("\t resource.URI.lastSegment = " + resource.URI.lastSegment())
		println("\t resource.URI.trimFileExtension = " + resource.URI.trimFileExtension())
		
		println("______________________________File Read______________________________")
		var outputByteArray = new ByteArrayOutputStream()
		resource.save(outputByteArray, null)
		println(outputByteArray.toString())
		outputByteArray.close()
		println("__________________________________________________________________________")
		
		// Create file name for the canonical sa file
		var fileNameWithoutExt = resource.URI.trimFileExtension().lastSegment()
		var canonicalFileName = fileNameWithoutExt + CANONICAL_EXT
		println("canonicalFileName = " + canonicalFileName)
		
		// Create in memory representation of canonical SA file
		var adaptations = resource.allContents.toIterable.filter(SemanticAdaptation).last.elements.filter(Adaptation);
		if (adaptations.size > 1){
			throw new Exception("Only one semantic adaptation is supported per .sa file")
		}
		var adaptation = adaptations.head
		
		println("Checking if file is already a canonical version...")
		if (adaptation.name.indexOf(NAME_SUFFIX) == -1){
			println("It is not.")
			
			adaptation.name = adaptation.name + NAME_SUFFIX
			
			adaptation.canonicalize
						
			outputByteArray = new ByteArrayOutputStream()
			adaptation.eResource.save(outputByteArray,null)
			
			println("______________________________Generated file______________________________")
			println(outputByteArray.toString())
			println("__________________________________________________________________________")
			
			fsa.generateFile(canonicalFileName, outputByteArray.toString())
			println("File " + canonicalFileName + " written.")
			outputByteArray.close()
			
			println("Generating canonical semantic adaptation for file " + resource.URI + "... DONE.")
			
		} else {
			println("It is already a canonical version.")
			println("Nothing to do.")
		}

	}
	
	def canonicalize(Adaptation sa){
		
		// Type inference
		inferTypes(sa)
		
		// TODO Add input ports
		
		// Add in params
		addInParams(sa)
		
	}
	
	def inferTypes(Adaptation sa){
		println("Inferring types...")
		
		/*
		 * Dumbest (and simplest) algorithm for this is a fixed point computation:
		 * 1. Look for every var/port declaration
		 * 2. If that var has a type already, nothing else to be done.
		 * 3. If that var has no type declared, then
		 * 3.1 If var/port has an initial value or connection, then
		 * 3.1.1 If the initial_value/connection has a type declared, then var gets that type.
		 * 3.1.2 Otherwise, nothing else to be done.
		 * 3.2 If var/port has no initial value or connection then this either is a missing feature, or an error.
		 * 3.3 If something has changed, go to 1. Otherwise, end.
		 */
		var fixedPoint = false
		var untypedElementsCounter = 0
		while (! fixedPoint){
			fixedPoint = true
			untypedElementsCounter = 0
			
			println("Inferring parameter types...")
			
			for (paramDeclarations : sa.params) {
				for (paramDeclaration : paramDeclarations.declarations) {
					println("Computing type for param " + paramDeclaration.name)
					if(paramDeclaration.type !== null){
						println("Already has a type: " + paramDeclaration.type)
					} else {
						println("Has no type.")
						var inferredTypeAttempt = extractTypeFromExpression(paramDeclaration.expr, paramDeclaration.name)
						if (inferredTypeAttempt !== null){
							paramDeclaration.type = inferredTypeAttempt
							fixedPoint = false
							println("Got new type: " + paramDeclaration.type)
						} else {
							untypedElementsCounter++
							println("Cannot infer type now.")
						}
					}
				}
			}
			
			if(sa.inner !== null){
				if(sa.inner instanceof InnerFMUDeclarationFull){
					var innerFMUFull = sa.inner as InnerFMUDeclarationFull
					for(fmu : innerFMUFull.fmus){
						println("Inferring port types of FMU " + fmu.name)
						for (port : EcoreUtil2.getAllContentsOfType(fmu, Port)) {
							if(port.type !== null){
								println("Already has a type: " + port.type)
							} else if(inferPortType(port)) {
								fixedPoint = false
							} else {
								untypedElementsCounter++
							}
						}
					}
					
					if (innerFMUFull.connection.size > 0){
						println("Inferring port types using internal scenario bindings.")
						for (binding : innerFMUFull.connection){
							if (binding.src.port.type !== null && binding.tgt.port.type !== null){
								println("Both ports have types already.")
							} else if (inferPortTypeViaConnection(binding)){
								fixedPoint = false
								untypedElementsCounter--
							}
						}
					}
				} else {
					throw new Exception("Type inference only supported for InnerFMUDeclarationFull.")
				}
			}
			
			println("Inferring external port types...")
			
			for (port : sa.inports) {
				if (port.type !== null){
					println("Already has a type: " + port.type)
					if (pushPortType(port)){
						fixedPoint = false
						untypedElementsCounter--
					} 
				} else if (inferPortType(port)){
					fixedPoint = false
				} else {
					untypedElementsCounter++
				}
			}
			for (port : sa.outports) {
				if (port.type !== null){
					println("Already has a type: " + port.type)
					if (pushPortType(port)){
						fixedPoint = false
						untypedElementsCounter--
					} 
				} else if (inferPortType(port)){
					fixedPoint = false
				} else {
					untypedElementsCounter++
				}
			}
			
			println("Inferring all other declaration types...")
			
			for (varDeclaration : EcoreUtil2.getAllContentsOfType(sa, SingleVarDeclaration)) {
				println("Computing type for declaration " + varDeclaration.name)
				if(varDeclaration.type !== null){
					println("Already has a type: " + varDeclaration.type)
				} else {
					var inferredTypeAttempt = extractTypeFromExpression(varDeclaration.expr, varDeclaration.name)
					if (inferredTypeAttempt !== null){
						varDeclaration.type = inferredTypeAttempt
						fixedPoint = false
						println("Got new type: " + varDeclaration.type)
					} else {
						untypedElementsCounter++
						println("Cannot infer type now.")
					}
				}
			}
			
			println("Ended iteration with untyped elements remaining: " + untypedElementsCounter)
		} // while (! fixedPoint)
		
		if (untypedElementsCounter > 0){
			throw new Exception("Could not infer all types. There are " + untypedElementsCounter + " untyped elements.")
		}
		
		println("Inferring types... DONE")
	}
	
	def extractTypeFromExpression(Expression expression, String declarationName){
		if (expression instanceof IntLiteral){
			return "Integer"
		} else if (expression instanceof RealLiteral){
			return "Real"
		} else if (expression instanceof BoolLiteral){
			return "Bool"
		} else if (expression instanceof StringLiteral){
			return "String"
		} else if (expression instanceof Variable){
			var varRef = expression as Variable
			if (varRef.ref instanceof Port){
				var decl = varRef.ref as Port
				if (decl.type !== null){
					return decl.type
				}
			} else if(varRef.ref instanceof SingleParamDeclaration){
				var decl = varRef.ref as SingleParamDeclaration
				if (decl.type !== null){
					return decl.type
				}
			} else if(varRef.ref instanceof SingleVarDeclaration){
				var decl = varRef.ref as SingleVarDeclaration
				if (decl.type !== null){
					return decl.type
				}
			} else if(varRef.ref instanceof DeclaredParameter){
				throw new Exception("Type cannot be inferred for references to DeclaredParameter (for now). Please specify the explicit type of declaration " + declarationName)
			} else {
				throw new Exception("Unexpected kind of Variable expression found.")
			}
		} else if(expression instanceof BuiltinFunction){
			if (expression instanceof IsSet || expression instanceof Close){
				return "Bool"
			} else {
				return "Real"
			}
		} else {
			throw new Exception("Initial value for declaration " + declarationName + " must be literal or var ref for now. Got instead " + expression + ". If you want complex expressions, give it an explicit type.")
		}
		return null
	}
	
	def inferPortTypeViaConnection(Connection binding){
		var typeInferred = false
		
		if (binding.src.port.type !== null && binding.tgt.port.type !== null){
			println("Both ports have types already.")
			throw new Exception("Wrong way of using this function. It assumes type is not inferred yet.")
		} else if (binding.src.port.type !== null){
			binding.tgt.port.type = binding.src.port.type
			println("Target port "+ binding.tgt.port.name +" got new type: " + binding.tgt.port.type)
		} else if (binding.tgt.port.type !== null){
			binding.src.port.type = binding.tgt.port.type
			println("Target port "+ binding.src.port.name +" got new type: " + binding.src.port.type)
		}
		
		return typeInferred
	}
	
	def inferPortTypeFromBindings(Port port){
		var typeInferred = false
		if(port.sourcedependency !== null){
			println("Has a source dependency: " + port.sourcedependency.port.name)
			if(port.sourcedependency.port.type === null){
				println("Dependency has no type yet.")
			} else {
				port.type = port.sourcedependency.port.type
				println("Got new type: " + port.type)
				typeInferred = true
			}
		} else {
			println("Has no source dependency.")
		}
		
		if (port.targetdependency !== null && !typeInferred) {
			println("Has a target dependency: " + port.targetdependency.owner.name + "." + port.targetdependency.port.name)
			if(port.targetdependency.port.type === null){
				//println("Port object: " + port.targetdependency.port)
				println("Dependency has no type yet.")
			} else {
				port.type = port.targetdependency.port.type
				println("Got new type: " + port.type)
				typeInferred = true
			}
		} else {
			println("Has no target dependency, or type has already been inferred from source dependency.")
		}
		return typeInferred
	}
	
	def pushPortType(Port port){
		var typeInferred = false
		println("Pushing type of port " + port.name + " to its bindings.")
		
		if(port.type === null){
			println("Has no type to be pushed.")
		} else {
			println("Pushing type: " + port.type)
			if(port.sourcedependency !== null){
				println("Has a source dependency: " + port.sourcedependency.port.name)
				if(port.sourcedependency.port.type === null){
					port.sourcedependency.port.type = port.type
					println("Port " + port.sourcedependency.port.name + " got new type: " + port.sourcedependency.port.type)
					typeInferred = true
				} else {
					println("Source port already has type.")
				}
			} else {
				println("Has no source dependency.")
			}
			
			if (port.targetdependency !== null) {
				println("Has a target dependency: " + port.targetdependency.port.name)
				if(port.targetdependency.port.type === null){
					println("Dependency has no type yet.")
					port.targetdependency.port.type = port.type
					println("Port " + port.targetdependency.port.name + " got new type: " + port.targetdependency.port.type)
					typeInferred = true
				} else {
					println("Target port already has type.")
				}
			} else {
				println("Has no target dependency, or type has already been inferred from source dependency.")
			}
		}
		
		return typeInferred
	}
	
	def inferPortType(Port port){
		var typeInferred = false
		println("Computing type for port " + port.name)
		//println("Object: " + port)
			
		if(port.type !== null){
			println("Already has a type: " + port.type)
			throw new Exception("Wrong way of using this function. It assumes type is not inferred yet.")
		} else {
			println("Has no type.")
			typeInferred = inferPortTypeFromBindings(port)
		}
		
		return typeInferred
	}
	
	def addInParams(Adaptation adaptation) {
		println("Adding input parameters...")
		
		val PARAM_PREFIX = "INIT_"
		
		var inputPort_to_parameterDeclaration_Map = new HashMap<Port, SingleParamDeclaration>(adaptation.inports.size)
		
		for (inputPortDeclaration : adaptation.inports) {
			println("Generating parameter for port " + inputPortDeclaration.name)
			var paramname = PARAM_PREFIX + inputPortDeclaration.name.toUpperCase()
			var paramAlreadyDeclared = false
			for(paramDeclarations : adaptation.params){
				for(paramDeclaration : paramDeclarations.declarations){
					if(paramDeclaration.name == paramname){
						paramAlreadyDeclared = true
					}
				}
			}
			if (paramAlreadyDeclared){
				println("Parameter " + paramname + " already declared for port " + inputPortDeclaration.name)
			} else {
				println("Declaring new parameter " + paramname + " for port " + inputPortDeclaration.name)
				var factory = SemanticAdaptationFactory.eINSTANCE
				if (adaptation.params.size == 0){
					adaptation.params.add(factory.createParamDeclarations())
				}
				var paramDeclaration = factory.createSingleParamDeclaration()
				
				// TODO Continue here after solving problem with ports.
				
				//adaptation.params.head.declarations.add()
			}
		}
		
		println("Adding input parameters... DONE")
	}
	
}
