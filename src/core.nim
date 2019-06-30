# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Uni|Grab unified data ripper core
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import os, htmlparser, xmlparser, parsecsv, xmltree, uri, httpclient, threadpool, asyncdispatch

#.{ [Classes]
when not defined(UniData):
    type UniData* = object
        ip:     string
        port:   string
        creds:  string

    # --Methods goes here:
    proc raw*(self: UniData, add_port = true, add_creds = true): string {.inline} =
        (if add_creds and self.creds.len>1: self.creds&"@" else: "") & self.ip & (if add_port: ":" & self.port else: "")

    proc check*(self: UniData, timeout = 5000): Future[string] {.async.} =
        let url = "http://" & self.raw()
        let future = newAsyncHttpClient().getContent(url)
        future.withTimeout(timeout).addCallback(proc() = future.fail(newException(OSError, "HTTP timed out.")))
        yield future
        let resp = FutureVar[string](future).mget() # Unconventional fixing to avoid HttpRequestErrors.
        future.error = nil; complete(future, resp)  # Unconventional fixing to avoid assertion errors.
        if future.failed or resp.len == 0 : return ""
        else:
            let title = if resp.len > 15:                                                         # Any reason to parse?
                let html = resp.parseHtml                                                         # OK, breaking it to:
                try: (try: html.findAll("title")[0].innerText except: $(html.findAll("meta")[0])) # Title/meta #1
                except: html[0].innerText.substr(0, 20)                                           # Somebody text.
            else: resp                                                                            # ...or getting as is.
            return url & " == " & title

    proc compose*(ip: string, port: int|string, creds: string = ""): UniData {.inline} =
        result = UniData(ip: ip, port: $port, creds: creds)
# -----------------------
when not defined(DataList):
    type DataList* = seq[UniData]

    # --Methods goes here:
    proc grab_xml(feed: string): DataList {.thread.} =
        for file in feed.joinPath("/*.xml").walkFiles:
            for node in file.loadXml.findAll("Device"): # Only devices are parsed.
                result.add compose(node.attr("ip"), node.attr("port"), node.attr("user")&":"&node.attr("password"))

    proc grab_html(feed: string): DataList {.thread.} =
        for file in feed.joinPath("/*.html").walkFiles:
            for entry in file.loadHtml.findAll("div"):
                if entry.attr("id") == "ipd": # Only ipds are parsed.
                    let uri = entry.findAll("a")[0].attr("href").parseUri
                    result.add compose(uri.hostname, uri.port)

    proc grab_csv(feed: string): DataList {.thread.} =
        for file in feed.joinPath("/*.csv").walkFiles:
            var csv: CsvParser
            csv.open(file, ';')
            csv.readHeaderRow()
            if "IP Address" in csv.headers: # Correct headers parsing.
                while csv.readRow():
                    result.add compose(csv.rowEntry("IP Address"), csv.rowEntry("Port"), csv.rowEntry("Authorization"))
            else: # Guess-based headers parsing.
                while csv.readRow():
                    result.add compose(csv.row[0], csv.row[1], csv.row[4])

    proc grab*(feed: string): DataList =
        var grab_res: seq[FlowVar[seq[UniData]]]
        grab_res.add(spawn feed.grab_xml())
        grab_res.add(spawn feed.grab_html())
        grab_res.add(spawn feed.grab_csv())
        for res in grab_res: result &= ^res

    proc raw*(self: DataList, add_port = true, add_creds = true): seq[string] =
        for ud in self: result.add(ud.raw(add_port, add_creds))

    proc check*(self: DataList): seq[Future[string]] =
        for ud in self: result.add(ud.check)
#.}

# --Extra--
echo "".substr(0, 20)
getAppFilename().splitFile.dir.setCurrentDir
when isMainModule:
    echo grab("./feed").raw()
    let listing = grab("./feed").check()
    for l in listing: l.addCallback(
         proc(fut: Future[string]) = 
            if fut.read()!="": echo fut.read()
    )
    discard listing.all.waitFor()