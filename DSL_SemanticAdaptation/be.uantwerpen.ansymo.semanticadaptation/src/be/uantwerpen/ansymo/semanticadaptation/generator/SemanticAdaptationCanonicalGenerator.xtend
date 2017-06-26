/*
 * generated by Xtext 2.10.0
 */
package be.uantwerpen.ansymo.semanticadaptation.generator

import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Adaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.BoolLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.BuiltinFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Close
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.CompositeOutputFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Connection
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.DataRule
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.DeclaredParameter
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Expression
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.FMU
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.InnerFMU
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.InnerFMUDeclaration
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.InnerFMUDeclarationFull
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.IntLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.IsSet
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.OutputFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Port
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.RealLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SemanticAdaptationFactory
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SingleParamDeclaration
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.SingleVarDeclaration
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.StateTransitionFunction
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.StringLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Unity
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Variable
import java.io.ByteArrayOutputStream
import java.util.HashMap
import java.util.LinkedList
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.generator.AbstractGenerator
import org.eclipse.xtext.generator.IFileSystemAccess2
import org.eclipse.xtext.generator.IGeneratorContext
import java.util.List

/**
 * Generates code from your model files on save.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#code-generation
 */
class SemanticAdaptationCanonicalGenerator extends AbstractGenerator {
	
	String CANONICAL_EXT = ".BASE.sa"
	String NAME_SUFFIX = "_BASE"
	
	override void doGenerate(Resource resource, IFileSystemAccess2 fsa, IGeneratorContext context) {
		Log.push("Generating canonical semantic adaptation for file " + resource.URI.toFileString() + "...")
		
		Log.println("Resource URI information:")
		Log.println("\t resource.URI.lastSegment = " + resource.URI.lastSegment())
		Log.println("\t resource.URI.trimFileExtension = " + resource.URI.trimFileExtension())
		
		// Create in memory representation of canonical SA file
		var adaptations = resource.allContents.toIterable.filter(SemanticAdaptation).last.elements.filter(Adaptation);
		if (adaptations.size > 1){
			throw new Exception("Only one semantic adaptation is supported per .sa file")
		}
		var adaptation = adaptations.head
		
		Log.println(prettyprint_model(adaptation, "File Read"))
		
		// Create file name for the canonical sa file
		var fileNameWithoutExt = resource.URI.trimFileExtension().lastSegment()
		var canonicalFileName = fileNameWithoutExt + CANONICAL_EXT
		Log.println("canonicalFileName = " + canonicalFileName)
		
		Log.println("Checking if file is already a canonical version...")
		if (adaptation.name.indexOf(NAME_SUFFIX) == -1){
			Log.println("It is not.")
			
			adaptation.name = adaptation.name + NAME_SUFFIX
			
			canonicalize(adaptation)
			
			Log.println(prettyprint_model(adaptation, "Generated File"))			
			
			fsa.generateFile(canonicalFileName, adaptation.serialize_model)
			Log.println("File " + canonicalFileName + " written.")
			
			
		} else {
			Log.println("It is already a canonical version.")
			Log.println("Nothing to do.")
		}
		
		Log.pop("Generating canonical semantic adaptation for file " + resource.URI.toFileString() + "... DONE.")
	}
	
	def prettyprint_model(Adaptation sa, String title){
		var outputByteArray = new ByteArrayOutputStream()
		sa.eResource.save(outputByteArray,null)
		return "______________________________" + title + "______________________________\n" +
				sa.serialize_model +
				"\n__________________________________________________________________________"
	}
	
	def serialize_model(Adaptation sa){
		var outputByteArray = new ByteArrayOutputStream()
		sa.eResource.save(outputByteArray,null)
		return outputByteArray.toString()
	}
	
	def inferUnits(Adaptation sa){
		// Unit inference
		var unitlessElements = genericDeclarationInferenceAlgorithm(sa , 
			[// getField
				element | {
					var DUMMY_UNIT = "Dips"
					if (element instanceof SingleParamDeclaration) {
						return DUMMY_UNIT
					} else if (element instanceof Port){
						return element.unity
					} else if (element instanceof SingleVarDeclaration){
						return DUMMY_UNIT
					} else {
						throw new Exception("Unexpected element type: " + element)
					}
				}
			],
			[// setField
				element, value | {
					if (element instanceof SingleParamDeclaration) {
						
					} else if (element instanceof Port){
						element.unity = EcoreUtil2.copy(value as Unity)
					} else if (element instanceof SingleVarDeclaration){
						
					} else {
						throw new Exception("Unexpected element type: " + element)
					}
				}
			],
			[// inferField
				element | {
					var DUMMY_UNIT = "Dips"
					if (element instanceof SingleParamDeclaration) {
						return DUMMY_UNIT
					} else if (element instanceof Port){
						return getPortUnit(element)
					} else if (element instanceof SingleVarDeclaration){
						return DUMMY_UNIT
					} else {
						throw new Exception("Unexpected element type: " + element)
					}
				}
			]
		)
		
		if (unitlessElements > 0){
			Log.println("Could not infer all element units. There are " + unitlessElements + " unitless elements.")
		}
	}
	
	def inferTypes(Adaptation sa){
		// Type inference
		var untypedElements = genericDeclarationInferenceAlgorithm(sa , 
			[// getField
				element | {
					if (element instanceof SingleParamDeclaration) {
						return element.type
					} else if (element instanceof Port){
						return element.type
					} else if (element instanceof SingleVarDeclaration){
						return element.type
					} else {
						throw new Exception("Unexpected element type: " + element)
					}
				}
			],
			[// setField
				element, value | {
					if (element instanceof SingleParamDeclaration) {
						element.type = value as String
					} else if (element instanceof Port){
						element.type = value as String
					} else if (element instanceof SingleVarDeclaration){
						element.type = value as String
					} else {
						throw new Exception("Unexpected element type: " + element)
					}
				}
			],
			[// inferField
				element | {
					if (element instanceof SingleParamDeclaration) {
						return extractTypeFromExpression(element.expr, element.name)
					} else if (element instanceof Port){
						return getPortType(element)
					} else if (element instanceof SingleVarDeclaration){
						return extractTypeFromExpression(element.expr, element.name)
					} else {
						throw new Exception("Unexpected element type: " + element)
					}
				}
			]
		)
		
		if (untypedElements > 0){
			
			Log.println("Error: Could not infer all types. There are " + untypedElements + " untyped elements.")
			
			Log.println(prettyprint_model(sa, "Current File"))
			
			throw new Exception("Could not infer all types. There are " + untypedElements + " untyped elements.")
		}
	}
	
	def canonicalize(Adaptation sa){
		Log.push("Canonicalize")
		
		inferUnits(sa)
		
		inferTypes(sa)
		
		addInPorts(sa)
		
		val inputPort2parameterDeclaration = addInParams(sa)
		
		val inputPort2InVarDeclaration = addInVars(sa, inputPort2parameterDeclaration)
		
		addInRules_External2Stored_Assignments(sa, inputPort2InVarDeclaration)
		
		val internalPort2ExternalPortBindings = findAllExternalPort2InputPort_Bindings(sa)
		
		addInRules_External2Internal_Assignments(sa, internalPort2ExternalPortBindings)
		
		removeInBindings(internalPort2ExternalPortBindings, sa)
		
		//addOutPorts(sa)
		
		Log.pop("Canonicalize")
	}
	
	def removeInBindings(HashMap<Port, Port> internalPort2ExternalPortBindings, Adaptation sa) {
		Log.push("removeInBindings")
		
		for (internalPort : internalPort2ExternalPortBindings.keySet){
			val externalPort = internalPort2ExternalPortBindings.get(internalPort)
			Log.println("Removing binding " + externalPort.name + "->" + internalPort.name)
			externalPort.targetdependency = null
		}
		
		Log.pop("removeInBindings")
	}
	
	def findAllExternalPort2InputPort_Bindings(Adaptation sa) {
		Log.push("findAllExternalPort2InputPort_Bindings")
		
		val internalPort2ExternalPortBindings = new HashMap<Port, Port>()
		
		for (port : getAllInnerFMUInputPortDeclarations(sa)){
			var parentFMU = port.eContainer as InnerFMU
			Log.println("Checking if port " + parentFMU.name + "." + port.name + " is bound to an external port.")
			val externalPort = findExternalPortByTargetDependency(sa, port)
			if (externalPort !== null){
				Log.println("Port " + parentFMU.name + "." + port.name + " is bound to an external port: " + externalPort.name)
				internalPort2ExternalPortBindings.put(port, externalPort)
			} else {
				Log.println("Port " + parentFMU.name + "." + port.name + " is not bound to an external port.")
			}
		}
		
		Log.pop("findAllExternalPort2InputPort_Bindings")
		
		return internalPort2ExternalPortBindings
	}
	
	def createExternalPortNameFromInternalPort(String parentFMUName, String internalPortName) {
		//return parentFMUName + "__" + internalPortName // Violates transparency
		return internalPortName
	}
	
	def addInRules_External2Internal_Assignments(Adaptation sa, HashMap<Port, Port> internalPort2ExternalPort) {
		Log.push("addInRules_External2Internal_Assignments")
		
		val dataRule  = getOrPrependTrueInRule(sa)
		
		for(internalPort : internalPort2ExternalPort.keySet){
			val externalPort = internalPort2ExternalPort.get(internalPort)
			addAssignmentToInternalPort(dataRule.outputfunction, internalPort, externalPort)
		}
		
		Log.pop("addInRules_External2Internal_Assignments")
	}
	
	def addAssignmentToInternalPort(OutputFunction function, Port internalPort, Port externalPort) {
		Log.push("addAssignmentToInternalPort")
		
		if(! (function instanceof CompositeOutputFunction) ){
			throw new Exception("Only CompositeOutputFunction is supported for now.")
		}
		
		val assignment = SemanticAdaptationFactory.eINSTANCE.createAssignment()
		assignment.lvalue = SemanticAdaptationFactory.eINSTANCE.createVariable()
		(assignment.lvalue as Variable).owner = internalPort.eContainer as InnerFMU
		(assignment.lvalue as Variable).ref = internalPort
		assignment.expr = SemanticAdaptationFactory.eINSTANCE.createVariable()
		(assignment.expr as Variable).owner = externalPort.eContainer as Adaptation
		(assignment.expr as Variable).ref = externalPort
		
		val outFunction = function as CompositeOutputFunction
		outFunction.statements.add(0, assignment)
		
		Log.println("Assignment " + internalPort.name + " := " + externalPort.name + " created.")
		
		Log.pop("addAssignmentToInternalPort")
	}
	
	def addInRules_External2Stored_Assignments(Adaptation sa, HashMap<Port, SingleVarDeclaration> inputPort2InVarDeclaration) {
		Log.push("addInRules_External2Stored_Assignments")
		
		val dataRule  = getOrPrependTrueInRule(sa)
		
		for(inPort : inputPort2InVarDeclaration.keySet){
			val storedVarDecl = inputPort2InVarDeclaration.get(inPort)
			addAssignmentToStoredVar(dataRule.statetransitionfunction, inPort, storedVarDecl)
		}
		
		Log.pop("addInRules_External2Stored_Assignments")
	}
	
	def addAssignmentToStoredVar(StateTransitionFunction function, Port inPort, SingleVarDeclaration storedVarDecl) {
		Log.push("addAssignmentToStoredVar")
		
		if (function.expression !== null){
			throw new Exception("Expressions in rules are not supported yet.")
			// This and the one below are asily solved with a syntactic sugar substitution.
		}
		if (function.assignment !== null){
			throw new Exception("Assignment in rules are not supported yet.")
		}
		
		val assignment = SemanticAdaptationFactory.eINSTANCE.createAssignment()
		assignment.lvalue = SemanticAdaptationFactory.eINSTANCE.createVariable()
		assignment.lvalue.ref = storedVarDecl
		assignment.expr = SemanticAdaptationFactory.eINSTANCE.createVariable()
		(assignment.expr as Variable).owner = inPort.eContainer as Adaptation
		(assignment.expr as Variable).ref = inPort
		
		function.statements.add(0, assignment)
		
		Log.println("Assignment " + storedVarDecl.name + " := " + inPort.name + " created.")
		
		Log.pop("addAssignmentToStoredVar")
	}
	
	def getOrPrependTrueInRule(Adaptation sa) {
		if (sa.in === null){
			sa.in = SemanticAdaptationFactory.eINSTANCE.createInRulesBlock()
		}
		var DataRule rule = null
		if (sa.in.rules.size == 0 || !isTrueRule(sa.in.rules.head)){
			Log.println("No existing rule found with true condition. Creating one.")
			val trueRule = SemanticAdaptationFactory.eINSTANCE.createDataRule()
			trueRule.condition = SemanticAdaptationFactory.eINSTANCE.createRuleCondition()
			val trueExpr = SemanticAdaptationFactory.eINSTANCE.createBoolLiteral()
			trueExpr.value = "true"
			trueRule.condition.condition = trueExpr
			
			trueRule.statetransitionfunction = SemanticAdaptationFactory.eINSTANCE.createStateTransitionFunction()
			
			trueRule.outputfunction = SemanticAdaptationFactory.eINSTANCE.createCompositeOutputFunction()
			
			sa.in.rules.add(0, trueRule)
			rule = trueRule
		} else {
			Log.println("Existing rule with true condition found.")
			rule = sa.in.rules.head
		}
		return rule
	}
	
	def isTrueRule(DataRule rule){
		if (rule.condition.condition instanceof BoolLiteral){
			return (rule.condition.condition as BoolLiteral).value == "true"
		}
		return false
	}
	
	def addInVars(Adaptation sa, Map<Port, SingleParamDeclaration> inputPort2parameterDeclaration){
		Log.push("addInVars")
		
		var inputPort2InVarDeclaration = new HashMap<Port, SingleVarDeclaration>()
		
		for(inputPort : inputPort2parameterDeclaration.keySet){
			Log.println("Processing port " + inputPort.name)
			val paramDecl = inputPort2parameterDeclaration.get(inputPort)
			
			val varDeclarationName = getGeneratedInVarDeclarationName(inputPort)			
			
			if (!varDeclarationExists(varDeclarationName, sa)){
				Log.println("Creating new input variable declaration " + varDeclarationName)
				
				val varDeclaration = addNewInputVarDeclaration(inputPort, paramDecl, sa)
				
				inputPort2InVarDeclaration.put(inputPort, varDeclaration)
			} else {
				Log.println("Input variable declaration " + varDeclarationName + " already exists.")
			}
		}
		
		Log.pop("addInVars")
		return inputPort2InVarDeclaration
	}
	
	def addNewInputVarDeclaration(Port externalInputPort, SingleParamDeclaration paramDecl, Adaptation sa) {
		if (sa.in === null){
			sa.in = SemanticAdaptationFactory.eINSTANCE.createInRulesBlock()
		}
		if (sa.in.globalInVars.size == 0){
			sa.in.globalInVars.add(SemanticAdaptationFactory.eINSTANCE.createDeclaration())
		}
		
		val newSingleVarDecl = SemanticAdaptationFactory.eINSTANCE.createSingleVarDeclaration()
		newSingleVarDecl.name = getGeneratedInVarDeclarationName(externalInputPort)
		newSingleVarDecl.type = externalInputPort.type
		val initValue = SemanticAdaptationFactory.eINSTANCE.createVariable()
		initValue.ref = paramDecl
		newSingleVarDecl.expr = initValue
		
		sa.in.globalInVars.head.declarations.add(newSingleVarDecl)
		
		Log.println("New input variable declaration created: " + newSingleVarDecl.name + " := " + paramDecl.name)
		return newSingleVarDecl
	}
	
	def varDeclarationExists(String invarName, Adaptation sa) {
		if (sa.in !== null){
			for (declarations : sa.in.globalInVars){
				for (decl : declarations.declarations){
					if (decl.name == invarName){
						return true
					}
				}
			}
		}
		return false
	}
	
	def getGeneratedInVarDeclarationName(Port externalInputPort) {
		return "stored__" + externalInputPort.name;
	}
	
	def genericDeclarationInferenceAlgorithm(Adaptation sa, 
												(EObject)=>Object getField, 
												(EObject, Object)=>void setField,
												(EObject)=>Object inferField
	){
		Log.push("Running generic inference algorithm...")
		
		/*
		 * Dumbest (and simplest) algorithm for this is a fixed point computation:
		 * 1. Look for every var/port declaration
		 * 2. If that var has a XXX already, nothing else to be done.
		 * 3. If that var has no XXX declared, then
		 * 3.1 If var/port has an initial value or connection, then
		 * 3.1.1 If the initial_value/connection has a XXX declared, then var gets that XXX.
		 * 3.1.2 Otherwise, nothing else to be done.
		 * 3.2 If var/port has no initial value or connection then this either is a missing feature, or an error.
		 * 3.3 If something has changed, go to 1. Otherwise, end.
		 * 
		 * An extra set of instructions is there to push the element field information using connections and bindings.
		 */
		var fixedPoint = false
		var unfieldedElementsCounter = 0
		while (! fixedPoint){
			fixedPoint = true
			unfieldedElementsCounter = 0
			
			Log.println("Inferring parameter fields...")
			
			for (paramDeclarations : sa.params) {
				for (paramDeclaration : paramDeclarations.declarations) {
					Log.println("Computing field for param " + paramDeclaration.name)
					if(getField.apply(paramDeclaration) !== null){
						Log.println("Already has been inferred: " + getField.apply(paramDeclaration))
					} else {
						Log.println("Has not been inferred yet.")
						if (tryInferAndAssignField(paramDeclaration, getField, setField, inferField)){
							fixedPoint = false
						} else {
							unfieldedElementsCounter++
						}
					}
				}
			}
			
			if(sa.inner !== null){
				if(sa.inner instanceof InnerFMUDeclarationFull){
					var innerFMUFull = sa.inner as InnerFMUDeclarationFull
					for(fmu : innerFMUFull.fmus){
						Log.println("Inferring port fields of FMU " + fmu.name)
						for (port : EcoreUtil2.getAllContentsOfType(fmu, Port)) {
							if(getField.apply(port) !== null){
								Log.println("Already has a field: " + getField.apply(port))
							} else {
								if (tryInferAndAssignField(port, getField, setField, inferField)){
									fixedPoint = false
								} else {
									unfieldedElementsCounter++
								}
							}
						}
					}
					
					if (innerFMUFull.connection.size > 0){
						Log.println("Inferring port fields using internal scenario bindings.")
						for (binding : innerFMUFull.connection){
							if (getField.apply(binding.src.port) !== null && getField.apply(binding.tgt.port) !== null){
								Log.println("Both ports have fields already.")
							} else {
								var inferredFieldAttempt = inferPortFieldViaConnection(binding, getField, setField, inferField)
								if (inferredFieldAttempt !== null){
									if (getField.apply(binding.src.port) === null){
										setField.apply(binding.src.port, inferredFieldAttempt)
									} else if (getField.apply(binding.tgt.port) === null){
										setField.apply(binding.tgt.port, inferredFieldAttempt)
									}
									fixedPoint = false
									unfieldedElementsCounter--
									Log.println("Got new field: " + inferredFieldAttempt)
								} else {
									Log.println("Cannot infer field from binding now.")
								}
							}
						}
					}
				} else {
					throw new Exception("Field inference only supported for InnerFMUDeclarationFull.")
				}
			}
			
			Log.println("Inferring external port fields...")
			
			var externalPorts = new LinkedList(sa.inports)
			externalPorts.addAll(sa.outports)
			
			for (port : externalPorts) {
				if (getField.apply(port) !== null){
					Log.println("Already has a field: " + getField.apply(port))
					if (pushPortField(port, getField, setField, inferField)){
						fixedPoint = false
						unfieldedElementsCounter--
					} 
				} else {
					if (tryInferAndAssignField(port, getField, setField, inferField)){
						fixedPoint = false
					} else {
						unfieldedElementsCounter++
					}
				}
			}
			
			Log.println("Inferring all other declaration fields...")
			
			for (varDeclaration : EcoreUtil2.getAllContentsOfType(sa, SingleVarDeclaration)) {
				Log.println("Computing field for declaration " + varDeclaration.name)
				if(getField.apply(varDeclaration) !== null){
					Log.println("Already has a field: " + getField.apply(varDeclaration))
				} else {
					if (tryInferAndAssignField(varDeclaration, getField, setField, inferField)){
						fixedPoint = false
					} else {
						unfieldedElementsCounter++
					}
				}
			}
			
			Log.println("Ended iteration with unfielded elements remaining: " + unfieldedElementsCounter)
		} // while (! fixedPoint)
		
		
		Log.pop("Running generic inference algorithm... DONE")
		
		return unfieldedElementsCounter
	}
	
	def tryInferAndAssignField(EObject element, 
									(EObject)=>Object getField, 
									(EObject, Object)=>void setField,
									(EObject)=>Object inferField) {
		var inferredFieldAttempt = inferField.apply(element)
		if (inferredFieldAttempt !== null){
			setField.apply(element, inferredFieldAttempt)
			Log.println("Got new field: " + inferredFieldAttempt)
			return true
		} else {
			Log.println("Cannot infer field now.")
			return false
		}
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
	
	def inferPortFieldViaConnection(Connection binding, 
										(EObject)=>Object getField, 
										(EObject, Object)=>void setField,
										(EObject)=>Object inferField
	){
		var Object resultField = null
		if (getField.apply(binding.src.port) !== null && getField.apply(binding.tgt.port) !== null){
			throw new Exception("Wrong way of using this function. It assumes type is not inferred yet.")
		} else if (getField.apply(binding.src.port) !== null){
			resultField = getField.apply(binding.src.port)
			Log.println("Target port "+ binding.tgt.port.name +" got new type: " + resultField)
		} else if (getField.apply(binding.tgt.port) !== null){
			resultField = getField.apply(binding.tgt.port)
			Log.println("Target port "+ binding.src.port.name +" got new type: " + resultField)
		}
		
		return resultField
	}
	
	def pushPortField(Port port, 
							(EObject)=>Object getField, 
							(EObject, Object)=>void setField,
							(EObject)=>Object inferField){
		var fieldInferred = false
		Log.println("Pushing field of port " + port.name + " to its bindings.")
		
		if(getField.apply(port) === null){
			Log.println("Has no field to be pushed.")
			throw new Exception("Wrong way of using this function. It assumes field is already inferred.")
		} else {
			Log.println("Pushing field: " + getField.apply(port))
			if(port.sourcedependency !== null){
				Log.println("Has a source dependency: " + port.sourcedependency.port.name)
				if(getField.apply(port.sourcedependency.port) === null){
					setField.apply(port.sourcedependency.port, getField.apply(port))
					Log.println("Port " + port.sourcedependency.port.name + " got new type: " + getField.apply(port.sourcedependency.port))
					fieldInferred = true
				} else {
					Log.println("Source port already has field.")
				}
			} else {
				Log.println("Has no source dependency.")
			}
			
			if (port.targetdependency !== null) {
				Log.println("Has a target dependency: " + port.targetdependency.port.name)
				if(getField.apply(port.targetdependency.port) === null){
					Log.println("Dependency has no field yet.")
					setField.apply(port.targetdependency.port, getField.apply(port))
					Log.println("Port " + port.targetdependency.port.name + " got new type: " + getField.apply(port.targetdependency.port))
					fieldInferred = true
				} else {
					Log.println("Target port already has field.")
				}
			} else {
				Log.println("Has no target dependency.")
			}
		}
		
		return fieldInferred
	}
	
	def getPortUnit(Port port){
		var unitInferred = false
		
		Log.println("Computing unit for port " + port.name)
		
		var Unity returnUnit = null
		
		if(port.unity !== null){
			throw new Exception("Wrong way of using this function. It assumes unit is not inferred yet.")
		} else {
			Log.println("Has no unit.")
			
			Log.println("Attempting to infer unit from bindings.")

			if(port.sourcedependency !== null){
				Log.println("Has a source dependency: " + port.sourcedependency.port.name)
				if(port.sourcedependency.port.unity === null){
					Log.println("Dependency has no unit yet.")
				} else {
					returnUnit = port.sourcedependency.port.unity
					Log.println("Got new unit: " + returnUnit)
					unitInferred = true
				}
			} else {
				Log.println("Has no source dependency.")
			}
			
			if (port.targetdependency !== null && !unitInferred) {
				Log.println("Has a target dependency: " + port.targetdependency.owner.name + "." + port.targetdependency.port.name)
				if(port.targetdependency.port.unity === null){
					Log.println("Dependency has no unit yet.")
				} else {
					returnUnit = port.targetdependency.port.unity
					Log.println("Got new unit: " + returnUnit)
					unitInferred = true
				}
			} else {
				Log.println("Has no target dependency, or unit has already been inferred from source dependency.")
			}
		}
		
		return returnUnit
	}
	
	def getPortType(Port port){
		var typeInferred = false
		
		Log.println("Computing type for port " + port.name)
		
		var String returnType = null
		
		if(port.type !== null){
			throw new Exception("Wrong way of using this function. It assumes type is not inferred yet.")
		} else {
			Log.println("Has no type.")
			
			Log.println("Attempting to infer type from units.")
			if (port.unity !== null){
				returnType = "Real"
				Log.println("Got new type: " + returnType)
				typeInferred = true
			} else {
				Log.println("Attempting to infer type from bindings.")

				if(port.sourcedependency !== null){
					Log.println("Has a source dependency: " + port.sourcedependency.port.name)
					if(port.sourcedependency.port.type === null){
						Log.println("Dependency has no type yet.")
					} else {
						returnType = port.sourcedependency.port.type
						Log.println("Got new type: " + returnType)
						typeInferred = true
					}
				} else {
					Log.println("Has no source dependency.")
				}
				
				if (port.targetdependency !== null && !typeInferred) {
					Log.println("Has a target dependency: " + port.targetdependency.owner.name + "." + port.targetdependency.port.name)
					if(port.targetdependency.port.type === null){
						//println("Port object: " + port.targetdependency.port)
						Log.println("Dependency has no type yet.")
					} else {
						returnType = port.targetdependency.port.type
						Log.println("Got new type: " + returnType)
						typeInferred = true
					}
				} else {
					Log.println("Has no target dependency, or type has already been inferred from source dependency.")
				}
			}
		}
		
		return returnType
	}
	
	def addInPorts(Adaptation sa) {
		Log.push("Adding input ports...")

		for (port : getAllInnerFMUInputPortDeclarations(sa)){
			var parentFMU = port.eContainer as InnerFMU
			Log.println("Checking if port " + parentFMU.name + "." + port.name + " has incoming connections")
			if (! hasConnection(port, sa, true)){
				Log.println("Port " + parentFMU.name + "." + port.name + " has no incoming connections.")
				val externalPortName = createExternalPortNameFromInternalPort(parentFMU.name, port.name)
				if (findExternalPortByName(sa, externalPortName) === null){
					var newExternalPort = createExternalInputPortDeclarationFromInnerPort(port, parentFMU, sa)
					Log.println("External port " + newExternalPort.name + " created.")
					newExternalPort.bindExternalInputPortTo(parentFMU, port)
					Log.println("External port " + newExternalPort.name + " bound to port " + parentFMU.name + "." + port.name)
				} else {
					Log.println("Error: External port " + externalPortName + " already declared.")
					throw new Exception("Error: External port " + externalPortName + " already declared. Please rename it to avoid clashes.")
				}
			} else {
				Log.println("Port " + parentFMU.name + "." + port.name + " has an incoming connection.")
			}
		}
		
		Log.pop("Adding input ports... DONE")
	}
	
	def bindExternalInputPortTo(Port externalInputPort, InnerFMU internalPortParent, Port internalPort) {
		externalInputPort.targetdependency = SemanticAdaptationFactory.eINSTANCE.createSpecifiedPort()
		externalInputPort.targetdependency.owner = internalPortParent
		externalInputPort.targetdependency.port = internalPort
	}
	
	def createExternalInputPortDeclarationFromInnerPort(Port port, FMU parent, Adaptation sa) {
		var externalInputPort = SemanticAdaptationFactory.eINSTANCE.createPort()
		externalInputPort.name = createExternalPortNameFromInternalPort(parent.name, port.name)
		externalInputPort.type = port.type
		externalInputPort.unity = EcoreUtil2.copy(port.unity)
		sa.inports.add(externalInputPort)
		return externalInputPort
	}
	
	def findExternalPortByName(Adaptation adaptation, String name) {
		for (externalInputPort : adaptation.inports){
			if (externalInputPort.name == name){
				return externalInputPort
			}
		}
		return null
	}
	
	
	def findExternalPortByTargetDependency(Adaptation sa, Port targetDependency) {
		for (externalInputPort : sa.inports){
			if (externalInputPort.targetdependency !== null && externalInputPort.targetdependency.port == targetDependency){
				return externalInputPort
			}
		}
		return null
	}
	
	
	def hasConnection(Port port, Adaptation adaptation, Boolean checkForIncomming) {
		
		var result = false
		
		if ( (checkForIncomming && port.sourcedependency !== null) ||
			 (! checkForIncomming && port.targetdependency !== null)
		){
			result = true
		} else {
			if (port.eContainer instanceof InnerFMU){
				
				var innerScenarioDeclaration = EcoreUtil2.getContainerOfType(port, InnerFMUDeclaration)
				
				if (innerScenarioDeclaration instanceof InnerFMUDeclarationFull){
					var innerScenarioWithCoupling = innerScenarioDeclaration as InnerFMUDeclarationFull
					if (innerScenarioWithCoupling.connection.size > 0){
						for (connection : innerScenarioWithCoupling.connection ){
							if ( (checkForIncomming && connection.tgt.port == port)){
								var parentFMU = port.eContainer as InnerFMU
								var sourceFMU = connection.src.port.eContainer as InnerFMU
								Log.println("Port " + parentFMU.name + "." + port.name + " has an incoming connection from internal port " + sourceFMU.name + "." + connection.src.port.name)
								result = true
							} else if (!checkForIncomming && connection.src.port == port) {
								var parentFMU = port.eContainer as InnerFMU
								var targetFMU = connection.tgt.port.eContainer as InnerFMU
								Log.println("Port " + parentFMU.name + "." + port.name + " has an outgoing connection to internal port " + targetFMU.name + "." + connection.tgt.port.name)
								result = true
							}
						}
					}
				}
				
				for (externalInputPort : adaptation.inports.filter[p | (checkForIncomming && p.targetdependency !== null) || (!checkForIncomming && p.sourcedependency !== null) ]){
					if (checkForIncomming && externalInputPort.targetdependency.port == port){
						var parentFMU = port.eContainer as InnerFMU
						Log.println("Port " + parentFMU.name + "." + port.name + " has an incoming connection from external port " + externalInputPort.name)
						result = true
					} else if ( !checkForIncomming &&  externalInputPort.sourcedependency.port == port){
						var parentFMU = port.eContainer as InnerFMU
						Log.println("Port " + parentFMU.name + "." + port.name + " has an outgoing connection to external port " + externalInputPort.name)
						result = true
					}
				}
			}
		}
		
		return result
	}
	
	def getAllInnerFMUInputPortDeclarations(Adaptation sa){
		return mapAllInnerFMUs(sa, [fmu | fmu.inports]);
	}
	
	def getAllInnerFMUOutputPortDeclarations(Adaptation sa){
		return mapAllInnerFMUs(sa, [fmu | fmu.outports]);
	}
	
	def <T> List<T> mapAllInnerFMUs(Adaptation sa, (InnerFMU)=>List<T> map){
		var result = new LinkedList()
		
		if(sa.inner !== null){
			if(sa.inner instanceof InnerFMUDeclarationFull){
				var innerFMUFull = sa.inner as InnerFMUDeclarationFull
				for(fmu : innerFMUFull.fmus){
					result.addAll(map.apply(fmu))
				}
			} else {
				throw new Exception("Only support for InnerFMUDeclarationFull.")
			}
		}
		
		return result;
	}
	
	
	def addInParams(Adaptation sa) {
		Log.push("Adding input parameters...")
		
		val PARAM_PREFIX = "INIT_"
		
		var inputPort2parameterDeclaration = new HashMap<Port, SingleParamDeclaration>(sa.inports.size)
		
		for (inputPortDeclaration : sa.inports) {
			Log.println("Generating parameter for port " + inputPortDeclaration.name)
			var paramname = PARAM_PREFIX + inputPortDeclaration.name.toUpperCase()
			
			if (paramAlreadyDeclared(paramname, sa)){
				Log.println("Parameter " + paramname + " already declared for port " + inputPortDeclaration.name)
			} else {
				Log.println("Declaring new parameter " + paramname + " for port " + inputPortDeclaration.name)
				var paramDeclaration = addNewParamDeclaration(paramname, inputPortDeclaration, sa)
				inputPort2parameterDeclaration.put(inputPortDeclaration, paramDeclaration)
			}
		}
		
		Log.pop("Adding input parameters... DONE")
		return inputPort2parameterDeclaration
	}
	
	def addNewParamDeclaration(String name, Port fromPort, Adaptation sa) {
		var factory = SemanticAdaptationFactory.eINSTANCE
		var paramDeclaration = factory.createSingleParamDeclaration()
		
		paramDeclaration.name = name
		paramDeclaration.type = fromPort.type
		paramDeclaration.expr = getDefaultTypeExpression(paramDeclaration.type)
		
		if (sa.params.size == 0){
			sa.params.add(factory.createParamDeclarations())
		}
		
		sa.params.head.declarations.add(paramDeclaration)
		return paramDeclaration
	}
	
	def getDefaultTypeExpression(String type) {
		switch (type) {
			case "Integer": {
				val result = SemanticAdaptationFactory.eINSTANCE.createIntLiteral
				result.value = 0
				return result
			}
			case "Real": {
				val result = SemanticAdaptationFactory.eINSTANCE.createRealLiteral
				result.value = 0.0f
				return result
			}
			case "Bool": {
				val result = SemanticAdaptationFactory.eINSTANCE.createBoolLiteral
				result.value = "false"
				return result
			}
			case "String": {
				val result = SemanticAdaptationFactory.eINSTANCE.createStringLiteral
				result.value = ""
				return result
			}
			default: {
				throw new Exception("Unexpected type.")
			}
		}
	}
	
	def paramAlreadyDeclared(String name, Adaptation sa) {
		for(paramDeclarations : sa.params){
			for(paramDeclaration : paramDeclarations.declarations){
				if(paramDeclaration.name == name){
					return true
				}
			}
		}
		return false
	}
	
	
	def addOutPorts(Adaptation sa) {
		Log.push("Adding output ports...")

		for (port : getAllInnerFMUOutputPortDeclarations(sa)){
			var parentFMU = port.eContainer as InnerFMU
			Log.println("Checking if port " + parentFMU.name + "." + port.name + " has outgoing connections")
			if (! hasConnection(port, sa, false)){
				Log.println("Port " + parentFMU.name + "." + port.name + " has no outgoing connections.")
				
				// TODO Continue here.
				
				val externalPortName = createExternalPortNameFromInternalPort(parentFMU.name, port.name)
				if (findExternalPortByName(sa, externalPortName) === null){
					var newExternalPort = createExternalInputPortDeclarationFromInnerPort(port, parentFMU, sa)
					Log.println("External port " + newExternalPort.name + " created.")
					newExternalPort.bindExternalInputPortTo(parentFMU, port)
					Log.println("External port " + newExternalPort.name + " bound to port " + parentFMU.name + "." + port.name)
				} else {
					Log.println("Error: External port " + externalPortName + " already declared.")
					throw new Exception("Error: External port " + externalPortName + " already declared. Please rename it to avoid clashes.")
				}
			} else {
				Log.println("Port " + parentFMU.name + "." + port.name + " has an incoming connection.")
			}
		}
		
		Log.pop("Adding output ports... DONE")
	}
	
}
