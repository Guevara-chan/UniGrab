﻿mode = ScriptMode.Verbose
exec """nim compile --cc:gcc --app:gui --passl:-s --opt:size --out:"../UniGrab.exe" main.nim"""
"../Uni│Grab.exe".rmFile
"../UniGrab.exe".mvFile "../Uni│Grab.exe"
if existsFile "../test.exe": rmFile "../test.exe"