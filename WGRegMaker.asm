; #########################################################################

    .486
    .model flat, stdcall
    option casemap :none   ; case sensitive

; #########################################################################

    include \masm32\include\windows.inc
    include \masm32\include\user32.inc
    include \masm32\include\kernel32.inc
    include \masm32\include\gdi32.inc
    include \masm32\include\shell32.inc
    include \masm32\include\masm32.inc

    includelib \masm32\lib\user32.lib
    includelib \masm32\lib\kernel32.lib
    includelib \masm32\lib\gdi32.lib
    includelib \masm32\lib\shell32.lib
    includelib \masm32\lib\masm32.lib

    ;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ;Function prototype definition
    
    DlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD
    ReloadMe PROTO :DWORD

    ; ---------------------
    ; literal string MACRO
    ; ---------------------
      literal MACRO quoted_text:VARARG
        LOCAL local_text
        .data
          local_text db quoted_text,0
        .code
        EXITM <local_text>
      ENDM
    ; --------------------------------
    ; string address in INVOKE format
    ; --------------------------------
      SADD MACRO quoted_text:VARARG
        EXITM <ADDR literal(quoted_text)>
      ENDM

; #########################################################################
    .const
    MIN_APP_LENGTH	equ 12
    IDC_MAKE	equ 2001
    IDC_RELOAD  equ 2002
    IDC_EXIT    equ 2003

    IDI_MAIN    equ 1000
    IDM_EXIT    equ 3001
    
    .data
    DlgName db "WGREGMAKEDLG",0
    szWGClass   db "WGMIXERCLASS",0
    szWGApp db MAX_PATH dup(0)
    szErr	db "error",0
    passbuf db MAX_PATH dup(0)
    userbuf db MAX_PATH dup(0)
    regbuf  db MAX_PATH dup(0)
    g_IsRegged  db FALSE
    g_IsInstalled db FALSE

    szFile	db "Wingroov.ini",0
    szRegSection	db "WinGrooveSetup",0
    szInstallSection	db "InstalledFiles",0
    
    szKeyTarget db "LFNWGDirectory",0
    szValTarget db MAX_PATH dup(0)
    
    szKeyApp    db "WGPLAYER.EXE",0
    szKeyPass   db "WGPASSWORD",0
    szValPass   db "ZAAAAAAA",0
    szKeyUID    db "WGUSERID",0
    szValUID    db "BJG70109",0
    szKeyReg    db "Registration",0
    szValReg    db "1",0
    
    szKey0	db "NegQueState0",0
    szKey1	db "NegQueState1",0
    szKey2	db "NegQueState2",0
    szKey3	db "NegQueState3",0
    szKey4	db "NegQueState4",0
    szKey5	db "NegQueState5",0
    szKey6	db "NegQueState6",0
    szKey7	db "NegQueState7",0

    szVal0	db "39378",0;"63147",0
    szVal1	db "35535",0;"42196",0
    szVal2	db "60362",0;"44769",0
    szVal3	db "39123",0;"60404",0
    szVal4	db "39363",0;"41676",0
    szVal5	db "52102",0;"63207",0
    szVal6	db "52139",0
    szVal7  	db "52102",0
    
    .data?
    hInstance   HINSTANCE ?
    g_AppName   LPSTR ?
    
    .code

start:

    invoke GetModuleHandle,NULL
    mov    hInstance,eax
    invoke DialogBoxParam, hInstance, ADDR DlgName,NULL,addr DlgProc,NULL
    invoke ExitProcess,eax
; #########################################################################

DlgProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL hMenu:HMENU
    LOCAL hBtnMake:HWND
    LOCAL hBtnReload:HWND
   
    .IF uMsg==WM_INITDIALOG
        ;==== init vars ... ======
        invoke GetModuleFileName,0,addr g_AppName,MAX_PATH
        invoke FindWindowEx,hWnd,NULL,SADD("Button"),SADD("&Make it")
        mov hBtnMake,eax
        invoke FindWindowEx,hWnd,NULL,SADD("Button"),SADD("&Reload")
        mov hBtnReload,eax
        
        ;===== build my menu item on sys menu... =====
        invoke GetSystemMenu,hWnd,FALSE
        mov hMenu,eax
        invoke AppendMenu,hMenu,MF_SEPARATOR,0,0
        invoke AppendMenu,hMenu,MF_STRING,8888,SADD("* &About WGRegMaker *")
        
        ;====== get WinGroove's info ... =======
        call FindWGInfo
        
        ; Disable "Make" button if WinGroove has not been installed,
        ; or has alreadey been regstered.
        .if !g_IsInstalled || g_IsRegged
            invoke EnableWindow,hBtnMake,FALSE
            invoke SetFocus,hBtnReload
        .endif
        invoke IsNT
        .if eax>=5
        	push AW_BLEND + AW_ACTIVATE
        .else
        	push AW_CENTER + AW_ACTIVATE
        .endif
        push 300
        push hWnd
        call AnimateWindow
    .ELSEIF uMsg==WM_CLOSE
        invoke EndDialog,hWnd,NULL
    .ELSEIF uMsg==WM_COMMAND
        mov eax,wParam
        mov edx,eax
        shr edx,16
        .if dx==BN_CLICKED
            .if ax==IDC_EXIT
                invoke SendMessage,hWnd,WM_CLOSE,NULL,NULL
            .elseif ax==IDC_MAKE
                call WriteRegData
                invoke SendMessage,hWnd,WM_COMMAND,IDC_RELOAD + BN_CLICKED,NULL
            .elseif ax==IDC_RELOAD
                invoke ReloadMe,hWnd  ;just do a reload                
            .endif
        .endif
    .ELSEIF uMsg==WM_SYSCOMMAND
        .if wParam==8888
            ;get my cmd and show my about box...
            invoke MessageBox,hWnd,\
            SADD("WinGroove 0.9e~0.A5 RegMaker by -=RogerJia=-",2 dup(0dh),"   ~Compiled with MASM32 7.0, it's great!!! :o~"),\
            SADD("WGRegMaker"),MB_OK + MB_ICONINFORMATION
        .endif

        ;==============================================
        ;ignore other sys cmds, leave them available
        ;==============================================
        invoke DefWindowProc,hWnd,uMsg,wParam,lParam
    .ELSE
        mov eax,FALSE ;if nothing to be done, must return FALSE.
        ret
    .ENDIF
    mov eax,TRUE
    ret
DlgProc endp

; #########################################################################

FindWGInfo proc
    ;check if WinGroove is installed by read string info.
    invoke GetPrivateProfileString,addr szInstallSection,addr szKeyApp,\
           addr szErr,addr szWGApp,MAX_PATH,addr szFile
    invoke StrLen,addr szWGApp
    
    .if eax>MIN_APP_LENGTH
        mov g_IsInstalled,TRUE
        invoke GetPrivateProfileString,addr szRegSection,addr szKeyTarget,\
                addr szErr,addr szValTarget,MAX_PATH,addr szFile

        ;=================================================
        ;See if its been registered by reading length of \
        ;passwd,userid and the value of reginfo.
        ;=================================================
        invoke GetPrivateProfileString,addr szRegSection,addr szKeyPass,\
                addr szErr,addr passbuf,MAX_PATH,addr szFile
        invoke StrLen,addr passbuf
        
        .if eax==8
            invoke GetPrivateProfileString,addr szRegSection,addr szKeyUID,\
                     addr szErr,addr userbuf,MAX_PATH,addr szFile
            invoke StrLen,addr userbuf

            .if eax==8
                invoke GetPrivateProfileString,addr szRegSection,addr szKeyReg,\
                         addr szErr,addr regbuf,MAX_PATH,addr szFile
                invoke atodw,addr regbuf
                .if eax==1
                    ;### if all OK, set True. ###
                    mov g_IsRegged,TRUE
                .endif
            .endif
        .endif
    .endif
    ret
FindWGInfo endp

; #########################################################################

ResetWG proc
    ;load WGPlayer or restart it if running.
    invoke CloseApp,addr szWGClass,0
    invoke ShellExecute,0,SADD("open"),addr szWGApp,0,0,SW_SHOWNORMAL
    ret
ResetWG endp

; #########################################################################

WriteRegData proc
    ;write all reg info ...
    invoke WritePrivateProfileString,addr szRegSection,addr szKeyPass,addr szValPass,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKeyUID,addr szValUID,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey0,addr szVal0,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey1,addr szVal1,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey2,addr szVal2,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey3,addr szVal3,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey4,addr szVal4,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey5,addr szVal5,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey6,addr szVal6,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKey7,addr szVal7,addr szFile
    invoke WritePrivateProfileString,addr szRegSection,addr szKeyReg,addr szValReg,addr szFile   
    ret	
WriteRegData endp

; #########################################################################

ReloadMe proc hWnd:HWND
    invoke SendMessage,hWnd,WM_SYSCOMMAND,SC_CLOSE,NULL
    call ResetWG
    invoke Sleep,1000
    invoke ShellExecute,0,SADD("open"),addr g_AppName,0,0,SW_SHOWNORMAL
    ret
ReloadMe endp

; #########################################################################

end start