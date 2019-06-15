[->Hive Workshop](https://www.hiveworkshop.com/threads/screenmouse.314806/)

 - Determine direction of mousemovement on screen
 - Get the mouse position on screen, relative to center
 - Get mouse button up/down state
 - Note that coordinates go from right to left (X) and bottom to top (Y)
 
 ### Issues (probably not possible to fix)
 - Results are distorted by the FoV (X-axis differences are smaller at the top of the screen than at the bottom)
 - Only accurate on flat terrain
 
 # Changelog
 ### v1.1.1
- Now setting DifX/Y and DifX/Y_s to 0 when move trigger is run with invalid mouse position or when disabled with SMEnablePlayerMove

### v1.1.0
- Added separate buttonTrigger registration
- SMRegisterPlayer renamed to SMRegisterPlayerDrag
- Added Enable/Disable function for each registration function
- DifX/Y, DifX/Y_s and RelX/Y now only updated when TriggerPlayer == LocalPlayer
- Getting player with GetTriggerPlayer() instead of saving trigger/player associations
- Registration limits removed, except:
-- each trigger/player combination can only be registered once
-- each buttonTrigger/player combination can have only one associated moveTrigger
- Misc improvements/changes

### v1.0.3
- Renamed ScreenMouseRegisterPlayer to SMRegisterPlayer
- Added SMRegisterPlayerMove
- Move trigger no longer disables itself if no mouse buttons are pressed down
- Added SMGetX(), SMGetY(), SMGetRelX() and SMGetRelY()
- Added checks if saved values exist to getter functions

### v1.0.2
- Players can now be registered more than once
- Improved moveTrigger enable/disable behaviour in buttonTrigger

### v1.0.1 (small update)
- Register function now checks if player and/or trigger(s) are already registered

### v1.0.1
- Values now stored per player/trigger in hashtable
- Get values with getter functions
- Choose which buttons to use (left, right, both together)
- Updated example trigger

### v1.0.0 (quick update)
- Updated to use triggers passed by user instead of internal triggers
- Nulled trg in MouseMoveCndAcn()
- Some small changes
- Added SM_difXs/SM_difYs; multipliers now only applied if larger than current field values
