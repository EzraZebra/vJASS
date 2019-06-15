function ShowPosition takes nothing returns boolean
    call BJDebugMsg("x: "+R2S(SMGetRelX(0))+", y: "+R2S(SMGetRelY(0)))
 
    return false
endfunction

function Trig_ScreenMouse_Example_Actions takes nothing returns nothing
    call SMRegisterPlayerButton(gg_trg_ScreenMouse_Example, Player(0))
 
    call TriggerAddCondition(gg_trg_ScreenMouse_Example, function ShowPosition)
endfunction

//===========================================================================
function InitTrig_ScreenMouse_Example takes nothing returns nothing
    set gg_trg_ScreenMouse_Example = CreateTrigger()
    call TriggerAddAction(gg_trg_ScreenMouse_Example, function Trig_ScreenMouse_Example_Actions)
endfunction
