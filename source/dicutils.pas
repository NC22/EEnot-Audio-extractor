unit dicutils;

interface

uses classes, sysutils, wavutils, mmsystem, filesearch, c_player, common_base_types, async_job;

type
  // в необозримом будущем ExportFile addfile ReplaceFile DeleteFile     
  // “ипы данных файла формата *.dic

  TDicHeader = packed record // 16 byte
    Format : array [0..3] of AnsiChar; // 4 байта, строка "DIC1"
	  Unknown  : array [0..3] of AnsiChar; // 4 байта, ?
	  Version : array [0..3] of AnsiChar; // верси€ формата
	  PackageNum : longint; // 4 байта, количество пакетов в словаре - l-end
  end;
  
  TDicPackage = packed record // Seek - TDicHeader.packageNum * sizeof(TDicPackage)
      FilelistStart : longint; // 4 байта, кол-во байт от начала файла, до начала списка файлов содержащихс€ в пакете - обратный пор€док байт
	  FileNum : longint; // 4 байта, количество файлов в пакете - обратный пор€док байт
      Name : array [0..15] of AnsiChar; // 16 байта, название файла - пакета. файл пакет - формат указан в описании списка файлов пакета
      // файл может находитс€ в поддирректории относительно дирректории размещени€ файла dic, название поддиректории зарание неизвестно
  end;
  
  TDicFile = packed record
    Freq : array[0..1] of Byte; // 2 байта, частота проигрывани€ волны PCM (дл€ WIP файлов), Ogg (дл€ WIO), u-Law (дл€ WIM) Hz - обратный пор€док байт, выводить с преобразованием в longint
    // битность нигде не указана, ставим 16 бит?
    Flags : array[0..1] of Byte; // первый байт - параметры воспроизведени€ 10 - loop 30 - loop + stereo 20 - stereo 00 - none F0 - ?
    // второй байт - ? параметры 80 - ? 00 - ? 
    Name : array [0..15] of AnsiChar; // название файла-вложени€
    Ending : longint; // 4 байта, количество байт до конца файла-вложени€ в файле-пакете - 1 - обратный пор€док байт (последний файл может невмещ€тс€)
  end;
  
  TDicPackageFileList = packed record
    Nop : array[0..3] of AnsiChar; // 4 байта, всегда 0x00
    Files : array of TDicFile; // по количеству в пакете
    Format : array [0..3] of AnsiChar; // формат файла-пакета
  end; 
  
  // возвращаемые типы данных класса

  TDicPackageListItem = record
    PackageName : array [0..15] of AnsiChar;
    Files : array of TDicFile;
    Format : array [0..3] of AnsiChar;
   	Path : string[255];
  end;
  
  TDicPackageList = array of TDicPackageListItem;

  TDicFileManager = Class(TInterfacedObject, IEgoFileManagerInterface)
    private 
	  LastError : string;
    DicPath : string;
    DicStream : TStream;
   	SearchDir : string;

	  PackageList: TDicPackageList;

    FOnSaveItemEnd : TPackageWorkEvent;
    FOnSavePackagesEnd : TPackageWorkEvent;

	  function ReadDicHeader(var Stream : TStream; var DicHeader : TDicHeader) : boolean;
    
    function GetPackageItemFormat(pkey, fkey : integer; var format : string) : boolean;
    function LoadWavToBuffer(pkey, fkey : integer; var F : TFileStream; var buffer : TBytes) : boolean;
    function LoadOggToBuffer(pkey, fkey : integer; var F : TFileStream; var buffer : TBytes) : boolean;
    function getReadFromFilePos(pkey, fkey : integer; var StartPos, EndPos, Len, ActualLen : integer; var F : TFileStream) : boolean;
		procedure UnloadDic;

    public
    unknownType : SmallInt;  // дл€ поиска неизвестного кодека

    property OnSaveItemEnd : TPackageWorkEvent read FOnSaveItemEnd write FOnSaveItemEnd;
    property OnSavePackagesEnd : TPackageWorkEvent read FOnSavePackagesEnd write FOnSavePackagesEnd;
                                               
	  function getLastError : string;
    function PackagesCount : integer;

    function GetPackageInfo(pkey: integer; var info : TPackageInfo) : boolean;

    function LoadFileToBuffer(pkey : integer; fkey : integer; var buffer : TBytes) : boolean; // дл€ проигрывани€ \ использовани€
    function GetPackagePath(pkey : integer) : string;

    function GetPackageItemInfo(pkey, fkey: integer; var info : TAudioInfo) : boolean;

    function SavePackageItem(pkey : integer; fkey : integer; saveTo, fname : string) : boolean;

    function Load(DicFile : string) : boolean;

    procedure ExecEventSaveItemEnd(State: TPackageWorkInfo);
    procedure ExecEventSavePackagesEnd(State: TPackageWorkInfo);

    Constructor Create;
    Destructor  Destroy;
  end;

implementation

Constructor TDicFileManager.Create;
begin
  Inherited Create;

  unknownType := $0006;
   // MediaPlayer := TMediaPlayer.Create(nil);

  FOnSaveItemEnd := nil;
  FOnSavePackagesEnd := nil;
  
	DicPath := '';
	DicStream := nil;
    LastError := '';
    
	SearchDir := '';
	SetLength(PackageList, 0);
end;

destructor TDicFileManager.Destroy;
begin
	UnloadDic;
	inherited;
end;

{Private functions}

procedure TDicFileManager.UnloadDic;
var
  b, i : Integer;
begin
    if DicStream <> nil then begin
        DicStream.Free;
        DicStream := nil;
    end;
    
    for i := 0 to Length(PackageList)-1 do begin
        for b := 0 to Length(PackageList[i].Files)-1 do begin
          Finalize(PackageList[i].Files[b]);
          FillChar(PackageList[i].Files[b], sizeof(PackageList[i].Files[b]), 0);
        end;
    end;
	
	SetLength(PackageList, 0);
end;

function TDicFileManager.ReadDicHeader(var Stream : TStream; var DicHeader : TDicHeader) : boolean;
begin
  Result := true;
  Stream.Read(DicHeader, sizeof(TDicHeader));
  with DicHeader do begin
      if Format <> 'DIC1' then begin
		      LastError := 'Wrong format';
		      Result := false;
	    end;
  end;
end;
 
function TDicFileManager.GetPackageItemFormat(pkey, fkey : integer; var format : string) : boolean;
begin
    format := '';
    Result := false;
    if Length(PackageList)-1 < pkey then begin
        LastError := 'Unexist index ' + IntToStr(pkey);
        Exit;
    end;

    if PackageList[pkey].Format = 'WIM' then format := 'wav'
    else if PackageList[pkey].Format = 'WIA' then format := 'wav'
    else if PackageList[pkey].Format = 'WIP' then format := 'wav'
    else if PackageList[pkey].Format = 'WIO' then format := 'ogg'
    else begin
        LastError := 'Unknown format';
        Exit;
    end;

    Result := true;
end;

{Public functions}

function TDicFileManager.PackagesCount : integer;
begin
   Result := Length(PackageList);
end;

function TDicFileManager.GetPackageInfo(pkey: integer; var info : TPackageInfo) : boolean;
begin
  Result := false;
  if (Length(PackageList) = 0) or (pkey > High(PackageList)) or (pkey < 0) then exit;
  info.PackageName := PackageList[pkey].PackageName + '.' + PackageList[pkey].Format;
  info.Format := PackageList[pkey].Format;
  info.FilesNum := Length(PackageList[pkey].Files);
  Result := true;
end;

procedure TDicFileManager.ExecEventSaveItemEnd(State: TPackageWorkInfo);
begin
  if Assigned(FOnSaveItemEnd) then FOnSaveItemEnd(State);
end;

procedure TDicFileManager.ExecEventSavePackagesEnd(State: TPackageWorkInfo);
begin
  if Assigned(FOnSavePackagesEnd) then FOnSavePackagesEnd(State);
end;

function TDicFileManager.GetPackageItemInfo(pkey, fkey: integer; var info : TAudioInfo) : boolean;
begin
  Result := false;
  if not GetPackageItemFormat(pkey, fkey, info.FileFormat) then exit;
  info.FileName := PackageList[pkey].Files[fkey].Name + '.' + info.FileFormat;

  info.isStereo := false;
  info.Channels := 1;
  if (PackageList[pkey].Files[fkey].Flags[0] <> $10) and
     (PackageList[pkey].Files[fkey].Flags[0] <> $00) then begin
    info.isStereo := true;
    info.Channels := 2;
  end;

  info.SamplesPerSec := 0;
  Move(PackageList[pkey].Files[fkey].Freq, info.SamplesPerSec, 2);
  info.wavType := -1;
  info.BitsPerSample := -1;

  if PackageList[pkey].Format = 'WIM' then begin
    info.wavType := $0007;
    info.BitsPerSample := 8;

    // у одного из файлов флаги F0 00 - проигрываетс€ норм. на частоте х4
    // у другого 30 80 - проигрываетс€ на частоте по умолчанию

    if PackageList[pkey].Files[fkey].Flags[1] = $00 then
     info.SamplesPerSec := info.SamplesPerSec * 4;
  end
  else if PackageList[pkey].Format = 'WIA' then begin
    info.wavType := $0006;
    // info.BitsPerSample := 3;
    // Stereo := 1;
    info.BitsPerSample := 8;
  end
  else if PackageList[pkey].Format = 'WIP' then begin
    info.wavType := $0001;
    info.BitsPerSample := 16;
  end;

  Result := true;
end;

function TDicFileManager.GetPackagePath(pkey : integer) : string;
var
  AudioFileList : TStringList;
  packageFileName : string;
begin
  Result := '';
  if High(PackageList) < pkey then exit;
  
  Result := PackageList[pkey].Path;
  if PackageList[pkey].Path <> '' then Exit;

  packageFileName := string(PackageList[pkey].PackageName) + '.' + string(PackageList[pkey].Format);
  if SearchDir[length(SearchDir)] <> '\' then SearchDir := SearchDir + '\';

  if FileExists(SearchDir + packageFileName) then begin
      PackageList[pkey].Path := SearchDir + packageFileName;
      Result := PackageList[pkey].Path;
      exit;
  end;
  
  AudioFileList := TStringList.Create;
  FileSearchFindFiles(AudioFileList, SearchDir, packageFileName, 2, 1);

  if AudioFileList.Count > 0 then PackageList[pkey].Path := AudioFileList[0];
  AudioFileList.Free;  
  
	Result := PackageList[pkey].Path;
end;

function TDicFileManager.getReadFromFilePos(pkey, fkey : integer; var StartPos, EndPos, Len, ActualLen : integer; var F : TFileStream) : boolean;
begin
    Result := false;
    if (High(PackageList) < pkey) or (High(PackageList[pkey].Files) < fkey) then exit;

    StartPos := 0;
    if fkey - 1 >= 0 then StartPos := PackageList[pkey].Files[fkey - 1].Ending;

    EndPos := PackageList[pkey].Files[fkey].Ending - 1;
    ActualLen := EndPos - StartPos;

    if (F <> nil) and (EndPos > F.Size) then EndPos := F.Size;

    Len := EndPos - StartPos;

    if (Len < 0) or (ActualLen < 0) then begin
        LastError := 'Bad data';
        Exit;
    end;

    Result := true;
end;

function TDicFileManager.LoadWavToBuffer(pkey, fkey : integer; var F : TFileStream; var buffer : TBytes) : boolean;
var
 StartPos, ActualLenAddByte, EndPos, Len, ActualLen : integer;
 
 // Len - длинна в соответствии с размером файла-пакета
 // ActualLen - длинна указана€ в файле дл€ муз. файла
 
 WavNoPcmHeader : TNoPcmWaveHeader;
 AudioFileInfo : TAudioInfo;

 PaddingByte : smallint; // если нечетное число байт в дата-блоке, добавл€ем пустой отступ     
 bufferSeek : integer;

 i : integer;
begin    
    Result := false;

    PaddingByte := 0;
    ActualLenAddByte := 0;

    if not getReadFromFilePos(pkey, fkey, StartPos, EndPos, Len, ActualLen, F) then exit;
    if Len < ActualLen then ActualLenAddByte := ActualLen - Len;
    if Odd(ActualLen) then PaddingByte := 1;

    if not GetPackageItemInfo(pkey, fkey, AudioFileInfo) then exit;
    if AudioFileInfo.wavType = -1 then exit;

    bufferSeek := sizeof(TNoPcmWaveHeader);
    //LastError := intToStr(AudioFileInfo.SamplesPerSec) + 'start ' + intToStr(AudioFileInfo.BitsPerSample) + ' end ' + intToStr(EndPos) + ' | ' + intToStr(Len) + ' | ' + intToStr(ActualLen) + ' | ' + intToStr(ActualLenAddByte);
    //LastError := LastError + ' AND ' + IntToStr(AudioFileInfo.Channels) + ' f ' + IntToStr(AudioFileInfo.wavType);
    if not CreateNoPcmWaveHeader(
            ActualLen,
            PaddingByte,
            AudioFileInfo.SamplesPerSec,
            AudioFileInfo.BitsPerSample,
            AudioFileInfo.Channels,
            AudioFileInfo.wavType,
            WavNoPcmHeader) then begin
      LastError := 'Create wave header fail';
      Exit;
    end;

    SetLength(buffer, bufferSeek);
    Move(WavNoPcmHeader, buffer[0], bufferSeek); 
    SetLength(buffer, Length(buffer) + Len);
    
    try
        F.Seek(StartPos, soFromBeginning);
        F.Read(buffer[bufferSeek], Len);
    except 
        LastError := 'Read to buffer fail';
        Exit;
    end;

    if (PaddingByte > 0) or (ActualLenAddByte > 0) then begin
        for i := 1 to PaddingByte + ActualLenAddByte do
        begin
            SetLength(buffer, Length(buffer)+1);
            buffer[Length(buffer)-1] := $00;
        end;
    end;
    
    Result := true;
end;

function TDicFileManager.LoadOggToBuffer(pkey, fkey : integer; var F : TFileStream; var buffer : TBytes) : boolean;
var
 StartPos : integer;
 EndPos : integer;
 Len : integer;
 ActualLen : integer;

 ActualLenAddByte : smallint;
 i : integer;
begin
    Result := false;

    if not getReadFromFilePos(pkey, fkey, StartPos, EndPos, Len, ActualLen, F) then exit;
    SetLength(buffer, Len);

    try
        F.Seek(StartPos, soFromBeginning);
        F.Read(buffer[0], Len);
    except 
        LastError := 'Read to buffer fail';
        Exit;
    end;

    ActualLenAddByte := 0;
    if Len < ActualLen then ActualLenAddByte := ActualLen - Len;

    if ActualLenAddByte > 0 then begin
        for i := 1 to ActualLenAddByte do
        begin
            SetLength(buffer, Length(buffer)+1);
            buffer[Length(buffer)-1] := $00;
        end;
    end;
    
    Result := true;
end;

function TDicFileManager.LoadFileToBuffer(pkey : integer; fkey : integer; var buffer : TBytes) : boolean;
var 
   Path : string;
   F: TFileStream;
   fileFormat : string;
begin
  Result:= false;
  setLength(buffer, 0);
    
	Path := GetPackagePath(pkey);
  F := nil;

	if (pkey > Length(PackageList)) or (pkey < 0) then begin
		LastError := 'Unexist package index';
		Exit;
	end;

	if (fkey > Length(PackageList[pkey].Files)) or (fkey < 0) then begin
		LastError := 'Unexist file index';
		Exit;
	end;

	if Length(Path) = 0 then begin
		LastError := 'File not found';
		Exit;
	end;  
    
  if not GetPackageItemFormat(pkey, fkey, fileFormat) then begin
      LastError := 'Unknown format';
      Exit;
  end;
    
	try
        try
            F := TFileStream.Create(Path, fmOpenRead);
            
            if fileFormat = 'wav' then begin
                Result := LoadWavToBuffer(pkey, fkey, F, buffer);
            end
            else if fileFormat = 'ogg' then begin
                Result := LoadOggToBuffer(pkey, fkey, F, buffer);
            end
            else begin
                LastError := 'Unknown format';
                Exit;
            end;
        except 
            LastError := 'Read to buffer fail';
            Exit;
        end;
	finally
    if F <> nil then F.Free;
	end;
    
end;

function TDicFileManager.SavePackageItem(pkey : integer; fkey : integer; saveTo, fname : string) : boolean;
var
 NewF : TFileStream;
 buffer : TBytes;
 itemFormat : string;
begin
    Result:= false;
    NewF := nil;

    if not GetPackageItemFormat(pkey, fkey, itemFormat) then begin
      exit;
    end;

    if fname = '' then fname := PackageList[pkey].Files[fkey].Name + '.' + itemFormat;

	  try
        if not LoadFileToBuffer(pkey, fkey, buffer) then begin
          Exit;
        end;

        try
            if saveTo[length(saveTo)] <> '\' then saveTo := saveTo + '\';
            // create and rewrite
            NewF := TFileStream.Create(saveTo + fname, fmCreate);
            NewF.Write(buffer[0], Length(buffer));
        except
            LastError := 'Write to file fail';
            Exit;
        end;
   	finally
        if NewF <> nil then NewF.Free;
	  end;

    Result := true;
end;

// unload previouse data and load new one

function TDicFileManager.Load(DicFile : string) : boolean;
var
  DicHeader : TDicHeader;
  TmpPackage : TDicPackage; 
  TmpPackageFilelist : TDicPackageFileList;
  i : integer;
  b : integer;
  nextPackagePos : integer;
begin
    Result := false;

    if Length(DicFile) <= 0 then begin
        LastError := 'Filename is incorrect';
        Exit;
    end;
    
    UnloadDic;
    
    SearchDir := ExtractFilePath(DicFile);
    DicPath := DicFile;

    i := 0;
    b := 0;

    try
        DicStream := TFileStream.Create(DicPath, fmOpenRead);
    except
        DicStream := nil;
        LastError := 'Dic file open fail';
        Exit;
    end;
    
    try
        try 
        DicStream.Seek(0, soFromBeginning);
        
        if not ReadDicHeader(DicStream, DicHeader) then begin
            LastError := 'Dic header read fail';
            Exit;
        end;
        
        SetLength(PackageList, DicHeader.PackageNum);
     
        for i := 0 to DicHeader.PackageNum-1 do begin
            DicStream.Read(TmpPackage, sizeof(TDicPackage));
            nextPackagePos := DicStream.Position;

            DicStream.Seek(TmpPackage.FilelistStart, soFromBeginning);

            // читаем список файлов
            DicStream.Read(TmpPackageFilelist.Nop, sizeof(TmpPackageFilelist.Nop));
            
            PackageList[i].Path := '';
            SetLength(TmpPackageFilelist.Files, TmpPackage.FileNum);
            SetLength(PackageList[i].Files, TmpPackage.FileNum);
            
            for b := 0 to TmpPackage.FileNum-1 do begin
                //Stream.Read(TmpPackageFilelist.Files[b], sizeof(TDicFile));
                DicStream.Read(PackageList[i].Files[b], sizeof(TDicFile));
            end;

            DicStream.Read(TmpPackageFilelist.Format, sizeof(TmpPackageFilelist.Format));

            // Move(TmpPackageFilelist.Files, PackageList[i].Files, sizeof(PackageList[i].Files));


            Move(TmpPackage.Name, PackageList[i].PackageName, sizeof(TmpPackage.Name));
            Move(TmpPackageFilelist.Format, PackageList[i].Format, sizeof(TmpPackageFilelist.Format));

            DicStream.Seek(nextPackagePos, soFromBeginning);
        end;
        Result := true;
        except
            LastError := 'Dic file corrupt or new version';
        end;
    finally
        DicStream.Free;
        DicStream := nil;
    end;
end;

function TDicFileManager.getLastError : string;
begin
  result := self.LastError;
end;

end.