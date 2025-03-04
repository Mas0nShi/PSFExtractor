function Native($DllFile) {
    $Lib = [IO.Path]::GetFileName($DllFile)
    $Marshal = [System.Runtime.InteropServices.Marshal]
    $Module = [AppDomain]::CurrentDomain.DefineDynamicAssembly((Get-Random), 'Run').DefineDynamicModule((Get-Random))
    $Struct = $Module.DefineType('DI', 1048841, [ValueType], 0)
    [void]$Struct.DefineField('lpStart', [IntPtr], 6)
    [void]$Struct.DefineField('uSize', [UIntPtr], 6)
    [void]$Struct.DefineField('Editable', [Boolean], 6)
    $DELTA_INPUT = $Struct.CreateType()
    $Struct = $Module.DefineType('DO', 1048841, [ValueType], 0)
    [void]$Struct.DefineField('lpStart', [IntPtr], 6)
    [void]$Struct.DefineField('uSize', [UIntPtr], 6)
    $DELTA_OUTPUT = $Struct.CreateType()
    $Class = $Module.DefineType('PSFE', 1048961, [Object], 0)
    [void]$Class.DefinePInvokeMethod('LoadLibraryW', 'kernel32.dll', 22, 1, [IntPtr], @([String]), 1, 3).SetImplementationFlags(128)
    [void]$Class.DefinePInvokeMethod('ApplyDeltaB', $Lib, 22, 1, [Int32], @([Int64], [Type]$DELTA_INPUT, [Type]$DELTA_INPUT, [Type]$DELTA_OUTPUT.MakeByRefType()), 1, 3)
    [void]$Class.DefinePInvokeMethod('DeltaFree', $Lib, 22, 1, [Int32], @([IntPtr]), 1, 3)
    $Win32 = $Class.CreateType()
}
function ApplyDelta($dBuffer, $dFile) {
    $trg = [Activator]::CreateInstance($DELTA_OUTPUT)
    $src = [Activator]::CreateInstance($DELTA_INPUT)
    $dlt = [Activator]::CreateInstance($DELTA_INPUT)
    $dlt.lpStart = $Marshal::AllocHGlobal($dBuffer.Length)
    $dlt.uSize = [Activator]::CreateInstance([UIntPtr], @([UInt32]$dBuffer.Length))
    $dlt.Editable = $true
    $Marshal::Copy($dBuffer, 0, $dlt.lpStart, $dBuffer.Length)
    [void]$Win32::ApplyDeltaB(0, $src, $dlt, [ref]$trg)
    if ($trg.lpStart -eq [IntPtr]::Zero) { return }
    $out = New-Object byte[] $trg.uSize.ToUInt32()
    $Marshal::Copy($trg.lpStart, $out, 0, $out.Length)
    [IO.File]::WriteAllBytes($dFile, $out)
    if ($dlt.lpStart -ne [IntPtr]::Zero) { $Marshal::FreeHGlobal($dlt.lpStart) }
    if ($trg.lpStart -ne [IntPtr]::Zero) { [void]$Win32::DeltaFree($trg.lpStart) }
}
function G($DirectoryName) {
    $DeltaList = [ordered] @{}
    $doc = New-Object xml
    $doc.Load($DirectoryName + "\express.psf.cix.xml")
    $child = $doc.FirstChild.NextSibling.FirstChild
    while (!$child.LocalName.Equals("Files")) { $child = $child.NextSibling }
    $FileList = $child.ChildNodes
    foreach ($file in $FileList) {
        $fileChild = $file.FirstChild
        while (!$fileChild.LocalName.Equals("Delta")) { $fileChild = $fileChild.NextSibling }
        $deltaChild = $fileChild.FirstChild
        while (!$deltaChild.LocalName.Equals("Source")) { $deltaChild = $deltaChild.NextSibling }
        $DeltaList[$($file.id)] = @{name = $file.name; time = $file.time; stype = $deltaChild.type; offset = $deltaChild.offset; length = $deltaChild.length };
    }
    return $DeltaList
}
function P($CabFile, $DllFile = 'msdelta.dll') {
    if ($DllFile -eq 'msdelta.dll' -and (Test-Path "$env:SystemRoot\System32\UpdateCompression.dll")) { $DllFile = "$env:SystemRoot\System32\UpdateCompression.dll" }
    . Native($DllFile)
    [void]$Win32::LoadLibraryW($DllFile)
    $DirectoryName = $CabFile.Substring(0, $CabFile.LastIndexOf('.'))
    $PSFFile = $DirectoryName + ".psf"
    $null = [IO.Directory]::CreateDirectory($DirectoryName)
    $DeltaList = G  $DirectoryName
    $PSFFileStream = [IO.File]::OpenRead([IO.Path]::GetFullPath($PSFFile))
    $cwd = [IO.Path]::GetFullPath($DirectoryName)
    [Environment]::CurrentDirectory = $cwd
    $null = [IO.Directory]::CreateDirectory("000")
    foreach ($DeltaFile in $DeltaList.Values) {
        $FullFileName = $DeltaFile.name
        if (Test-Path $FullFileName) { continue }
        $ShortFold = [IO.Path]::GetDirectoryName($FullFileName)
        $ShortFile = [IO.Path]::GetFileName($FullFileName)
        [bool]$UseRobo = (($cwd + '\' + $FullFileName).Length -gt 255) -or (($cwd + '\' + $ShortFold).Length -gt 248)
        if ($UseRobo -eq 0 -and $ShortFold.IndexOf("_") -ne -1) { $null = [IO.Directory]::CreateDirectory($ShortFold) }
        if ($UseRobo -eq 0) { $WhereFile = $FullFileName }
        Else { $WhereFile = "000\" + $ShortFile }
        try { [void]$PSFFileStream.Seek($DeltaFile.offset, 0) } catch {}
        $Buffer = New-Object byte[] $DeltaFile.length
        try { [void]$PSFFileStream.Read($Buffer, 0, $DeltaFile.length) } catch {}
        $OutputFileStream = [IO.File]::Create($WhereFile)
        try { [void]$OutputFileStream.Write($Buffer, 0, $DeltaFile.length) } catch {}
        [void]$OutputFileStream.Close()
        if ($DeltaFile.stype -eq "PA30" -or $DeltaFile.stype -eq "PA31") { ApplyDelta $Buffer $WhereFile }
        $null = [IO.File]::SetLastWriteTimeUtc($WhereFile, [DateTime]::FromFileTimeUtc($DeltaFile.time))
        if ($UseRobo -eq 0) { continue }
        Start-Process robocopy.exe -NoNewWindow -Wait -ArgumentList ('"' + $cwd + '\000' + '"' + ' ' + '"' + $cwd + '\' + $ShortFold + '"' + ' ' + $ShortFile + ' /MOV /R:1 /W:1 /NS /NC /NFL /NDL /NP /NJH /NJS')
    }
    [void]$PSFFileStream.Close()
    $null = [IO.Directory]::Delete("000", $True)
}