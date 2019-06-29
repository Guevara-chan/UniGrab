# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Uni|Grab unified data ripper v0.03
# Developed in 2019 by Guevara-chan
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import core, os, strutils, sequtils, asyncdispatch, wnim

#.{ [Classes]
when not defined(UI):
    type check_args = tuple[output: wTextCtrl, out_accum: wTextCtrl]
    var check_chan: Channel[DataList]

    # --Methods goes here.
    proc checker(args: check_args) {.thread.} =
        while true:
            let (output, out_accum) = args
            let last_grab   = check_chan.recv()
            let out_path    = out_accum.value
            output.value    = ".../Please, wait/..."
            output.value    = last_grab.check.all.waitFor().filterIt(it!="").join("\n")
            out_path.writeFile(output.value)

    proc main(def_feed: string) =
        # -Init definitions.
        let
            tstyle  = wBorderSunken or wTeRich or wTeReadOnly or wTeMultiline or wVScroll
            app     = App()
            frame   = Frame(title="=[Uni|Grab v0.03]=", size=(400, 220))
            panel   = Panel(frame)
            panels  = NoteBook(panel)
            pchunks = panels.insertPage(text="Chunks")
            pchecks = panels.insertPage(text="Checkup")
            start   = Button(panel, label="Grab:")
            ilocate = Button(panel, label="Locate..")
            olocate = Button(pchunks, label="Locate..")
            clocate = Button(pchecks, label="Locate..")
            feed    = TextCtrl(panel, style=wBorderSunken, value=def_feed)
            chunks  = TextCtrl(pchunks, style=tstyle)
            checked = TextCtrl(pchecks, style=tstyle)
            chunklog= TextCtrl(pchunks, style=wBorderSunken)
            checklog= TextCtrl(pchecks, style=wBorderSunken)
            addports= CheckBox(pchunks, label="+port")
            addcreds= CheckBox(pchunks, label="+login")
        var last_grab:      DataList
        var check_thread:   Thread[check_args]

        # -Additional fixes.
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
            |[addports(=55)][addcreds(=55)][chunklog][olocate(=55)]|
            V:|[chunks][addports,addcreds, olocate]|
            V:|[chunks]-1-[chunklog]-1-|
            """
            panels[1].autolayout """
            |[checked]|
            |[checklog][clocate(=55)]|
            V:|[checked][clocate]|
            V:|[checked]-1-[checklog]-1-|
            """
        proc format() =
            chunks.value = last_grab.raw(addports.value, addcreds.value).join("\n") 
            chunklog.value.writeFile(chunks.value)
            chunks.showPosition(0)
        proc process() =
            try:    last_grab = grab(feed.value); format(); check_chan.send(last_grab)
            except: chunks.value = getCurrentExceptionMsg() 
        proc best_out() =
            let fname = feed.value.splitFile.name
            chunklog.value = ".".joinPath(fname & " - chunks.txt")
            checklog.value = ".".joinPath(fname & " - checked.txt")
        proc ask_path(tc: wTextCtrl) =
            let res=FileDialog(frame,style=wFdSave,wildcard="*.txt",defaultFile=tc.value.absolutePath).showModalResult()
            if res.len > 0: tc.value = res[0]
        # -Event handling.
        feed.wEvent_Text            do (): best_out()
        panel.wEvent_Size           do (): layout()
        start.wEvent_Button         do (): process()
        addports.wEvent_CheckBox    do (): format()
        addcreds.wEvent_CheckBox    do (): format()
        olocate.wEvent_Button       do (): ask_path(chunklog)
        clocate.wEvent_Button       do (): ask_path(checklog)
        ilocate.wEvent_Button       do (): # Input directory selector.
            let new_feed = DirDialog(frame, 
                defaultPath = if feed.value.dirExists:feed.value.absolutePath else: "").showModalResult()
            if new_feed != "": feed.value = new_feed            
        # -Finalization.
        check_chan.open()
        layout(); best_out(); process()
        check_thread.createThread(checker, (checked, checklog))
        frame.center()
        frame.show()
        app.mainLoop()
#.}

# ==Main code==
main(if paramCount() > 0: paramStr(1) else: ".\\feed")