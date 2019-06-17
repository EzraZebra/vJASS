//===========================================================================
//
//  Value Range v.1.0.0
//  by loktar
//  -------------------------------------------------------------------------
// * Manage value ranges
//  -------------------------------------------------------------------------
//
//    -------
//    * API *
//    -------
//	*	constant key F_NONE, F_DEG, F_PCT, F_INT
//			- Format types
//
//  *	real ClampDeg(real value, boolean to360)
//			- Clamp value in degrees between 0 - 360
//			- Sets 360 to 0 by default, and 0 to 360 if to360 == true
//
//	*	struct range
//		*	real min, max, incr
//				- Minimum value, maximum value, value increment
//
//		*	integer format
//				- Format type: F_NONE, F_DEG, F_PCT, F_INT
//
//		*	string errMsg
//				- Error string
//
//		*	range create(real min, real max, real increment, integer format, string errMsg)
//				- Create a new range
//				- Format: F_NONE, F_DEG, F_PCT, F_INT
//
//		*	boolean validate(real value)
//				- Check if value is within range
//
//		*	real adjust(real value)
//				- Adjust value to a valid one
//				- Degrees will be set to the closest valid value
//				- Other formats will be set to min if value < min or max if value > max
//
//===========================================================================
library ValueRange
    globals
        constant key F_NONE
        constant key F_DEG // Degrees
        constant key F_PCT // Percent
        constant key F_INT // Integer stored as Real -> R2I (but I2R not needed when passing to func or comparing)
    endglobals
//===============================================================================
//===============================================================================
   
//===============================================================================
//==== UTILITY FUNCTIONS ========================================================
//===============================================================================
    //==== Clamp degrees between 0-360 ====
    function ClampDeg takes real value, boolean to360 returns real
        local real mod = 360
        if value > 360 or (not to360 and value == 360) then
            set mod = -360
        endif
        loop
            exitwhen (value > 0 and value < 360) or (not to360 and value == 0) or (to360 and value == 360)
            set value = value+mod
        endloop
        return value
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================
    
//===============================================================================
//==== RANGE STRUCT =============================================================
//===============================================================================
    struct range
        real min
        real max
        real incr
        integer format
        string errMsg
        
        static method create takes real min, real max, real incr, integer format, string errMsg returns range
            local range r = range.allocate()
            set r.min = min
            set r.max = max
            set r.incr = incr
            set r.format = format
            set r.errMsg = errMsg
            return r
        endmethod
        
        method validate takes real value returns boolean
            if this.format == F_DEG then
                set value = ClampDeg(value, true)
            endif
            
            // VALID
            return value >= this.min and value <= this.max
        endmethod
        
        method adjust takes real value returns real
            if this.format == F_DEG then
                set value = ClampDeg(value, true)
            endif
        
            if value < this.min then
                if this.format == F_DEG and this.min-value > value-this.max+360 then // Get the value that is closest (min if equal diff)
                    set value = this.max
                else
                    set value = this.min
                endif
            elseif value > this.max then
                if this.format != F_DEG or this.min-value+360 >= value-this.max then // Get the value that is closest (max if equal diff)
                    set value = this.max
                else
                    set value = this.min
                endif
            endif
        
            if this.format == F_DEG then
                set value = ClampDeg(value, false) // Set to 0 if 360
            endif
            
            return value
        endmethod
    endstruct
//===============================================================================
//===============================================================================
endlibrary