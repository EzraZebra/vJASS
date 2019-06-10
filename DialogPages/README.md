 - Create a dialog with automatic pages
 - Optionally show an index page
 - Automatic Next/Previous/Back/Cancel buttons

# Changelog
## v1.0.2a (fix)
 - Script actually compiles now
 - Fixed/improved handling of 0 buttons and 0 buttons per page
 - Fixed/improved behaviour when index enabled and number of buttons < buttons per page

## v1.0.2
 - DialogPDisplay and DialogPDestroy now take dialogId instead of dialog handle as argument
 - DialogPCreate: -- Added argument: boolean showIndex -- Now returns dialogId instead of dialog handle -- Fixed hashtable reference leak
 - DialogPGetClickedId now returns DP_NONE instead of DP_NOT_FOUND if no button has been clicked yet
 - DialogPAddButton now returns DP_NOT_FOUND instead of -1 if dialog isn't found
 - Index is now only shown when number of buttons > buttons per page
 - New functions: -- DialogPSetButtonsPP -- DialogPSetButtonsText, DialogPSetButtonsHotkey, DialogPDisplayButtons -- DialogPGetHandle -- DialogPAddQuitButton, DialogPSetQuitButton
 - Functions renamed: -- DialogPSetPageIndex -> DialogPSetPage -- DialogPSetIndexPageIndex -> DialogPSetIndexPage
 - Removed global variable: DP_showIndex

## v1.0.1 (small update)
 - Fixed third page not being available when there are 3 pages
 - Switched next and previous buttons

## v1.0.1 (fix)
 - Corrected a mistake in calculating number of index pages

## v1.0.1
 - Added option to show an index page
 - Misc

