" Title:         ProjectParse
" Author:        Dan Price   vim@danprice.fastmail.net
"
" Documentation: type ":help ProjectParse"
" License:       Public domain, no restrictions whatsoever
"
" Version:       1.1 -- Programs can inspect g:ProjectParseVersion


" Initialization {{{
if exists("g:ProjectParseVersion") || &cp
    finish
endif
let g:ProjectParseVersion = "1.1"
" }}}

" Internals {{{
" Warning/Error {{{
function! s:Info(message)
    echohl Normal | echomsg "[ProjectParse] ".a:message | echohl None
endfunction
function! s:Warning(message)
    echohl WarningMsg | echomsg "[ProjectParse] Warning: ".a:message | echohl None
endfunction
function! s:Error(message)
    echohl ErrorMsg | echomsg "[ProjectParse] Error: ".a:message | echohl None
endfunction
"}}}
" Trim {{{
function! s:Trim(s)
    let len = strlen(a:s)

    let beg = 0
    while beg < len
        if a:s[beg] != " " && a:s[beg] != "\t"
            break
        endif
        let beg += 1
    endwhile

    let end = len - 1
    while end >= 0
        if a:s[end] != " " && a:s[end] != "\t"
            break
        endif
        let end -= 1
    endwhile

    return strpart(a:s, beg, end-beg+1)
endfunction
"}}}
" IncreaseIndent {{{
function! s:IncreaseIndent()
    let s:indentLevel += 1
endfunction
" }}}
" DecreaseIndent {{{
function! s:DecreaseIndent()
    let s:indentLevel -= 1
endfunction
" }}}
" Write {{{
function! s:Write(str)
    let i = 0
    let str = a:str
    while i < s:indentLevel
        let str = " ".str
        let i += 1
    endwhile
    call add(s:out, str)
endfunction
" }}}
" AddFile {{{
function! s:AddFile(f,dir)
    if !filereadable(a:dir.'/'.a:f)
        " TODO: decide on whether to warn here or not; consider whether it's a
        " well-formed file or a pattern
        "call s:Warning("'".a:f."' is not unreadable")
        return
    endif
    call s:Write(a:f)
endfunction
" }}}
" OpenFold {{{
function! s:OpenFold(file, name, dir)
    let line = a:name
    if !empty(a:dir)
        let line .= "=".a:dir
    else
        let line .= "=\"\""
    endif
    if !empty(a:file) && !empty(a:dir)
        let line .= " filter=\"\""
    endif
    if !empty(a:file)
        let line .= " proj=".fnamemodify(a:file, ":t")
        let line .= " mtime=".getftime(a:file)
    endif
    let line .= " {"
    call s:Write(line)
    call s:IncreaseIndent()
endfunction
" }}}
" CloseFold {{{
function! s:CloseFold()
    call s:DecreaseIndent()
    call s:Write("}")
endfunction
" }}}
" CheckIsReadable {{{
function! s:CheckIsReadable(prj)
    if !filereadable(a:prj)
        throw a:prj." is unreadable"
    endif
endfunction
" }}}
" CheckNotEmpty {{{
function! s:CheckNotEmpty(prj, lines)
    if empty(a:lines)
        throw a:prj." is empty"
    endif
endfunction
" }}}
" GetProjectFilename {{{
function! s:GetProjectFilename()
    if exists("g:proj_filename")
        return g:proj_filename
    endif
    return $HOME."/.vimprojects"
endfunction
" }}}
" InsertProject {{{
function! s:InsertProject(root_name, root_dir)
    let i = 0
    let start = -1
    let end = -1
    let pf = s:GetProjectFilename()
    let fLines = readfile(pf)
    for line in fLines
        if line =~ '^\s*'.a:root_name.'='.a:root_dir.".*"
            let start=i
            let indent=match(line, "[^ ]")
            let endpattern  = '^'
            let endpattern .= repeat(" ", indent)
            let endpattern .= '}$'
        elseif start != -1
            if line =~ endpattern
                let end = i
                break
            endif
        endif
        let i += 1
    endfor

    if start != -1
        call remove(fLines, start, end)
    else
        let start = len(fLines)
    endif
    call extend(fLines, s:out, start)
    call writefile(fLines, pf)
endfunction
" }}}
" UpdateProjects {{{
function! s:UpdateProjects(manual)
    let toUpdate = []

    " TODO: use a prefix with these names so that they don't conflict

    let pf = s:GetProjectFilename()
    let fLines = readfile(pf)
    let root = ""
    let rootdir = ""
    for line in fLines
        if line =~ '^\s*[\w\d]\+=.*'
            let project = {}
            let project["name"] = s:Trim(strpart(line, 0, stridx(line, '=')))
            let project["indent"] = match(line, "[^ ]")
            let fields = split(line)
            for f in fields
                let pair = split(f, '=')
                if len(pair) == 2
                    let project[pair[0]] = pair[1]
                endif
            endfor
            if line =~ '^\w.*'
                let root = project["name"]
                let rootdir = project[root]
            endif

            if !has_key(project, "proj") | continue | endif

            let project["dir"] = project[project["name"]]
            let project["root"] = root
            let project["rootdir"] = rootdir

            if project["rootdir"] == project["dir"]
                let project["absdir"] = project["rootdir"]
            else
                let project["absdir"] = project["rootdir"]."/".project["dir"]
            endif

            let file = project["absdir"]."/".project["proj"]

            if !filereadable(file)
                call s:Warning("File '".file."' not found")
                continue
            endif

            let newMtime = str2nr(getftime(file))
            if newMtime > str2nr(project["mtime"])
                call add(toUpdate, project)
            endif
        endif
    endfor

    for p in toUpdate
        let name = p["name"]
        let file = p["dir"]."/".p["proj"]

        if a:manual
            echo "Updating project '".name."' (".file.")"
        endif

        let s:indentLevel = p["indent"]
        call s:ProjectParse(file)
    endfor
endfunction
" }}}

" InitializeGlobals {{{
function! s:InitializeGlobals()
    let s:out = []
    if !exists("s:indentLevel")
        let s:indentLevel = 0
    endif

    let s:entries = []
    let s:relationships = {}
    let s:hasdep = {}
    let s:byid = {}
endfunction
" }}}
" ClearGlobals {{{
function! s:ClearGlobals()
    unlet s:out
    unlet s:indentLevel

    unlet s:entries
    unlet s:relationships
    unlet s:hasdep
    unlet s:byid
endfunction
" }}}

" Visual Studio {{{
" WriteVcFolder {{{
function! s:WriteVcFolder(sln, d)

    let proj = a:d
    let id = proj['id']

    call s:OpenFold("", proj['name'], "")

    for i in s:relationships[id]
        let v = s:byid[i]

        if v['folder'] == 1
            call s:WriteVcFolder(a:sln, v)
        else
            call s:ParseVcProj(a:sln, v['loc'], v['name'])
        endif

        let j = 0
        while j < len(s:entries)
            if s:entries[j]['name'] == v['name']
                call remove(s:entries, j)
                break
            endif
            let j += 1
        endwhile
    endfor

    call s:CloseFold()
endfunction
" }}}
" ParseVcProj {{{
function! s:ParseVcProj(sln, vcproj, name)

    let vcproj = substitute(a:vcproj, "\\", "/", "g")

    if vcproj !~ ".*\.vcproj"
        call s:Error(vcproj." is not a Visual Studio project file")
        return
    endif

    " TODO: verify file version

    call s:CheckIsReadable(vcproj)

    let fLines = readfile(vcproj)
    call s:CheckNotEmpty(vcproj)

    if !empty(a:name)
        let vcproj_name=a:name
    else
        let vcproj_name=fnamemodify(vcproj, ":t:r")
    endif
    let vcproj_dir=fnamemodify(vcproj, ":p:h")

    if !empty(a:sln)
        let sln_dir=fnamemodify(a:sln, ":p:h")
        let reldir=substitute(vcproj_dir, sln_dir."/", "", "")
    else
        let reldir = vcproj_dir
    endif

    call s:OpenFold(vcproj, vcproj_name, reldir)

    let state = "Unset"
    let filter = ""

    for line in fLines
        if state == "Unset"
            if line =~ "\s*<Files>\s*"
                let state = "Files"
            endif
        elseif state == "Files"
            if line =~ "</Files>"
                let state = "Unset"
            elseif line =~ "\s*<Filter\s*"
                let state = "Filtered"
                let filter = ""
            endif
        elseif state == "Filtered"
            if line =~ "</Filter>"
                let state = "Files"
            elseif line =~ "Name=.*" && filter == ""
                let filter = substitute(line, '\s*Name=\"\(.*\)\"', '\1', "")
            elseif line =~ "RelativePath=.*"
                let var = substitute(line, '\s*RelativePath=\"\(.*\)\"', '\1', "")
                let var = substitute(var, "^\.\\", "", "")
                let var = substitute(var, "\\", "/", "g")
                call s:AddFile(var, vcproj_dir)
            endif
        endif
    endfor

    call s:CloseFold()

    " TODO: integrate this more elegantly
    if empty(a:sln)
        call s:InsertProject(vcproj_name, reldir)
    endif

endfunction
" }}}
" ParseVcIcProj {{{
function! s:ParseVcIcProj(icproj)
    let icproj = substitute(a:icproj, "\\", "/", "g")

    call s:CheckIsReadable(icproj)

    let fLines = readfile(icproj)
    call s:CheckNotEmpty(icproj, fLines)

    for line in fLines
        if line =~ "VCNestedProjectFileName=\".*\""
            let loc = substitute(Trim(line), 'VCNestedProjectFileName=\"\(.*\)\"', '\1', "")
            return loc
        endif
    endfor

    return ""
endfunction
" }}}
" ParseVcSln {{{
function! s:ParseVcSln(sln)

    let sln = substitute(a:sln, "\\", "/", "g")

    if sln !~ ".*\.sln"
        call s:Error(sln." is not a Visual Studio solution file")
        return
    endif

    " TODO: verify file version

    call s:CheckIsReadable(sln)

    let fLines = readfile(sln)
    call s:CheckNotEmpty(sln, fLines)

    let sln_dir=fnamemodify(sln, ":p:h")
    let sln_name=fnamemodify(sln, ":t:r")

    call s:OpenFold(sln, sln_name, sln_dir)

    let state = "Unset"
    let filter = ""

    for line in fLines
        if state == "Unset"
            if line =~ "Project(\".*\") = \".*\", \".*\", \".*\""
                let name = substitute(line, 'Project(\".*\") = \"\(.*\)\", \"\(.*\)\", \"{\(.*\)}\"', '\1', "")
                let loc = substitute(line, 'Project(\".*\") = \"\(.*\)\", \"\(.*\)\", \"{\(.*\)}\"', '\2', "")
                let id = substitute(line, 'Project(\".*\") = \"\(.*\)\", \"\(.*\)\", \"{\(.*\)}\"', '\3', "")

                if loc !~ '.*\.[vi]cproj'
                    let isFolder = 1
                elseif loc =~ '.*\.icproj'
                    let vcname = s:ParseVcIcProj(loc)
                    if empty(vcname)
                        call s:Error("Failed to parse ".loc)
                        continue
                    endif
                    let loc = substitute(loc, name.".icproj", vcname, '')
                else
                    let isFolder = 0
                endif

                let d = {'name': name, 'loc': loc, 'id': id, 'folder': isFolder}
                call add(s:entries, d)
                let s:byid[id] = d

            elseif line =~ "GlobalSection(NestedProjects) = preSolution"
                let state = "Nested"
            endif
        elseif state == "Nested"
            if line =~ "EndGlobalSection"
                let state = "Unset"
            else
                let child = Trim(substitute(line, '{\(.*\)} = {\(.*\)}', '\1', ""))
                let parent = Trim(substitute(line, '{\(.*\)} = {\(.*\)}', '\2', ""))
                if !has_key(s:relationships, parent)
                    let s:relationships[parent] = [child]
                else
                    call add(s:relationships[parent], child)
                endif
                let s:hasdep[child] = parent
            endif
        endif
    endfor

    let folderId = 0

    while len(s:entries) > 0
        let proj = s:entries[0]

        if has_key(s:hasdep, proj['id'])
            call remove(s:entries, 0)
            call add(s:entries, proj)
            continue
        endif

        if proj['folder'] == 1
            call s:WriteVcFolder(sln, proj)
        else
            call s:ParseVcProj(sln, proj['loc'], proj['name'])
        endif

        call remove(s:entries, 0)

    endwhile

    call s:CloseFold()

    call s:InsertProject(sln_name, sln_dir)

endfunction
" }}}
"}}}
" Code Blocks {{{
" ParseCbProj {{{
function! s:ParseCbProj(sln, cbproj, name)

    let cbproj = substitute(a:cbproj, "\\", "/", "g")

    if cbproj !~ ".*\.cbp"
        call s:Error(cbproj." is not a code::blocks project file")
        return
    endif

    " TODO: verify file version

    call s:CheckIsReadable(cbproj)

    let fLines = readfile(cbproj)
    call s:CheckNotEmpty(cbproj, fLines)

    if !empty(a:name)
        let cbproj_name=a:name
    else
        let cbproj_name=fnamemodify(cbproj, ":t:r")
    endif
    let cbproj_dir=fnamemodify(cbproj, ":p:h")

    if !empty(a:sln)
        let sln_dir=fnamemodify(a:sln, ":p:h")
        let cbproj_dir=substitute(cbproj_dir, sln_dir."/", "", "")
    endif

    call s:OpenFold(cbproj, cbproj_name, cbproj_dir)

    let state = "Unset"
    let filter = ""

    for line in fLines
        if line =~ '<Unit filename=\"[^"]\+\".*'
            let var = substitute(s:Trim(line), '<Unit filename=\"\([^"]\+\)\".*', '\1', "")
            let var = substitute(var, "^\./", "", "")
            call s:AddFile(var, cbproj_dir)
        endif
    endfor

    call s:CloseFold()

    " TODO: integrate this more elegantly
    if empty(a:sln)
        call s:InsertProject(cbproj_name, cbproj_dir)
    endif

endfunction
" }}}
" ParseCbWorkspace {{{
function! s:ParseCbWorkspace(sln)

    let sln = substitute(a:sln, "\\", "/", "g")

    if sln !~ ".*\.workspace"
        call s:Error(sln." is not a code::blocks workspace file")
        return
    endif

    " TODO: verify file version

    call s:CheckIsReadable(sln)

    let fLines = readfile(sln)
    call s:CheckNotEmpty(sln, fLines)

    let sln_dir=fnamemodify(sln, ":p:h")
    let sln_name=fnamemodify(sln, ":t:r")

    call s:OpenFold(sln, sln_name, sln_dir)

    let state = "Unset"
    let filter = ""

    for line in fLines
        if line =~ '<Project filename=\"[^"]\+\".*/>'
            let loc = substitute(s:Trim(line), '<Project filename=\"\([^\"]\+\)\".*/>', '\1', "")
            let name=fnamemodify(loc, ":t:r")

            call s:ParseCbProj(sln, loc, name)
        endif
    endfor

    call s:CloseFold()

    call s:InsertProject(sln_name, sln_dir)

endfunction
" }}}
"}}}
" Automake {{{
" ParseAmMakefile {{{
function! s:ParseAmMakefile(am, parentdir)

    let am = substitute(a:am, "\\", "/", "g")

    if am !~ ".*Makefile.am"
        call s:Error(am." is not an automake project file")
        return
    endif

    call s:CheckIsReadable(am)

    let fLines = readfile(am)
    call s:CheckNotEmpty(am, fLines)

    let am_dir=fnamemodify(am, ":p:h")
    let am_name=""

    let sources = []
    let subdirs = []

    let state = "Unset"

    let lnum = 0
    let numLines = len(fLines)
    while lnum < numLines
        let line = fLines[lnum]
        let line = s:Trim(line)
        if state == "Unset"
            if line =~ "\\s*bin_PROGRAMS\\s*=\\s*.*"
                let am_name = s:Trim(strpart(line, stridx(line, "=")+1))
            elseif line =~ "\\s*SUBDIRS\\s*=\\s*.*"
                let subdirs = split(substitute(line, "\\s*SUBDIRS\\s*=\\s*\(.*\)", '\1', ""), " ")
            elseif line =~ "^\\s*".am_name."_SOURCES\\s*=\\s*.*"
                let state = "Files"

                " Skip incrementing the line counter
                continue
            endif
        elseif state == "Files"

            if line =~ "^\\s*".am_name."_SOURCES\\s*=\\s*.*"
                let line = strpart(line, stridx(line, "=")+1)
            endif

            if line !~ '.*\\$'
                let state = "Unset"
            endif

            let files = substitute(line, '\\$', '', "")
            let files = s:Trim(files)
            let filelist = split(files, " ")
            for f in filelist
                call add(sources, f)
            endfor
        endif
        let lnum += 1
    endwhile

    if empty(am_name)
        let am_name=fnamemodify(am_dir, ":t")
    endif

    let subcount = 0
    for subdir in subdirs
        let subdir = s:Trim(subdir)
        let subam = am_dir.'/'.subdir.'/Makefile.am'
        if filereadable(subam)
            let subcount += 1
        endif
    endfor
    let passthrough = empty(sources) && (subcount==1) && empty(a:parentdir)
    let reldir = empty(a:parentdir) ? am_dir : fnamemodify(am_dir, ":t")

    if !passthrough
        call s:OpenFold(am, am_name, reldir)
        for s in sources
            call s:AddFile(s, am_dir)
        endfor
    endif
    for subdir in subdirs
        let subdir = s:Trim(subdir)
        let subam = am_dir.'/'.subdir.'/Makefile.am'
        if filereadable(subam)
            call s:ParseAmMakefile(subam, passthrough ? "" : subdir)
        endif
    endfor
    if !passthrough
        call s:CloseFold()
    endif

    if empty(a:parentdir) && !passthrough
        call s:InsertProject(am_name, am_dir)
    endif

endfunction
" }}}
"}}}
" CMake {{{
" ParseCmakelist {{{
function! s:ParseCmakelist(cmf, first)

    let cmf = substitute(a:cmf, "\\", "/", "g")

    if cmf !~ ".*CMakeLists.txt"
        call s:Error(cmf." is not an automake project file")
        return
    endif

    call s:CheckIsReadable(cmf)

    let fLines = readfile(cmf)
    call s:CheckNotEmpty(cmf, fLines)

    let cmf_dir=fnamemodify(cmf, ":p:h")
    let cmf_name=""

    let sources = []
    let subdirs = []

    let state = "Unset"

    let lnum = 0
    let numLines = len(fLines)
    while lnum < numLines
        let line = fLines[lnum]
        let line = s:Trim(line)
        if state == "Unset"
            if line =~# 'project(.*)'
                let cmf_name = substitute(line, 'project(\(.*\))', '\1', "")
            elseif line =~# 'add_subdirectory(.*)'
                let subdir = substitute(line, 'add_subdirectory(\(.*\))', '\1', "")
                call add(subdirs, subdir)
            elseif line =~# 'source_group(.*'
                let state = "Files"

                " Skip incrementing the line counter
                continue
            endif
        elseif state == "Files"
            if line =~# 'source_group(.*'
                let line = strpart(line, stridx(line, "FILES")+strlen("FILES"))
            endif

            if line =~# ")$"
                let state = "Unset"
                let line = strpart(line, 0, strlen(line)-1)
            endif

            let filelist = split(line, " ")
            for f in filelist
                call add(sources, f)
            endfor
        endif
        let lnum += 1
    endwhile

    if empty(cmf_name)
        let cmf_name=fnamemodify(cmf_dir, ":t")
    endif

    let subcount = 0
    for subdir in subdirs
        let subcmf = cmf_dir.'/'.subdir.'/CMakeLists.txt'
        if filereadable(subcmf)
            let subcount += 1
        endif
    endfor
    let passthrough = empty(sources) && (subcount==1) && (a:first==1)

    if !passthrough
        call s:OpenFold(cmf, cmf_name, cmf_dir)
        for s in sources
            call s:AddFile(s, cmf_dir)
        endfor
    endif
    for subdir in subdirs
        let subcmf = cmf_dir.'/'.subdir.'/CMakeLists.txt'
        if filereadable(subcmf)
            call s:ParseCmakelist(subcmf, passthrough)
        endif
    endfor
    if !passthrough
        call s:CloseFold()
    endif

    if a:first && !passthrough
        call s:InsertProject(cmf_name, cmf_dir)
    endif

endfunction
" }}}
"}}}
" MPLAB {{{
" ParseMplab {{{
function! s:ParseMplab(mcp)

    let mcp = substitute(a:mcp, "\\", "/", "g")

    if mcp !~ ".*\.mcp"
        call s:Error(mcp." is not an automake project file")
        return
    endif

    call s:CheckIsReadable(mcp)

    let fLines = readfile(mcp)
    call s:CheckNotEmpty(mcp, fLines)

    let mcp_dir=fnamemodify(mcp, ":p:h")
    let mcp_name=fnamemodify(mcp, ":t:r")

    let sources = []

    let state = "Unset"

    let lnum = 0
    let numLines = len(fLines)
    while lnum < numLines
        let line = fLines[lnum]
        let line = s:Trim(line)
        if state == "Unset"
            if line =~ '\[FILE_INFO\]'
                let state = "Files"
            endif
        elseif state == "Files"

            if line =~ '\[.*\]'
                let state = "Unset"
                continue
            endif

            let file = substitute(line, 'file_\d\+=', '', "")
            call add(sources, file)
        endif
        let lnum += 1
    endwhile

    call s:OpenFold(mcp, mcp_name, mcp_dir)
    for s in sources
        call s:AddFile(s, mcp_dir)
    endfor
    call s:CloseFold()

    call s:InsertProject(mcp_name, mcp_dir)

endfunction
" }}}
"}}}
" CodeLite {{{
" ParseCodeLite {{{
function! s:ParseCodeLite(cl_prj)

    let cl_prj = substitute(a:cl_prj, "\\", "/", "g")

    if cl_prj !~ ".*\.project"
        call s:Error(cl_prj." is not a codelite project file")
        return
    endif

    call s:CheckIsReadable(cl_prj)

    let fLines = readfile(cl_prj)
    call s:CheckNotEmpty(cl_prj, fLines)

    let cl_dir=fnamemodify(cl_prj, ":p:h")
    let cl_name=fnamemodify(cl_prj, ":t:r")

    let sourcemap = {}

    let state = "Unset"
    let folder = ""

    let lnum = 0
    let numLines = len(fLines)
    while lnum < numLines
        let line = fLines[lnum]
        let line = s:Trim(line)
        if state == "Unset"
            if line =~ '<CodeLite_Project Name'
                let pairs = split(line)
                for p in pairs
                    if p =~ "Name.*"
                        let cl_name = split(p, "=")[1]
                        let cl_name=cl_name[1:strlen(cl_name)-2]
                    endif
                endfor
            elseif line =~ '<VirtualDirectory'
                let state = "Files"
                let folder = substitute(line, '<VirtualDirectory Name=\"\([^"]\+\)">', '\1', "")
                if !has_key(sourcemap, folder)
                    let sourcemap[folder] = []
                endif
            endif
        elseif state == "Files"

            if line =~ '</VirtualDirectory.*'
                let state = "Unset"
                let folder = ""
                continue
            endif

            let file = substitute(line, '<File Name=\"\([^"]\+\)"/>', '\1', "")
            call add(sourcemap[folder], file)
        endif
        let lnum += 1
    endwhile

    call s:OpenFold(cl_prj, cl_name, cl_dir)
    for k in keys(sourcemap)
        call s:OpenFold("", k, "")
        let sources = sourcemap[k]
        for s in sources
            call s:AddFile(s, cl_dir)
        endfor
        call s:CloseFold()
    endfor
    call s:CloseFold()

    call s:InsertProject(cl_name, cl_dir)

endfunction
" }}}
"}}}

" ProjectParse {{{
function! s:ProjectParse(f)
    let f = a:f
    call s:InitializeGlobals()
    try
        if     f =~ ".*\.sln"
            call s:ParseVcSln(f)
        elseif f =~ ".*\.vcproj"
            call s:ParseVcProj("", f, "")
        elseif f =~ ".*\.workspace"
            call s:ParseCbWorkspace(f)
        elseif f =~ ".*\.cbp"
            call s:ParseCbProj("", f, "")
        elseif f =~ ".*Makefile\.am"
            call s:ParseAmMakefile(f, "")
        " TODO: implement CMake parsing (very difficult)
        "elseif f =~ ".*CMakeLists\.txt"
            "call s:ParseCmakelist(f, 1)
        elseif f =~ ".*\.mcp"
            call s:ParseMplab(f)
        " TODO: this will likely need some disambiguation in the future
        elseif f =~ ".*\.project"
            call s:ParseCodeLite(f)
        else
            call s:Error("This filetype is not yet supported")
        endif
    catch /.*/
        call s:Error(v:exception)
    endtry
    call s:ClearGlobals()
endfunction
" }}}
" }}}

" Commands {{{
command! -complete=file -nargs=1 ProjectParse :call s:ProjectParse(<f-args>)
command! -nargs=0 ProjectUpdate :call s:UpdateProjects(1)
"}}}

" AutoUpdate {{{
" Upon sourcing this file, update all projects that are out of date
if !exists("g:ProjectParseNoAutoUpdate")
    call s:UpdateProjects(0)
endif
"}}}

