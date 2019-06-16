//===========================================================================
//
//  Screen Mouse v1.1.2
//  by loktar
//  -------------------------------------------------------------------------
// * Determine direction of mousemovement on screen
// * Get the mouse position on screen, relative to center
// * Get mouse button up/down state
// * Note that coordinates go from right to left (X) and bottom to top (Y)
// * LIMITATIONS:
// * * Cursor must be on map geometry
// * * Results are distorted on non-flat terrain
// * * Relative position is distorted by Field of View (x values are smaller at the top of the screen than at the bottom)
//  -------------------------------------------------------------------------
//
//    -------
//    * API *
//    -------
//  *    boolean SMRegisterPlayerMove(trigger moveTrigger, player plr)
//          - Register mouse move functionality
//          - Disables moveTrigger
//          - Native trigger functions can be used in actions/conditions added to moveTrigger
//          - Returns false if trigger/player combination is already registered
//
//  *    boolean SMEnablePlayerMove(boolean enable, trigger moveTrigger, integer playerId)
//          - Enable/disable ScreenMouse move functionality
//          - If enable == false, prevents all moveTrigger actions from executing
//          - If enable == false, disables moveTrigger
//          - Returns false if trigger/player combination doesn't exist
//
//  *    boolean SMRegisterPlayerButton(trigger buttonTrigger, player plr)
//          - Register mouse button functionality
//          - Native trigger functions can be used in actions/conditions added to buttonTrigger
//          - Returns false if trigger/player combination is already registered
//
//  *    boolean SMEnablePlayerButton(boolean enable, trigger buttonTrigger, integer playerId)
//          - Enable/disable ScreenMouse button functionality
//          - If enable == false, prevents all buttonTrigger actions from executing
//          - Enables/disables buttonTrigger
//          - Returns false if trigger/player combination doesn't exist
//
//  *    boolean SMRegisterPlayerDrag(trigger buttonTrigger, trigger moveTrigger, player plr, boolean left, boolean right, boolean both)
//          - Register mouse drag functionality: enable/disable moveTrigger while holding down mouse button(s)
//          - Register for left button, right button and/or both together
//          - Calls SMRegisterPlayerMove() and SMRegisterPlayerButton()
//          - Returns false if buttonTrigger/player combination already has a moveTrigger associated
//
//  *    boolean SMEnablePlayerDrag(boolean left, boolean right, boolean both, trigger buttonTrigger, integer playerId)
//          - Enable/disable ScreenMouse drag functionality
//          - If any flag == true, enables buttonTrigger
//          - If all flags == false, disables buttonTrigger and associated moveTrigger
//          - Returns false if buttonTrigger/player combination doesn't exist or has no associated moveTrigger
//
//  *    boolean SMIsLeftDown(integer playerId), SMIsRightDown(integer playerId)
//          - Mouse button up/down state
//          - Set with buttonTriggers
//
//  *    real SMGetDifX(integer playerId), SMGetDifY(integer playerId)
//          - Difference with previous mouse position on screen
//          - Set with moveTriggers
//
//  *    real SMGetRelX(integer playerId), SMGetRelY(integer playerId)
//          - Position of the mouse relative to the center of the screen
//          - Set with buttonTriggers
//
//  *    real SMGetDifXs(integer playerId), SMGetDifYs(integer playerId)
//          - Difference with previous mouse position on map, compensated for Target Distance and Field of View
//          - Set with moveTriggers
//
//  *    real SMGetX(integer playerId), SMGetY(integer playerId)
//          - Difference with previous mouse position on screen
//          - Set with moveTriggers
//
//  *    real SM_minX, SM_maxX, SM_minY, SM_maxY
//          - Mouse position bounds
//          - Default: Camera Bounds
//
//  *    real SM_distMpl
//          - Multiplier for Target Distance compensation
//          - Only applied if larger than current Target Distance
//          - Difference/Distance*SM_distMpl
//          - Default: 1650
//
//  *    real SM_fovMpl
//          - Multiplier for Field of View compensation (in Radians!)
//          - Only applied if larger than current Field of View
//          - Difference/FoV*SM_fovMpl
//          - Default: Deg2Rad(70)
//
//===========================================================================
library ScreenMouse initializer InitScreenMouse
    globals
        private constant real R90 = Deg2Rad(90)
        
        private gamecache gcSM = InitGameCache("ScreenMouse.w3v")
        private constant string DIFX   = "difx"
        private constant string DIFY   = "dify"
        private constant string DIFX_S = "difxs"
        private constant string DIFY_S = "difys"
        private constant string RELX   = "relx"
        private constant string RELY   = "rely"
        
        private hashtable htbSM = InitHashtable()
        private constant key X
        private constant key Y
        private constant key LEFT_DOWN
        private constant key RIGHT_DOWN
        private constant key DO_LEFT
        private constant key DO_RIGHT
        private constant key DO_BOTH
        private constant key TRG_MOVE
 
        real SM_minX // GetCameraBound cannot be called at init
        real SM_maxX
        real SM_minY
        real SM_maxY
        real SM_distMpl = 1650
        real SM_fovMpl  = Deg2Rad(70)
    endglobals
//===============================================================================
//===============================================================================
 
//===============================================================================
//==== MOUSE FUNCS ==============================================================
//===============================================================================
    //==== Compensate angles and save ====
    //==== ! This function should only be called locally ! ====
    private function SaveScreenDif takes real difX, real difY, string keyP, string keyX, string keyY returns nothing
        local real field
        local real tmpX
 
        // Compensate Rotation
        set field = GetCameraField(CAMERA_FIELD_ROTATION)
        set tmpX = difX // Save original newX for newY calculation
        set difX = Cos(field-R90)*(difX) + Sin(field-R90)*(difY)
        set difY = Cos(field+R90)*(-difY) - Sin(field+R90)*(-tmpX)
 
        // Compensate Roll
        set field = GetCameraField(CAMERA_FIELD_ROLL)
        set tmpX = difX // Save original newX for newY calculation
        set difX = Sin(field-R90)*(-difX) + Cos(field-R90)*(-difY)
        set difY = Sin(field+R90)*(difY) - Cos(field+R90)*(tmpX)
 
        // Compensate AoA
        set difY = Sin(-GetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK))*difY
 
        call StoreReal(gcSM, keyP, keyX, difX)
        call StoreReal(gcSM, keyP, keyY, difY)
        call SyncStoredReal(gcSM, keyP, keyX)
        call SyncStoredReal(gcSM, keyP, keyY)
    endfunction
    //========
 
    //==== Check for valid mouse position ====
    private function IsValidPosition takes real x, real y returns boolean
        return (x != 0 or y != 0) and x >= SM_minX and x <= SM_maxX and y >= SM_minY and y <= SM_maxY // Mouse on UI gives (0, 0)
    endfunction
    //========
 
    //==== Mouse Move ====
    private function MouseMoveCndAcn takes nothing returns boolean
        local real newX
        local real newY
        local real realTmp
        local real realTmp2
        local player plr = GetTriggerPlayer()
        local integer pId = GetPlayerId(plr)
        local trigger trg = GetTriggeringTrigger()
        local integer hIdMove = GetHandleId(trg)
        local boolean success = false
        local string keyP
 
        if HaveSavedBoolean(htbSM, pId, hIdMove) and LoadBoolean(htbSM, pId, hIdMove) then
            call DisableTrigger(trg)
     
            set newX = BlzGetTriggerPlayerMouseX()
            set newY = BlzGetTriggerPlayerMouseY()
            
            if IsValidPosition(newX, newY) then
                if not HaveSavedReal(htbSM, pId, X) or not HaveSavedReal(htbSM, pId, Y) then
                    call SaveReal(htbSM, pId, X, newX)
                    call SaveReal(htbSM, pId, Y, newY)
                else
                    set realTmp = LoadReal(htbSM, pId, X)
                    set realTmp2 = LoadReal(htbSM, pId, Y)
                    call SaveReal(htbSM, pId, X, newX)
                    call SaveReal(htbSM, pId, Y, newY)
                    
                    if IsValidPosition(realTmp, realTmp2) and plr == GetLocalPlayer() then
                        set newX = realTmp-newX
                        set newY = realTmp2-newY
         
                        // Compensate Distance
                        set realTmp = GetCameraField(CAMERA_FIELD_TARGET_DISTANCE)
                        if realTmp > SM_distMpl then
                            set newX = newX/realTmp*SM_distMpl
                            set newY = newY/realTmp*SM_distMpl
                        endif
                 
                        // Compensate FoV
                        set realTmp = GetCameraField(CAMERA_FIELD_FIELD_OF_VIEW)
                        if realTmp > SM_fovMpl then
                            set newX = newX/realTmp*SM_fovMpl
                            set newY = newY/realTmp*SM_fovMpl
                        endif
                 
                        set keyP = I2S(pId)
                        call StoreReal(gcSM, keyP, DIFX_S, newX)
                        call StoreReal(gcSM, keyP, DIFY_S, newY)
                        call SyncStoredReal(gcSM, keyP, DIFX_S)
                        call SyncStoredReal(gcSM, keyP, DIFY_S)
                        call SaveScreenDif(newX, newY, keyP, DIFX, DIFY)
                        
                        set success = true
                    endif // saved valid & local player
                endif // have saved
            endif // new valid
            
            call EnableTrigger(trg)
        endif // move enabled for player
 
        if not success then
            set keyP = I2S(pId)
            call StoreReal(gcSM, keyP, DIFX, 0)
            call StoreReal(gcSM, keyP, DIFY, 0)
            call StoreReal(gcSM, keyP, DIFX_S, 0)
            call StoreReal(gcSM, keyP, DIFY_S, 0)
        endif
        
        set plr = null
        set trg = null
 
        return success // trigger/player combo is enabled and local player?
    endfunction
    //========
 
    //==== Mouse Button ====
    private function MouseBtnCndAcn takes nothing returns boolean
        local player plr = GetTriggerPlayer()
        local integer pId = GetPlayerId(plr)
        local integer hIdBtn = GetHandleId(GetTriggeringTrigger())
        local mousebuttontype mouseBtn
        local real mouseX
        local real mouseY
        local integer p_hBtnId
        local trigger moveTrg = null
        local integer hIdMove
        local boolean enable
        
        if HaveSavedBoolean(htbSM, pId, hIdBtn) and LoadBoolean(htbSM, pId, hIdBtn) then
            set mouseBtn = BlzGetTriggerPlayerMouseButton()
            set mouseX = BlzGetTriggerPlayerMouseX()
            set mouseY = BlzGetTriggerPlayerMouseY()
     
            // Mouse Down
            if GetTriggerEventId() == EVENT_PLAYER_MOUSE_DOWN then
                // MOUSE_BUTTON_TYPE_MIDDLE does not fire this event as of 1.30.4
                if mouseBtn == MOUSE_BUTTON_TYPE_LEFT then
                    call SaveBoolean(htbSM, pId, LEFT_DOWN, true)
                elseif mouseBtn == MOUSE_BUTTON_TYPE_RIGHT then
                    call SaveBoolean(htbSM, pId, RIGHT_DOWN, true)
                endif
         
                // Set relative position
                if IsValidPosition(mouseX, mouseY) and plr == GetLocalPlayer() then
                    call SaveScreenDif(GetCameraTargetPositionX()-mouseX, GetCameraTargetPositionY()-mouseY, I2S(pId), RELX, RELY)
                endif
         
            // Mouse Up
            elseif mouseBtn == MOUSE_BUTTON_TYPE_LEFT then
                call SaveBoolean(htbSM, pId, LEFT_DOWN, false)
            elseif mouseBtn == MOUSE_BUTTON_TYPE_RIGHT then
                call SaveBoolean(htbSM, pId, RIGHT_DOWN, false)
            endif
     
            // Enable/Disable Drag
            set p_hBtnId = pId+hIdBtn*100
     
            if HaveSavedHandle(htbSM, p_hBtnId, TRG_MOVE) then
                set moveTrg = LoadTriggerHandle(htbSM, p_hBtnId, TRG_MOVE)
                set hIdMove = GetHandleId(moveTrg)
         
                if HaveSavedBoolean(htbSM, pId, hIdMove) and LoadBoolean(htbSM, pId, hIdMove) then
                    set enable = LoadBoolean(htbSM, pId, RIGHT_DOWN)
                    if LoadBoolean(htbSM, pId, LEFT_DOWN) then
                        set enable = (enable and LoadBoolean(htbSM, p_hBtnId, DO_BOTH)) or (not enable and LoadBoolean(htbSM, p_hBtnId, DO_LEFT))
                    else
                        set enable = enable and LoadBoolean(htbSM, p_hBtnId, DO_RIGHT)
                    endif
             
                    if enable then
                        // Enable Move trigger
                        if not IsTriggerEnabled(moveTrg) then
                            call SaveReal(htbSM, pId, X, mouseX)
                            call SaveReal(htbSM, pId, Y, mouseY)
                            call EnableTrigger(moveTrg)
                        endif
                    else
                        call DisableTrigger(moveTrg)
                    endif
                endif
         
                set moveTrg = null
            endif
     
            set plr = null
            return true
        endif
 
        set plr = null
        return false // trigger/player combo is disabled
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================
 
//===============================================================================
//==== API FUNCS ================================================================
//===============================================================================
    //==== Register MOVE to trigger/player ====
    function SMRegisterPlayerMove takes trigger moveTrg, player plr returns boolean
        local integer hIdMove = GetHandleId(moveTrg)
        local integer pId = GetPlayerId(plr)
 
        if not HaveSavedBoolean(htbSM, pId, hIdMove) then
            call SaveBoolean(htbSM, pId, hIdMove, true)
     
            call DisableTrigger(moveTrg)
            call TriggerRegisterPlayerEvent(moveTrg, plr, EVENT_PLAYER_MOUSE_MOVE)
            call TriggerAddCondition(moveTrg, function MouseMoveCndAcn)
     
            return true
        endif
 
        return false // trigger/player combo already registered
    endfunction
    //========
 
    //==== Enable/Disable MOVE for trigger/player ====
    function SMEnablePlayerMove takes boolean enable, trigger moveTrg, integer pId returns boolean
        local integer hIdMove = GetHandleId(moveTrg)
 
        if HaveSavedBoolean(htbSM, pId, hIdMove) then
            call SaveBoolean(htbSM, pId, hIdMove, enable)
     
            if not enable then
                call DisableTrigger(moveTrg)
            endif
     
            return true
        endif
 
        return false // not found
    endfunction
    //========
 
    //==== Register BUTTON to trigger/player ====
    function SMRegisterPlayerButton takes trigger btnTrg, player plr returns boolean
        local integer hIdBtn = GetHandleId(btnTrg)
        local integer pId = GetPlayerId(plr)
 
        if not HaveSavedBoolean(htbSM, pId, hIdBtn) then
            call SaveBoolean(htbSM, pId, hIdBtn, true)
            if not HaveSavedBoolean(htbSM, pId, LEFT_DOWN) then
                call SaveBoolean(htbSM, pId, LEFT_DOWN, false)
                call SaveBoolean(htbSM, pId, RIGHT_DOWN, false)
            endif
     
            call TriggerRegisterPlayerEvent(btnTrg, plr, EVENT_PLAYER_MOUSE_DOWN)
            call TriggerRegisterPlayerEvent(btnTrg, plr, EVENT_PLAYER_MOUSE_UP)
            call TriggerAddCondition(btnTrg, function MouseBtnCndAcn)
     
            return true
        endif
 
        return false // trigger/player combo already registered
    endfunction
    //========
 
    //==== Enable/Disable MOVE for trigger/player ====
    function SMEnablePlayerButton takes boolean enable, trigger btnTrg, integer pId returns boolean
        local integer hIdBtn = GetHandleId(btnTrg)
 
        if HaveSavedBoolean(htbSM, pId, hIdBtn) then
            call SaveBoolean(htbSM, pId, hIdBtn, enable)
     
            if enable then
                call EnableTrigger(btnTrg)
            else
                call DisableTrigger(btnTrg)
            endif
     
            return true
        endif
 
        return false // not found
    endfunction
    //========
 
    //==== Register DRAG to triggers/player ====
    function SMRegisterPlayerDrag takes trigger btnTrg, trigger moveTrg, player plr, boolean left, boolean right, boolean both returns boolean
        local integer hIdBtn = GetHandleId(btnTrg)
        local integer pId = GetPlayerId(plr)
        local integer p_hBtnId = pId+hIdBtn*100
 
        if not HaveSavedHandle(htbSM, p_hBtnId, TRG_MOVE) then
            call SaveTriggerHandle(htbSM, p_hBtnId, TRG_MOVE, moveTrg)
            call SaveBoolean(htbSM, p_hBtnId, DO_LEFT, left)
            call SaveBoolean(htbSM, p_hBtnId, DO_RIGHT, right)
            call SaveBoolean(htbSM, p_hBtnId, DO_BOTH, both)
            call SMRegisterPlayerButton(btnTrg, plr)
            call SMRegisterPlayerMove(moveTrg, plr)
     
            return true
        endif
 
        return false // player/btn trg combo already registered
    endfunction
    //========
 
    //==== Enable/Disable DRAG for trigger/player ====
    function SMEnablePlayerDrag takes boolean left, boolean right, boolean both, trigger btnTrg, integer pId returns boolean
        local integer id = pId+GetHandleId(btnTrg)*100
 
        if HaveSavedHandle(htbSM, id, TRG_MOVE) then
            call SaveBoolean(htbSM, id, DO_LEFT, left)
            call SaveBoolean(htbSM, id, DO_RIGHT, right)
            call SaveBoolean(htbSM, id, DO_BOTH, both)
     
            if left or right or both then
                call EnableTrigger(btnTrg)
            else
                call DisableTrigger(btnTrg)
                call DisableTrigger(LoadTriggerHandle(htbSM, id, TRG_MOVE))
            endif
     
            return true
        endif
 
        return false // not found
    endfunction
    //========
 
    //==== Get Left Down ====
    function SMIsLeftDown takes integer playerId returns boolean
        return HaveSavedBoolean(htbSM, playerId, LEFT_DOWN) and LoadBoolean(htbSM, playerId, LEFT_DOWN)
    endfunction
    //========
 
    //==== Get Right Down ====
    function SMIsRightDown takes integer playerId returns boolean
        return HaveSavedBoolean(htbSM, playerId, RIGHT_DOWN) and LoadBoolean(htbSM, playerId, RIGHT_DOWN)
    endfunction
    //========
 
    // ==== Get difX ====
    function SMGetDifX takes integer playerId returns real
        local string keyP = I2S(playerId)
        if HaveStoredReal(gcSM, keyP, DIFX) then
            return GetStoredReal(gcSM, keyP, DIFX)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get difY ====
    function SMGetDifY takes integer playerId returns real
        local string keyP = I2S(playerId)
        if HaveStoredReal(gcSM, keyP, DIFY) then
            return GetStoredReal(gcSM, keyP, DIFY)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get difXs ====
    function SMGetDifXs takes integer playerId returns real
        local string keyP = I2S(playerId)
        if HaveStoredReal(gcSM, keyP, DIFX_S) then
            return GetStoredReal(gcSM, keyP, DIFX_S)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get difYs ====
    function SMGetDifYs takes integer playerId returns real
        local string keyP = I2S(playerId)
        if HaveStoredReal(gcSM, keyP, DIFY_S) then
            return GetStoredReal(gcSM, keyP, DIFY_S)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get X ====
    function SMGetX takes integer playerId returns real
        if HaveSavedReal(htbSM, playerId, X) then
            return LoadReal(htbSM, playerId, X)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get Y ====
    function SMGetY takes integer playerId returns real
        if HaveSavedReal(htbSM, playerId, Y) then
            return LoadReal(htbSM, playerId, Y)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get Relative X ====
    function SMGetRelX takes integer playerId returns real
        local string keyP = I2S(playerId)
        if HaveStoredReal(gcSM, keyP, RELX) then
            return GetStoredReal(gcSM, keyP, RELX)
        endif
        return 0.0
    endfunction
    //========
 
    // ==== Get Relative Y ====
    function SMGetRelY takes integer playerId returns real
        local string keyP = I2S(playerId)
        if HaveStoredReal(gcSM, keyP, RELY) then
            return GetStoredReal(gcSM, keyP, RELY)
        endif
        return 0.0
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================
 
//===============================================================================
//==== INITIALIZER ==============================================================
//===============================================================================
    private function InitScreenMouse takes nothing returns nothing
        call TriggerSleepAction(0) // For GetCameraBound
 
        // Get map bounds
        set SM_minX = GetCameraBoundMinX()
        set SM_maxX = GetCameraBoundMaxX()
        set SM_minY = GetCameraBoundMinY()
        set SM_maxY = GetCameraBoundMaxY()
    endfunction
//===============================================================================
//===============================================================================
endlibrary
