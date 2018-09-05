/* line below added during FMU creation */ 
#include "dlldata_impl.h"     
#ifdef _MSC_VER
#include "windows.h"
#include "shlwapi.h"
#endif
#ifndef DYMOLA_STATIC_IMPORT
#define DYMOLA_STATIC_IMPORT DYMOLA_STATIC
#endif
#ifndef FMU_SKIP_MODEL_EXCHANGE

/* The generic implementation of the FMI ME interface. */
/* need to include first so that correct files are included */
#include "conf.h"
#include "util.h"
#include "result.h"
#include "memdebug.h"

#include "fmiFunctions_fwd.h"

#include "dlldata.h"
#include "dymosim.h"

#include <string.h>
#include <assert.h>


/* platform specifics */
#if defined(_MSC_VER) && _MSC_VER >= 1400
/* avoid warnings from Visual Studio */
#define strncpy(dest, src, len) strncpy_s(dest, (len) + 1, src, len)
#endif

/* ----------------- global variables ----------------- */

/* This has 2 purposes:
   1. Detect attempts to create mutliple instances of same FMU.
   2. Direct logging from libds code to FMI logger, when providing FMU with source code. 
*/

/* when compiling as a single complilation unit, this is already defined */
#ifndef FMU_SOURCE_SINGLE_UNIT
extern Component* globalComponent;
extern Component* globalComponent2;
#endif

/* ----------------- macros ----------------- */

#define ME_RESULT_SAMPLE(atEvent)                             \
if (comp->storeResult == FMITrue) {                           \
		result_sample(comp, atEvent);                         \
}

/* ----------------- external function declarations ----------------- */
struct DYNInstanceData;
DYMOLA_STATIC int GetDymolaOneIteration(struct DYNInstanceData*);
DYMOLA_STATIC void SetDymolaOneIteration(struct DYNInstanceData*, int val);
extern void declare_(double*, double*, double*, void**,int*);

/* ----------------- local function declarations ----------------- */

FMIStatus initializeModel(FMIComponent c, FMIBoolean toleranceControlled, FMIReal relativeTolerance, FMIBoolean complete);

/* ----------------- function definitions ----------------- */

/* For 2.0 this is replaced by a common function named fmiGetTypesPlatform_. */
#ifndef FMI_2
DYMOLA_STATIC const char* fmiGetModelTypesPlatform_()
{
	return fmiModelTypesPlatform;
}
#endif

/* ---------------------------------------------------------------------- */
#ifndef FMU_SOURCE_SINGLE_UNIT
extern char* GUIDString;
#endif

#endif /* FMU_SKIP_MODEL_EXCHANGE */

 struct DYNInstanceDataMinimal {
		  struct BasicDDymosimStruct*basicD;
		  struct BasicIDymosimStruct*basicI;
 };
DYMOLA_STATIC_IMPORT size_t dyn_allowMultipleInstances;
DYMOLA_STATIC void DYNInitializeDid(struct DYNInstanceData*did_);
DYMOLA_STATIC
#ifdef FMI_2
FMIComponent fmiInstantiateModel_(FMIString instanceName,
								  FMIString fmuGUID,
								  FMIString fmuResourceLocation,
								  const FMICallbackFunctions* functions,
								  FMIBoolean visible,
								  FMIBoolean loggingOn)
#else
FMIComponent fmiInstantiateModel_(FMIString instanceName,
								  FMIString fmuGUID,
								  fmiMECallbackFunctions functions,
								  FMIBoolean loggingOn)
#endif /* FMI_2 */
{
	static FMIString label = "fmiInstantiateModel";
	Component* comp;
	size_t i;
	int QiErr = 0;
#ifdef FMI_2
	const FMICallbackFunctions* funcs = functions;
	JacobianData* jacData;
#else
	fmiMECallbackFunctions* funcs = &functions;
#endif
	if (!dyn_allowMultipleInstances && globalComponent != NULL) {
		util_logger(globalComponent, instanceName != NULL ? instanceName : globalComponent->instanceName,
			FMIFatal, "", "%s: multiple instances within same process not supported", label);
		return NULL;
	}


#ifdef MEMLEAK_DEBUG
	{
#ifdef FMI_2
		FMICallbackFunctions* funcs = (FMICallbackFunctions*) functions;
#else
		fmiMECallbackFunctions* funcs = (fmiMECallbackFunctions*) &functions;
#endif
		funcs->allocateMemory = memdebug_calloc;
		funcs->freeMemory = memdebug_free;
		memdebug_setup();
	}
#endif
	comp = (Component*) funcs->allocateMemory(1 , sizeof(Component));
	if (comp == NULL) {
		goto fail;
	}
	if (dyn_allowMultipleInstances) {
		comp->did = (struct DYNInstanceData*)funcs->allocateMemory(1, dyn_allowMultipleInstances);
		if (comp->did == NULL) {
			goto fail;
		}
		DYNInitializeDid(comp->did);
	} else {
		comp->did = 0;
	}
	comp->handles=0;
#ifdef _MSC_VER
	{
		/* For Loading DLLs from the model. This variant assumes absolute paths and non-wide file names*/
		extern const char*dllLibraryPath[];
		int numDlls,i,maxLen=0;
		if (dllLibraryPath!=0) {
			for(numDlls=0;dllLibraryPath[numDlls];++numDlls) {
				int stri=(int) strlen(dllLibraryPath[numDlls]);
				if (stri>maxLen) maxLen=stri;
			}
			if (numDlls>0) {
				char*s;
				extern const char* dymosimFMIPath();
				int fmiPathLen = (int) strlen(dymosimFMIPath());
				if(fmiPathLen>maxLen) maxLen=fmiPathLen;
				comp->handles=(void**)funcs->allocateMemory(numDlls, sizeof(void*));
				s=(FMIChar*)funcs->allocateMemory(maxLen+1,sizeof(FMIChar));
				if (s==0 || comp->handles==0) goto fail;
				for(i=0;i<numDlls;++i) {
					comp->handles[i]=0;
					strcpy(s,dllLibraryPath[i]);
#if _WIN32_WINNT >= 0x0502
					if (s[0]=='.' && s[1]=='\\') {
						/* Special handling of local DLLs */
						strcpy(s, dymosimFMIPath());
						if (s[0]==0) strcpy(s,dllLibraryPath[i]);
					}
					/* This is the good way */
					PathRemoveFileSpecA(s);
					SetDllDirectoryA(s);
#endif
					comp->handles[i]=(void*)LoadLibraryA(dllLibraryPath[i]);
#if _WIN32_WINNT >= 0x0502
					SetDllDirectory(0);
#endif
				}
				funcs->freeMemory(s);
			}
		}
	}
#endif
	/* Initialize to NULL to facilitate freeing om memory */
	comp->dstruct = NULL;
	comp->istruct = NULL;
	comp->states = comp->derivatives = comp->parameters = comp->inputs = comp->outputs = comp->auxiliary =
		comp->crossingFunctions = comp->statesNominal = NULL;

	comp->isCoSim = FMIFalse; /*Default, change later if Co-Sim*/
	/* set sensible default start time */
	comp->time = 0;
	comp->logbufp = comp->logbuf;
#ifdef FMI_2
	comp->functions = funcs;
	comp->instanceName = util_strdup(comp->functions, instanceName);
#else
	comp->functions.logger = funcs->logger;
	comp->functions.allocateMemory = funcs->allocateMemory;
	comp->functions.freeMemory = funcs->freeMemory;
	comp->instanceName = util_strdup(&comp->functions, instanceName);
#endif
#ifdef FMI_2
	//comp->functions.componentEnvironment = funcs->componentEnvironment;
#endif
	if (comp->instanceName == NULL) {
		goto fail;
	}
	comp->loggingOn = loggingOn;

	/* verify GUID */
	if (strcmp(fmuGUID, GUIDString) != 0) {
		util_logger(comp, instanceName, FMIError, "", "Invalid GUID: %s, expected %s", fmuGUID, GUIDString);
		goto fail;
	}
#ifndef FMU_SOURCE_CODE_EXPORT
	/* Initialize - which will give a predictable error for missing license (otherwise it will be detected later). Not needed for source code export. */
	{
		extern int InitializeDymosimRunTime();
		if (!InitializeDymosimRunTime()) {
			util_logger(comp, instanceName,
				FMIFatal, "", "The license file was not found. Use the environment variable \"DYMOLA_RUNTIME_LICENSE\" to specify your Dymola license file.\n");
			goto fail;
		}
	}
#endif

	comp->dstruct = (struct BasicDDymosimStruct*) funcs->allocateMemory(1, sizeof(struct BasicDDymosimStruct));
	comp->istruct = (struct BasicIDymosimStruct*) funcs->allocateMemory(1, sizeof(struct BasicIDymosimStruct));
	if (comp->dstruct == NULL || comp->istruct == NULL) {
		goto fail;
	}
	comp->duser = (double*) comp->dstruct;
	comp->iuser = (int*) comp->istruct;
	if (comp->did) {
		(( struct DYNInstanceDataMinimal*)comp->did)->basicD=comp->dstruct;
		(( struct DYNInstanceDataMinimal*)comp->did)->basicI=comp->istruct;
	}

	setBasicStruct((double*) comp->dstruct, (int*) comp->istruct);

	{
		int nx, nx2, nu, ny, nw, np, nsp, nrel2, nrel, ncons, dae;
		size_t i =0;
		GetDimensions2(&nx, &nx2, &nu, &ny, &nw, &np, &nsp, &nrel2, &nrel, &ncons, &dae);
		comp->nStates = nx;
		comp->nIn = nu;
		comp->nOut = ny;
		comp->nAux = nw;
		comp->nPar = np;
		comp->nSPar = nsp;
		comp->nCross = 2 * nrel;

		/* Guard against zero value for size by adding one */
		comp->states = (FMIReal*) funcs->allocateMemory(comp->nStates + 1, sizeof(FMIReal));
		comp->derivatives = (FMIReal*) funcs->allocateMemory(comp->nStates + 1, sizeof(FMIReal));
		comp->parameters = (FMIReal*) funcs->allocateMemory(comp->nPar + 1, sizeof(FMIReal));
		comp->inputs = (FMIReal*) funcs->allocateMemory(comp->nIn + 1, sizeof(FMIReal));
		comp->outputs = (FMIReal*) funcs->allocateMemory(comp->nOut + 1, sizeof(FMIReal));
		comp->auxiliary = (FMIReal*) funcs->allocateMemory(comp->nAux + 1, sizeof(FMIReal));
		comp->crossingFunctions = (FMIReal*) funcs->allocateMemory(comp->nCross + 1, sizeof(FMIReal));
		comp->statesNominal = (FMIReal*) funcs->allocateMemory(comp->nStates + 1, sizeof(FMIReal));
		comp->sParameters = (FMIChar**) funcs->allocateMemory(comp->nSPar + 1, sizeof(FMIChar*));
		comp->oldStates = (FMIReal*) funcs->allocateMemory(comp->nStates+1, sizeof(FMIReal));
	}


	if (comp->states == NULL || comp->derivatives == NULL || comp->parameters == NULL ||
		comp->inputs == NULL || comp->outputs == NULL || comp->auxiliary == NULL ||
		comp->crossingFunctions == NULL || comp->statesNominal == NULL || comp->sParameters == NULL) {
			goto fail;
	}
	/*Temporary fmiString pointers to retreve  original fmiStrings when calling reset
	 allocated if needed in reset*/
	comp->tsParameters = NULL; 
	/*  no info available, using default values */
	for (i = 0; i < comp->nStates; i++) {
		comp->statesNominal[i] = 1.0;
	}

#ifdef NEW_CODE_GENERATION
	/* TODO: */
	// assign_real_t(Trivial_variables* v, real_t** p)
	// ...
#endif

	comp->mStatus = modelInstantiated;
	comp->storeResult = FMIFalse;

	comp->iData = NULL;

#ifdef FMI_2
	jacData = &comp->jacData;
	jacData->jacA = jacData->jacB = jacData->jacC = jacData->jacD = NULL;
	jacData->jacV = jacData->jacVTmp1 = jacData->jacVTmp2 = jacData->jacZ = jacData->jacZTmp1 = jacData->jacZTmp2 = NULL;
	jacData->nJacA = jacData->nJacB = jacData->nJacC = jacData->nJacD = 0;
	jacData->nJacV = jacData->nJacZ = 0;
	comp->recalJacobian = 1;
#endif

	/* FMI API does not require caller to set start values, so must fetch start values for
	   states and parameters (other variables are initiated by dsblock_) */
	declare_(comp->states, comp->parameters, comp->inputs, (void **)comp->sParameters, &QiErr);
	for(i=0; i < comp->nSPar; ++i){
		FMIString s=(comp->sParameters)[i];
		size_t len;
		len=strlen(s);
		if (len>MAX_STRING_SIZE) len=MAX_STRING_SIZE;
		(comp->sParameters)[i] = (FMIChar*) funcs->allocateMemory(MAX_STRING_SIZE+1, sizeof(FMIChar));
		memcpy((comp->sParameters)[i], s, len+1);
		(comp->sParameters)[i][MAX_STRING_SIZE]='\0';
	}

	if (QiErr != 0) {
		util_logger(comp, comp->instanceName, FMIError, "",
			"%s: declare_ failed, QiErr = %d", label, QiErr);
		goto fail;
	}	
	/* Default values for setup experiment */
	comp->tStart = 0;
	comp->StopTimeDefined = FMIFalse;
	comp->tStop = 0;
	comp->relativeToleranceDefined = FMIFalse;
	comp->relativeTolerance = 0;

	comp->valWasSet = 0;

	if (!dyn_allowMultipleInstances)
		globalComponent = comp;

	util_logger(comp, comp->instanceName, FMIOK, "", "%s completed", label, QiErr);
	return comp;

fail:
	if (comp != NULL) {
		FMIString iName = instanceName != NULL ? instanceName : "";
		util_logger(comp, iName, FMIFatal, "", "Instantiation failed");
		fmiFreeModelInstance_(comp);
	}
	return NULL;
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC void fmiFreeModelInstance_(FMIComponent c)
{
	Component* comp = (Component*) c;
	FMICallbackFreeMemory freeMemory;
#ifdef FMI_2
	JacobianData* jacData;
#endif
	int i;
	if (comp == NULL) {
		return;
	}

	LOG(comp, FMIOK, "fmiFreeModelInstance");

	assert(comp->instanceName != NULL);
#ifdef FMI_2
	freeMemory = comp->functions->freeMemory;
#else
	freeMemory = comp->functions.freeMemory;
#endif
	freeMemory((void*) comp->instanceName);comp->instanceName=NULL;

	freeMemory(comp->dstruct);comp->dstruct=NULL;
	freeMemory(comp->istruct);comp->istruct=NULL;

	freeMemory(comp->states);comp->states=NULL;
	freeMemory(comp->derivatives);comp->derivatives=NULL;
	freeMemory(comp->parameters);comp->parameters=NULL;
	freeMemory(comp->inputs);comp->inputs=NULL;
	freeMemory(comp->outputs);comp->outputs=NULL;
	freeMemory(comp->auxiliary);comp->auxiliary=NULL;
	freeMemory(comp->crossingFunctions);comp->crossingFunctions=NULL;
	for(i= (int) comp->nSPar-1; i >=0; --i){
		freeMemory( (comp->sParameters)[i]);
		comp->sParameters[i]=NULL;
	}
	freeMemory(comp->sParameters);comp->sParameters=NULL;
	freeMemory(comp->statesNominal);comp->statesNominal=NULL;
	freeMemory(comp->oldStates);comp->oldStates=NULL;

	if(comp->tsParameters != NULL){
		freeMemory(comp->tsParameters);
		comp->tsParameters=NULL;
	}
#ifdef FMI_2
	jacData = &comp->jacData;
	freeMemory(jacData->jacA);jacData->jacA = NULL;
	freeMemory(jacData->jacB);jacData->jacB = NULL;
	freeMemory(jacData->jacC);jacData->jacC = NULL;
	freeMemory(jacData->jacD);jacData->jacD = NULL;
	freeMemory(jacData->jacV);jacData->jacV = NULL;
	freeMemory(jacData->jacVTmp1);jacData->jacVTmp1 = NULL;
	freeMemory(jacData->jacVTmp2);jacData->jacVTmp2 = NULL;
	freeMemory(jacData->jacZ);jacData->jacZ = NULL;
	freeMemory(jacData->jacZTmp1);jacData->jacZTmp1 = NULL;
	freeMemory(jacData->jacZTmp2);jacData->jacZTmp2 = NULL;
#endif /* FMI_2 */

	if (comp->handles) {
#ifdef _MSC_VER
		extern const char*dllLibraryPath[];
		int numDlls,i;
		if (dllLibraryPath!=0) {
			for(numDlls=0;dllLibraryPath[numDlls];++numDlls);
			for(i=0;i<numDlls;++i) {
				FreeLibrary(comp->handles[i]);
				comp->handles[i]=0;
			}
		}
#endif
		freeMemory(comp->handles);comp->handles = NULL;
	}
	if (comp->did) {
#ifdef DYN_MULTINSTANCE
		extern void EnsureMarkFree2();
		EnsureMarkFree2();
#endif
		freeMemory(comp->did);
		comp->did=NULL;
	}
	freeMemory(comp);comp = NULL;
	if (!dyn_allowMultipleInstances) {
		assert(globalComponent == c || globalComponent == NULL);
		globalComponent = NULL;
	}
#ifndef FMU_SOURCE_CODE_EXPORT
	{
		extern void UnInitializeDymosimRunTime();
		UnInitializeDymosimRunTime();
	}
#endif
#ifdef MEMLEAK_DEBUG
	memdebug_check();
#endif
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiSetTime_(FMIComponent c, FMIReal time)
{
	static FMIString label = "fmiSetTime";
	Component* comp = (Component*) c;
	/* avoid cluttering the code with check if time == comp->time to handle odd uses of this function
	   what complicates it is that if in modelEventModeExit, even same time should be considered */
#ifdef FMI_2
	if (comp->mStatus == modelEventModeExit) {
		if (comp->nStates != 0) {
			util_logger(comp, comp->instanceName, FMIWarning, "", "%s: only allowed for discrete models when not in continuous time mode", label);
			return FMIWarning;
		}
		/* resuse this mode also to discrete models for convenience */
		comp->mStatus = modelContinousTimeMode;
	} else if (comp->mStatus != modelContinousTimeMode && comp->mStatus != modelInstantiated)  {
		util_logger(comp, comp->instanceName, FMIWarning, "", "%s: not allowed in this state", label);
		return FMIWarning;
	}
#endif
	comp->time = time;
	comp->icall = iDemandStart;
	comp->recalJacobian = 1;
	util_logger(comp, comp->instanceName, FMIOK, "", "%s to %g", label, time);
	return FMIOK;
}

#ifndef FMU_SKIP_MODEL_EXCHANGE
/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiSetContinuousStates_(FMIComponent c, const FMIReal x[], size_t nx)
{
	static FMIString label = "fmiSetContinuousStates";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;

	if (nx != comp->nStates) {
		status = FMIWarning;
		util_logger(comp, comp->instanceName, status, "",
			"fmiSetContinuousStates: argument nx = %u is incorrect, should be %u", nx, comp->nStates);
		if (nx > comp->nStates) {
			/* truncate */
			nx = comp->nStates;
		}
	}
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	memcpy(comp->states, x, nx * sizeof(FMIReal));
	/* reset caching */
	comp->valWasSet = 1;
	comp->icall = iDemandStart;
	comp->recalJacobian = 1;
	return status;
}

#endif /* FMU_SKIP_MODEL_EXCHANGE */

#ifdef FMI_2
/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiEnterModelInitializationMode_(FMIComponent c, FMIBoolean toleranceControlled, FMIReal relativeTolerance)
{
	static FMIString label = "fmiEnterModelInitializationMode";
	Component* comp = (Component*) c;
	FMIStatus status;

	util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);

	status = util_initialize_model(c, toleranceControlled, relativeTolerance, FMIFalse);
	if (status != FMIOK) {
		return status;
	}
	comp->mStatus = modelInitializationMode;
	util_logger(comp, comp->instanceName, FMIOK, "", "%s completed", label);
	return status;
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiExitModelInitializationMode_(FMIComponent c)
{
	static FMIString label = "fmiExitModelInitializationMode";
	Component* comp = (Component*) c;
	FMIStatus status;

	util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);
	status = util_exit_model_initialization_mode(c, label, modelEventMode);
	comp->firstEventCall=FMITrue;
	if (status != FMIOK) {
		return status;
	}
	util_logger(comp, comp->instanceName, FMIOK, "", "%s completed", label);
	return FMIOK;
}

#else /* FMI_2 */

/* ---------------------------------------------------------------------- */

DYMOLA_STATIC FMIStatus fmiInitialize_ (FMIComponent c, FMIBoolean toleranceControlled, FMIReal relativeTolerance, FMIEventInfo* eventInfo)
{
	static FMIString label = "fmiInitialize";
	Component* comp = (Component*) c;
	FMIStatus status;

	// for co-simulation, this initialization is only a subset
	if (!comp->isCoSim) {
		util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);
	}
	status = util_initialize_model(c, toleranceControlled, relativeTolerance, FMITrue);
	if (status != fmiOK ) {
		return status;
	}

	eventInfo->terminateSimulation = FMIFalse;
	eventInfo->upcomingTimeEvent = (comp->dstruct->mNextTimeEvent < TIME_INFINITY) ? FMITrue : FMIFalse;
	if (eventInfo->upcomingTimeEvent == FMITrue) {
		eventInfo->nextEventTime = comp->dstruct->mNextTimeEvent;
	}

	// for co-simulation, this initialization is only a subset
	if (!comp->isCoSim) {
		comp->mStatus = modelContinousTimeMode;
		util_logger(comp, comp->instanceName, status, "", "%s completed", label);
	}

	comp->eventIterationOnGoing = 0;
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return FMIOK;
}
#endif /* FMI_2 */

#ifndef FMU_SKIP_MODEL_EXCHANGE

#ifdef FMI_2
/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiEnterEventMode_(FMIComponent c)
{
	static FMIString label = "fmiEnterEventMode";
	Component* comp = (Component*) c;
	
	util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);
	if (comp->mStatus != modelContinousTimeMode) {
		util_logger(comp, comp->instanceName, FMIWarning, "", "%s: may only be called in continuous time mode", label);
		return FMIWarning;
	}
	comp->mStatus = modelEventMode;
	comp->firstEventCall = FMITrue;
	util_logger(comp, comp->instanceName, FMIOK, "", "%s done", label);
	return FMIOK;
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiEnterContinuousTimeMode_(FMIComponent c)
{
	static FMIString label = "fmiEnterContinuousTimeMode";
	Component* comp = (Component*) c;
	
	util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);
	if (comp->mStatus != modelEventModeExit) {
		util_logger(comp, comp->instanceName, FMIWarning, "", "%s: may only be called when exited event mode", label);
		return FMIWarning;
	}
	ME_RESULT_SAMPLE(FMITrue);
	comp->mStatus = modelContinousTimeMode;
	util_logger(comp, comp->instanceName, FMIOK, "", "%s done", label);
	return FMIOK;
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiNewDiscreteStates_(FMIComponent c, FMIEventInfo* eventInfo)
{	
	static FMIString label = "fmiNewDiscreteStates";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
	int QiErr = 0;
	FMIBoolean converged = 0;
	size_t i = 0;

	util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);

	/* for co-simulation, sampling is handled at higher level */
	if (comp->isCoSim == FMIFalse) {
		ME_RESULT_SAMPLE(FMITrue);
	}
	memcpy(comp->oldStates,comp->states, comp->nStates*sizeof(FMIReal));
	if(comp->nStates == 0 && comp->mStatus == modelContinousTimeMode){
		comp->mStatus = modelEventMode;
	}
	/* configure actual event iteration */
	switch (comp->mStatus) {
		case modelEventModeExit:
			/* allowed to restart the event iteration again */
			comp->mStatus = modelEventMode;
			/* fall-through */
		case modelEventMode:
		case modelEventMode2:
			if(comp->valWasSet && !comp->firstEventCall){
				SetDymolaOneIteration(comp->did, 5);
				QiErr = util_refresh_cache(comp, iDemandEventHandling, NULL, &converged);
				if (QiErr != 0) {
					goto eventDone;
				}
			}
			SetDymolaOneIteration(comp->did, 3);
			break;
		default:
			util_logger(comp, comp->instanceName, FMIWarning, "", "%s: may only be called in event mode", label);
			return FMIWarning;
	}
	comp->icall = 0;
	QiErr = util_refresh_cache(comp, iDemandEventHandling, NULL, &converged);

eventDone:
	eventInfo->valuesOfContinuousStatesChanged = FMIFalse;
	for (i=0; i<comp->nStates; ++i){
		if(comp->states[i] != comp->oldStates[i]){
			eventInfo->valuesOfContinuousStatesChanged = FMITrue;
		}
	}
	if (QiErr != 0) {
		if (QiErr == -999) {
			util_logger(comp, comp->instanceName, FMIOK, "", "%s: simulation terminated by model", label);
			eventInfo->terminateSimulation = FMITrue;
			eventInfo->newDiscreteStatesNeeded = FMIFalse;
			eventInfo->nominalsOfContinuousStatesChanged= FMIFalse;
			//eventInfo->valuesOfContinuousStatesChanged = (comp->nStates > 0) ? FMITrue : FMIFalse;
			eventInfo->nextEventTimeDefined = FMIFalse;
			eventInfo->nextEventTime = 1.0e37;
			comp->mStatus = modelEventModeExit;
			comp->terminationByModel = FMITrue;
			return FMIOK;
		} else {
			util_logger(comp, comp->instanceName, FMIError, "",
				"%s: dsblock_ failed, QiErr = %d", label, QiErr);
			return util_error(comp);
		}
	}
	
	if (converged == FMIFalse)
	{
		eventInfo->newDiscreteStatesNeeded = FMITrue;
		comp->mStatus = modelEventMode2;
		comp->eventIterRequired = 1;
	} else {
		eventInfo->newDiscreteStatesNeeded = FMIFalse;
		comp->mStatus = modelEventModeExit;
		comp->eventIterRequired = 0;
	}

	eventInfo->terminateSimulation = FMIFalse;
	eventInfo->nominalsOfContinuousStatesChanged= FMIFalse;
	eventInfo->nextEventTimeDefined = (comp->dstruct->mNextTimeEvent < (1.0E37 - 1)) ? FMITrue : FMIFalse;
	if (eventInfo->nextEventTimeDefined == FMITrue) {
		eventInfo->nextEventTime = comp->dstruct->mNextTimeEvent;
	}
	comp->recalJacobian = 1;
	util_logger(comp, comp->instanceName, FMIOK, "", "%s completed", label);
	return FMIOK;
}
#else
DYMOLA_STATIC FMIStatus fmiEventUpdate_(FMIComponent c, FMIBoolean intermediateResults, FMIEventInfo* eventInfo)
{
	static FMIString label = "fmiEventUpdate";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
	int QiErr = 0;
	FMIBoolean converged = 0;

	util_logger(comp, comp->instanceName, FMIOK, "", "%s...", label);

	if (comp->mStatus != modelContinousTimeMode) {
        util_logger(comp, comp->instanceName, FMIWarning, "",
			"%s: initialization must be done before event updating is allowed", label);
		return FMIWarning;
	}

	ME_RESULT_SAMPLE(FMITrue);
	status = util_event_update(c, intermediateResults, eventInfo);
	if (status == FMIError) {
		return util_error(comp);
	} else if (status == FMIFatal) {
		return FMIFatal;
	}

	util_logger(comp, comp->instanceName, FMIOK, "", "%s completed", label);
	return status;
}

#endif /* FMI_2 */

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiCompletedIntegratorStep_(FMIComponent c,
#ifdef FMI_2
	FMIBoolean noSetFMUStatePriorToCurrentPoint,
	FMIBoolean* enterEventMode,
	FMIBoolean* terminateSimulation)
#else
	FMIBoolean* callEventUpdate)
#endif
{
	static FMIString label = "fmiCompletedIntegratorStep";
	Component* comp = (Component*) c;

	ME_RESULT_SAMPLE(FMIFalse);

#ifdef FMI_2
	if (comp->storeResult == FMITrue) {
		if (noSetFMUStatePriorToCurrentPoint) {
			result_flush(comp);
		}
	}
	*terminateSimulation = comp->terminationByModel;
	/* only applies to step event */
	*enterEventMode = comp->istruct->mTriggerStepEvent ? FMITrue : FMIFalse;
#else
	*callEventUpdate = comp->istruct->mTriggerStepEvent ? FMITrue : FMIFalse;
#endif
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return FMIOK;
}

#endif /* FMU_SKIP_MODEL_EXCHANGE */

/* ---------------------------------------------------------------------- */
extern void delayBuffersClose(void);
extern void delayBuffersCloseNew(struct DYNInstanceData*);
#ifdef FMI_2
DYMOLA_STATIC FMIStatus fmiTerminateModel_(FMIComponent c)

#else
DYMOLA_STATIC FMIStatus fmiTerminate_(FMIComponent c)
#endif
{
#ifdef FMI_2
	static FMIString label = "fmi2Terminate";
#else
	static FMIString label = "fmiTerminate";
#endif
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
	if (comp->mStatus == modelTerminated) {
		util_logger(comp, comp->instanceName, FMIWarning, "", "%s: already terminated, ignoring call", label);
		return FMIWarning;
	}
	if (!comp->isCoSim) {
		LOG(comp, FMIOK, label);
		if(comp->QiErr == 0 && comp->terminationByModel == FMIFalse){
			/*Special case for terminal, call dsblock_ directly instead of
			using util_refresh_cache to avoid messy logic*/
			int terminal = iDemandTerminal;
			if (comp->did) {
				globalComponent2=comp;
				dsblock_tid(&terminal, &comp->icall, &comp->time, comp->states, 0,             
					comp->inputs, comp->parameters, 0, 0, comp->derivatives,       
					comp->outputs, comp->auxiliary,                                
					comp->crossingFunctions, comp->duser, comp->iuser,
					(void**) comp->sParameters, comp->did, &comp->QiErr, 0);
				globalComponent2=0;
			} else {
				dsblock_(&terminal, &comp->icall, &comp->time, comp->states, 0,             
					comp->inputs, comp->parameters, 0, 0, comp->derivatives,       
					comp->outputs, comp->auxiliary,                                
					comp->crossingFunctions, comp->duser, comp->iuser,
					(void**) comp->sParameters, &comp->QiErr);
			}
			if (comp->QiErr>=-995 && comp->QiErr<=-990) comp->QiErr=0; /* Ignore special cases for now */
			if(!(comp->QiErr == 0 || comp->QiErr==-999)){
				status = FMIError;
				util_logger(comp, comp->instanceName, FMIError, "",
					"%s: calling terminal section of dsblock_ failed, QiErr = %d",
					label,comp->QiErr);
			}
		}
	}
	util_print_dymola_timers(c);
#ifndef FMU_SOURCE_CODE_EXPORT
	if (comp->storeResult == FMITrue) {
		result_teardown(comp);
	}
#endif /* FMU_SOURCE_CODE_EXPORT */

	if (comp->did) {
		delayBuffersCloseNew(comp->did);
	} else {
		delayBuffersClose();
	}

	comp->mStatus = modelTerminated;
	return status;
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiGetDerivatives_(FMIComponent c, FMIReal derivatives[], size_t nx)
{
	static FMIString label = "fmiGetDerivatives";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
	int QiErr = 0;
	if(	comp->mStatus == modelInstantiated){
		util_logger(comp, comp->instanceName, FMIWarning, "",
#ifdef FMI_2
			"%s: fmiEnterInitializationMode must be called before calling %s", label, label);
#else
			"%s: fmiInitializeModel must be called before calling %s", label, label);
#endif
		return FMIWarning;
	}
	if (nx != comp->nStates) {
		status = FMIWarning;
		util_logger(comp, comp->instanceName, status, "",
			"%s: argument nx = %u is incorrect, should be %u", label, nx, comp->nStates);
		if (nx > comp->nStates) {
			/* truncate */
			nx = comp->nStates;
		}
	}

	if (comp->icall < iDemandDerivative) {
		/* refresh cache */
		int QiErr = util_refresh_cache(comp, iDemandDerivative, label, NULL);
		if (QiErr != 0) {
			return (QiErr == 1) ? FMIDiscard : util_error(comp); 
		}
	}

	memcpy(derivatives, comp->derivatives, nx * sizeof(FMIReal));
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return status;
}

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiGetEventIndicators_(FMIComponent c, FMIReal eventIndicators[], size_t ni)
{
	static FMIString label = "fmiGetEventIndicators";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
	if(	comp->mStatus == modelInstantiated ||comp->mStatus == modelInitializationMode){
		util_logger(comp, comp->instanceName, FMIWarning, "",
#ifdef FMI_2
			"%s: fmiExitInitializationMode must be called before calling %s", label, label);
#else
			"%s: fmiInitializeModel must be called before calling %s", label, label);
#endif
		return FMIWarning;
	}
	if (ni != comp->nCross) {
		status = FMIWarning;
		util_logger(comp, comp->instanceName, status, "",
			"%s: argument ni = %u is incorrect, should be %u", label, ni, comp->nCross);
		if (ni > comp->nCross) {
			/* truncate */
			ni = comp->nCross;
		}
	}

	if (comp->icall < iDemandCrossingFunction) {
		/* refresh cache */
		int QiErr = util_refresh_cache(comp, iDemandCrossingFunction, label, NULL);
		if (QiErr != 0) {
			return (QiErr == 1) ? FMIDiscard : util_error(comp); 
		}
	}

	memcpy(eventIndicators, comp->crossingFunctions, ni * sizeof(FMIReal));
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return status;
}

#ifndef FMU_SKIP_MODEL_EXCHANGE

/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiGetContinuousStates_(FMIComponent c, FMIReal states[], size_t nx)
{
	static FMIString label = "fmiGetContinuousStates";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
#ifdef FMI_2
	if(	comp->mStatus == modelInstantiated){
		util_logger(comp, comp->instanceName, FMIWarning, "",
			"%s: fmiEnterInitializationMode must be called before calling %s", label, label);
		return FMIWarning;
	}
#endif
	if (nx != comp->nStates) {
		status = FMIWarning;
		util_logger(comp, comp->instanceName, status, "",
			"%s: argument nx = %u is incorrect, should be %u", label, nx, comp->nStates);
		if (nx > comp->nStates) {
			/* truncate */
			nx = comp->nStates;
		}
	}

	memcpy(states, comp->states, nx * sizeof(FMIReal));
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return status;
}

/* ---------------------------------------------------------------------- */
#ifdef FMI_2
DYMOLA_STATIC FMIStatus fmiGetNominalsOfContinuousStates_(FMIComponent c, FMIReal x_nominal[], size_t nx) {
	static FMIString label = "fmiGetNominalsOfContinuousStates";
#else
DYMOLA_STATIC FMIStatus fmiGetNominalContinuousStates_(FMIComponent c, FMIReal x_nominal[], size_t nx) {
	static FMIString label = "fmiGetNominalContinuousStates";
#endif
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;

	if (nx != comp->nStates) {
		status = FMIWarning;
		util_logger(comp, comp->instanceName, status, "",
			"%s: argument nx = %u is incorrect, should be %u", label, nx, comp->nStates);
		if (nx > comp->nStates) {
			/* truncate */
			nx = comp->nStates;
		}
	}

	memcpy(x_nominal, comp->statesNominal, nx * sizeof(FMIReal));
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return status;
}

#ifndef FMI_2
/* ---------------------------------------------------------------------- */
DYMOLA_STATIC FMIStatus fmiGetStateValueReferences_(FMIComponent c, FMIValueReference vrx[], size_t nx)
{
	static FMIString label = "fmiGetStateValueReferences";
	Component* comp = (Component*) c;
	FMIStatus status = FMIOK;
	size_t i;

	if (nx != comp->nStates) {
		status = FMIWarning;
		util_logger(comp, comp->instanceName, status, "",
			"%s: argument nx = %u is incorrect, should be %u", label, nx, comp->nStates);
		if (nx > comp->nStates) {
			/* truncate */
			nx = comp->nStates;
		}
	}

	for (i = 0; i < nx; i++) {
#ifndef FMU_SOURCE_SINGLE_UNIT
		extern unsigned int FMIStateValueReferences_[];
#endif
		vrx[i] = FMIStateValueReferences_[i];
	}
	util_logger(comp, comp->instanceName, FMIOK, "", "%s", label);
	return status;
}
#endif /* FMI_2 */

#endif /* FMU_SKIP_MODEL_EXCHANGE */