# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
# Uni|Grab unified data ripper core
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=- #
import os, strutils, htmlparser, xmlparser, parsecsv, xmltree, uri, httpclient, threadpool, asyncdispatch

#.{ [Classes]
when not defined(UniData):
    type UniData* = object
        ip, port, creds: string

    # --Methods goes here:
    proc raw*(self: UniData, add_port = true, add_creds = true): string {.inline} =
        (if add_creds and self.creds.len>1: self.creds&"@" else: "") & self.ip & (if add_port: ":" & self.port else: "")

    proc check*(self: UniData, timeout = 5000): Future[string] {.async.} =
        # Aux proc.
        proc checkNil(txt: string): string =
            result = txt.replace('\n', ' ').strip(); if result == "": raise newException(ValueError, "I Am Error")
        proc anyText(root: XmlNode): string =
            for child in root: (try: return child.innerText.checkNil except: discard)
        # Init setup.
        let url = "http://" & self.raw()
        let client = newAsyncHttpClient()
        let future = client.getContent(url)
        yield future.withTimeout(timeout)
        client.close()
        # Actual handling.
        let resp = FutureVar[string](future).mget()
        if future.failed or resp.len == 0: return ""
        else:
            let brief = if resp.len > 15:     # Any reasons to ever parse?
                try:
                    let html = resp.parseHtml # OK, breaking it to either title tag or text of any child:
                    try: html.findAll("title")[0].innerText.checkNil except: html.anyText.checkNil.substr(0, 20)
                except: ":/nil/:"             # No luck == nil
            else: resp                        # No reason == returning as is.
            return url & " == " & brief

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
            if "IP Address" in csv.headers: # Named headers parsing.
                while csv.readRow():
                    result.add compose(csv.rowEntry("IP Address"), csv.rowEntry("Port"), csv.rowEntry("Authorization"))
            else:                           # Guess-based headers parsing.
                let (ip, port, creds) = (0, 1, 4)
                while csv.readRow():
                    result.add compose(csv.row[ip], csv.row[port], csv.row[creds])

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

    proc wait*(self: seq[Future[string]]): seq[string] {.discardable.} =
        for future in self:
            try:
                while not future.finished: poll()
                result.add(future.read())
            except: discard
#.}

# --Extra--
getAppFilename().splitFile.dir.setCurrentDir
when isMainModule: echo grab("./feed").raw()