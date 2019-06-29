mode = ScriptMode.Verbose
exec """nim compile --cc:gcc --app:gui --passl:-s --opt:size --out:"../Uni│Grab.exe" main.nim"""
if existsFile "../test.exe": rmFile "../test.exe"