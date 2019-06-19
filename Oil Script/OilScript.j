//===========================================================================
//
//  Oil Resource System v1.0.0
//  by loktar
//
//===========================================================================
library OilResource initializer InitOilResource
    globals
        // SOUNDS
        private constant sound SND_ERR = CreateSound("Sound\\Interface\\Error.wav", false, false, false, 10, 10, "DefaultEAXON")
        private constant sound SND_WRN = CreateSound("Sound\\Interface\\Warning.wav", false, false, false, 10, 10, "DefaultEAXON")
        
        // ABILITIES
        private constant integer ID_PATCH      = 'n000'//'n608'
        private constant integer AID_HRVST     = 'A608'
        private constant integer AID_RTRN      = 'A60O'
        private constant integer AID_RTRN_TRGT = 'A609'
        private constant integer OID_HRVST  = 852018 // "harvest"
        private constant integer OID_RTRN   = 852020 // "returnresources"
        private constant integer OID_SMART  = 851971 // "smart"
        private constant integer OID_CANCEL = 851976 // Cancel
        
        // OIL
        private constant integer OIL_CARRY = 100
        private constant integer OIL_LOW   = 1500
        private constant integer OIL_MAX   = 9999999
        private constant string  OIL_CLR   = "ff404080"
        private constant real    REFINERY_BONUS = 0.25
        private constant real    REFUND_RATE_CONSTRUCT = 0.75
        private constant real    REFUND_RATE_UPGRADE   = 0.75
        private constant real    REFUND_RATE_TRAIN     = 1
        private constant real    REFUND_RATE_RESEARCH  = 1
        private integer oilPlayer = 0
        private multiboarditem mbiIcon
        private multiboarditem mbiOil
        
        // HASHTABLE
        // Training/Building Cost
        private constant key COST_UNIT
        private constant key COST_BUILDING
        private constant key COST_RESEARCH
        private constant key COST_RESEARCH_INCR
        private constant key COST_Q
        private constant key MAXTECH
        private constant key UPGRADE
        // Building Types
        private constant key PLATFORMS
        private constant key DROPOFFS
        private constant key REFINERIES
        // Tanker & Patch/Platform
        private constant key OIL
        // Tanker
        private constant key LAST_HRVST
        private constant key TRIGGER
        // Patch/Platform
        private constant key GROUP
        private constant key BUILDER
        // Triggers
        private constant key TANKER
        // Misc
        private constant key TARGET
        private hashtable htbOil = InitHashtable()
    endglobals
//===============================================================================
//===============================================================================
   
//===============================================================================
//==== MESSAGES =================================================================
//===============================================================================
    //==== Warning Message ====
    private function PatchWarningMsg takes player plr, string msg, real x, real y returns nothing
        if plr == GetLocalPlayer() then
            if not GetSoundIsPlaying(SND_WRN) then
                call StartSound(SND_WRN)
            endif
            call ClearTextMessages()
            call DisplayTimedTextToPlayer(plr, 0.512, 0, 10, "|cffffcc00An oil patch "+msg+".|r")
            call PingMinimapEx(x, y, 1.5, 255, 255, 0, false)
            call SetCameraQuickPosition(x, y)
        endif
    endfunction
    //========
    
    //==== Error Message ====
    private function ErrorMsg takes player plr, string msg returns nothing
        if plr == GetLocalPlayer() then
            if not GetSoundIsPlaying(SND_ERR) then
                call StartSound(SND_ERR)
            endif
            call ClearTextMessages()
            call DisplayTimedTextToPlayer(plr, 0.512, 0, 10, "|cffffcc00"+msg+".|r")
        endif
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================

//===============================================================================
//==== SET PLAYER OIL ===========================================================
//===============================================================================
    function SetPlayerOil takes integer value, boolean add returns nothing
        local string oilStr
        local real width
        
        if add then
            set value = value+oilPlayer
        endif
        if value > OIL_MAX then
            set value = OIL_MAX
        endif
        
        set oilPlayer = value
        set oilStr = I2S(value)
        set width = StringLength(oilStr)*0.007
        call MultiboardSetItemWidth(mbiIcon, 0.072-width)
        call MultiboardSetItemWidth(mbiOil, width)
        call MultiboardSetItemValue(mbiOil, oilStr)
    endfunction
//===============================================================================
//===============================================================================
   
//===============================================================================
//==== FILTERS ==================================================================
//===============================================================================
    //==== Dropoff Filter ====
    private function DropoffFltr takes nothing returns boolean
        local unit fltrUnit = GetFilterUnit()
        local boolean r = GetUnitState(fltrUnit, UNIT_STATE_LIFE) > 0 and HaveSavedBoolean(htbOil, DROPOFFS, GetUnitTypeId(fltrUnit))
        set fltrUnit = null
        return r
    endfunction
    //========
    
    //==== Refinery Filter ====
    private function RefineryFltr takes nothing returns boolean
        local unit fltrUnit = GetFilterUnit()
        local boolean r = GetUnitState(fltrUnit, UNIT_STATE_LIFE) > 0 and HaveSavedBoolean(htbOil, REFINERIES, GetUnitTypeId(fltrUnit))
        set fltrUnit = null
        return r
    endfunction
    //========
    
    //==== Has Harvest Filter ====
    private function HasHarvestFltr takes nothing returns boolean
        return GetUnitAbilityLevel(GetFilterUnit(), AID_HRVST) == 1
    endfunction
    //========
    
    //==== Has Return Filter ====
    private function HasReturnFltr takes nothing returns boolean
        return GetUnitAbilityLevel(GetFilterUnit(), AID_RTRN) == 1
    endfunction
    //========
    
    //==== Has Harvest or Return Filter ====
    private function HasHarvestOrReturnFltr takes nothing returns boolean
        local unit fltrUnit = GetFilterUnit()
        local boolean r = GetUnitAbilityLevel(fltrUnit, AID_HRVST) == 1 or GetUnitAbilityLevel(fltrUnit, AID_RTRN) == 1
        set fltrUnit = null
        return r
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================
   
//===============================================================================
//==== SAFE ORDER ===============================================================
//===============================================================================
    //==== Issue order IF no orders are queued ====
    private function SafeOrderTmrCndAcn takes nothing returns boolean
        local trigger trg = GetTriggeringTrigger()
        local integer id = GetHandleId(trg)
        local unit tanker = null
        
        if HaveSavedHandle(htbOil, id, TANKER) then
            set tanker = LoadUnitHandle(htbOil, id, TANKER)
            
            if GetUnitCurrentOrder(tanker) == 0 then
                if GetUnitAbilityLevel(tanker, AID_HRVST) == 1 then
                    call IssueTargetOrderById(tanker, OID_HRVST, LoadUnitHandle(htbOil, id, TARGET))
                elseif GetUnitAbilityLevel(tanker, AID_RTRN) == 1 then
                    call IssueTargetOrderById(tanker, OID_RTRN, LoadUnitHandle(htbOil, id, TARGET))
                endif
            endif
            
            set tanker = null
            
            call FlushChildHashtable(htbOil, id)
        endif
        
        call DestroyTrigger(trg)
        set trg = null
        
        return false
    endfunction
    
    private function SafeOrder takes unit tanker, unit target returns nothing
        local trigger trg = CreateTrigger()
        local integer id = GetHandleId(trg)
            
        call SaveUnitHandle(htbOil, id, TANKER, tanker)
        call SaveUnitHandle(htbOil, id, TARGET, target)
        
        call TriggerAddCondition(trg, function SafeOrderTmrCndAcn)
        call TriggerRegisterTimerEvent(trg, 0, false)
        set trg = null
    endfunction
//===============================================================================
//===============================================================================
   
//===============================================================================
//==== PLATFORMS ================================================================
//===============================================================================
    //==== Save last harvested Platform ====
    private function SaveLastHarvest takes integer tankerId, unit platform returns nothing
        if HaveSavedBoolean(htbOil, PLATFORMS, GetUnitTypeId(platform)) then
            if GetUnitState(platform, UNIT_STATE_LIFE) > 0 then
                call SaveUnitHandle(htbOil, tankerId, LAST_HRVST, platform)
            elseif HaveSavedHandle(htbOil, tankerId, LAST_HRVST) then
                call RemoveSavedHandle(htbOil, tankerId, LAST_HRVST)
            endif
        endif
    endfunction
    //========
    
    //==== Platform Construction -> Transfer Oil ====
    private function PlatformStartFltrAcn takes nothing returns boolean
        local unit platform = GetFilterUnit()
        local integer id
        
        if HaveSavedBoolean(htbOil, PLATFORMS, GetUnitTypeId(platform)) then
            set id = StringHash(R2S(GetUnitX(platform))+R2S(GetUnitY(platform)))
            
            if HaveSavedInteger(htbOil, id, OIL) then
                call SetResourceAmount(platform, LoadInteger(htbOil, id, OIL))
            else
                call SetResourceAmount(platform, 0)
            endif
        endif
        
        set platform = null
        return false
    endfunction
    //========
    
    //==== Platform Finished -> Order Harvest ====
    private function PlatformFinishFltrAcn takes nothing returns boolean
        local unit platform = GetFilterUnit()
        local unit builder = null
        local integer id
        
        if HaveSavedBoolean(htbOil, PLATFORMS, GetUnitTypeId(platform)) then
            set id = StringHash(R2S(GetUnitX(platform))+R2S(GetUnitY(platform)))
            
            if HaveSavedHandle(htbOil, id, BUILDER) then
                set builder = LoadUnitHandle(htbOil, id, BUILDER)
                
                call SaveLastHarvest(GetHandleId(builder), platform)
                call SafeOrder(builder, platform)
                
                call RemoveSavedHandle(htbOil, id, BUILDER)
                set builder = null
            endif
        endif
        
        set platform = null
        return false
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================

//===============================================================================
//==== HARVESTING ===============================================================
//===============================================================================
    //==== Automatic Return ====
    private function AutoReturn takes unit tanker, boolean safe returns nothing
        local real tankerX = GetUnitX(tanker)
        local real tankerY = GetUnitY(tanker)
        local real closestDist = -1
        local real checkDist
        local real checkX
        local real checkY
        local group checkGrp = CreateGroup()
        local unit checkUnit
        local unit target = null
        
        // Get nearest dropoff 
        call GroupEnumUnitsOfPlayer(checkGrp, GetOwningPlayer(tanker), function DropoffFltr)
        loop
            set checkUnit = FirstOfGroup(checkGrp)
            exitwhen checkUnit == null
            call GroupRemoveUnit(checkGrp, checkUnit)
            
            set checkX = GetUnitX(checkUnit) - tankerX
            set checkY = GetUnitY(checkUnit) - tankerY
            set checkDist = SquareRoot(checkX*checkX + checkY*checkY)
            
            if closestDist == -1 or checkDist < closestDist then
                set closestDist = checkDist
                set target = checkUnit
            endif
        endloop
        call DestroyGroup(checkGrp)
        set checkGrp = null
        
        // Issue order if target found
        if target != null then
            if safe then
                call SafeOrder(tanker, target)
            else
                call IssueTargetOrderById(tanker, OID_RTRN, target)
            endif
            
            set target = null
        endif
    endfunction
    //========
    
    //==== Remove Tanker from Target's Group ====
    private function TankerRemoveFromGroup takes unit tanker returns nothing
        local group grp = null
        local integer tankerId = GetHandleId(tanker)
        local integer targetId
        
        if HaveSavedHandle(htbOil, tankerId, TRIGGER) then
            call DestroyTrigger(LoadTriggerHandle(htbOil, tankerId, TRIGGER))
            call RemoveSavedHandle(htbOil, tankerId, TRIGGER)
        endif
        
        if HaveSavedHandle(htbOil, tankerId, TARGET) then
            set targetId = GetHandleId(LoadUnitHandle(htbOil, tankerId, TARGET))
            call RemoveSavedHandle(htbOil, tankerId, TARGET)
            
            if HaveSavedHandle(htbOil, targetId, GROUP) then
                set grp = LoadGroupHandle(htbOil, targetId, GROUP)
                call GroupRemoveUnit(grp, tanker)
                if FirstOfGroup(grp) == null then
                    call RemoveSavedHandle(htbOil, targetId, GROUP)
                    call DestroyGroup(grp)
                endif
                set grp = null
            endif
        endif
    endfunction
    //===========================================================================
    //===========================================================================
    
    //==== Tanker Immediate/Point Order -> Remove from Group ====
    private function TankerRemoveFromGroupCndAcn takes nothing returns boolean
        call TankerRemoveFromGroup(GetOrderedUnit())
        return false
    endfunction
    //========
    
    //==== Invalid Harvest Target Timer Expires -> Add Abil Back ====
    private function AddHarvestTmrCndAcn takes nothing returns boolean
        local trigger trg = GetTriggeringTrigger()
        local integer id = GetHandleId(trg)
        
        if HaveSavedHandle(htbOil, id, TANKER) then
            call UnitAddAbility(LoadUnitHandle(htbOil, id, TANKER), AID_HRVST)
            call FlushChildHashtable(htbOil, id)
        endif
        call DestroyTrigger(trg)
        
        set trg = null
        return false
    endfunction
    //========
    
    //==== Target Orders ====
    private function TargetOrderCndAcn takes nothing returns boolean
        local integer id = GetIssuedOrderId()
        local unit oUnit = GetOrderedUnit()
        local unit target = null
        local trigger trg = null
        local boolean hasHrvst
        local boolean isPlatform
        local group grp = null
        
        call TankerRemoveFromGroup(oUnit)
        
        if id == OID_HRVST or id == OID_RTRN then
            set target = GetOrderTargetUnit()
            set isPlatform = HaveSavedBoolean(htbOil, PLATFORMS, GetUnitTypeId(target))
            
            // INVALID HARVEST TARGET
            if id == OID_HRVST and not isPlatform and GetUnitAbilityLevel(oUnit, AID_HRVST) == 1 then
                call ErrorMsg(GetOwningPlayer(oUnit), "Must target an Oil Platform")
                call UnitRemoveAbility(oUnit, AID_HRVST)
                
                set trg = CreateTrigger()
                call TriggerAddCondition(trg, function AddHarvestTmrCndAcn)
                call SaveUnitHandle(htbOil, GetHandleId(trg), TANKER, oUnit)
                call TriggerRegisterTimerEvent(trg, 0, false)
                set trg = null
                
            // SAVE TARGET & ADD TO GROUP
            else
                set id = GetHandleId(oUnit)
                set trg = CreateTrigger()
                call SaveUnitHandle(htbOil, id, TARGET, target)
                call SaveTriggerHandle(htbOil, id, TRIGGER, trg)
                
                set id = GetHandleId(target)
                if HaveSavedHandle(htbOil, id, GROUP) then
                    set grp = LoadGroupHandle(htbOil, id, GROUP)
                else
                    set grp = CreateGroup()
                    call SaveGroupHandle(htbOil, id, GROUP, grp)
                endif
                if not IsUnitInGroup(oUnit, grp) then
                    call GroupAddUnit(grp, oUnit)
                endif
                
                call TriggerRegisterUnitEvent(trg, oUnit, EVENT_UNIT_ISSUED_ORDER)
                call TriggerRegisterUnitEvent(trg, oUnit, EVENT_UNIT_ISSUED_POINT_ORDER)
                call TriggerAddCondition(trg, function TankerRemoveFromGroupCndAcn)
                
                set trg = null
                set grp = null
            endif
            
            set target = null
            
        // SMART ORDER
        elseif id == OID_SMART then
            set hasHrvst = GetUnitAbilityLevel(oUnit, AID_HRVST) == 1
            
            if hasHrvst or GetUnitAbilityLevel(oUnit, AID_RTRN) == 1 then
                set target = GetOrderTargetUnit()
                
                if GetUnitState(target, UNIT_STATE_LIFE) > 0 then
                    set id = GetUnitTypeId(target)
                    
                    if hasHrvst then
                        if HaveSavedBoolean(htbOil, PLATFORMS, id) then
                            call IssueTargetOrderById(oUnit, OID_HRVST, target)
                        endif
                    elseif HaveSavedBoolean(htbOil, PLATFORMS, id) or HaveSavedBoolean(htbOil, DROPOFFS, id) then
                        call IssueTargetOrderById(oUnit, OID_RTRN, target)
                    endif
                endif
                
                set target = null
            endif
        
        // PLATFORM BUILD -> SAVE TANKER
        elseif HaveSavedBoolean(htbOil, PLATFORMS, id) then
            set target = GetOrderTargetUnit()
            call SaveUnitHandle(htbOil, StringHash(R2S(GetUnitX(target))+R2S(GetUnitY(target))), BUILDER, oUnit)
            set target = null
        endif
                
        set oUnit = null
        
        return false
    endfunction
    //========
    
    //==== Return Order (no target) - Has Return Filter ====
    private function ReturnOrderCndAcn takes nothing returns boolean
        if GetIssuedOrderId() == OID_RTRN then
            call AutoReturn(GetOrderedUnit(), false)
        endif
        return false
    endfunction
    //========
    
    //==== Tanker Trained (HasHarvest Filter) -> Order Harvest Rally ====
    private function RallyPointCndAcn takes nothing returns boolean
        local unit target = GetUnitRallyUnit(GetTriggerUnit())
        
        if GetUnitState(target, UNIT_STATE_LIFE) > 0 and HaveSavedBoolean(htbOil, PLATFORMS, GetUnitTypeId(target)) then
            call IssueTargetOrderById(GetTrainedUnit(), OID_HRVST, target)
        endif
        
        set target = null
        return false
    endfunction
    //========
    
    //==== Return timer expries -> remove RTRN, add HRVST, order harvest
    private function ReturnTmrCndAcn takes nothing returns boolean
        local trigger trg = GetTriggeringTrigger()
        local integer id = GetHandleId(trg)
        local unit tanker = null
        local unit target = null
        
        if HaveSavedHandle(htbOil, id, TANKER) then
            set tanker = LoadUnitHandle(htbOil, id, TANKER)
            call FlushChildHashtable(htbOil, id)
            
            call UnitRemoveAbility(tanker, AID_RTRN)
            call UnitAddAbility(tanker, AID_HRVST)
            
            set id = GetHandleId(tanker)
            if HaveSavedHandle(htbOil, id, LAST_HRVST) then
                set target = LoadUnitHandle(htbOil, id, LAST_HRVST)
                
                if GetUnitState(target, UNIT_STATE_LIFE) <= 0 then
                    call RemoveSavedHandle(htbOil, id, LAST_HRVST)
                elseif GetUnitCurrentOrder(tanker) == 0 then
                    call IssueTargetOrderById(tanker, OID_HRVST, target)
                endif
                
                set target = null
            endif
            
            set tanker = null
        endif
        
        call DestroyTrigger(trg)
        set trg = null
        return false
    endfunction
    //========
    
    //==== Full Tanker Harvest timer expries -> remove/add RTRN & autoreturn
    private function FullHarvestTmrCndAcn takes nothing returns boolean
        local trigger trg = GetTriggeringTrigger()
        local integer id = GetHandleId(trg)
        local unit tanker = null
        
        if HaveSavedHandle(htbOil, id, TANKER) then
            set tanker = LoadUnitHandle(htbOil, id, TANKER)
            
            call UnitRemoveAbility(tanker, AID_RTRN)
            call UnitAddAbility(tanker, AID_RTRN)
            if GetUnitCurrentOrder(tanker) == 0 then
                call AutoReturn(tanker, false)
            endif
            
            set tanker = null
            call FlushChildHashtable(htbOil, id)
        endif
        
        call DestroyTrigger(trg)
        set trg = null
        return false
    endfunction
    //========
    
    //==== Tanker Channels Spell (HasReturn Filter) -> Return ====
    private function ReturnCndAcn takes nothing returns boolean
        local unit tanker = null
        local unit target = null
        local integer tankerId
        local integer targetId
        local integer carryOil
        local player owner = null
        local group grpRefs = null
        local texttag tag
        local trigger trg = null
        
        if GetSpellAbilityId() == AID_RTRN_TRGT then
            set tanker = GetSpellAbilityUnit()
            set tankerId = GetHandleId(tanker)
            
            if HaveSavedHandle(htbOil, tankerId, TARGET) then
                set target = LoadUnitHandle(htbOil, tankerId, TARGET)
                set targetId = GetUnitTypeId(target)
                
                // RETURN
                if HaveSavedBoolean(htbOil, DROPOFFS, targetId) and GetUnitState(target, UNIT_STATE_LIFE) > 0  then
                    call TankerRemoveFromGroup(tanker)
                    
                    if HaveSavedInteger(htbOil, tankerId, OIL) then
                        set carryOil = LoadInteger(htbOil, tankerId, OIL)
                        
                        if carryOil > 0 then
                            set owner = GetOwningPlayer(tanker)
                            // Check for refineries
                            set grpRefs = CreateGroup()
                            call GroupEnumUnitsOfPlayer(grpRefs, owner, function RefineryFltr)
                            if FirstOfGroup(grpRefs) != null then
                                set carryOil = carryOil + R2I(carryOil*REFINERY_BONUS)
                            endif
                            call DestroyGroup(grpRefs)
                            set grpRefs = null
                            
                            // Show floating text
                            set tag = CreateTextTag()
                            call SetTextTagVelocity(tag, 0, 0.0355)
                            call SetTextTagPermanent(tag, false)
                            call SetTextTagLifespan(tag, 3)
                            call SetTextTagFadepoint(tag, 2)
                            call SetTextTagPos(tag, GetUnitX(tanker), GetUnitY(tanker), 0)
                            call SetTextTagText(tag, "|c"+OIL_CLR+"+"+I2S(carryOil)+"|r", 0.023)
                            
                            // Give oil to player
                            if owner == GetLocalPlayer() then
                                call SetPlayerOil(carryOil, true)
                            endif
                            
                            set owner = null
                        endif
                        
                        // Remove oil from tanker
                        call AddUnitAnimationProperties(tanker, "gold", false)
                        call RemoveSavedInteger(htbOil, tankerId, OIL)
                        
                        // Switch and harvest last platform
                        call UnitRemoveAbility(tanker, AID_RTRN_TRGT)
                        call UnitAddAbility(tanker, AID_RTRN_TRGT)
                        
                        set trg = CreateTrigger()
                        call SaveUnitHandle(htbOil, GetHandleId(trg), TANKER, tanker)
                        call TriggerAddCondition(trg, function ReturnTmrCndAcn)
                        call TriggerRegisterTimerEvent(trg, 0, false)
                        set trg = null
                    endif
                    
                // HARVEST & TANKER FULL
                elseif HaveSavedBoolean(htbOil, PLATFORMS, targetId) and GetUnitState(target, UNIT_STATE_LIFE) > 0 then
                    if HaveSavedInteger(htbOil, tankerId, OIL) and LoadInteger(htbOil, tankerId, OIL) >= OIL_CARRY then
                        call TankerRemoveFromGroup(tanker)
                        call SaveLastHarvest(tankerId, target)
                        
                        call UnitRemoveAbility(tanker, AID_RTRN_TRGT)
                        call UnitAddAbility(tanker, AID_RTRN_TRGT)
                        
                        set trg = CreateTrigger()
                        call SaveUnitHandle(htbOil, GetHandleId(trg), TANKER, tanker)
                        call TriggerAddCondition(trg, function FullHarvestTmrCndAcn)
                        call TriggerRegisterTimerEvent(trg, 0, false)
                        set trg = null
                    endif
                endif
                
                set target = null
            endif // Have target
            
            set tanker = null
        endif // abil == rtrn_trgt
        
        return false
    endfunction
    //========
    
    //==== Tanker Starts Spell Effect (HasHarvestOrReturn Filter) -> Harvest ====
    private function HarvestCndAcn takes nothing returns boolean
        local unit target = null
        local unit tanker = null
        local integer aId = GetSpellAbilityId()
        local integer targetId
        local integer tankerId
        local integer patchOil
        local integer carryOil
        
        if (aId == AID_HRVST or aId == AID_RTRN_TRGT) then
            set target = GetSpellTargetUnit()
            set targetId = GetUnitTypeId(target)
            
            // HARVEST
            if HaveSavedBoolean(htbOil, PLATFORMS, targetId) and GetUnitState(target, UNIT_STATE_LIFE) > 0 then
                set tanker = GetSpellAbilityUnit()
                set tankerId = GetHandleId(tanker)
                call TankerRemoveFromGroup(tanker)
                
                if HaveSavedInteger(htbOil, tankerId, OIL) then
                    set carryOil = LoadInteger(htbOil, tankerId, OIL)
                else
                    set carryOil = 0
                endif
                
                if carryOil < OIL_CARRY then
                    set patchOil = GetResourceAmount(target)
                    
                    if patchOil > OIL_CARRY-carryOil then
                        // Update patch oil
                        set patchOil = patchOil-OIL_CARRY+carryOil
                        call SetResourceAmount(target, patchOil)
                        call SaveInteger(htbOil, StringHash(R2S(GetUnitX(target))+R2S(GetUnitY(target))), OIL, patchOil)
                        
                        // Running low
                        if patchOil <= OIL_LOW and patchOil+OIL_CARRY-carryOil > OIL_LOW then
                            call PatchWarningMsg(GetOwningPlayer(target), "is running low", GetUnitX(target), GetUnitY(target))
                        endif
                        
                        set carryOil = OIL_CARRY
                    else
                        // Exhausted
                        call PatchWarningMsg(GetOwningPlayer(target), "has been exhausted", GetUnitX(target), GetUnitY(target))
                        call FlushChildHashtable(htbOil, StringHash(R2S(GetUnitX(target))+R2S(GetUnitY(target))))
                        call KillUnit(target)
                        
                        set carryOil = patchOil+carryOil
                    endif
                
                    if carryOil > 0 then
                        // Give oil to tanker
                        call SaveInteger(htbOil, tankerId, OIL, carryOil)
                        call AddUnitAnimationProperties(tanker, "gold", true)
                    endif
                endif
               
                call SaveLastHarvest(tankerId, target)
                
                // Switch & Return Oil
                if aId == AID_HRVST then
                    call UnitRemoveAbility(tanker, AID_HRVST)
                    call UnitAddAbility(tanker, AID_RTRN)
                endif
                if carryOil > 0 then
                    call AutoReturn(tanker, true)
                endif
                
                set tanker = null
            endif // target is platform
            
            set target = null
        endif // if harvest or return
        
        return false
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================

//===============================================================================
//==== OIL COST =================================================================
//===============================================================================
    //==== Not enough oil timer expires -> restore tech allowed ====
    private function RestoreTechTmrCndAcn takes nothing returns boolean
        local trigger trg = GetTriggeringTrigger()
        local integer id = GetHandleId(trg)
        
        if HaveSavedInteger(htbOil, id, TARGET) then
            if HaveSavedInteger(htbOil, id, MAXTECH) then
                call SetPlayerTechMaxAllowed(GetLocalPlayer(), LoadInteger(htbOil, id, TARGET), LoadInteger(htbOil, id, MAXTECH))
            else // failsafe
                call SetPlayerTechMaxAllowed(GetLocalPlayer(), LoadInteger(htbOil, id, TARGET), -1)
            endif
            call FlushChildHashtable(htbOil, id)
        endif
        
        call DestroyTrigger(trg)
        set trg = null
        
        return false
    endfunction
    //========
    
    //==== Build order interrupted ====
    private function BuildInterruptCndAcn takes nothing returns boolean
        local trigger trg = GetTriggeringTrigger()
        local integer trgId = GetHandleId(trg)
        local integer targetId
        
        if HaveSavedInteger(htbOil, trgId, TARGET) then
            set targetId = LoadInteger(htbOil, trgId, TARGET)
            call FlushChildHashtable(htbOil, trgId)
            
            if HaveSavedInteger(htbOil, COST_BUILDING, targetId) then
                call SetPlayerOil(LoadInteger(htbOil, COST_BUILDING, targetId), true)
            endif
        endif
        
        call DestroyTrigger(trg)
        set trg = null
        
        return false
    endfunction
    //========
    
    //==== Train/Build/Upgrade/Research Order ====
    private function OilCostOrderCndAcn takes nothing returns boolean
        local integer id = GetIssuedOrderId()
        local integer trgId
        local integer cost
        local integer costType = -1
        local boolean isImmediate = GetTriggerEventId() == EVENT_PLAYER_UNIT_ISSUED_ORDER
        local trigger trg = null
        local player plr = null
        local unit oUnit = null
        
        // BUILD/UPGRADE
        if HaveSavedInteger(htbOil, COST_BUILDING, id) then
            set cost = LoadInteger(htbOil, COST_BUILDING, id)
            set costType = COST_BUILDING
        elseif isImmediate then
            // TRAIN
            if HaveSavedInteger(htbOil, COST_UNIT, id) then
                set cost = LoadInteger(htbOil, COST_UNIT, id)
                set costType = COST_UNIT
            // RESEARCH
            elseif HaveSavedInteger(htbOil, COST_RESEARCH, id) then
                set cost = LoadInteger(htbOil, COST_RESEARCH, id)
                set costType = COST_RESEARCH
                if HaveSavedInteger(htbOil, COST_RESEARCH_INCR, id) then
                    set cost = cost + GetPlayerTechCount(GetLocalPlayer(), id, true) * LoadInteger(htbOil, COST_RESEARCH_INCR, id)
                endif
            endif
        endif
            
        if costType != -1 then
            if oilPlayer >= cost then
                set oUnit = GetOrderedUnit()
                call SetPlayerOil(-cost, true)
                
                // Build order -> register interruption
                if not isImmediate then
                    set trg = CreateTrigger()
                    
                    call SaveInteger(htbOil, GetHandleId(trg), TARGET, id)
                    call TriggerAddCondition(trg, function BuildInterruptCndAcn)
                    call TriggerRegisterUnitEvent(trg, oUnit, EVENT_UNIT_DEATH)
                    call TriggerRegisterUnitEvent(trg, oUnit, EVENT_UNIT_ISSUED_ORDER)
                    call TriggerRegisterUnitEvent(trg, oUnit, EVENT_UNIT_ISSUED_POINT_ORDER)
                    call TriggerRegisterUnitEvent(trg, oUnit, EVENT_UNIT_ISSUED_TARGET_ORDER)
                    
                    set trg = null
                    
                else
                    
                    // Upgrade order -> Save upgrade type
                    if costType == COST_BUILDING then
                        call SaveInteger(htbOil, GetHandleId(oUnit), UPGRADE, id)
                    
                    // Train/Research order -> Save queued cost
                    else
                        set id = GetHandleId(oUnit)
                        
                        if costType == COST_UNIT then
                            set cost = R2I(cost*REFUND_RATE_TRAIN)
                        else
                            set cost = R2I(cost*REFUND_RATE_RESEARCH)
                        endif
                        
                        if HaveSavedInteger(htbOil, id, COST_Q) then
                            set cost = cost + LoadInteger(htbOil, id, COST_Q)
                        endif
                        
                        call SaveInteger(htbOil, id, COST_Q, cost)
                    endif
                endif
                
                set oUnit = null
                
            // Not enough oil
            else
                set plr = GetLocalPlayer()
                set trg = CreateTrigger()
                set trgId = GetHandleId(trg)
                
                call ErrorMsg(plr, "Not enough oil")
                call SaveInteger(htbOil, trgId, TARGET, id)
                call SaveInteger(htbOil, trgId, MAXTECH, GetPlayerTechMaxAllowed(plr, id))
                call SetPlayerTechMaxAllowed(plr, id, 0)
                
                call TriggerAddCondition(trg, function RestoreTechTmrCndAcn)
                call TriggerRegisterTimerEvent(trg, 0, false)
                
                set plr = null
                set trg = null
            endif
        endif
        
        return false
    endfunction
    //========
    
    //==== Remove cost from Q ====
    private function QCostEnd takes integer id, integer oil, boolean cancel returns nothing
        // Canceled -> refund
        if cancel then
            call SetPlayerOil(oil, true)
        endif
        
        // Remove from queued cost
        if HaveSavedInteger(htbOil, id, COST_Q) then
            set oil = LoadInteger(htbOil, id, COST_Q) - oil
            
            if oil <= 0 then
                call RemoveSavedInteger(htbOil, id, COST_Q)
            else
                call SaveInteger(htbOil, id, COST_Q, oil)
            endif
        endif
    endfunction
    //========
    
    //==== Training Finished or Cancelled ====
    private function TrainEndCndAcn takes nothing returns boolean
        local integer id = GetTrainedUnitType()
        
        if HaveSavedInteger(htbOil, COST_UNIT, id) then
            call QCostEnd(GetHandleId(GetTriggerUnit()), R2I(LoadInteger(htbOil, COST_UNIT, id)*REFUND_RATE_TRAIN), GetTriggerEventId() == EVENT_PLAYER_UNIT_TRAIN_CANCEL)
        endif
        
        return false
    endfunction
    //========
    
    //==== Research Finished or Cancelled ====
    private function ResearchEndCndAcn takes nothing returns boolean
        local integer id = GetResearched()
        local integer cost
        local boolean cancel
        
        if HaveSavedInteger(htbOil, COST_RESEARCH, id) then
            set cost = LoadInteger(htbOil, COST_RESEARCH, id)
            set cancel = GetTriggerEventId() == EVENT_PLAYER_UNIT_RESEARCH_CANCEL
            
            if HaveSavedInteger(htbOil, COST_RESEARCH_INCR, id) then
                if cancel then
                    set cost = cost + GetPlayerTechCount(GetLocalPlayer(), id, true) * LoadInteger(htbOil, COST_RESEARCH_INCR, id)
                else
                    set cost = cost + (GetPlayerTechCount(GetLocalPlayer(), id, true)-1) * LoadInteger(htbOil, COST_RESEARCH_INCR, id)
                endif
            endif
                
            call QCostEnd(GetHandleId(GetTriggerUnit()), R2I(cost*REFUND_RATE_RESEARCH), cancel)
        endif
        
        return false
    endfunction
    //========
    
    //==== Upgrade Finished ====
    private function UpgradeFinishFltrAcn takes nothing returns boolean
        local integer id = GetHandleId(GetFilterUnit())
        
        if HaveSavedInteger(htbOil, id, UPGRADE) then
            call RemoveSavedInteger(htbOil, id, UPGRADE)
        endif
        
        return false
    endfunction
    //========
    
    //==== Upgrade Cancelled ====
    private function UpgradeCancelFltrAcn takes nothing returns boolean
        local integer id = GetHandleId(GetFilterUnit())
        local integer tid
        
        if HaveSavedInteger(htbOil, id, UPGRADE) then
            set tid = LoadInteger(htbOil, id, UPGRADE)
            call RemoveSavedInteger(htbOil, id, UPGRADE)
            
            if HaveSavedInteger(htbOil, COST_BUILDING, tid) then
                call SetPlayerOil(R2I(LoadInteger(htbOil, COST_BUILDING, tid)*REFUND_RATE_UPGRADE), true)
            endif
        endif
        
        return false
    endfunction
    //========
    
    //==== Build Cancel ====
    private function BuildCancelFltrAcn takes nothing returns boolean
        local integer id = GetUnitTypeId(GetFilterUnit())
        
        if HaveSavedInteger(htbOil, COST_BUILDING, id) then
            call SetPlayerOil(R2I(LoadInteger(htbOil, COST_BUILDING, id)*REFUND_RATE_CONSTRUCT), true)
        endif
        
        return false
    endfunction
    //===========================================================================
    //===========================================================================
//===============================================================================
//===============================================================================

//===============================================================================
//==== UNIT DEATH ===============================================================
//===============================================================================
    //==== Platform or Dropoff Dies -> Give new orders to tankers ====
    //==== Platform Dies -> Replace with Patch ====
    //==== Tanker Dies -> Remove from Target group ====
    //==== Flush hashtable ====
    private function UnitDiesCndAcn takes nothing returns boolean
        local unit dyingU = GetDyingUnit()
        local unit target = null
        local group grp = null
        local integer uid = GetHandleId(dyingU)
        local integer id = GetUnitTypeId(dyingU)
        local integer oil
        local boolean isPlatform = HaveSavedBoolean(htbOil, PLATFORMS, id)
        local real x
        local real y
        
        if isPlatform or HaveSavedBoolean(htbOil, DROPOFFS, id) then
            set x = GetUnitX(dyingU)
            set y = GetUnitY(dyingU)
            
            // Update tankers orders & destroy group
            if HaveSavedHandle(htbOil, uid, GROUP) then
                set grp = LoadGroupHandle(htbOil, uid, GROUP)
                
                loop
                    set target = FirstOfGroup(grp)
                    exitwhen target == null
                    call GroupRemoveUnit(grp, target)
                    
                    set id = GetHandleId(target)
                    if HaveSavedHandle(htbOil, id, TARGET) and LoadUnitHandle(htbOil, id, TARGET) == dyingU then
                        // Destroy trigger & flush htb
                        if HaveSavedHandle(htbOil, id, TRIGGER) then
                            call DestroyTrigger(LoadTriggerHandle(htbOil, id, TRIGGER))
                        endif
                        call FlushChildHashtable(htbOil, id)
                    
                        // Check for queued order and issue new order
                        if GetUnitAbilityLevel(target, AID_RTRN) == 1 then // Make sure return order doesn't survive as no-target order
                            call UnitRemoveAbility(target, AID_RTRN)
                            call UnitAddAbility(target, AID_RTRN)
                        endif
                        if GetUnitCurrentOrder(target) == 0 then
                            if isPlatform then
                                call IssuePointOrder(target, "move", x, y)
                            else
                                call AutoReturn(target, false)
                            endif
                        endif
                    endif
                endloop
                
                call DestroyGroup(grp)
                set grp = null
            endif        
            
            // Restore Oil Patch & Transfer Oil (if not exhausted)
            if isPlatform then
                set id = StringHash(R2S(x)+R2S(y))
                set target = null
                
                if HaveSavedInteger(htbOil, id, OIL) then
                    set oil = LoadInteger(htbOil, id, OIL)
                    
                    if oil > 0 then
                        set target = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), ID_PATCH, x, y, bj_UNIT_FACING)
                        call SetResourceAmount(target, oil)
                        
                        // Make sure it's in the right position
                        if GetUnitX(target) != x or GetUnitY(target) != y then
                            call SetUnitPathing(target, false)
                            call SetUnitPosition(target, x, y)
                            call SetUnitPathing(target, true)
                        endif
                
                        if HaveSavedHandle(htbOil, id, BUILDER) then
                            call RemoveSavedHandle(htbOil, id, BUILDER)
                        endif
                    endif
                endif
                
                if target == null then
                    call FlushChildHashtable(htbOil, id)
                else
                    set target = null
                endif
            endif
        
        // Remove tanker from target group
        elseif HaveSavedHandle(htbOil, uid, TARGET) or HaveSavedHandle(htbOil, uid, TRIGGER) then
            call TankerRemoveFromGroup(dyingU)
        endif
        
        // Refund queued units
        if HaveSavedInteger(htbOil, uid, COST_Q) and GetOwningPlayer(dyingU) == GetLocalPlayer() then
            set oil = LoadInteger(htbOil, uid, COST_Q)
            
            if oil > 0 then
                call SetPlayerOil(oil, true)
            endif
        endif
            
        call FlushChildHashtable(htbOil, uid)
        
        set dyingU = null
        return false
    endfunction
//===============================================================================
//===============================================================================

//===============================================================================
//==== INITIALIZER ==============================================================
//===============================================================================
    //==== Save Oil Amounts ====
    private function SaveOilAmountFltr takes nothing returns boolean
        local unit fltrUnit = GetFilterUnit()
        local integer fltrId = GetUnitTypeId(fltrUnit)
        
        if fltrId == ID_PATCH or HaveSavedBoolean(htbOil, PLATFORMS, fltrId) then
            call SaveInteger(htbOil, StringHash(R2S(GetUnitX(fltrUnit))+R2S(GetUnitY(fltrUnit))), OIL, GetResourceAmount(fltrUnit))
        endif
        
        set fltrUnit = null
        return false
    endfunction
    //===========================================================================
    //===========================================================================
    
    private function InitOilResource takes nothing returns nothing
        local player plr
        local multiboard mtb = CreateMultiboard()
        local group grpOil = CreateGroup()
        local trigger trg = CreateTrigger()
        local trigger trgTargetOrder = CreateTrigger()
        local trigger trgReturnOrder = CreateTrigger()
        local trigger trgRallyPoint = CreateTrigger()
        local trigger trgHarvest = CreateTrigger()
        local trigger trgReturn = CreateTrigger()
        local trigger trgUnitDies = CreateTrigger()
        local integer i = 0
        
        call TriggerSleepAction(0) // For multiboard
        
        // TEST
        call SaveInteger(htbOil, COST_RESEARCH, 'Rhme', 100)
        call SaveInteger(htbOil, COST_RESEARCH_INCR, 'Rhme', 100)
        call SaveInteger(htbOil, COST_UNIT, 'hpea', 100)
        call SaveInteger(htbOil, COST_BUILDING, 'hhou', 100)
        call SaveBoolean(htbOil, PLATFORMS, 'h001', true) // human
        
        
        call SaveBoolean(htbOil, PLATFORMS, 'h61L', true) // human
        call SaveBoolean(htbOil, PLATFORMS, 'h61M', true) // orc
        call SaveBoolean(htbOil, DROPOFFS, 'h61C', true) // human shipyard
        call SaveBoolean(htbOil, DROPOFFS, 'h61D', true) // human refinery
        call SaveBoolean(htbOil, DROPOFFS, 'o607', true) // orc shipyard
        call SaveBoolean(htbOil, DROPOFFS, 'h61J', true) // orc refinery
        call SaveBoolean(htbOil, REFINERIES, 'h61D', true) // human
        call SaveBoolean(htbOil, REFINERIES, 'h61J', true) // orc

        call SaveInteger(htbOil, COST_UNIT, 'h606', 500) // Human transport
        call SaveInteger(htbOil, COST_UNIT, 'h607', 700) // Human destroyer
        call SaveInteger(htbOil, COST_UNIT, 'h608', 1000) // Human battleship
        call SaveInteger(htbOil, COST_UNIT, 'h61X', 800) // Human submarine
        call SaveInteger(htbOil, COST_UNIT, 'o605', 500) // Orc transport
        call SaveInteger(htbOil, COST_UNIT, 'o604', 700) // Orc destroyer
        call SaveInteger(htbOil, COST_UNIT, 'o606', 1000) // Orc juggernaut
        //call SaveInteger(htbOil, COST_UNIT, '????', 800) // Orc turtle
        
        call SaveInteger(htbOil, COST_RESEARCH, 'Rhra', 1000) // Human Upgrade Cannons
        call SaveInteger(htbOil, COST_RESEARCH_INCR, 'Rhra', 2000)
        call SaveInteger(htbOil, COST_RESEARCH, 'R60B', 1000) // Orc Upgrade Cannons
        call SaveInteger(htbOil, COST_RESEARCH_INCR, 'R60B', 2000)
         
        call SaveInteger(htbOil, COST_BUILDING, 'hbla', 100) // Human blacksmith
        call SaveInteger(htbOil, COST_BUILDING, 'h61E', 400) // Human foundry
        call SaveInteger(htbOil, COST_BUILDING, 'h61D', 200) // Human refinery
        call SaveInteger(htbOil, COST_BUILDING, 'hkee', 200) // Human keep
        call SaveInteger(htbOil, COST_BUILDING, 'hcas', 500) // Human castle
        call SaveInteger(htbOil, COST_BUILDING, 'h61T', 100) // Orc blacksmith
        call SaveInteger(htbOil, COST_BUILDING, 'h61K', 400) // Orc foundry
        call SaveInteger(htbOil, COST_BUILDING, 'h61J', 200) // Orc refinery
        call SaveInteger(htbOil, COST_BUILDING, 'ostr', 200) // Orc stronghold
        call SaveInteger(htbOil, COST_BUILDING, 'ofrt', 500) // Orc fortress
        
        call SetSoundChannel(SND_WRN, 8)
        call SetSoundChannel(SND_ERR, 8)
        call SetSoundVolume(SND_WRN, 80)
        call SetSoundVolume(SND_ERR, 127)
        
        call MultiboardSetTitleText(mtb, "Oil")
        call MultiboardSetRowCount(mtb, 1)
        call MultiboardSetColumnCount(mtb, 2)
        set mbiIcon = MultiboardGetItem(mtb, 0, 0)
        call MultiboardSetItemIcon(mbiIcon, "ReplaceableTextures\\CommandButtons\\BTNoil.blp")
        set mbiOil = MultiboardGetItem(mtb, 0, 1)
        call MultiboardSetItemStyle(mbiOil, true, false)
        call SetPlayerOil(udg_StartingOil, false)
        call MultiboardDisplay(mtb, true)
            
        loop
            exitwhen i > bj_MAX_PLAYERS+3
            
            set plr = Player(i)
            
            // SAVE PATCH OIL AMOUNT
            call GroupEnumUnitsOfPlayer(grpOil, plr, function SaveOilAmountFltr)
            
            // TRANSFER OIL AMOUNT & TANKER CLEANUP
            call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_CONSTRUCT_START,  function PlatformStartFltrAcn)
            call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_CONSTRUCT_FINISH, function PlatformFinishFltrAcn)
            
            // HARVESTING TRIGGERS
            call TriggerRegisterPlayerUnitEvent(trgTargetOrder, plr, EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, null)
            call TriggerRegisterPlayerUnitEvent(trgReturnOrder, plr, EVENT_PLAYER_UNIT_ISSUED_ORDER,        function HasReturnFltr)
            call TriggerRegisterPlayerUnitEvent(trgRallyPoint,  plr, EVENT_PLAYER_UNIT_TRAIN_FINISH,        function HasHarvestFltr)
            call TriggerRegisterPlayerUnitEvent(trgHarvest,     plr, EVENT_PLAYER_UNIT_SPELL_EFFECT,        function HasHarvestOrReturnFltr)
            call TriggerRegisterPlayerUnitEvent(trgReturn,      plr, EVENT_PLAYER_UNIT_SPELL_CHANNEL,       function HasReturnFltr)
            call TriggerRegisterPlayerUnitEvent(trgUnitDies,    plr, EVENT_PLAYER_UNIT_DEATH,               null)
            
            set i = i+1
        endloop
        
        call TriggerAddCondition(trgTargetOrder, function TargetOrderCndAcn)
        call TriggerAddCondition(trgReturnOrder, function ReturnOrderCndAcn)
        call TriggerAddCondition(trgRallyPoint,  function RallyPointCndAcn)
        call TriggerAddCondition(trgHarvest,     function HarvestCndAcn)
        call TriggerAddCondition(trgReturn,      function ReturnCndAcn)
        call TriggerAddCondition(trgUnitDies,    function UnitDiesCndAcn)
        
        // OIL COST TRIGGERS
        set plr = GetLocalPlayer()
        set trg = CreateTrigger() // Train Order
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_ISSUED_ORDER, null)
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, null)
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, null)
        call TriggerAddCondition(trg, function OilCostOrderCndAcn)
        set trg = CreateTrigger() // Train Finish or Cancel
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_TRAIN_CANCEL, null)
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_TRAIN_FINISH, null)
        call TriggerAddCondition(trg, function TrainEndCndAcn)
        set trg = CreateTrigger() // Research Finish or Cancel
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_RESEARCH_CANCEL, null)
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_RESEARCH_FINISH, null)
        call TriggerAddCondition(trg, function ResearchEndCndAcn)
        set trg = CreateTrigger() // Upgrade Finish or Cancel & Build Cancel
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_UPGRADE_FINISH, function UpgradeFinishFltrAcn)
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_UPGRADE_CANCEL, function UpgradeCancelFltrAcn)
        call TriggerRegisterPlayerUnitEvent(trg, plr, EVENT_PLAYER_UNIT_CONSTRUCT_CANCEL, function BuildCancelFltrAcn)
        
        set mtb = null
        set plr = null
        call DestroyGroup(grpOil)
        set grpOil = null
        set trg = null
        set trgTargetOrder = null
        set trgReturnOrder = null
        set trgRallyPoint = null
        set trgHarvest = null
        set trgReturn = null
        set trgUnitDies = null
    endfunction
//===============================================================================
//===============================================================================
endlibrary