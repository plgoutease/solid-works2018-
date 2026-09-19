Dim WshShell,objFSO,ver,ie,reg,windir,srv_dict,firewall_dict,objWMIService,Shell,obj(),objRegistry
	Set WshShell=WScript.CreateObject("WScript.Shell")
	Set objFSO = CreateObject("Scripting.FileSystemObject")
	Set objWMIService = GetObject("winmgmts:\\.")
	Set Shell=CreateObject("Shell.Application")
	Set srv_dict=CreateObject("Scripting.Dictionary") '需调整的服务
	Set firewall_dict=CreateObject("Scripting.Dictionary")'需禁止接连网络的程序
	Set objRegistry=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
	Set objWMI = GetObject("Winmgmts:\\.\Root\Cimv2")
	Set colOperatingSystems = objWMIService.InstancesOf("Win32_OperatingSystem")

If WScript.Arguments.length = 0 Then
	Shell.ShellExecute "wscript.exe", Chr(34) &  WScript.ScriptFullName & Chr(34) & " uac", "", "runas", 1
	WScript.quit
End If

my_dir=left(wscript.scriptfullname,instrrev(wscript.scriptfullname,"\")-1) '& "\" '找到程序所在目录
For Each objOperatingSystem In colOperatingSystems
   windir=objOperatingSystem.WindowsDirectory
Next
prog_dir=WshShell.ExpandEnvironmentStrings("%ProgramFiles%")
prog86_dir=WshShell.ExpandEnvironmentStrings("%ProgramFiles(x86)%")
user_dir=WshShell.ExpandEnvironmentStrings("%USERPROFILE%")
pub_dir=WshShell.ExpandEnvironmentStrings("%PUBLIC%")
data_dir=WshShell.ExpandEnvironmentStrings("%ProgramData%")

bingpath=chr(34) & prog_dir & "\Common Files\SOLIDWORKS Shared\"
WshShell.Run "regsvr32.exe /s /u " & chr(34) & my_dir & "\swhtmlcontrol.dll" & chr(34),0,true
WshShell.Run "regsvr32.exe /s /u " & bingpath & "sldwinshellextu.dll" & chr(34),0,true
WshShell.Run "regsvr32.exe /s /u " & bingpath & "sldthumbnailprovider.dll" & chr(34),0,true

Close_Process("sldProcMon.exe") '关闭程序
Close_Process("SLDWORKS.exe") '关闭程序
Close_Process ("SolidWorksLicensing.exe")
Close_Process ("sldimdownloader.exe")
Close_Process ("sldBgDwld.exe")
Close_Process ("sldCheckForUpdates.exe")
Close_Process ("sldimdownloader.exe")
Close_Process ("swlmutil.exe")
Close_Process ("sldrxET.exe")
Close_Process ("sldrxmm.exe")
Close_Process ("sldrx.exe")
Close_Process ("swlmwiz.exe")
Close_Process ("sldShellExtServer.exe")
Close_Process ("lmutil.exe")

strDesktop = WshShell.SpecialFolders("AllUsersDesktop") '桌面
'【修复】版本号改为2018 (原为 SLDWORKS2022.lnk)
del strDesktop & "\SLDWORKS2018.lnk"

'删除服务...
WshShell.Run "net.exe stop " & chr(34) & "SolidWorks Flexnet Server" & chr(34),0,true
WshShell.Run "net.exe stop " & chr(34) & "FlexNet Licensing Service 64" & chr(34),0,true
WshShell.Run "net.exe stop " & chr(34) & "SolidWorks Licensing Service" & chr(34),0,true
WshShell.Run "sc.exe delete " & chr(34) & "SolidWorks Flexnet Server" & chr(34),0,true
WshShell.Run "sc.exe delete " & chr(34) & "FlexNet Licensing Service 64" & chr(34),0,true
WshShell.Run "sc.exe delete " & chr(34) & "SolidWorks Licensing Service" & chr(34),0,true

'【说明】此处原脚本在写入.reg文件后立即删除，随后才调用regedit导入，
'导致导入时文件已不存在、注册表清理静默失败。已在下方调整为：
'  写入 -> 导入 -> 删除临时文件

Set tmp1 = objFSO.OpenTextFile(my_dir & "\zhucebiao_un.reg",   1) '读入旧的文件
tmp2=tmp1.ReadAll:tmp1.close
'读已安装的SW字库
tmp2=tmp2 & vbCrLf & "[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts]"
tmp2=tmp2 & vbCrLf
strPath = "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
Set oReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
'【修复】EnumValues 补全第4个输出参数 arrValueTypes，符合标准调用方式
oReg.EnumValues &H80000002,strPath,arrValueNames,arrValueTypes '&H80000002=HKLM
	strOut=""
For Each fonts In arrValueNames
    '【修复】原来是两个独立 if，一个字体项若同时满足两个条件会被重复写入两次删除行；
    '        且第二个条件(路径含"\")过于宽泛，会误删其他非SolidWorks的第三方字体。
    '        现改为 ElseIf，并且第二个条件加上关键字限制，仅匹配路径中包含
    '        "SolidWorks" 或 "SLD" 字样的字体项，避免误删。
    font_file=WshShell.RegRead("HKEY_LOCAL_MACHINE\" & strPath & "\" & fonts)
    if left(fonts,2)="SW" then
        tmp2 = tmp2 & chr(34) & fonts & chr(34) & "=-" & vbCrLf
    elseif instr(font_file,"\")>0 and (instr(lcase(font_file),"solidworks")>0 or instr(lcase(font_file),"sld")>0) then
        tmp2 = tmp2 & chr(34) & fonts & chr(34) & "=-" & vbCrLf
    end if
Next
Set tmp1=objFSO.OpenTextFile(my_dir & "\安装修改.reg",8,True,0)
tmp1.Write tmp2:tmp1.close:set tmp1=nothing
ins= "regedit /s " & chr(34) & my_dir & "\安装修改.reg" & chr(34)
WshShell.Run  ins,1,true ' 【修复】先调入注册表
del my_dir & "\安装修改.reg" ' 【修复】导入完成后再删除临时reg文件

'释放禁止的1个服务联网：SolidWorks Licensing Service
tmp2="SolidWorks Licensing Service"
tmp3="%CommonProgramFiles(x86)%\SolidWorks Shared\Service\SolidWorksLicensing.exe"
tmp3=WshShell.ExpandEnvironmentStrings(tmp3) 
tmp1=" del rule name=" & chr(34) & tmp2 & chr(34)  '服务
WshShell.Run "netsh advfirewall firewall " & tmp1 ,0,true '删除之前规则

'释放禁止的2个服务联网：FlexNet Licensing Service 64
'【修复】原名称多写了一个"W"（写成 "WFlexNet Licensing Service 64"），
'        与前面添加/停止/删除服务时使用的名称"FlexNet Licensing Service 64"不一致，
'        导致 netsh 找不到匹配规则、删除静默失败。已改为一致的名称。
tmp2="FlexNet Licensing Service 64"
tmp3="%CommonProgramFiles%\Macrovision Shared\FlexNet Publisher\FNPLicensingService64.exe"
tmp3=WshShell.ExpandEnvironmentStrings(tmp3) 
tmp1=" del rule name=" & chr(34) & tmp2 & chr(34)  '服务
WshShell.Run "netsh advfirewall firewall " & tmp1 ,0,true '删除之前规则

del ("C:\Windows\SolidWorks")
del (prog_dir & "\Common Files\SOLIDWORKS Shared")
del (prog86_dir & "\Common Files\SOLIDWORKS Shared")
del (prog86_dir & "\Common Files\SOLIDWORKS 安装管理程序")
del (user_dir & "\AppData\Local\SolidWorks")
del (user_dir & "\AppData\Roaming\SOLIDWORKS")
'【修复】版本号改为2018 (原为 SOLIDWORKS 2022)
del (user_dir & "\AppData\Roaming\SOLIDWORKS 2018")
del (data_dir & "\SOLIDWORKS")

'【修复】原注释称"需关闭DHCP服务的Svchost.exe才能删"，实际占用该evtx文件句柄的是
'        Windows事件日志(Eventlog)服务，与DHCP无关。原脚本从未真正停止任何服务，
'        删除大概率因文件被占用而静默失败。现改为先停止eventlog服务再删除，
'        完成后重新启动该服务，避免影响系统日志功能。
WshShell.Run "net.exe stop eventlog",0,true
del (windir & "\System32\winevt\Logs\SolidWorks-DTS.evtx")
WshShell.Run "net.exe start eventlog",0,true

i=WshShell.popup("卸载完成，5秒后退出程序",5,"SolidWorks卸载程序",VbOKCancel) 
Wscript.Quit 






Function move_dir(dir0,dir1)'dir0:原目录;dir1:移动过去的新目录
	dim file,fs,items,objdir
	dir1=UCase(trim(dir1)):if right(dir1,1)="\" then dir1=left(dir1,len(dir1)-1) '容错去空格和后\
	dir0=UCase(trim(dir0)):if right(dir0,1)="\" then dir0=left(dir0,len(dir0)-1) '容错去空格和后\
	fs = Split(dir1, "\")
	for each file in fs
	  if not file=nul then items=items&file&"\"
	  if not objFSO.FileExists(items&"\nul") then Set objdir = objFSO.CreateFolder(items)
	next
	objdir=left(dir1,instrrev(dir1,"\")-1) '& "\" 
	fs=right(dir1,len(dir1)-len(objdir))
	if fs=right(dir0,len(fs)) then
		dir1=objdir
		if right(dir1,1)=":" then dir1=dir1 & "\"
	end if
	'CreateObject("Shell.Application").NameSpace(dir1).MoveHere dir0,&H0&'FOF_CREATEPROGRESSDLG 
	'上述方法不能直接覆盖，所以只能用复制和删除
	on error resume next
		objFSO.CopyFolder dir0,dir1,True '复制目录里的文件到新的地方
		'del(dir0)'暂时不忙删除，万一需要重复安装？
	on error goto 0
End Function

Function NetWork(val) '因未设置延迟,所以不要重复调用或在短时内操作网络
'接收参数：0:关闭“本地连接”   1:打开“本地连接”   2:自动(关闭则打开；打开则关闭)
    dim w,i
    Set w=objWMI.ExecQuery("select * from WIN32_NetworkAdapter")
    For Each i In w
       If instr(i.NetConnectionID,"本地连接")>0 or instr(i.NetConnectionID,"以太网")>0 Then
             if val=0 then i.Disable
             if val=1 then i.Enable
             if val=2 then
                 If i.NetConnectionStatus<>0 then
                    i.Disable
                 Else
                    i.Enable
                 end if
             end if
       End If
    next
    set w=nothing
'wscript.sleep 400
End Function

Function Wait(proc) '等待程序完成,十秒还没完成则退出
    dim mark,obj,proce,data,x
    do
      mark=0
      Set obj = getobject("winmgmts:\\.\root\cimv2")
      Set proce = obj.execquery("select * from win32_process")
      For each x in proce
        if lcase(x.name)=proc then mark=1
        data=data+1
      next
      if mark=0 or data>100 then exit do
      wscript.sleep 100
      Set obj = nothing
      Set proce = nothing
    loop
End Function 

'关闭程序
Function Close_Process(ProcessName) '关闭程序
    Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
    Set colProcessList = objWMIService.ExecQuery ("Select * from Win32_Process Where Name = '" & ProcessName & "'")
    For Each objProcess in colProcessList
        objProcess.Terminate()
    Next
End Function

Function Shortcut(Short_name,path_and_name) '为在桌面创建一个快捷方式
    strDesktop = WshShell.SpecialFolders("AllUsersDesktop") '在桌面创建一个快捷方式
    set oShellLink = WshShell.CreateShortcut(strDesktop & "\" & Short_name & ".lnk")   '名称
    oShellLink.TargetPath = path_and_name      '目标
    oShellLink.WindowStyle = 1    '窗口样式  1默认窗口激活，参数3最大化激活，参数7最小化
    oShellLink.Hotkey = ""         '快捷键
    oShellLink.IconLocation = path_and_name & ",0"     '第几个图标
    oShellLink.Description = Short_name      '备注
    oShellLink.WorkingDirectory = left(path_and_name,InStrRev(path_and_name,"\")-1)   '起始位置
    oShellLink.Arguments = ""    '参数
    oShellLink.Save     '保存
End Function

Function del(del_file) '删除文件或者文件夹，之所以最后一种可能实现前两种功能还要分开成三种，是因为效率
  dim file_path,str2,str3,pattern,tmp1,tmp2,tmp3
  tmp2="":tmp3="" '初使化临时变量
  del_file=WshShell.ExpandEnvironmentStrings(trim(del_file))'还原带环境变量,去掉空格,下面这句设置解属性参数,其中SID在上文已定义
  file_path = lcase(objFSO.GetParentFolderName(del_file)) '取父目录方法
  if del_file="" then del="调用时没写被删除的文件":exit Function
  if not objFSO.FolderExists(file_path) then del="没找到父文件夹:" & del_file :exit Function
  on error resume next
      '【修复】原代码错误地把 windir 拼接在 del_file 前面（如 "C:\WindowsC:\Program Files\..."），
      '        导致路径不存在，takeown/icacls 实际从未生效；
      '        同时 icacls 的 "/f" 用法有误（"/f" 是 takeown 的参数，icacls 无需此参数放在路径前）。
      '        现改为直接使用 del_file 本身，并补上 /r /d y（递归取得子对象所有权，遇提示自动选y）
      '        和 /t（icacls 递归应用于子文件夹/文件）。
      WshShell.Run "takeown.exe /f " & chr(34) & del_file & chr(34) & " /r /d y",0,true
      WshShell.Run "icacls.exe " & chr(34) & del_file & chr(34) & " /grant administrators:F /t",0,true
      objFSO.deletefile del_file,true '用通配符删除文件
      objFSO.deletefolder del_file,true '直接删除文件夹
  on error goto 0
End Function

Function SRV_ADD(Service_Name,mode)
	'Set tmp=GetObject("winmgmts:\\.\root\cimv2").get("win32_service")
	'uu=tmp.create("WFlexNet Licensing Service 64","FlexNet Licensing Service 64","C:\Program Files\Common Files\Macrovision Shared\FlexNet 'Publisher\FNPLicensingService64.exe",16,2,"Manual",True,Null,null)
	'Set tmp=nothing
End Function

'例：Call SRV("RemoteAccess","del")
Function SRV(Service_Name,mode)'设置系统服务,stop:停,Start:启,del:删,Disabled:禁,Automatic:自动,Manual:手动,delayed-auto延迟启动
	dim ObjServices,SRV_msg'返回值：正常完成/操作值错mode/无此服务
	SRV_msg=""
	SRV_msg=WshShell.RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\" & Service_Name & "\Start")
	if SRV_msg="" then exit Function
	Set ObjServices = GetObject("winmgmts:\\.\root\cimv2").ExecQuery("Select * from Win32_Service where Name="&"'"&Service_Name &"'")  
	SRV="未找到" & Service_Name:FOREXIT=0
	For Each Service In ObjServices
		SRV="有服务" & Service_Name
		Service_mode=LCase(mode)'默认手工启动，是否考虑预置Start=3 ？
		Select Case LCase(Service_mode)
			Case "stop"'停止服务
				Call Service.StopService()
				Start=0
				'If Service.State = "Running" Then '不同服务停下来时间不一样
			Case "start"'启动服务
				Call Service.Start()
				Start=0
			Case "del"'删除服务
				Start=6
			Case "demand"'手动
				Start = 3
			Case "auto"'自动启动
				Start = 2
				Service_mode="Automatic"
			Case "delayed-auto"'延迟启动
				Start = 5
				 Service_mode="Automatic"
			Case "disabled"'禁用
				Start = 4                  
				Service_mode="Disabled"
			case else  
				SRV="操作错" & mode
				Start=0
		End Select
		if Start>0 then
			Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")
			oReg.EnumKey HKEY_LOCAL_MACHINE,"SYSTEM\CurrentControlSet\Services\",arrSubKeys
			SRV="无服务" & Service_Name
			For Each subkey In arrSubKeys
				SRV="找到有" & Service_Name
				if subkey=Service.Name then
					if Start=6 then '单独处理删除服务
						SRV_reg="HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\" & subkey & "\Start"
						Service.StopService() '防火墙服务必须停止后才能删除，其他大多不必
						Service.Delete():SRV="删成功" & subkey'删除本服务
SRV_msg="":on error resume next:SRV_msg=WshShell.RegRead(SRV_reg):on error goto 0'尝试读这个服务
						if SRV_msg>"" then'如果这个服务仍然没被删除就解除注册表权限然后尝试直接删除注册表
							SetRegACL "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\"& subkey 
							oReg.deletekey HKEY_LOCAL_MACHINE ,"SYSTEM\CurrentControlSet\Services\" & subkey
SRV_msg="":on error resume next:SRV_msg=WshShell.RegRead(SRV_reg):on error goto 0'尝试读这个服务
							if SRV_msg>"" then '尝试使用Reg命令
								'msgbox "cmd /c reg delete ""HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\" & subkey & """ /f"
								WshShell.Run "cmd /c reg delete ""HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\" & subkey & """ /f",0,true
SRV_msg="":on error resume next:SRV_msg=WshShell.RegRead(SRV_reg):on error goto 0'尝试读这个服务
								if SRV_msg>"" then SRV="删失败" & subkey  else SRV="删成功" & subkey 
							end if
						end if
					else
						'Service.ChangeStartMode(Service_mode)'本来用这句就可以了，能得到最好的兼容性，但权限问题会造成不确定的无效
						Delay=0:if start=5 then Delay=1:Start=2'预设不延时启动(具体秒在Control\AutoStartDelay)
						TryWrtReg "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\" & subkey & "\DelayedAutostart",Delay,"REG_DWORD"
						TryWrtReg "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\" & subkey & "\Start"           ,Start,"REG_DWORD"
					end if
					FOREXIT=1'只可能有一个同名服务，不需要完成所有循环
				end if
				if FOREXIT=1 then exit for
			Next 
		end if
		if FOREXIT=1 then exit for
	Next
	Set ObjServices = nothing
End Function
