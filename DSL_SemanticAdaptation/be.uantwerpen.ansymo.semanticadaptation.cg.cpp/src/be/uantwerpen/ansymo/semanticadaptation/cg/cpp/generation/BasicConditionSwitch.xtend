package be.uantwerpen.ansymo.semanticadaptation.cg.cpp.generation

import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.data.ReturnInformation
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.util.SemanticAdaptationSwitch
import org.eclipse.emf.ecore.EObject
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Multi
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Div
import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.data.SVType
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Neg
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.RealLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.IntLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Literal
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.BoolLiteral
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Min
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Minus
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Plus
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.LessThan
import be.uantwerpen.ansymo.semanticadaptation.cg.cpp.exceptions.TypeException
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.Or
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.NotEquals
import be.uantwerpen.ansymo.semanticadaptation.semanticAdaptation.GreaterThanOrEquals

class BasicConditionSwitch extends SemanticAdaptationSwitch<ReturnInformation> {

	private def Object convertTypeToObject(SVType type, Literal object) {
		switch (type) {
			case Real: {
				return (object as RealLiteral).value.doubleValue;
			}
			case Integer: {
				return (object as IntLiteral).value;
			}
			case Boolean: {
				return Boolean.parseBoolean((object as BoolLiteral).value);
			}
			default: {
			}
		}
	}
	
		override ReturnInformation caseRealLiteral(RealLiteral object) {
		var retInfo = new ReturnInformation();
		retInfo.type = SVType.Real;
		retInfo.value = convertTypeToObject(retInfo.type, object);
		retInfo.code = '''«object.value»''';
		return retInfo;
	}

	override ReturnInformation caseIntLiteral(IntLiteral object) {
		var retInfo = new ReturnInformation();
		retInfo.type = SVType.Integer;
		retInfo.value = convertTypeToObject(retInfo.type, object);
		retInfo.code = '''«object.value»''';
		return retInfo;
	}

	override ReturnInformation caseBoolLiteral(BoolLiteral object) {
		var retInfo = new ReturnInformation();
		retInfo.type = SVType.Boolean;
		retInfo.value = convertTypeToObject(retInfo.type, object);
		retInfo.code = '''«object.value»''';

		return retInfo;
	}

	override ReturnInformation defaultCase(EObject object) {
		var retVal = new ReturnInformation();
		retVal.code = '''[«object.class»]''';
		return retVal;
	}

	override ReturnInformation caseMulti(Multi object) {
		val doSwitchLeft = doSwitch(object.left);
		val doSwitchRight = doSwitch(object.right);
		var retVal = new ReturnInformation(doSwitchLeft, doSwitchRight);
		retVal.code = '''«doSwitchLeft.code» * «doSwitchRight.code»''';
		return retVal;
	}

	override ReturnInformation caseDiv(Div object) {
		val doSwitchLeft = doSwitch(object.left);
		val doSwitchRight = doSwitch(object.right);
		var retVal = new ReturnInformation(doSwitchLeft, doSwitchRight);
		retVal.code = '''«doSwitchLeft.code» / «doSwitchRight.code»''';
		retVal.type = SVType.Real;
		retVal.forceType = true;
		return retVal;
	}

	override ReturnInformation caseNeg(Neg object) {

		var doSwitch = doSwitch(object.right);
		var retVal = new ReturnInformation(doSwitch);
		retVal.code = doSwitch.code;

		return retVal;
	}
	
		override ReturnInformation caseMin(Min object) {
		var retInfo = new ReturnInformation();
		var doSwitchResCode = newArrayList();
		for (expr : object.args) {
			val doSwitchRes_ = this.doSwitch(expr);
			doSwitchResCode.add(doSwitchRes_.code);
			retInfo = new ReturnInformation(retInfo, doSwitchRes_);
		}
		retInfo.code = '''min(«doSwitchResCode.join(",")»)'''
		return retInfo;
	}

	override ReturnInformation caseMinus(Minus object) {
		val doSwitchLeft = doSwitch(object.left);
		val doSwitchRight = doSwitch(object.right);
		var retVal = new ReturnInformation(doSwitchLeft, doSwitchRight);
		retVal.code = '''«doSwitchLeft.code» - «doSwitchRight.code»''';
		return retVal;
	}

	override ReturnInformation casePlus(Plus object) {
		val doSwitchLeft = doSwitch(object.left);
		val doSwitchRight = doSwitch(object.right);
		var retVal = new ReturnInformation(doSwitchLeft, doSwitchRight);
		retVal.code = '''«doSwitchLeft.code» + «doSwitchRight.code»''';
		return retVal;
	}
	
	override ReturnInformation caseGreaterThanOrEquals(GreaterThanOrEquals object)
	{
		var ret = new ReturnInformation();
		val left = doSwitch(object.left);
		val right = doSwitch(object.right);
		val code = '''«left.code» >= «right.code»'''
		if(!Conversions.isTypeANumber(left.type) || !Conversions.isTypeANumber(right.type))
		{
			throw new TypeException('''Wrong types at: «code»''');
		}
		ret.type = SVType.Boolean;
		ret.code = code;
		return ret;
	}
	
	override ReturnInformation caseNotEquals(NotEquals object)
	{
		var ret = new ReturnInformation();
		val left = doSwitch(object.left);
		val right = doSwitch(object.right);
		val code = '''«left.code» != «right.code»'''
		if(left.type !== right.type)
		{
			throw new TypeException('''Wrong types at: «code»''');
		}
		ret.type = SVType.Boolean;
		ret.code = code;
		return ret;
	}
	
	override ReturnInformation caseLessThan(LessThan object)
	{
		var ret = new ReturnInformation();
		val left = doSwitch(object.left);
		val right = doSwitch(object.right);
		val code = '''«left.code» < «right.code»'''
		if(!Conversions.isTypeANumber(left.type) || !Conversions.isTypeANumber(right.type))
		{
			throw new TypeException('''Wrong types at: «code»''');
		}
		ret.type = SVType.Boolean;
		ret.code = code;
		return ret;
	}
	
	override ReturnInformation caseOr(Or object)
	{
		var ret = new ReturnInformation();
		val left = doSwitch(object.left);
		val right = doSwitch(object.right);
		val code = '''«left.code» || «right.code»'''
		if(left.type !== SVType.Boolean || right.type !== SVType.Boolean)
		{
			throw new TypeException('''Wrong types at: «code»''');
		}
		ret.type = SVType.Boolean;
		ret.code = code;
		return ret;
	}

}
