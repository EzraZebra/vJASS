function ShowMovement takes nothing returns boolean
    local string strDif = ""

    if SMGetDifX(0) > 0 then
        set strDif = "Left"
    elseif SMGetDifX(0) < 0 then
        set strDif = "Right"
    endif

    if SMGetDifY(0) < 0 then
        set strDif = strDif+" Up"
    elseif SMGetDifY(0) > 0 then
        set strDif = strDif+" Down"
    endif

    if SMIsLeftDown(0) then
        if SMIsRightDown(0) then
            set strDif = "|cffff0000"+strDif+"|r"
        else
            set strDif = "|cff00ff00"+strDif+"|r"
        endif
    elseif SMIsRightDown(0) then
        set strDif = "|cff0000ff"+strDif+"|r"
    endif

    call BJDebugMsg(strDif)

    return false
endfunction

function StartMoveTrig takes nothing returns boolean
    if IsTriggerEnabled(gg_trg_ScreenMouse_Example) then
        call DisableTrigger(gg_trg_ScreenMouse_Example)
    else
        call EnableTrigger(gg_trg_ScreenMouse_Example)
    endif

    return false
endfunction

function Trig_ScreenMouse_Example_Actions takes nothing returns nothing
    local trigger trgArrow = CreateTrigger()

    call SMRegisterPlayerDrag(CreateTrigger(), gg_trg_ScreenMouse_Example, Player(0), true, true, true)
    call TriggerAddCondition(gg_trg_ScreenMouse_Example, function ShowMovement)

    call TriggerRegisterPlayerEvent(trgArrow, Player(0), EVENT_PLAYER_ARROW_DOWN_DOWN)
    call TriggerAddCondition(trgArrow, function StartMoveTrig)

    set trgArrow = null
endfunction

//===========================================================================
function InitTrig_ScreenMouse_Example takes nothing returns nothing
    set gg_trg_ScreenMouse_Example = CreateTrigger()
    call TriggerAddAction(gg_trg_ScreenMouse_Example, function Trig_ScreenMouse_Example_Actions)
endfunction
