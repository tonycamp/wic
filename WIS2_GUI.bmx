SuperStrict

Import MaxGUI.Drivers
Import BRL.EventQueue
Import BRL.System
Import BRL.StandardIO
Import BRL.Pixmap
Import BRL.Max2D
Import BRL.PNGLoader
Import BRL.JPGLoader

Const APP_TITLE:String = "WIS2 Studio v2.1 - Selector Edition"
Const DEFAULT_QUALITY:String = "80"

Const CODEC_HAAR:Int = 0
Const CODEC_DCT:Int = 1
Const CODEC_DTT:Int = 2
Const CODEC_HYBRID:Int = 3
Const CODEC_ADAPTIVE:Int = 4
Const CODEC_LOSSLESS:Int = 5
Const CODEC_WEBP:Int = 6
Const CODEC_JXL:Int = 7
Const CODEC_AVIF:Int = 8
Const CODEC_WEBP_LOSSLESS:Int = 9
Const CODEC_JXL_LOSSLESS:Int = 10
Const CODEC_AVIF_LOSSLESS:Int = 11
Const CODEC_PNG:Int = 12
Const CODEC_JPEG:Int = 13
Const CODEC_WIS2_NHW:Int = 14
Const CODEC_WIS2_SELECTOR:Int = 15

Const MENU_ADD_FILE:Int = 1001
Const MENU_ADD_FOLDER:Int = 1002
Const MENU_OPEN_OUTPUT:Int = 1003
Const MENU_EXIT:Int = 1004
Const MENU_REMOVE:Int = 1101
Const MENU_CLEAR:Int = 1102
Const MENU_COMPRESS_ALL:Int = 1103
Const MENU_EXTRACT_ALL:Int = 1104
Const MENU_STOP_BATCH:Int = 1105
Const MENU_SAVE_LOG:Int = 1201
Const MENU_RESET_SETTINGS:Int = 1202
Const MENU_ABOUT:Int = 1301


Global mainWindow:TGadget
Global inputField:TGadget
Global outputField:TGadget
Global qualityField:TGadget
Global codecCombo:TGadget
Global lumaCombo:TGadget
Global chromaCombo:TGadget
Global levelsCombo:TGadget
Global statusLabel:TGadget
Global titleLabel:TGadget
Global convertButton:TGadget
Global extractButton:TGadget
Global progressBar:TGadget
Global statusDetailLabel:TGadget
Global fileList:TGadget
Global queueStatusLabel:TGadget
Global queueTitleLabel:TGadget
Global removeButton:TGadget
Global clearButton:TGadget
Global aboutButton:TGadget
Global outputFolderField:TGadget
Global outputFolderButton:TGadget
Global inputBrowseButton:TGadget
Global outputButton:TGadget
Global batchCompressButton:TGadget
Global batchExtractButton:TGadget
Global statsOriginalLabel:TGadget
Global statsOutputLabel:TGadget
Global statsRatioLabel:TGadget
Global statsTimeLabel:TGadget
Global statsProcessedLabel:TGadget
Global statsEtaLabel:TGadget
Global statsSavingsLabel:TGadget
Global progressPercentLabel:TGadget
Global lastOperationSuccess:Int
Global lastOutputPath:String
Global addFolderButton:TGadget
Global openOutputFolderButton:TGadget
Global logList:TGadget
Global rememberSettingsCheck:TGadget
Global autoOpenFolderCheck:TGadget
Global SETTINGS_FILE:String = "wis2_studio.ini"
Global recursiveFolderCheck:TGadget
Global imageInfoLabel:TGadget
Global estimateLabel:TGadget
Global previewCanvas:TGadget
Global previewPixmap:TPixmap
Global previewThumbnail:TPixmap
Global previewThumbCanvasW:Int
Global previewThumbCanvasH:Int
Global previewPath:String
Global batchPreviewTempPath:String
Global folderFilesAdded:Int
Global stopBatchButton:TGadget
Global saveLogButton:TGadget
Global stopBatchRequested:Int
Global batchRunning:Int
Global HISTORY_FILE:String = "wis2_history.csv"
Global darkThemeCheck:TGadget
Global headerPanel:TGadget
Global toolbarPanel:TGadget
Global queuePanel:TGadget
Global profilePanel:TGadget
Global advancedPanel:TGadget
Global filesPanel:TGadget
Global statsPanel:TGadget
Global previewPanel:TGadget
Global logPanel:TGadget
Global progressPanel:TGadget
Global queuePaths:String[] = New String[10000]
Global queuePathCount:Int = 0
Global themeLabels:TGadget[] = New TGadget[64]
Global themeLabelCount:Int = 0
Global helpPanel:TGadget

Function ThemeLabel:TGadget(text:String, x:Int, y:Int, w:Int, h:Int, parent:TGadget, style:Int = 0)
    Local gadget:TGadget = CreateLabel(text, x, y, w, h, parent, style)
    If themeLabelCount < themeLabels.Length Then
        themeLabels[themeLabelCount] = gadget
        themeLabelCount :+ 1
    End If
    Return gadget
End Function

Function CreateThemedGroupPanel:TGadget(x:Int, y:Int, width:Int, height:Int, parent:TGadget, title:String)
    Local panel:TGadget
    Local titleLabel:TGadget

    panel = CreatePanel(x, y, width, height, parent, PANEL_GROUP, "")
    titleLabel = ThemeLabel(title, 12, 0, width - 24, 20, panel)
    SetGadgetFont(titleLabel, LoadGuiFont("Segoe UI", 9, FONT_BOLD))

    Return panel
End Function

Function SetThemeForeground(gadget:TGadget, r:Int, g:Int, b:Int)
    If gadget Then SetGadgetColor(gadget, r, g, b, False)
End Function

Function SetThemeBackground(gadget:TGadget, r:Int, g:Int, b:Int)
    If gadget Then SetGadgetColor(gadget, r, g, b, True)
End Function

Function HistoryPath:String()
    Return AppFolder() + HISTORY_FILE
End Function

Function EscapeCSV:String(value:String)
    Return Chr(34) + value.Replace(Chr(34), Chr(34) + Chr(34)) + Chr(34)
End Function

Function AddHistory(inputPath:String, outputPath:String, success:Int, elapsedMs:Int)
    Local stream:TStream
    Local newFile:Int = FileType(HistoryPath()) <> 1

    If newFile Then
        stream = WriteFile(HistoryPath())
    Else
        stream = OpenFile(HistoryPath(), True, True)
        If stream Then SeekStream(stream, StreamSize(stream))
    End If

    If Not stream Then Return
    If newFile Then WriteLine stream, "date,time,input,output,status,elapsed_ms"

    Local state:String = "FAILED"
    If success Then state = "SUCCESS"

    WriteLine stream, EscapeCSV(CurrentDate()) + "," + EscapeCSV(CurrentTime()) + "," + ..
        EscapeCSV(inputPath) + "," + EscapeCSV(outputPath) + "," + ..
        EscapeCSV(state) + "," + elapsedMs
    CloseStream stream
End Function

Function SaveActivityLog()
    Local selected:String = RequestFile("Guardar activity log", "Text file:txt", True, "wis2_activity_log.txt")
    If selected = "" Then Return
    If Lower(ExtractExt(selected)) <> "txt" Then selected :+ ".txt"

    Local stream:TStream = WriteFile(selected)
    If Not stream Then
        Notify "Could not save the activity log.", True
        Return
    End If

    For Local i:Int = 0 Until CountGadgetItems(logList)
        WriteLine stream, GadgetItemText(logList, i)
    Next
    CloseStream stream
    SetStatus("Log guardado: " + selected)
End Function

Function ResetSavedSettings()
    If FileType(SettingsPath()) = 1 Then DeleteFile(SettingsPath())
    SetButtonState(rememberSettingsCheck, False)
    SetStatus("Definições guardadas removidas.")
    LogMessage("Saved settings reset")
End Function

Function ApplyTheme()
    If Not mainWindow Then Return

    Local dark:Int = darkThemeCheck And ButtonState(darkThemeCheck) <> 0
    Local i:Int

    If dark Then
        ' Main surfaces and group panels.
        SetThemeBackground(mainWindow, 31, 34, 39)
        SetThemeBackground(headerPanel, 38, 43, 49)
        SetThemeBackground(toolbarPanel, 38, 43, 49)
        SetThemeBackground(queuePanel, 38, 43, 49)
        SetThemeBackground(profilePanel, 38, 43, 49)
        SetThemeBackground(advancedPanel, 38, 43, 49)
        SetThemeBackground(filesPanel, 38, 43, 49)
        SetThemeBackground(statsPanel, 38, 43, 49)
        SetThemeBackground(previewPanel, 38, 43, 49)
        SetThemeBackground(helpPanel, 38, 43, 49)
        SetThemeBackground(logPanel, 38, 43, 49)
        SetThemeBackground(progressPanel, 38, 43, 49)

        ' Group-box captions and every registered label use light text.
        SetThemeForeground(toolbarPanel, 235, 238, 242)
        SetThemeForeground(queuePanel, 235, 238, 242)
        SetThemeForeground(profilePanel, 235, 238, 242)
        SetThemeForeground(advancedPanel, 235, 238, 242)
        SetThemeForeground(filesPanel, 235, 238, 242)
        SetThemeForeground(statsPanel, 235, 238, 242)
        SetThemeForeground(previewPanel, 235, 238, 242)
        SetThemeForeground(helpPanel, 235, 238, 242)
        SetThemeForeground(logPanel, 235, 238, 242)
        SetThemeForeground(progressPanel, 235, 238, 242)
        For i = 0 Until themeLabelCount
            SetThemeForeground(themeLabels[i], 235, 238, 242)
            SetThemeBackground(themeLabels[i], 38, 43, 49)
        Next

        ' Editable and selectable controls: dark surface, readable text.
        SetThemeBackground(inputField, 48, 52, 58); SetThemeForeground(inputField, 245, 245, 245)
        SetThemeBackground(outputField, 48, 52, 58); SetThemeForeground(outputField, 245, 245, 245)
        SetThemeBackground(outputFolderField, 48, 52, 58); SetThemeForeground(outputFolderField, 245, 245, 245)
        SetThemeBackground(qualityField, 48, 52, 58); SetThemeForeground(qualityField, 245, 245, 245)
        SetThemeBackground(fileList, 36, 39, 44); SetThemeForeground(fileList, 238, 241, 245)
        SetThemeBackground(logList, 25, 27, 31); SetThemeForeground(logList, 225, 230, 235)
        SetThemeBackground(codecCombo, 48, 52, 58); SetThemeForeground(codecCombo, 245, 245, 245)
        SetThemeBackground(lumaCombo, 48, 52, 58); SetThemeForeground(lumaCombo, 245, 245, 245)
        SetThemeBackground(chromaCombo, 48, 52, 58); SetThemeForeground(chromaCombo, 245, 245, 245)
        SetThemeBackground(levelsCombo, 48, 52, 58); SetThemeForeground(levelsCombo, 245, 245, 245)

        ' Native Windows buttons keep a light face on the NG 1.56 Win32 driver.
        ' Use dark captions so there is never white text on a white/light button.
        SetThemeForeground(convertButton, 20, 20, 20)
        SetThemeForeground(extractButton, 20, 20, 20)
        SetThemeForeground(batchCompressButton, 20, 20, 20)
        SetThemeForeground(batchExtractButton, 20, 20, 20)
        SetThemeForeground(stopBatchButton, 20, 20, 20)
        SetThemeForeground(removeButton, 20, 20, 20)
        SetThemeForeground(clearButton, 20, 20, 20)
        SetThemeForeground(addFolderButton, 20, 20, 20)
        SetThemeForeground(openOutputFolderButton, 20, 20, 20)
        SetThemeForeground(saveLogButton, 20, 20, 20)
        SetThemeForeground(aboutButton, 20, 20, 20)
        SetThemeForeground(inputBrowseButton, 20, 20, 20)
        SetThemeForeground(outputButton, 20, 20, 20)
        SetThemeForeground(outputFolderButton, 20, 20, 20)
        ' Checkboxes sit directly on the dark panels, so their captions stay light.
        SetThemeForeground(rememberSettingsCheck, 235, 238, 242)
        SetThemeForeground(autoOpenFolderCheck, 235, 238, 242)
        SetThemeForeground(recursiveFolderCheck, 235, 238, 242)
        SetThemeForeground(darkThemeCheck, 235, 238, 242)
    Else
        SetThemeBackground(mainWindow, 240, 240, 240)
        SetThemeBackground(headerPanel, 240, 240, 240)
        SetThemeBackground(toolbarPanel, 240, 240, 240)
        SetThemeBackground(queuePanel, 240, 240, 240)
        SetThemeBackground(profilePanel, 240, 240, 240)
        SetThemeBackground(advancedPanel, 240, 240, 240)
        SetThemeBackground(filesPanel, 240, 240, 240)
        SetThemeBackground(statsPanel, 240, 240, 240)
        SetThemeBackground(previewPanel, 240, 240, 240)
        SetThemeBackground(helpPanel, 240, 240, 240)
        SetThemeBackground(logPanel, 240, 240, 240)
        SetThemeBackground(progressPanel, 240, 240, 240)

        SetThemeForeground(toolbarPanel, 20, 20, 20)
        SetThemeForeground(queuePanel, 20, 20, 20)
        SetThemeForeground(profilePanel, 20, 20, 20)
        SetThemeForeground(advancedPanel, 20, 20, 20)
        SetThemeForeground(filesPanel, 20, 20, 20)
        SetThemeForeground(statsPanel, 20, 20, 20)
        SetThemeForeground(previewPanel, 20, 20, 20)
        SetThemeForeground(helpPanel, 20, 20, 20)
        SetThemeForeground(logPanel, 20, 20, 20)
        SetThemeForeground(progressPanel, 20, 20, 20)
        For i = 0 Until themeLabelCount
            SetThemeForeground(themeLabels[i], 20, 20, 20)
            SetThemeBackground(themeLabels[i], 240, 240, 240)
        Next

        SetThemeBackground(inputField, 255, 255, 255); SetThemeForeground(inputField, 20, 20, 20)
        SetThemeBackground(outputField, 255, 255, 255); SetThemeForeground(outputField, 20, 20, 20)
        SetThemeBackground(outputFolderField, 255, 255, 255); SetThemeForeground(outputFolderField, 20, 20, 20)
        SetThemeBackground(qualityField, 255, 255, 255); SetThemeForeground(qualityField, 20, 20, 20)
        SetThemeBackground(fileList, 255, 255, 255); SetThemeForeground(fileList, 20, 20, 20)
        SetThemeBackground(logList, 255, 255, 255); SetThemeForeground(logList, 20, 20, 20)
        SetThemeBackground(codecCombo, 255, 255, 255); SetThemeForeground(codecCombo, 20, 20, 20)
        SetThemeBackground(lumaCombo, 255, 255, 255); SetThemeForeground(lumaCombo, 20, 20, 20)
        SetThemeBackground(chromaCombo, 255, 255, 255); SetThemeForeground(chromaCombo, 20, 20, 20)
        SetThemeBackground(levelsCombo, 255, 255, 255); SetThemeForeground(levelsCombo, 20, 20, 20)

        SetThemeForeground(convertButton, 20, 20, 20)
        SetThemeForeground(extractButton, 20, 20, 20)
        SetThemeForeground(batchCompressButton, 20, 20, 20)
        SetThemeForeground(batchExtractButton, 20, 20, 20)
        SetThemeForeground(stopBatchButton, 20, 20, 20)
        SetThemeForeground(removeButton, 20, 20, 20)
        SetThemeForeground(clearButton, 20, 20, 20)
        SetThemeForeground(addFolderButton, 20, 20, 20)
        SetThemeForeground(openOutputFolderButton, 20, 20, 20)
        SetThemeForeground(saveLogButton, 20, 20, 20)
        SetThemeForeground(aboutButton, 20, 20, 20)
        SetThemeForeground(inputBrowseButton, 20, 20, 20)
        SetThemeForeground(outputButton, 20, 20, 20)
        SetThemeForeground(outputFolderButton, 20, 20, 20)
        SetThemeForeground(rememberSettingsCheck, 20, 20, 20)
        SetThemeForeground(autoOpenFolderCheck, 20, 20, 20)
        SetThemeForeground(recursiveFolderCheck, 20, 20, 20)
        SetThemeForeground(darkThemeCheck, 20, 20, 20)
    End If

    RedrawGadget(mainWindow)
End Function

Function RequestStopBatch()
    If Not batchRunning Then
        SetStatus("No batch is currently running.")
        Return
    End If

    stopBatchRequested = True
    DisableGadget(stopBatchButton)
    SetGadgetText(stopBatchButton, "STOP REQUESTED")
    SetStatus("The batch will stop after the current file.")
    LogMessage("Stop requested; waiting for current file")
End Function
Function PumpBatchEvents:Int()
    ' BatchProcess runs synchronously. Pump queued GUI events between files so
    ' STOP AFTER CURRENT is received as soon as the current encoder/decoder exits.
    While PollEvent()
        Select EventID()
            Case EVENT_GADGETACTION
                If EventSource() = stopBatchButton Then RequestStopBatch()
            Case EVENT_MENUACTION
                If EventData() = MENU_STOP_BATCH Then RequestStopBatch()
            Case EVENT_WINDOWCLOSE
                RequestStopBatch()
            Case EVENT_GADGETPAINT
                If EventSource() = previewCanvas Then PaintPreview()
        End Select
    Wend
    Return stopBatchRequested
End Function

Function ForceBatchPreviewRefresh(milliseconds:Int = 120)
    ' MaxGUI can postpone canvas painting while a synchronous external decoder
    ' is running. Repaint explicitly and briefly pump the event queue so the
    ' decoded image becomes visible before the next batch item starts.
    If Not previewCanvas Then Return

    Local started:Int = MilliSecs()
    Repeat
        RedrawGadget(previewCanvas)
        PaintPreview()
        PumpBatchEvents()
        Delay 10
    Until MilliSecs() - started >= milliseconds Or stopBatchRequested
End Function


Function SettingsPath:String()
    Return AppFolder() + SETTINGS_FILE
End Function

Function LogMessage(message:String)
    If logList Then
        Local stamp:String = CurrentDate() + " " + CurrentTime()
        AddGadgetItem(logList, stamp + "  |  " + message)
        SelectGadgetItem(logList, CountGadgetItems(logList) - 1)
    End If
End Function

Function SaveSettings()
    If Not rememberSettingsCheck Or ButtonState(rememberSettingsCheck) = 0 Then Return

    Local stream:TStream = WriteFile(SettingsPath())
    If Not stream Then Return

    WriteLine stream, "codec=" + SelectedGadgetItem(codecCombo)
    WriteLine stream, "quality=" + Trim(GadgetText(qualityField))
    WriteLine stream, "luma=" + SelectedGadgetItem(lumaCombo)
    WriteLine stream, "chroma=" + SelectedGadgetItem(chromaCombo)
    WriteLine stream, "levels=" + SelectedGadgetItem(levelsCombo)
    WriteLine stream, "output=" + GadgetText(outputFolderField)
    WriteLine stream, "autoopen=" + ButtonState(autoOpenFolderCheck)
    WriteLine stream, "recursive=" + ButtonState(recursiveFolderCheck)
    WriteLine stream, "darktheme=" + ButtonState(darkThemeCheck)
    CloseStream stream
End Function

Function LoadSettings()
    Local path:String = SettingsPath()
    If FileType(path) <> 1 Then Return

    Local stream:TStream = ReadFile(path)
    If Not stream Then Return

    While Not Eof(stream)
        Local line:String = ReadLine(stream)
        Local equals:Int = line.Find("=")
        If equals <= 0 Then Continue

        Local key:String = Lower(Trim(line[..equals]))
        Local value:String = Trim(line[equals + 1..])

        Select key
            Case "codec"
                Local codec:Int = Int(value)
                If codec >= 0 And codec < CountGadgetItems(codecCombo) Then SelectGadgetItem(codecCombo, codec)
            Case "quality"
                SetGadgetText(qualityField, value)
            Case "luma"
                Local luma:Int = Int(value)
                If luma >= 0 And luma < CountGadgetItems(lumaCombo) Then SelectGadgetItem(lumaCombo, luma)
            Case "chroma"
                Local chroma:Int = Int(value)
                If chroma >= 0 And chroma < CountGadgetItems(chromaCombo) Then SelectGadgetItem(chromaCombo, chroma)
            Case "levels"
                Local levels:Int = Int(value)
                If levels >= 0 And levels < CountGadgetItems(levelsCombo) Then SelectGadgetItem(levelsCombo, levels)
            Case "output"
                If value <> "" Then SetGadgetText(outputFolderField, value)
            Case "autoopen"
                SetButtonState(autoOpenFolderCheck, Int(value) <> 0)
            Case "recursive"
                SetButtonState(recursiveFolderCheck, Int(value) <> 0)
            Case "darktheme"
                SetButtonState(darkThemeCheck, Int(value) <> 0)
        End Select
    Wend

    CloseStream stream
    SetButtonState(rememberSettingsCheck, True)
End Function

Function IsSupportedQueueFile:Int(path:String)
    Local ext:String = Lower(ExtractExt(path))
    Return ext = "png" Or ext = "jpg" Or ext = "jpeg" Or ext = "bmp" Or ..
        ext = "tif" Or ext = "tiff" Or ext = "webp" Or ext = "jxl" Or ..
        ext = "avif" Or ext = "heic" Or ext = "bz3" Or ext = "dat"
End Function

Function AddFolderRecursive(folder:String, recursive:Int)
    If folder = "" Or FileType(folder) <> 2 Then Return

    Local entries:String[] = LoadDir(folder)

    For Local name:String = EachIn entries
        If name = "." Or name = ".." Then Continue

        Local path:String = JoinPath(folder, name)
        Local kind:Int = FileType(path)

        If kind = 1 And IsSupportedQueueFile(path) Then
            Local before:Int = CountGadgetItems(fileList)
            AddFileToQueue(path)
            If CountGadgetItems(fileList) > before Then folderFilesAdded :+ 1
        Else If kind = 2 And recursive Then
            AddFolderRecursive(path, recursive)
        End If
    Next
End Function

Function AddFolderToQueue(folder:String)
    If folder = "" Or FileType(folder) <> 2 Then Return

    folderFilesAdded = 0
    Local recursive:Int = recursiveFolderCheck And ButtonState(recursiveFolderCheck) <> 0
    AddFolderRecursive(folder, recursive)

    SetStatus("Folder added: " + folderFilesAdded + " file(s).")
    LogMessage("Add Folder: " + folder + " (" + folderFilesAdded + " files, recursive=" + recursive + ")")
End Function

Function ChooseFolderInput()
    Local folder:String = RequestDir("Add images from a folder", AppDir)
    If folder <> "" Then AddFolderToQueue(folder)
End Function

Function OpenOutputFolder()
    Local folder:String = DefaultOutputFolder()
    If FileType(folder) <> 2 Then
        Notify "The output folder does not exist.", True
        Return
    End If
?Win32
    System_ "explorer " + QuoteArg(folder.Replace("/", Chr(92)))
?MacOS
    System_ "open " + QuoteArg(folder)
?Linux
    System_ "xdg-open " + QuoteArg(folder)
?
    LogMessage("Output folder opened: " + folder)
End Function

Function SilentSystem:Int(command:String)
?Win32
    ' Run console tools through Windows Script Host with a hidden window.
    ' The third Run argument waits for completion, so return codes remain available.
    Local scriptPath:String = AppDir + "/wis2_silent_" + MilliSecs() + ".vbs"
    Local stream:TStream = WriteFile(scriptPath)
    If stream = Null Then Return System_(command)

    Local vbsCommand:String = command.Replace(Chr(34), Chr(34) + Chr(34))
    WriteLine stream, "Set shell = CreateObject(" + Chr(34) + "WScript.Shell" + Chr(34) + ")"
    WriteLine stream, "result = shell.Run(" + Chr(34) + vbsCommand + Chr(34) + ", 0, True)"
    WriteLine stream, "WScript.Quit result"
    CloseStream stream

    Local result:Int = System_("wscript.exe //B //NoLogo " + QuoteArg(scriptPath))
    If FileType(scriptPath) = 1 Then DeleteFile(scriptPath)
    Return result
?Not Win32
    Return System_(command)
?
End Function

Function QuoteArg:String(value:String)
	Return Chr(34) + value.Replace(Chr(34), "") + Chr(34)
End Function

Function AppFolder:String()
	Local path:String = AppDir
	If path.EndsWith("/") Or path.EndsWith(Chr(92)) Then Return path
	Return path + "/"
End Function

Function ToolPath:String(name:String)
	Local suffix:String = ""
?Win32
	suffix = ".exe"
?
	Local path:String = AppFolder() + name + suffix
	If FileType(path) = 1 Then Return path

	' Os codecs JXL/AVIF podem estar na subpasta distribuída com a GUI.
	Local codecPath:String = AppFolder() + "codecs_jxl_avif/" + name + suffix
	If FileType(codecPath) = 1 Then Return codecPath
	Return path
End Function

Function Bzip3ToolPath:String()
	Local path:String = ToolPath("bzip3")
	If FileType(path) = 1 Then Return path
	Return ToolPath("bz3")
End Function

Function SetStatus(message:String)
	SetGadgetText(statusLabel, message)
	If statusDetailLabel Then SetGadgetText(statusDetailLabel, message)
End Function

Function SetProgress(value:Int)
	' The progress bar is reserved exclusively for batch operations.
	' Single-file Compress/Extract actions must never alter it.
	If Not batchRunning Then Return
	If value < 0 Then value = 0
	If value > 1000 Then value = 1000
	If progressBar Then UpdateProgBar(progressBar, Float(value) / 1000.0)
	If progressPercentLabel Then SetGadgetText(progressPercentLabel, "Batch: " + (value / 10) + "%")
End Function

Function ValidateQuality:Int()
	If IsLosslessCodec(SelectedCodec()) Then Return 100
	Local quality:Int = Int(Trim(GadgetText(qualityField)))
	If quality < 0 Or quality > 100 Then
		Notify "Quality must be between 0 and 100.", True
		Return -1
	End If
	Return quality
End Function

Function SelectedCodec:Int()
	Return SelectedGadgetItem(codecCombo)
End Function

Function SelectedLumaDiv:Int()
	Return SelectedGadgetItem(lumaCombo) + 1
End Function

Function SelectedChromaDiv:Int()
	Return SelectedGadgetItem(chromaCombo) + 1
End Function

Function SelectedNHWLevels:Int()
	Return SelectedGadgetItem(levelsCombo) + 1
End Function

Function IsWIS2Codec:Int(codec:Int)
	Return (codec >= CODEC_HAAR And codec <= CODEC_LOSSLESS) Or codec = CODEC_WIS2_NHW Or codec = CODEC_WIS2_SELECTOR
End Function

Function IsLosslessCodec:Int(codec:Int)
	Return codec = CODEC_LOSSLESS Or codec = CODEC_WEBP_LOSSLESS Or codec = CODEC_JXL_LOSSLESS Or codec = CODEC_AVIF_LOSSLESS
End Function

Function CodecExtension:String(codec:Int)
	Select codec
		Case CODEC_HAAR, CODEC_DCT, CODEC_DTT, CODEC_HYBRID, CODEC_ADAPTIVE, CODEC_LOSSLESS, CODEC_WIS2_NHW, CODEC_WIS2_SELECTOR
			Return "bz3"
		Case CODEC_WEBP, CODEC_WEBP_LOSSLESS
			Return "webp"
		Case CODEC_JXL, CODEC_JXL_LOSSLESS
			Return "jxl"
		Case CODEC_AVIF, CODEC_AVIF_LOSSLESS
			Return "avif"
		Case CODEC_PNG
			Return "png"
		Case CODEC_JPEG
			Return "jpg"
	End Select
	Return "png"
End Function

Function DecodedOutputExtension:String(codec:Int)
	' Quando a entrada é WIS2, os três primeiros itens representam modos de
	' codificação, não formatos de imagem. Nesse caso PNG é o padrão.
	If IsWIS2Codec(codec) Then Return "png"
	Return CodecExtension(codec)
End Function

Function EnsureExtension:String(path:String, extension:String)
	If Lower(ExtractExt(path)) = Lower(extension) Then Return path
	If ExtractExt(path) = "" Then Return path + "." + extension
	Return StripExt(path) + "." + extension
End Function

Function CheckTool:Int(path:String, displayName:String)
	If FileType(path) = 1 Then Return True
	Notify "Could not find " + displayName + " em:" + Chr(10) + path, True
	Return False
End Function

Function FormatBytes:String(size:Long)
	If size < 1024 Then Return size + " B"
	If size < 1024 * 1024 Then Return String(Int(Double(size) / 1024.0 * 10.0) / 10.0) + " KB"
	If size < 1024 * 1024 * 1024 Then Return String(Int(Double(size) / (1024.0 * 1024.0) * 10.0) / 10.0) + " MB"
	Return String(Int(Double(size) / (1024.0 * 1024.0 * 1024.0) * 10.0) / 10.0) + " GB"
End Function
Function FormatDuration:String(milliseconds:Long)
	If milliseconds < 0 Then milliseconds = 0
	Local totalSeconds:Long = milliseconds / 1000
	Local hours:Long = totalSeconds / 3600
	Local minutes:Long = (totalSeconds Mod 3600) / 60
	Local seconds:Long = totalSeconds Mod 60
	If hours > 0 Then Return hours + "h " + minutes + "m " + seconds + "s"
	If minutes > 0 Then Return minutes + "m " + seconds + "s"
	Return seconds + "s"
End Function


Function QueuePath:String(index:Int)
    If index < 0 Or index >= queuePathCount Then Return ""
    Return queuePaths[index]
End Function

Function QueueCount:Int()
    Return queuePathCount
End Function

Function AppendQueuePath(path:String)
    If queuePathCount >= queuePaths.Length Then
        RuntimeError "Queue limit reached"
    End If

    queuePaths[queuePathCount] = path
    queuePathCount :+ 1
End Function

Function RemoveQueuePath(index:Int)
    If index < 0 Or index >= queuePathCount Then Return

    For Local i:Int = index Until queuePathCount - 1
        queuePaths[i] = queuePaths[i + 1]
    Next

    queuePathCount :- 1
    queuePaths[queuePathCount] = ""
End Function

Function QueueContains:Int(path:String)
    Local target:String = Lower(path)

    For Local i:Int = 0 Until queuePathCount
        If Lower(queuePaths[i]) = target Then Return True
    Next

    Return False
End Function

Function DefaultOutputPath:String(inputPath:String)
    If inputPath = "" Then Return ""

    Local folder:String = Trim(GadgetText(outputFolderField))
    If folder = "" Or FileType(folder) <> 2 Then folder = ExtractDir(inputPath)
    If folder = "" Or FileType(folder) <> 2 Then folder = AppDir

    Local inputExt:String = Lower(ExtractExt(inputPath))
    Local outputName:String
    If inputExt = "bz3" Or inputExt = "dat" Then
        outputName = StripExt(StripDir(inputPath)) + "_rebuilded." + DecodedOutputExtension(SelectedCodec())
    Else
        outputName = StripExt(StripDir(inputPath)) + "." + CodecExtension(SelectedCodec())
    End If

    Return JoinPath(folder, outputName)
End Function

Function SetSelectedPath(path:String)
    path = Trim(path)
    If path = "" Then Return
    If FileType(path) <> 1 Then
        SetStatus("Ficheiro inválido: " + path)
        LogMessage("Invalid input path: " + path)
        Return
    End If

    SetGadgetText(inputField, path)

    Local inputExt:String = Lower(ExtractExt(path))
    Local outputPath:String
    If inputExt = "bz3" Or inputExt = "dat" Then
        outputPath = StripExt(path) + "_rebuilded." + DecodedOutputExtension(SelectedCodec())
    Else
        outputPath = StripExt(path) + "." + CodecExtension(SelectedCodec())
    End If
    SetGadgetText(outputField, outputPath)

    SetStatus("Input: " + path)
    LogMessage("Input path: " + path)
    LogMessage("Output path: " + outputPath)
    UpdateSelectedImageInfo(path)
End Function

Function ChooseSelectedInput()
    Local selected:String = RequestFile("Select input file", ..
        "Images and WIS2:png,jpg,jpeg,bmp,tga,tif,tiff,webp,jxl,avif,heic,bz3,dat;All files:*", False)
    selected = Trim(selected)
    If selected = "" Then Return

    SetSelectedPath(selected)
    If Not QueueContains(selected) Then AddFileToQueue(selected)
    SetProgress(0)
End Function

Function ChooseSelectedOutput()
    Local current:String = Trim(GadgetText(outputField))
    Local selected:String = RequestFile("Select output file", "All files:*", True, current)
    selected = Trim(selected)
    If selected <> "" Then
        SetGadgetText(outputField, selected)
        SetStatus("Output: " + selected)
        LogMessage("Output path: " + selected)
    End If
End Function

Function UpdateQueueStatus()
	Local count:Int = queuePathCount
	Local total:Long = 0
	For Local i:Int = 0 Until count
		Local path:String = QueuePath(i)
		If FileType(path) = 1 Then total :+ FileSize(path)
	Next
	SetGadgetText(queueTitleLabel, "File Queue  (" + count + " file(s)  |  " + FormatBytes(total) + ")")
	If count = 0 Then
		DisableGadget(removeButton)
		DisableGadget(clearButton)
	Else
		EnableGadget(removeButton)
		EnableGadget(clearButton)
	End If
End Function

Function FormatName:String(path:String)
    Local ext:String = Upper(ExtractExt(path))
    If ext = "" Then Return "Unknown"
    Return ext
End Function

Function EstimateOutputSize:Long(inputBytes:Long, codec:Int, quality:Int)
    If inputBytes <= 0 Then Return 0

    Local factor:Double = 0.65

    Select codec
        Case CODEC_HAAR
            factor = 0.36 + (Double(quality) / 100.0) * 0.34
        Case CODEC_DCT
            factor = 0.20 + (Double(quality) / 100.0) * 0.36
        Case CODEC_DTT
            factor = 0.22 + (Double(quality) / 100.0) * 0.38
        Case CODEC_HYBRID
            factor = 0.18 + (Double(quality) / 100.0) * 0.35
        Case CODEC_ADAPTIVE
            factor = 0.17 + (Double(quality) / 100.0) * 0.34
        Case CODEC_LOSSLESS
            factor = 0.80
        Case CODEC_WIS2_NHW
            factor = 0.19 + (Double(quality) / 100.0) * 0.36
        Case CODEC_WIS2_SELECTOR
            factor = 0.17 + (Double(quality) / 100.0) * 0.34
        Case CODEC_WEBP
            factor = 0.16 + (Double(quality) / 100.0) * 0.32
        Case CODEC_JXL
            factor = 0.14 + (Double(quality) / 100.0) * 0.30
        Case CODEC_AVIF
            factor = 0.12 + (Double(quality) / 100.0) * 0.29
        Case CODEC_PNG
            factor = 0.72
        Case CODEC_JPEG
            factor = 0.14 + (Double(quality) / 100.0) * 0.34
    End Select

    Return Long(Double(inputBytes) * factor)
End Function

Function ClearPreview()
    previewPixmap = Null
    previewThumbnail = Null
    previewThumbCanvasW = 0
    previewThumbCanvasH = 0
    previewPath = ""
    If previewCanvas Then RedrawGadget(previewCanvas)
End Function

Function UpdateSelectedImageInfo(path:String)
    If Not imageInfoLabel Then Return

    If path = "" Or FileType(path) <> 1 Then
        SetGadgetText(imageInfoLabel, "No image selected")
        SetGadgetText(estimateLabel, "Estimated output: -")
        ClearPreview()
        Return
    End If

    Local size:Long = FileSize(path)
    Local ext:String = FormatName(path)
    Local info:String = "File: " + StripDir(path) + Chr(10) + ..
        "Format: " + ext + Chr(10) + ..
        "Size: " + FormatBytes(size)

    previewPixmap = LoadPixmap(path)
    previewThumbnail = Null
    previewThumbCanvasW = 0
    previewThumbCanvasH = 0
    previewPath = path

    If previewPixmap Then
        info :+ Chr(10) + "Resolution: " + PixmapWidth(previewPixmap) + " x " + PixmapHeight(previewPixmap)
        info :+ Chr(10) + "Pixel format: RGB/RGBA pixmap"
    Else
        info :+ Chr(10) + "Resolution: unavailable until decoded"
    End If

    SetGadgetText(imageInfoLabel, info)

    Local quality:Int = Int(Trim(GadgetText(qualityField)))
    If quality < 1 Or quality > 100 Then quality = 80
    Local estimated:Long = EstimateOutputSize(size, SelectedCodec(), quality)
    SetGadgetText(estimateLabel, "Selected image estimate: " + Chr(126) + FormatBytes(estimated) + " " + Chr(40) + "content dependent" + Chr(41))

    If previewCanvas Then RedrawGadget(previewCanvas)
End Function

Function DeleteBatchPreviewTemp()
    If batchPreviewTempPath <> "" And FileType(batchPreviewTempPath) = 1 Then
        DeleteFile(batchPreviewTempPath)
    End If
    batchPreviewTempPath = ""
End Function

Function ShowBatchPreview(path:String, extractMode:Int = False)
    ' Display the file currently being processed. Native pixmap formats are
    ' loaded directly. WebP, JXL, AVIF and HEIC use the bundled decoders.
    DeleteBatchPreviewTemp()

    If path = "" Or FileType(path) <> 1 Then
        ClearPreview()
        Return
    End If

    Local pix:TPixmap = LoadPixmap(path)
    Local loadedPath:String = path

    If pix = Null And Not extractMode Then
        Local ext:String = Lower(ExtractExt(path))
        If ext = "webp" Or ext = "jxl" Or ext = "avif" Or ext = "heic" Then
            batchPreviewTempPath = AppFolder() + "wis2_batch_preview.png"
            If FileType(batchPreviewTempPath) = 1 Then DeleteFile(batchPreviewTempPath)
            If DecodeExternalToPNG(path, batchPreviewTempPath) Then
                pix = LoadPixmap(batchPreviewTempPath)
                loadedPath = batchPreviewTempPath
            End If
        End If
    End If

    ' During Extract All the current input is normally a BZ3/DAT archive,
    ' not a directly displayable image. Keep the last decoded thumbnail
    ' visible while the next archive is being decoded. As soon as DecodeWIS2
    ' creates the PNG for the current item, this function is called again and
    ' replaces the preview with the new image.
    If pix Or Not extractMode Then
        previewPixmap = pix
        previewThumbnail = Null
        previewThumbCanvasW = 0
        previewThumbCanvasH = 0
        previewPath = loadedPath
    End If

    If imageInfoLabel Then
        Local info:String = "Current batch file: " + StripDir(path) + Chr(10) + ..
            "Format: " + FormatName(path) + Chr(10) + ..
            "Size: " + FormatBytes(FileSize(path))
        If pix Then
            info :+ Chr(10) + "Resolution: " + PixmapWidth(pix) + " x " + PixmapHeight(pix)
        Else If extractMode Then
            If previewPixmap Then
                info :+ Chr(10) + "Preview: previous image kept while decoding current file"
            Else
                info :+ Chr(10) + "Preview: decoding current file..."
            End If
        Else
            info :+ Chr(10) + "Preview: unavailable for this format"
        End If
        SetGadgetText(imageInfoLabel, info)
    End If

    If previewCanvas Then
        RedrawGadget(previewCanvas)
        PaintPreview()
        If batchRunning Then ForceBatchPreviewRefresh(80)
    End If
End Function

Function RebuildPreviewThumbnail()
    previewThumbnail = Null
    previewThumbCanvasW = 0
    previewThumbCanvasH = 0

    If Not previewCanvas Or Not previewPixmap Then Return

    Local cw:Int = GadgetWidth(previewCanvas)
    Local ch:Int = GadgetHeight(previewCanvas)
    Local pw:Int = PixmapWidth(previewPixmap)
    Local ph:Int = PixmapHeight(previewPixmap)
    If cw <= 0 Or ch <= 0 Or pw <= 0 Or ph <= 0 Then Return

    ' Leave a small border around the thumbnail.
    Local availableW:Int = cw - 8
    Local availableH:Int = ch - 8
    If availableW < 1 Then availableW = 1
    If availableH < 1 Then availableH = 1

    Local scaleX:Double = Double(availableW) / Double(pw)
    Local scaleY:Double = Double(availableH) / Double(ph)
    Local scale:Double = scaleX
    If scaleY < scale Then scale = scaleY

    ' Do not enlarge small images; only shrink images that do not fit.
    If scale > 1.0 Then scale = 1.0

    Local thumbW:Int = Int(Double(pw) * scale + 0.5)
    Local thumbH:Int = Int(Double(ph) * scale + 0.5)
    If thumbW < 1 Then thumbW = 1
    If thumbH < 1 Then thumbH = 1

    If thumbW = pw And thumbH = ph Then
        previewThumbnail = previewPixmap
    Else
        previewThumbnail = ResizePixmap(previewPixmap, thumbW, thumbH)
    End If

    previewThumbCanvasW = cw
    previewThumbCanvasH = ch
End Function

Function PaintPreview()
    If Not previewCanvas Then Return

    SetGraphics CanvasGraphics(previewCanvas)
    SetClsColor(32, 35, 39)
    Cls

    If previewPixmap Then
        Local cw:Int = GadgetWidth(previewCanvas)
        Local ch:Int = GadgetHeight(previewCanvas)

        If Not previewThumbnail Or previewThumbCanvasW <> cw Or previewThumbCanvasH <> ch Then
            RebuildPreviewThumbnail()
        End If

        If previewThumbnail Then
            Local tw:Int = PixmapWidth(previewThumbnail)
            Local th:Int = PixmapHeight(previewThumbnail)
            Local drawX:Int = (cw - tw) / 2
            Local drawY:Int = (ch - th) / 2
            DrawPixmap(previewThumbnail, drawX, drawY)
        End If
    Else
        SetColor(210, 210, 210)
        DrawText("Preview unavailable", 12, 12)
    End If

    Flip 0
End Function

Function SelectQueuedFile(index:Int)
	If index < 0 Or index >= CountGadgetItems(fileList) Then Return
	Local path:String = QueuePath(index)
	If path = "" Then
		path = Trim(GadgetText(inputField))
		If path = "" Then Return
	End If
	SetSelectedPath(path)
End Function

Function AddFileToQueue(path:String)
	If path = "" Or FileType(path) <> 1 Then Return
	If QueueContains(path) Then
		SetSelectedPath(path)
		SetStatus("The file is already in the queue: " + path)
		Return
	End If
	Local ext:String = Upper(ExtractExt(path))
	If ext = "" Then ext = "FILE"
	Local display:String = StripDir(path) + "  |  " + ext + "  |  " + FormatBytes(FileSize(path)) + "  |  Ready"
	AppendQueuePath(path)
	AddGadgetItem(fileList, display)
	Local newIndex:Int = queuePathCount - 1
	SelectGadgetItem(fileList, newIndex)
	SetSelectedPath(path)
	UpdateQueueStatus()
	LogMessage("Added: " + path)
End Function

Function RemoveSelectedQueueFile()
	Local index:Int = SelectedGadgetItem(fileList)
	If index < 0 Then Return
	RemoveGadgetItem(fileList, index)
	RemoveQueuePath(index)
	If CountGadgetItems(fileList) > 0 Then
		If index >= CountGadgetItems(fileList) Then index = CountGadgetItems(fileList) - 1
		SelectGadgetItem(fileList, index)
		SelectQueuedFile(index)
	Else
		SetGadgetText(inputField, "")
		SetGadgetText(outputField, "")
		UpdateSelectedImageInfo("")
	End If
	UpdateQueueStatus()
End Function

Function ClearQueue()
	ClearGadgetItems(fileList)
	For Local i:Int = 0 Until queuePathCount
		queuePaths[i] = ""
	Next
	queuePathCount = 0
	SetGadgetText(inputField, "")
	SetGadgetText(outputField, "")
	UpdateSelectedImageInfo("")
	SetProgress(0)
	SetStatus("Lista limpa.")
	LogMessage("Queue cleared")
	UpdateQueueStatus()
End Function

Function ShowAbout()
	Notify "WIS2 Studio" + Chr(10) + Chr(10) + ..
		"Release 2026 - NHW Edition" + Chr(10) + ..
		"Includes automatic WIS2/NHW detection and CDF 5/3 codec support." + Chr(10) + Chr(10) + ..
		"Created by Antonio Campanico (Tony Camp)" + Chr(10) + Chr(10) + ..
		"WIS2 Studio is completely free to use for personal and commercial projects." + Chr(10) + Chr(10) + ..
		"If you would like to support future development, tips are always welcome, but never required." + Chr(10) + Chr(10) + ..
		"MBWay:" + Chr(10) + ..
		"+351 968 100 493" + Chr(10) + Chr(10) + ..
		"Thank you for supporting independent software development.", False
End Function

Function DefaultOutputFolder:String()
	Local folder:String = Trim(GadgetText(outputFolderField))
	If folder <> "" And FileType(folder) = 2 Then Return folder
	Local inputPath:String = Trim(GadgetText(inputField))
	If inputPath <> "" Then Return ExtractDir(inputPath)
	Return AppDir
End Function

Function JoinPath:String(folder:String, name:String)
	If folder.EndsWith("/") Or folder.EndsWith(Chr(92)) Then Return folder + name
	Return folder + "/" + name
End Function

Function ChooseOutputFolder()
	Local selected:String = RequestDir("Select output folder", DefaultOutputFolder())
	If selected <> "" Then SetGadgetText(outputFolderField, selected)
End Function

Function QueueOutputPath:String(inputPath:String, extracting:Int)
	' By default, batch output is written beside each input file.
	' A folder explicitly selected by the user overrides this behaviour.
	Local folder:String = Trim(GadgetText(outputFolderField))
	If folder = "" Or folder = AppDir Or FileType(folder) <> 2 Then
		folder = ExtractDir(inputPath)
	End If
	If folder = "" Or FileType(folder) <> 2 Then folder = AppDir

	Local baseName:String = StripExt(StripDir(inputPath))
	If extracting Then
		Return JoinPath(folder, baseName + "_rebuilded." + DecodedOutputExtension(SelectedCodec()))
	End If
	Return JoinPath(folder, baseName + "." + CodecExtension(SelectedCodec()))
End Function

Function ResetStatistics()
	SetGadgetText(statsOriginalLabel, "Original total: 0 B")
	SetGadgetText(statsOutputLabel, "Compressed total: 0 B")
	SetGadgetText(statsRatioLabel, "Ratio: -")
	SetGadgetText(statsSavingsLabel, "Space saved: -")
	SetGadgetText(statsTimeLabel, "Elapsed: 0s")
	SetGadgetText(statsEtaLabel, "Estimated remaining: --")
	SetGadgetText(statsProcessedLabel, "Processed: 0 / 0")
End Function

Function UpdateStatistics(originalTotal:Long, outputBytes:Long, elapsedMs:Long, processed:Int, total:Int, attempted:Int)
	SetGadgetText(statsOriginalLabel, "Original total: " + FormatBytes(originalTotal))
	SetGadgetText(statsOutputLabel, "Compressed total: " + FormatBytes(outputBytes))
	If outputBytes > 0 Then
		Local ratio:Double = Double(originalTotal) / Double(outputBytes)
		SetGadgetText(statsRatioLabel, "Ratio: " + String(Int(ratio * 100.0) / 100.0) + ":1")
	Else
		SetGadgetText(statsRatioLabel, "Ratio: -")
	End If
	If originalTotal > 0 And outputBytes >= 0 Then
		Local savedPercent:Double = (1.0 - (Double(outputBytes) / Double(originalTotal))) * 100.0
		SetGadgetText(statsSavingsLabel, "Space saved: " + String(Int(savedPercent * 10.0) / 10.0) + "%")
	Else
		SetGadgetText(statsSavingsLabel, "Space saved: -")
	End If
	SetGadgetText(statsTimeLabel, "Elapsed: " + FormatDuration(elapsedMs))
	If attempted > 0 And attempted < total Then
		Local etaMs:Long = Long((Double(elapsedMs) / Double(attempted)) * Double(total - attempted))
		SetGadgetText(statsEtaLabel, "Estimated remaining: " + FormatDuration(etaMs))
	ElseIf attempted >= total Then
		SetGadgetText(statsEtaLabel, "Estimated remaining: 0s")
	Else
		SetGadgetText(statsEtaLabel, "Estimated remaining: calculating...")
	End If
	SetGadgetText(statsProcessedLabel, "Processed: " + processed + " / " + total)

    If estimateLabel Then
        If processed > 0 And outputBytes > 0 And total > 0 Then
            Local averageOutputBytes:Double
            Local estimatedBatchBytes:Long

            averageOutputBytes = Double(outputBytes) / Double(processed)
            estimatedBatchBytes = Long(averageOutputBytes * Double(total))
            SetGadgetText(estimateLabel, "Estimated batch output: " + Chr(126) + FormatBytes(estimatedBatchBytes) + "  |  Average: " + FormatBytes(Long(averageOutputBytes)) + " / file")
        ElseIf total > 0 Then
            SetGadgetText(estimateLabel, "Estimated batch output: calculating...")
        End If
    End If
End Function

Function BatchProcess(extractMode:Int)
	Local total:Int = CountGadgetItems(fileList)
	If total = 0 Then
		Notify "Add at least one file to the queue.", True
		Return
	End If

	Local quality:Int = ValidateQuality()
	If quality < 0 Then Return

	DisableGadget(batchCompressButton)
	DisableGadget(batchExtractButton)
	DisableGadget(convertButton)
	DisableGadget(extractButton)
	EnableGadget(stopBatchButton)
	SetGadgetText(stopBatchButton, "STOP AFTER CURRENT")
	stopBatchRequested = False
	batchRunning = True
	If progressPercentLabel Then SetGadgetText(progressPercentLabel, "Batch: 0%")
	If progressBar Then UpdateProgBar(progressBar, 0.0)

	Local originalTotal:Long = 0
	For Local sizeIndex:Int = 0 Until total
		Local sizePath:String = QueuePath(sizeIndex)
		If FileType(sizePath) = 1 Then originalTotal :+ FileSize(sizePath)
	Next
	Local outputBytes:Long = 0
	Local processed:Int = 0
	Local failures:Int = 0
	Local attempted:Int = 0
	Local started:Int = MilliSecs()
	ResetStatistics()
	UpdateStatistics(originalTotal, 0, 0, 0, total, 0)
	SetProgress(0)

	For Local i:Int = 0 Until total
		' Handle a STOP click that may have been queued while the previous
		' encoder/decoder process was running.
		PumpBatchEvents()
		If stopBatchRequested Then Exit

		Local path:String = QueuePath(i)
		Local ext:String = Lower(ExtractExt(path))
		Local compatible:Int = (extractMode And (ext = "bz3" Or ext = "dat")) Or ..
			(Not extractMode And ext <> "bz3" And ext <> "dat")

		If Not compatible Then
			failures :+ 1
			attempted :+ 1
			SetProgress(Int(Double(attempted) / Double(total) * 1000.0))
			UpdateStatistics(originalTotal, outputBytes, MilliSecs() - started, processed, total, attempted)
			PumpBatchEvents()
			If stopBatchRequested Then Exit
			Continue
		End If

		SelectGadgetItem(fileList, i)
		SetGadgetText(inputField, path)
		Local outputPath:String = QueueOutputPath(path, extractMode)
		SetGadgetText(outputField, outputPath)

		' Keep the Preview panel synchronized with the current batch item.
		ShowBatchPreview(path, extractMode)
		PumpBatchEvents()
		SetStatus("Processing " + (i + 1) + " of " + total + ": " + StripDir(path))

		If extractMode Then
			ExtractAction()
		Else
			CompressAction()
		End If

		If lastOperationSuccess And FileType(lastOutputPath) = 1 Then
			outputBytes :+ FileSize(lastOutputPath)
			processed :+ 1
			If extractMode Then
				ShowBatchPreview(lastOutputPath, False)
				ForceBatchPreviewRefresh(350)
			End If
		Else
			failures :+ 1
		End If
		attempted :+ 1
		SetProgress(Int(Double(attempted) / Double(total) * 1000.0))
		UpdateStatistics(originalTotal, outputBytes, MilliSecs() - started, processed, total, attempted)
		AddHistory(path, outputPath, lastOperationSuccess, MilliSecs() - started)

		' The stop request is deliberately checked only after the current file
		' has completely finished. No next file will be started.
		PumpBatchEvents()
		If stopBatchRequested Then Exit
	Next

	If Not stopBatchRequested Then
		SetProgress(1000)
		UpdateStatistics(originalTotal, outputBytes, MilliSecs() - started, processed, total, total)
	Else
		SetProgress(Int(Double(attempted) / Double(total) * 1000.0))
		UpdateStatistics(originalTotal, outputBytes, MilliSecs() - started, processed, total, attempted)
	End If
	EnableGadget(batchCompressButton)
	EnableGadget(batchExtractButton)
	EnableGadget(convertButton)
	EnableGadget(extractButton)
	DisableGadget(stopBatchButton)
	SetGadgetText(stopBatchButton, "STOP AFTER CURRENT")
	batchRunning = False
	If stopBatchRequested Then
		SetStatus("Batch stopped after current file: " + attempted + " of " + total + " attempted; " + processed + " succeeded.")
		LogMessage("Batch stopped after current file: " + attempted + "/" + total + " attempted")
	Else
		SetStatus("Batch complete: " + processed + " succeeded, " + failures + " skipped/failed.")
		LogMessage("Batch finished: " + processed + " success, " + failures + " skipped/error")
	End If
	DeleteBatchPreviewTemp()
	SaveSettings()
	If ButtonState(autoOpenFolderCheck) <> 0 And processed > 0 Then OpenOutputFolder()
End Function

Function ChooseInput()
    Local selected:String = RequestFile("Select file", ..
        "Suportados:png,jpg,jpeg,bmp,tif,tiff,webp,jxl,avif,heic,bz3,dat;Imagens:png,jpg,jpeg,bmp,tif,tiff,webp,jxl,avif,heic;WIS2:bz3,dat;Todos:*", False)
    selected = Trim(selected)
    If selected = "" Then Return

    SetSelectedPath(selected)
    If Not QueueContains(selected) Then AddFileToQueue(selected)
    SetProgress(0)
End Function

Function ChooseOutput()
	Local inputPath:String = Trim(GadgetText(inputField))
	Local inputExt:String = Lower(ExtractExt(inputPath))
	Local defaultExt:String

	If inputExt = "bz3" Or inputExt = "dat" Then
		defaultExt = DecodedOutputExtension(SelectedCodec())
	Else
		defaultExt = CodecExtension(SelectedCodec())
	End If

	Local selected:String = RequestFile("Guardar resultado", "Ficheiro:" + defaultExt, True, GadgetText(outputField))
	If selected <> "" Then SetGadgetText(outputField, EnsureExtension(selected, defaultExt))
End Function

Function UpdateCodecControls()
	Local codec:Int = SelectedCodec()
	Local isLossless:Int = IsLosslessCodec(codec)
	If isLossless Then
		SetGadgetText(qualityField, "100")
		DisableGadget(qualityField)
		DisableGadget(lumaCombo)
		DisableGadget(chromaCombo)
        DisableGadget(levelsCombo)
		SetStatus("Lossless mode: exact reconstruction")
	Else
		EnableGadget(qualityField)
		If codec = CODEC_WIS2_NHW Then
			EnableGadget(lumaCombo)
			EnableGadget(chromaCombo)
            EnableGadget(levelsCombo)
			SetStatus("WIS2 NHW: Nested Haar Int32, alpha preservado")
		ElseIf codec = CODEC_WIS2_SELECTOR Then
			EnableGadget(lumaCombo)
			EnableGadget(chromaCombo)
            EnableGadget(levelsCombo)
			SetStatus("WIS2 Selector: DCT / Haar por bloco, nivel Haar 1 a 7")
		Else
			EnableGadget(lumaCombo)
			EnableGadget(chromaCombo)
            DisableGadget(levelsCombo)
		End If
	End If
End Function

Function UpdateOutputForCodec()
	Local inputPath:String = Trim(GadgetText(inputField))
	If inputPath = "" Then Return

	Local inputExt:String = Lower(ExtractExt(inputPath))
	If inputExt = "bz3" Or inputExt = "dat" Then
		Local decodedExt:String = DecodedOutputExtension(SelectedCodec())
		SetGadgetText(outputField, StripExt(inputPath) + "_rebuilded." + decodedExt)
	Else
		SetGadgetText(outputField, StripExt(inputPath) + "." + CodecExtension(SelectedCodec()))
	End If
End Function

Function SaveInternal:Int(inputPath:String, outputPath:String, quality:Int)
	Local pix:TPixmap = LoadPixmap(inputPath)
	If pix = Null Then Return False
	Local ext:String = Lower(ExtractExt(outputPath))
	If ext = "png" Then
		SavePixmapPNG(pix, outputPath)
	Else If ext = "jpg" Or ext = "jpeg" Then
		SavePixmapJPeg(pix, outputPath, quality)
	Else
		Return False
	End If
	Return FileType(outputPath) = 1
End Function

Function DecodeExternalToPNG:Int(inputPath:String, outputPng:String)
	Local ext:String = Lower(ExtractExt(inputPath))
	Local tool:String
	Local command:String
	Select ext
		Case "webp"
			tool = ToolPath("dwebp")
			If Not CheckTool(tool, "dwebp.exe") Then Return False
			command = QuoteArg(tool) + " " + QuoteArg(inputPath) + " -o " + QuoteArg(outputPng)
		Case "jxl"
			tool = ToolPath("djxl")
			If Not CheckTool(tool, "djxl.exe") Then Return False
			command = QuoteArg(tool) + " " + QuoteArg(inputPath) + " " + QuoteArg(outputPng)
		Case "avif", "heic"
			tool = ToolPath("avifdec")
			If Not CheckTool(tool, "avifdec.exe") Then Return False
			command = QuoteArg(tool) + " " + QuoteArg(inputPath) + " " + QuoteArg(outputPng)
		Default
			Return SaveInternal(inputPath, outputPng, 100)
	End Select
	If FileType(outputPng) = 1 Then DeleteFile(outputPng)
	Local result:Int = SilentSystem(command)
	Return result = 0 And FileType(outputPng) = 1
End Function

Function PreparePNG:String(inputPath:String, basePath:String)
	If Lower(ExtractExt(inputPath)) = "png" Then Return inputPath
	Local tempPng:String = basePath + "_gui_input.png"
	If FileType(tempPng) = 1 Then DeleteFile(tempPng)
	If DecodeExternalToPNG(inputPath, tempPng) Then Return tempPng
	Return ""
End Function

Function EncodeFromPNG:Int(inputPng:String, outputPath:String, quality:Int, codec:Int)
	Local ext:String = Lower(ExtractExt(outputPath))
	Local tool:String
	Local command:String
	Select ext
		Case "png", "jpg", "jpeg"
			Return SaveInternal(inputPng, outputPath, quality)
		Case "webp"
			tool = ToolPath("cwebp")
			If Not CheckTool(tool, "cwebp.exe") Then Return False
			If codec = CODEC_WEBP_LOSSLESS Then
				command = QuoteArg(tool) + " -lossless -z 9 " + QuoteArg(inputPng) + " -o " + QuoteArg(outputPath)
			Else
				command = QuoteArg(tool) + " -q " + quality + " " + QuoteArg(inputPng) + " -o " + QuoteArg(outputPath)
			End If
		Case "jxl"
			tool = ToolPath("cjxl")
			If Not CheckTool(tool, "cjxl.exe") Then Return False
			If codec = CODEC_JXL_LOSSLESS Then
				command = QuoteArg(tool) + " " + QuoteArg(inputPng) + " " + QuoteArg(outputPath) + " -d 0"
			Else
				command = QuoteArg(tool) + " " + QuoteArg(inputPng) + " " + QuoteArg(outputPath) + " -q " + quality
			End If
		Case "avif"
			tool = ToolPath("avifenc")
			If Not CheckTool(tool, "avifenc.exe") Then Return False
			If codec = CODEC_AVIF_LOSSLESS Then
				command = QuoteArg(tool) + " --lossless " + QuoteArg(inputPng) + " " + QuoteArg(outputPath)
			Else
				command = QuoteArg(tool) + " -q " + quality + " " + QuoteArg(inputPng) + " " + QuoteArg(outputPath)
			End If
		Default
			Notify "Unsupported compression profile: ." + ext, True
			Return False
	End Select
	If FileType(outputPath) = 1 Then DeleteFile(outputPath)
	Local result:Int = SilentSystem(command)
	Return result = 0 And FileType(outputPath) = 1
End Function

Function ConvertImage:Int(inputPath:String, outputPath:String, quality:Int, codec:Int)
	Local basePath:String = StripExt(outputPath)
	Local inputPng:String = PreparePNG(inputPath, basePath)
	If inputPng = "" Then Return False
	Local temporary:Int = inputPng <> inputPath
	Local result:Int = EncodeFromPNG(inputPng, outputPath, quality, codec)
	If temporary And FileType(inputPng) = 1 Then DeleteFile(inputPng)
	Return result
End Function

Const WIS2_FORMAT_UNKNOWN:Int = 0
Const WIS2_FORMAT_CLASSIC:Int = 1
Const WIS2_FORMAT_NHW:Int = 2
Const WIS2_FORMAT_SELECTOR:Int = 3

Function DetectWIS2DatFormat:Int(datPath:String)
	If datPath = "" Or FileType(datPath) <> 1 Then Return WIS2_FORMAT_UNKNOWN
	' NHWCO04! contains 8 bytes of magic plus 17 Int32 header fields.
	' Reject obviously truncated containers before launching an external decoder.
	If FileSize(datPath) < 76 Then Return WIS2_FORMAT_UNKNOWN

	Local stream:TStream = ReadStream(datPath)
	If Not stream Then Return WIS2_FORMAT_UNKNOWN

	Local magic8:String = ""
	For Local i:Int = 0 Until 8
		If Eof(stream) Then Exit
		magic8 :+ Chr(ReadByte(stream))
	Next
	CloseStream(stream)

	If magic8.Length >= 8 And magic8[..8] = "NHWCO04!" Then Return WIS2_FORMAT_NHW
	If magic8.Length >= 4 And magic8[..4] = "NHW3" Then Return WIS2_FORMAT_NHW
	If magic8.Length >= 4 And magic8[..4] = "WIS4" Then Return WIS2_FORMAT_SELECTOR
	If magic8.Length >= 4 And magic8[..4] = "WIS2" Then Return WIS2_FORMAT_CLASSIC
	Return WIS2_FORMAT_UNKNOWN
End Function

Function WIS2FormatName:String(format:Int)
	Select format
		Case WIS2_FORMAT_CLASSIC
			Return "WIS2"
		Case WIS2_FORMAT_NHW
			Return "WIS2 NHW"
		Case WIS2_FORMAT_SELECTOR
			Return "WIS2 Selector"
	End Select
	Return "unknown"
End Function

Function ExtractWIS2Dat:String(inputPath:String)
	Local inputExt:String = Lower(ExtractExt(inputPath))
	If inputExt = "dat" Then Return inputPath
	If inputExt <> "bz3" Then Return ""

	Local bzipPath:String = Bzip3ToolPath()
	If Not CheckTool(bzipPath, "bzip3.exe") Then Return ""

	Local datPath:String = StripExt(inputPath) + "_gui_temp.dat"
	Local archivePath:String = datPath + ".bz3"
	If FileType(datPath) = 1 Then DeleteFile(datPath)
	If FileType(archivePath) = 1 Then DeleteFile(archivePath)
	CopyFile(inputPath, archivePath)

	If Not batchRunning Then SetStatus("Extracting BZ3...")
	PollEvent()
	Local command:String = QuoteArg(bzipPath) + " -d -k -f " + QuoteArg(archivePath)
	Local result:Int = SilentSystem(command)
	If FileType(archivePath) = 1 Then DeleteFile(archivePath)

	If result <> 0 Or FileType(datPath) <> 1 Then
		If FileType(datPath) = 1 Then DeleteFile(datPath)
		Return ""
	End If
	Return datPath
End Function

Function EncodeWIS2:Int(inputPath:String, outputPath:String, codec:Int, quality:Int)
	If Not IsWIS2Codec(codec) Then
		Notify "Choose a WIS2 mode to create DAT/BZ3.", True
		Return False
	End If

	Local encoderName:String = "WIS2_Encoder"
	Local encoderPath:String = ToolPath(encoderName)
	Local bzipPath:String = Bzip3ToolPath()
	If Not CheckTool(encoderPath, encoderName + ".exe") Then Return False

	Local targetExt:String = Lower(ExtractExt(outputPath))
	If targetExt <> "dat" And targetExt <> "bz3" Then
		outputPath = EnsureExtension(outputPath, "bz3")
		SetGadgetText(outputField, outputPath)
		targetExt = "bz3"
	End If

	Local basePath:String = StripExt(outputPath)
	Local tempImage:String = basePath + "_gui_input.png"
	Local tempDat:String = basePath + "_gui.dat"
	Local compressedDat:String = tempDat + ".bz3"

	If FileType(tempImage) = 1 Then DeleteFile(tempImage)
	If FileType(tempDat) = 1 Then DeleteFile(tempDat)
	If FileType(compressedDat) = 1 Then DeleteFile(compressedDat)

	If Not batchRunning Then SetStatus("Preparing the input image...")
	PollEvent()
	Local preparedPng:String = PreparePNG(inputPath, basePath)
	If preparedPng = "" Then
		Notify "Could not prepare the input image.", True
		Return False
	End If
	Local result:Int = 0
	tempImage = preparedPng

	Local command:String
	If codec = CODEC_WIS2_SELECTOR Then
		encoderName = "WIS2_Selector_Encoder"
		encoderPath = ToolPath(encoderName)
		If Not CheckTool(encoderPath, encoderName + ".exe") Then Return False
		If Not batchRunning Then SetStatus("Encoding WIS2 Selector...")
		PollEvent()
		command = QuoteArg(encoderPath) + " " + QuoteArg(tempImage) + " " + QuoteArg(tempDat) + " " + quality + " " + SelectedLumaDiv() + " " + SelectedChromaDiv() + " " + SelectedNHWLevels()
	ElseIf codec = CODEC_WIS2_NHW Then
		If Not batchRunning Then SetStatus("Encoding WIS2 NHW...")
		PollEvent()
		command = QuoteArg(encoderPath) + " " + QuoteArg(tempImage) + " " + QuoteArg(tempDat) + " 8 " + quality + " " + SelectedLumaDiv() + " " + SelectedChromaDiv() + " " + SelectedNHWLevels()
	Else
		Local codecMode:Int = codec + 1
		If codec = CODEC_LOSSLESS Then codecMode = 6
		If Not batchRunning Then SetStatus("Encoding WIS2...")
		PollEvent()
		command = QuoteArg(encoderPath) + " " + QuoteArg(tempImage) + " " + QuoteArg(tempDat) + " " + codecMode + " " + quality + " " + SelectedLumaDiv() + " " + SelectedChromaDiv()
	End If
	result = SilentSystem(command)
	If tempImage <> inputPath And FileType(tempImage) = 1 Then DeleteFile(tempImage)
	If result <> 0 Or FileType(tempDat) <> 1 Then
		Notify encoderName + " finished with an error.", True
		Return False
	End If
	If DetectWIS2DatFormat(tempDat) = WIS2_FORMAT_UNKNOWN Then
		If FileType(tempDat) = 1 Then DeleteFile(tempDat)
		Notify encoderName + " created an invalid or incomplete DAT file.", True
		LogMessage("Invalid DAT generated by " + encoderName)
		Return False
	End If

	If targetExt = "dat" Then
		If FileType(outputPath) = 1 Then DeleteFile(outputPath)
		RenameFile(tempDat, outputPath)
		Return FileType(outputPath) = 1
	End If

	If Not CheckTool(bzipPath, "bzip3.exe") Then Return False
	If Not batchRunning Then SetStatus("Compressing DAT to BZ3...")
	PollEvent()
	command = QuoteArg(bzipPath) + " -f " + QuoteArg(tempDat)
	result = SilentSystem(command)

	If result = 0 And FileType(compressedDat) = 1 Then
		If FileType(outputPath) = 1 Then DeleteFile(outputPath)
		RenameFile(compressedDat, outputPath)
	End If
	If FileType(tempDat) = 1 Then DeleteFile(tempDat)
	If FileType(compressedDat) = 1 Then DeleteFile(compressedDat)

	Return result = 0 And FileType(outputPath) = 1
End Function

Function DecodeWIS2:Int(inputPath:String, outputPath:String, quality:Int)
	Local datPath:String = ExtractWIS2Dat(inputPath)
	If datPath = "" Then
		Notify "Could not obtain the DAT file for decoding.", True
		Return False
	End If

	Local removeDat:Int = Lower(ExtractExt(inputPath)) = "bz3"
	Local detectedFormat:Int = DetectWIS2DatFormat(datPath)
	If detectedFormat = WIS2_FORMAT_UNKNOWN Then
		If removeDat And FileType(datPath) = 1 Then DeleteFile(datPath)
		Notify "Unknown or invalid DAT header. Expected WIS2 or NHWCO04!.", True
		LogMessage("Unknown DAT format: " + inputPath)
		Return False
	End If

	Local decoderName:String = "WIS2_Decoder"
	If detectedFormat = WIS2_FORMAT_SELECTOR Then decoderName = "WIS2_Selector_Decoder"
	Local decoderPath:String = ToolPath(decoderName)
	If Not CheckTool(decoderPath, decoderName + ".exe") Then
		If removeDat And FileType(datPath) = 1 Then DeleteFile(datPath)
		Return False
	End If

	LogMessage("Detected format: " + WIS2FormatName(detectedFormat) + " | decoder: " + decoderName)
	If Not batchRunning Then SetStatus("Detected " + WIS2FormatName(detectedFormat) + ". Decoding...")
	Local targetExt:String = Lower(ExtractExt(outputPath))
	If targetExt = "" Then
		outputPath :+ ".png"
		SetGadgetText(outputField, outputPath)
		targetExt = "png"
	End If

	Local decoderOutput:String = outputPath
	Local tempPng:String = ""
	If targetExt <> "png" Then
		tempPng = StripExt(outputPath) + "_gui_rebuilded_temp.png"
		decoderOutput = tempPng
		If FileType(tempPng) = 1 Then DeleteFile(tempPng)
	End If

	If Not batchRunning Then SetStatus("Decoding " + decoderName + "...")
	If batchRunning Then ForceBatchPreviewRefresh(80)
	PollEvent()
	Local command:String = QuoteArg(decoderPath) + " " + QuoteArg(datPath) + " " + QuoteArg(decoderOutput)
	Local result:Int = SilentSystem(command)
	If removeDat And FileType(datPath) = 1 Then DeleteFile(datPath)
	If result <> 0 Or FileType(decoderOutput) <> 1 Then
		If tempPng <> "" And FileType(tempPng) = 1 Then DeleteFile(tempPng)
		Notify decoderName + " finished with an error.", True
		Return False
	End If

	' Show the newly reconstructed PNG immediately. This is important in
	' Extract All because the final target may still need another conversion.
	If batchRunning Then
		ShowBatchPreview(decoderOutput, False)
		ForceBatchPreviewRefresh(350)
	End If

	If tempPng <> "" Then
		If Not batchRunning Then SetStatus("Converting the decoded image...")
		PollEvent()
		Local converted:Int = EncodeFromPNG(tempPng, outputPath, quality, SelectedCodec())
		If FileType(tempPng) = 1 Then DeleteFile(tempPng)
		Return converted
	End If

	Return True
End Function

Function EnsureSelectedJob:Int()
	Local inputPath:String = Trim(GadgetText(inputField))

	' A ListBox do MaxGUI envia EVENT_GADGETSELECT. Mesmo que o campo ainda
	' esteja vazio, recupera o caminho real guardado na fila.
	If inputPath = "" Or FileType(inputPath) <> 1 Then
		Local index:Int = SelectedGadgetItem(fileList)
		If index < 0 And QueueCount() > 0 Then index = 0
		If index >= 0 Then
			SelectQueuedFile(index)
			inputPath = Trim(GadgetText(inputField))
		End If
	End If

	If inputPath = "" Or FileType(inputPath) <> 1 Then Return False

	Local outputPath:String = Trim(GadgetText(outputField))
	If outputPath = "" Then
		outputPath = DefaultOutputPath(inputPath)
		SetGadgetText(outputField, outputPath)
	End If

	LogMessage("Selected input: " + inputPath)
	LogMessage("Selected output: " + outputPath)
	Return outputPath <> ""
End Function

Function ConvertFile()
	Local operationStarted:Int = MilliSecs()
	lastOperationSuccess = False
	lastOutputPath = ""
	If Not EnsureSelectedJob() Then
		Notify "Select a file in the queue or use ADD FILE.", True
		Return
	End If
	Local inputPath:String = Trim(GadgetText(inputField))
	Local outputPath:String = Trim(GadgetText(outputField))
	If inputPath = "" Or outputPath = "" Then
		Notify "Select both an input file and an output file.", True
		Return
	End If
	If FileType(inputPath) <> 1 Then
		Notify "The input file does not exist:" + Chr(10) + inputPath, True
		Return
	End If

	Local outputDir:String = ExtractDir(outputPath)
	If outputDir = "" Then outputDir = AppDir
	If FileType(outputDir) <> 2 Then
		Notify "The output folder does not exist:" + Chr(10) + outputDir, True
		Return
	End If

	LogMessage("Input path: " + inputPath)
	LogMessage("Output path: " + outputPath)

	Local quality:Int = ValidateQuality()
	If quality < 0 Then Return

	Local inputExt:String = Lower(ExtractExt(inputPath))
	Local outputExt:String = Lower(ExtractExt(outputPath))
	Local codec:Int = SelectedCodec()
	Local success:Int = False

	' Se o utilizador escreveu um nome sem extensão, usa a extensão do codec escolhido.
	If outputExt = "" Then
		outputPath = EnsureExtension(outputPath, CodecExtension(codec))
		SetGadgetText(outputField, outputPath)
		outputExt = Lower(ExtractExt(outputPath))
	End If

	DisableGadget(convertButton)
	DisableGadget(extractButton)
	If Not batchRunning Then SetProgress(100)

	If inputExt = "bz3" Or inputExt = "dat" Then
		success = DecodeWIS2(inputPath, outputPath, quality)
	Else If outputExt = "bz3" Or outputExt = "dat" Then
		success = EncodeWIS2(inputPath, outputPath, codec, quality)
	Else
		If Not batchRunning Then SetStatus("Converting image...")
		PollEvent()
		success = ConvertImage(inputPath, outputPath, quality, codec)
	End If

	If Not batchRunning Then SetProgress(1000)
	EnableGadget(convertButton)
	EnableGadget(extractButton)
	If success Then
		lastOperationSuccess = True
		lastOutputPath = GadgetText(outputField)
		If Not batchRunning Then SetStatus("Conversion complete: " + GadgetText(outputField))
		LogMessage("Completed: " + GadgetText(outputField))
		SaveSettings()
	Else
		lastOperationSuccess = False
		If Not batchRunning Then SetStatus("Conversion failed.")
		LogMessage("Operation failed: " + inputPath)
	End If
	If Not batchRunning Then AddHistory(inputPath, outputPath, lastOperationSuccess, MilliSecs() - operationStarted)
End Function

Function CompressAction()
	If Not EnsureSelectedJob() Then
		Notify "Select a file in the queue or use ADD FILE.", True
		Return
	End If
	Local inputPath:String = Trim(GadgetText(inputField))
	Local ext:String = Lower(ExtractExt(inputPath))
	If ext = "bz3" Or ext = "dat" Then
		Notify "This file is already WIS2. Use Extract to reconstruct it.", True
		Return
	End If
	ConvertFile()
End Function

Function ExtractAction()
	If Not EnsureSelectedJob() Then
		Notify "Select a WIS2 file in the queue or use ADD FILE.", True
		Return
	End If
	Local inputPath:String = Trim(GadgetText(inputField))
	Local ext:String = Lower(ExtractExt(inputPath))
	If ext <> "bz3" And ext <> "dat" Then
		Notify "Select a WIS2 .bz3 or .dat file to extract.", True
		Return
	End If
	ConvertFile()
End Function

mainWindow = CreateWindow("WIS2 Studio 2.0 - Step 5 Compact", 0, 0, 1280, 940, Null, ..
	WINDOW_TITLEBAR | WINDOW_CLIENTCOORDS | WINDOW_CENTER | WINDOW_STATUS)

Local menuRoot:TGadget = WindowMenu(mainWindow)
Local fileMenu:TGadget = CreateMenu("&File", 0, menuRoot)
CreateMenu("&Add File", KEY_O | MODIFIER_CONTROL, fileMenu, MENU_ADD_FILE)
CreateMenu("Add &Folder", KEY_D | MODIFIER_CONTROL, fileMenu, MENU_ADD_FOLDER)
CreateMenu("", 0, fileMenu)
CreateMenu("Open Output Folder", 0, fileMenu, MENU_OPEN_OUTPUT)
CreateMenu("", 0, fileMenu)
CreateMenu("E&xit", 0, fileMenu, MENU_EXIT)

Local queueMenu:TGadget = CreateMenu("&Queue", 0, menuRoot)
CreateMenu("&Remove Selected", KEY_DELETE, queueMenu, MENU_REMOVE)
CreateMenu("&Clear Queue", 0, queueMenu, MENU_CLEAR)
CreateMenu("", 0, queueMenu)
CreateMenu("&Compress All", KEY_F5, queueMenu, MENU_COMPRESS_ALL)
CreateMenu("&Extract All", KEY_F6, queueMenu, MENU_EXTRACT_ALL)
CreateMenu("&Stop After Current", KEY_ESCAPE, queueMenu, MENU_STOP_BATCH)

Local toolsMenu:TGadget = CreateMenu("&Tools", 0, menuRoot)
CreateMenu("Save Activity &Log", 0, toolsMenu, MENU_SAVE_LOG)
CreateMenu("&Reset Saved Settings", 0, toolsMenu, MENU_RESET_SETTINGS)

Local helpMenu:TGadget = CreateMenu("&Help", 0, menuRoot)
CreateMenu("&About WIS2 Studio", KEY_F1, helpMenu, MENU_ABOUT)
UpdateWindowMenu(mainWindow)

' Header
headerPanel = CreatePanel(0, 0, 1280, 70, mainWindow, PANEL_BORDER)
titleLabel = ThemeLabel("WIS2 Studio", 20, 7, 360, 34, headerPanel)
SetGadgetFont(titleLabel, LoadGuiFont("Segoe UI", 19, FONT_BOLD))
Local subtitleLabel:TGadget = ThemeLabel("Batch image compression workspace", 22, 42, 420, 20, headerPanel)
SetGadgetFont(subtitleLabel, LoadGuiFont("Segoe UI", 9, 0))
aboutButton = CreateButton("ABOUT", 1168, 18, 90, 30, headerPanel)

' Toolbar
 toolbarPanel = CreateThemedGroupPanel(12, 78, 1256, 62, mainWindow, "Actions")
Local inputButton:TGadget = CreateButton("ADD FILE", 12, 18, 86, 32, toolbarPanel)
addFolderButton = CreateButton("ADD FOLDER", 106, 18, 96, 32, toolbarPanel)
removeButton = CreateButton("REMOVE", 210, 18, 82, 32, toolbarPanel)
clearButton = CreateButton("CLEAR", 300, 18, 76, 32, toolbarPanel)
batchCompressButton = CreateButton("COMPRESS ALL", 390, 18, 118, 32, toolbarPanel)
batchExtractButton = CreateButton("EXTRACT ALL", 516, 18, 108, 32, toolbarPanel)
convertButton = CreateButton("COMPRESS ONE", 638, 14, 132, 40, toolbarPanel)
extractButton = CreateButton("EXTRACT ONE", 778, 18, 112, 32, toolbarPanel)
stopBatchButton = CreateButton("STOP", 898, 18, 82, 32, toolbarPanel)
openOutputFolderButton = CreateButton("FOLDER", 988, 18, 94, 32, toolbarPanel)
saveLogButton = CreateButton("LOG", 1090, 18, 80, 32, toolbarPanel)
DisableGadget(stopBatchButton)

' Queue
queuePanel = CreatePanel(12, 148, 680, 258, mainWindow, PANEL_GROUP, "")
queueTitleLabel = ThemeLabel("File Queue  (0 file(s)  |  0 B)", 12, 0, 650, 20, queuePanel)
SetGadgetFont(queueTitleLabel, LoadGuiFont("Segoe UI", 9, FONT_BOLD))
Local columns:TGadget = ThemeLabel("File name                                      | Type   | Size       | Status", 12, 22, 650, 20, queuePanel)
SetGadgetFont(columns, LoadGuiFont("Consolas", 9, FONT_BOLD))
fileList = CreateListBox(12, 44, 656, 202, queuePanel)
queueStatusLabel = queueTitleLabel

' Right options
profilePanel = CreateThemedGroupPanel(704, 148, 564, 112, mainWindow, "Compression Profile")
ThemeLabel("Profile:", 18, 30, 86, 24, profilePanel)
codecCombo = CreateComboBox(110, 24, 300, 28, profilePanel)
AddGadgetItem(codecCombo, "Fast - WIS2 Haar", GADGETITEM_DEFAULT)
AddGadgetItem(codecCombo, "Balanced - WIS2 DCT")
AddGadgetItem(codecCombo, "Quality - WIS2 DTT")
AddGadgetItem(codecCombo, "Hybrid - WIS2 DCT + DTT")
AddGadgetItem(codecCombo, "Adaptive - WIS2 per block")
AddGadgetItem(codecCombo, "Lossless - WIS2 RGB (exact)")
AddGadgetItem(codecCombo, "WebP")
AddGadgetItem(codecCombo, "JPEG XL")
AddGadgetItem(codecCombo, "AVIF")
AddGadgetItem(codecCombo, "WebP Lossless")
AddGadgetItem(codecCombo, "JPEG XL Lossless")
AddGadgetItem(codecCombo, "AVIF Lossless")
AddGadgetItem(codecCombo, "PNG")
AddGadgetItem(codecCombo, "JPEG")
AddGadgetItem(codecCombo, "WIS2 NHW - Nested Haar Int32")
AddGadgetItem(codecCombo, "WIS2 Selector - DCT / Haar per block")
SelectGadgetItem(codecCombo, CODEC_HAAR)
ThemeLabel("Quality:", 18, 68, 86, 22, profilePanel)
qualityField = CreateTextField(110, 64, 72, 27, profilePanel)
SetGadgetText(qualityField, DEFAULT_QUALITY)
ThemeLabel("(0 - 100)", 194, 68, 84, 22, profilePanel)

advancedPanel = CreateThemedGroupPanel(704, 268, 564, 138, mainWindow, "Advanced and Output")
ThemeLabel("Luma:", 18, 27, 78, 22, advancedPanel)
lumaCombo = CreateComboBox(110, 22, 82, 27, advancedPanel)
For Local lumaDivValue:Int = 1 To 10
    If lumaDivValue = 1 Then
        AddGadgetItem(lumaCombo, String(lumaDivValue), GADGETITEM_DEFAULT)
    Else
        AddGadgetItem(lumaCombo, String(lumaDivValue))
    End If
Next
SelectGadgetItem(lumaCombo, 0)
ThemeLabel("Chroma:", 220, 27, 82, 22, advancedPanel)
chromaCombo = CreateComboBox(304, 22, 82, 27, advancedPanel)
For Local chromaDivValue:Int = 1 To 20
    If chromaDivValue = 2 Then
        AddGadgetItem(chromaCombo, String(chromaDivValue), GADGETITEM_DEFAULT)
    Else
        AddGadgetItem(chromaCombo, String(chromaDivValue))
    End If
Next
SelectGadgetItem(chromaCombo, 1)

ThemeLabel("Nivel Haar:", 420, 26, 100, 20, advancedPanel)
levelsCombo = CreateComboBox(520, 22, 82, 27, advancedPanel)
For Local nhwLevel:Int = 1 To 7
    AddGadgetItem(levelsCombo, String(nhwLevel))
Next
SelectGadgetItem(levelsCombo, 3)
DisableGadget(levelsCombo)
ThemeLabel("Output:", 18, 66, 78, 22, advancedPanel)
outputFolderField = CreateTextField(110, 61, 382, 27, advancedPanel)
SetGadgetText(outputFolderField, AppDir)
outputFolderButton = CreateButton("...", 500, 61, 42, 27, advancedPanel)
rememberSettingsCheck = CreateButton("Remember output folder", 18, 101, 166, 22, advancedPanel, BUTTON_CHECKBOX)
SetButtonState(rememberSettingsCheck, True)
autoOpenFolderCheck = CreateButton("Open when done", 190, 101, 126, 22, advancedPanel, BUTTON_CHECKBOX)
recursiveFolderCheck = CreateButton("Recursive", 322, 101, 92, 22, advancedPanel, BUTTON_CHECKBOX)
SetButtonState(recursiveFolderCheck, True)
darkThemeCheck = CreateButton("Dark theme", 420, 101, 112, 22, advancedPanel, BUTTON_CHECKBOX)

' Selected job and statistics
filesPanel = CreateThemedGroupPanel(12, 414, 680, 104, mainWindow, "Selected Job")
ThemeLabel("Input:", 16, 30, 82, 22, filesPanel)
inputField = CreateTextField(100, 24, 466, 27, filesPanel)
inputBrowseButton = CreateButton("BROWSE", 574, 24, 90, 27, filesPanel)
ThemeLabel("Output:", 16, 69, 82, 22, filesPanel)
outputField = CreateTextField(100, 63, 466, 27, filesPanel)
outputButton = CreateButton("BROWSE", 574, 63, 90, 27, filesPanel)

statsPanel = CreateThemedGroupPanel(704, 414, 564, 104, mainWindow, "Batch Statistics")
statsOriginalLabel = ThemeLabel("Original total: 0 B", 18, 26, 250, 18, statsPanel)
statsOutputLabel = ThemeLabel("Compressed total: 0 B", 290, 26, 250, 18, statsPanel)
statsRatioLabel = ThemeLabel("Ratio: -", 18, 48, 250, 18, statsPanel)
statsSavingsLabel = ThemeLabel("Space saved: -", 290, 48, 250, 18, statsPanel)
statsTimeLabel = ThemeLabel("Elapsed: 0s", 18, 70, 250, 18, statsPanel)
statsEtaLabel = ThemeLabel("Estimated remaining: --", 290, 70, 250, 18, statsPanel)
statsProcessedLabel = ThemeLabel("Processed: 0 / 0", 18, 88, 250, 16, statsPanel)

' Preview and help
previewPanel = CreateThemedGroupPanel(12, 526, 680, 202, mainWindow, "Selected Image (Preview)")
previewCanvas = CreateCanvas(14, 25, 300, 150, previewPanel)
imageInfoLabel = ThemeLabel("No image selected", 330, 30, 330, 86, previewPanel)
estimateLabel = ThemeLabel("Estimated output: -", 320, 136, 350, 38, previewPanel)
SetGadgetFont(estimateLabel, LoadGuiFont("Arial", 10, FONT_BOLD))

helpPanel = CreateThemedGroupPanel(704, 526, 564, 194, mainWindow, "Help")
Local helpTitle:TGadget = ThemeLabel("NHW Edition - Final Package", 18, 28, 300, 26, helpPanel)
SetGadgetFont(helpTitle, LoadGuiFont("Segoe UI", 11, FONT_BOLD))
Local helpText:TGadget = ThemeLabel("Select files or folders in the queue." + Chr(10) + Chr(10) + ..
    "Choose a compression profile and quality. WIS2 Selector chooses DCT or Haar independently for each block, with Haar level 1-7 (2x2 to 128x128). WIS2 NHW uses Nested Haar Int32 with selectable luma/chroma divisors and levels, preserving alpha losslessly. WIS2, WebP, JPEG XL and AVIF lossless profiles ignore quality and preserve pixels exactly." + Chr(10) + ..
    "Use COMPRESS ONE for the selected file or COMPRESS ALL for the queue." + Chr(10) + ..
    "Set the output folder and advanced options in the right panel.", ..
    18, 60, 520, 112, helpPanel)

' Activity log
logPanel = CreateThemedGroupPanel(12, 728, 1256, 98, mainWindow, "Activity Log")
logList = CreateListBox(12, 22, 1232, 56, logPanel)

' Progress and status
progressPanel = CreateThemedGroupPanel(12, 834, 1256, 52, mainWindow, "Batch Progress")
statusDetailLabel = ThemeLabel("Ready. Add one or more files.", 14, 19, 300, 20, progressPanel)
progressBar = CreateProgBar(320, 19, 832, 18, progressPanel)
UpdateProgBar(progressBar, 0.0)
progressPercentLabel = ThemeLabel("Batch: 0%", 1164, 17, 76, 22, progressPanel)
statusLabel = ThemeLabel("Ready", 0, 0, 1, 1, mainWindow)

DisableGadget(removeButton)
DisableGadget(clearButton)
ResetStatistics()
LoadSettings()
UpdateCodecControls()
ApplyTheme()
LogMessage("WIS2 Studio started")
UpdateSelectedImageInfo("")

While True
	WaitEvent()
	Select EventID()
		Case EVENT_WINDOWCLOSE
			SaveSettings()
			End
		Case EVENT_GADGETPAINT
			If EventSource() = previewCanvas Then PaintPreview()
		Case EVENT_MENUACTION
			Select EventData()
				Case MENU_ADD_FILE
					ChooseInput()
				Case MENU_ADD_FOLDER
					ChooseFolderInput()
				Case MENU_OPEN_OUTPUT
					OpenOutputFolder()
				Case MENU_EXIT
					SaveSettings()
					End
				Case MENU_REMOVE
					RemoveSelectedQueueFile()
				Case MENU_CLEAR
					ClearQueue()
					ResetStatistics()
				Case MENU_COMPRESS_ALL
					BatchProcess(False)
				Case MENU_EXTRACT_ALL
					BatchProcess(True)
				Case MENU_STOP_BATCH
					RequestStopBatch()
				Case MENU_SAVE_LOG
					SaveActivityLog()
				Case MENU_RESET_SETTINGS
					ResetSavedSettings()
				Case MENU_ABOUT
					ShowAbout()
			End Select
		Case EVENT_WINDOWACCEPT
			' Sem drag and drop no BlitzMax NG 1.56.
		Case EVENT_GADGETSELECT
			If EventSource() = fileList Then
				SelectQueuedFile(SelectedGadgetItem(fileList))
				SetProgress(0)
			End If
		Case EVENT_GADGETACTION
			Select EventSource()
				Case inputButton
					ChooseInput()
					SetProgress(0)
				Case inputBrowseButton
					ChooseSelectedInput()
					SetProgress(0)
				Case addFolderButton
					ChooseFolderInput()
				Case openOutputFolderButton
					OpenOutputFolder()
				Case saveLogButton
					SaveActivityLog()
				Case stopBatchButton
					RequestStopBatch()
				Case removeButton
					RemoveSelectedQueueFile()
				Case clearButton
					ClearQueue()
					ResetStatistics()
				Case fileList
					SelectQueuedFile(SelectedGadgetItem(fileList))
				Case outputButton
					ChooseSelectedOutput()
				Case outputFolderButton
					ChooseOutputFolder()
				Case codecCombo
					UpdateCodecControls()
					UpdateOutputForCodec()
					UpdateSelectedImageInfo(Trim(GadgetText(inputField)))
					SaveSettings()
				Case qualityField
					UpdateSelectedImageInfo(Trim(GadgetText(inputField)))
					SaveSettings()
				Case rememberSettingsCheck
					SaveSettings()
				Case autoOpenFolderCheck
					SaveSettings()
				Case recursiveFolderCheck
					SaveSettings()
				Case darkThemeCheck
					ApplyTheme()
					SaveSettings()
				Case convertButton
					CompressAction()
				Case extractButton
					ExtractAction()
				Case batchCompressButton
					BatchProcess(False)
				Case batchExtractButton
					BatchProcess(True)
				Case aboutButton
					ShowAbout()
			End Select
	End Select
Wend
