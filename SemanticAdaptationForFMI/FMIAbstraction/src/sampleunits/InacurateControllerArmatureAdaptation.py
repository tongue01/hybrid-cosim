import logging

import numpy

from units.AbstractSimulationUnit import AbstractSimulationUnit, STEP_ACCEPT


l = logging.getLogger()

class InacurateControllerArmatureAdaptation(AbstractSimulationUnit):
    """
    This is the adaptation of the armature signal coming from the power system and into the controller statechart.
    It therefore gets a continuous input and outputs events.
    The input will be the armature continuous signal.
    The output will be the event "obj" whenever the absolute value of 
        the armature signal exceeds a certain threshold.
        
    Note that we could have coded a generic signal crossing adaptation unit 
        and there is a whole range of pathological cases that we are not dealing with now.
        For these, see the implementation of the AbstractZeroCrossingBlock 
        of the DiracCBD Simulator
        
    The detailed behaviour of this block is as follows:
    ______________________________
    f = InacurateControllerArmatureAdaptation(...)
    f.enterInitMode()
    f.setValues(...,armature)
        The FMU records this value in its internal state.
    "" = f.getValues(...)
        The empty event is returned because at time t=0, there can be no crossing. 
        Because there was no doStep call in between, the event returned here can only be None.
    f.exitInitMode()
    
    f.setValues(..., None)
        The FMU records the value as the current input in its internal state.
    f.doStep(..., H)
        The FMU checks whether the current input has crossed the given threshold, 
            taking into account the previous value of the input, 
            already stored in the internal state.
        The output value is then calculated and the current input moved into the internal state.
    "someReaction" = f.getValues(...)
        Gets the output event. Can either be absent, or the obj event.
    ______________________________
    
    """
    
    def __init__(self, name, num_rtol, num_atol, threshold, upward):
        
        self._num_rtol = num_rtol
        self._num_atol = num_atol
        
        assert upward, "Not implemented yet."
        
        self.__crossUpward = upward
        
        self.__threshold = threshold
        
        self.armature_current = "armature_current"
        self.previous_input = "previous_input"
        self.out_event = "out_event"
        input_vars = [self.armature_current]
        state_vars = [self.previous_input, self.out_event]
        algebraic_functions = {}
        AbstractSimulationUnit.__init__(self, name, algebraic_functions, state_vars, input_vars)
    
    def _isClose(self, a, b):
        return numpy.isclose(a,b, self._num_rtol, self._num_atol)
    
    def _biggerThan(self, a, b):
        return not numpy.isclose(a,b, self._num_rtol, self._num_atol) and a > b
    
    def _doInternalSteps(self, time, step, iteration, cosim_step_size):
        l.debug(">%s._doInternalSteps(%f, %d, %d, %f)", self._name, time, step, iteration, cosim_step_size)
        
        assert self._biggerThan(cosim_step_size, 0), "cosim_step_size too small: {0}".format(cosim_step_size)
        assert iteration == 0, "Fixed point iterations not supported yet."
        
        previous_input = self.getValues(step-1, iteration, self._getStateVars())[self.previous_input]
        current_input = self.getValues(step, iteration, self._getInputVars())[self.armature_current]
        
        output_event = ""
        
        l.debug("previous_input=%f", previous_input)
        l.debug("current_input=%f", current_input)
        
        if (not self._biggerThan(previous_input, self.__threshold)) \
                and self._biggerThan(current_input, self.__threshold) \
                and self.__crossUpward:
            output_event = "obj"
        
        l.debug("output_event=%f", previous_input)
        self.setValues(step, iteration, {self.out_event: output_event})
        
        # Commit the new state and discard previous.
        self.setValues(step, iteration, {self.previous_input: current_input})
        
        l.debug("<%s._doInternalSteps() = (%s, %d)", self._name, STEP_ACCEPT, cosim_step_size)
        return (STEP_ACCEPT, cosim_step_size)