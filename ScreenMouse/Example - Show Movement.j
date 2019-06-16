function ShowMovement takes nothing returns boolean
    local string strDif = ""
    local integer pid = GetPlayerId(GetTriggerPlayer())
    
    if SMGetDifX(pid) > 0 then
        set strDif = "Left"
    elseif SMGetDifX(pid) < 0 then
        set strDif = "Right"
    endif

    if SMGetDifY(pid) < 0 then
        set strDif = strDif+" Up"
    elseif SMGetDifY(pid) > 0 then
        set strDif = strDif+" Down"
    endif

    if SMIsLeftDown(pid) then
        if SMIsRightDown(pid) then
            set strDif = "|cffff0000"+strDif+"|r"
        else
            set strDif = "|cff00ff00"+strDif+"|r"
        endif
    elseif SMIsRightDown(pid) then
        set strDif = "|cff0000ff"+strDif+"|r"
    endif

    if strDif == "" then
        call BJDebugMsg("none")
    else
        call BJDebugMsg(strDif)
    endif

    return false
endfunction

function ShowMovement_Actions takes nothing returns nothing
    local trigger trgMoveP1 = CreateTrigger()
    local trigger trgMoveP2 = CreateTrigger()

    call SMRegisterPlayerDrag(CreateTrigger(), trgMoveP1, Player(0), true, true, true)
    call TriggerAddCondition(trgMoveP1, function ShowMovement)
    call SMRegisterPlayerDrag(CreateTrigger(), trgMoveP2, Player(1), true, true, true)
    call TriggerAddCondition(trgMoveP2, function ShowMovement)
    
    set trgMoveP1 = null
    set trgMoveP2 = null
endfunction

//===========================================================================
function InitTrig_ShowMovement takes nothing returns nothing
    set gg_trg_ShowMovement = CreateTrigger()

    call TriggerAddAction(gg_trg_ShowMovement, function ShowMovement_Actions)
endfunction
