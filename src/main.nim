# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Uni|Grab unified data ripper v0.03
# Developed in 2019 by Guevara-chan
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import core, os, strutils, sequtils
import wNim/[wApp,wFrame,wTextCtrl,wButton,wMessageDialog,wPanel,wNoteBook,wCheckBox,wIcon,wFileDialog,wDirDialog]
when sizeof(int) == 8: {.link: "res/uni64.o".}
{.this: self.}

#.{ [Classes]
when not defined(UniUI):
    type UniUI = ref object of wApp
        check_thread:       Thread[UniUI]
        recheck_thread:     Thread[UniUI]
        checked, checklog:  wTextCtrl
        last_grab:          DataList
    var check_chan: Channel[DataList]

    # --Methods goes here.
    proc dump(feed: wTextCtrl, path: string): string {.discardable.} =
        try: (path.writeFile(feed.value); "")
        except: getCurrentExceptionMsg()

    proc inquire(err_text: string): bool {.discardable.} =
        if err_text != "": MessageDialog(nil, err_text, "[Uni|Grab] error:", wIconErr).display.int == 0 else: true

    proc checker(self: UniUI) {.thread.} =
        try:
            let last_grab   = check_chan.recv()
            let out_path    = checklog.value
            checked.value   = ".../Please, wait/..."
            checked.value   = last_grab.check.wait().filterIt(it!="").join("\n")
            checked.dump(out_path)
        except: checked.value = getCurrentExceptionMsg() 

    proc rechecker(self: UniUI) {.thread.} =
        while true:
            if not check_thread.running: check_thread.createThread(checker, self) else: 250.sleep()

    proc newUniUI(def_feed: string): UniUI {.discardable.} =
        # -Init definitions.
        let 
            tstyle  = wBorderSunken or wTeRich or wTeReadOnly or wTeMultiline or wVScroll
            self    = new UniUI
            app     = App()
            frame   = Frame(title="=[Uni|Grab v0.03]=", size=(400, 220))
            panel   = Panel(frame)
            panels  = NoteBook(panel)
            pchunks = panels.insertPage(text="Chunks")
            pchecks = panels.insertPage(text="Checkup")
            start   = Button(panel, label="Grab:")
            ilocate = Button(panel, label="Locate..")
            chunksav= Button(pchunks, label="Save..")
            checksav= Button(pchecks, label="Save..")
            feed    = TextCtrl(panel, style=wBorderSunken, value=def_feed)
            chunks  = TextCtrl(pchunks, style=tstyle)
            checked = TextCtrl(pchecks, style=tstyle)
            chunklog= TextCtrl(pchunks, style=wBorderSunken)
            checklog= TextCtrl(pchecks, style=wBorderSunken)
            addports= CheckBox(pchunks, label="+port")
            addcreds= CheckBox(pchunks, label="+login")
        # -Additional fixes.
        (self.checked, self.checklog) = (checked, checklog)
        try: frame.icon = Icon("", 0) except: discard
        panel.margin = 5
        # -Auxiliary procs.
        proc layout() =
            panel.autolayout """
                |[start(=55)][feed][ilocate(=55)]|
                |[panels]|
                V:|[start, ilocate][panels]|
                V:|-1-[feed]-1-[panels]|
            """
            panels[0].autolayout """
                |[chunks]|
                |[addports(=55)][addcreds(=55)][chunklog][chunksav(=55)]|
                V:|[chunks][addports,addcreds, chunksav]|
                V:|[chunks]-1-[chunklog]-1-|
            """
            panels[1].autolayout """
                |[checked]|
                |[checklog][checksav(=55)]|
                V:|[checked][checksav]|
                V:|[checked]-1-[checklog]-1-|
            """
        proc format() =
            chunks.value = self.last_grab.raw(addports.value, addcreds.value, false).join("\n") 
            chunks.dump(chunklog.value)
            chunks.showPosition(0)
        proc process() =
            try:    
                self.last_grab = grab(feed.value); format(); check_chan.send(self.last_grab)
            except: chunks.value = getCurrentExceptionMsg() 
        proc best_out() =
            let fname = feed.value.splitFile.name
            for (ctrl, pref) in [(chunklog, "chunks"), (checklog, "checked")]:
                ctrl.value = ".".joinPath [fname, " - ", pref, ".txt"].join("")
        proc ask_path(tc: wTextCtrl, feed: wTextCtrl) =
            const pattern = "Log files (*.txt)|*.txt|All files (*.*)|*.*"
            let thisdir = tc.value.splitFile.dir.absolutePath
            let res = FileDialog(frame, style = wFdSave, wildcard = pattern, defaultDir = thisdir).display()
            if res.len > 0 and feed.dump(res[0]).inquire(): tc.value = res[0]
        # -Event handling.
        feed.wEvent_Text            do (): best_out()
        panel.wEvent_Size           do (): layout()
        start.wEvent_Button         do (): process()
        addports.wEvent_CheckBox    do (): format()
        addcreds.wEvent_CheckBox    do (): format()
        chunksav.wEvent_Button      do (): ask_path(chunklog, chunks)
        checksav.wEvent_Button      do (): ask_path(checklog, checked)
        ilocate.wEvent_Button       do (): # Input directory selector.
            let new_feed = DirDialog(frame, 
                defaultPath = if feed.value.dirExists:feed.value.absolutePath else: "").display()
            if new_feed != "": feed.value = new_feed            
        # -Finalization.
        check_chan.open()
        layout(); best_out(); process()
        self.recheck_thread.createThread(rechecker, self)
        frame.center()
        frame.show()
        app.mainLoop()
        return self
#.}

# ==Main code==
newUniUI(if paramCount() > 0: paramStr(1) else: ".\\feed")