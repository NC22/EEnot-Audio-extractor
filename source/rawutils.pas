unit rawutils;

interface

uses classes, sysutils, dicutils, wavutils, mmsystem, filesearch, c_player, common_base_types;

type

  TRawPackageItem = record
    Name : string;
    Format : string;
   	Path : string;
  end;
  
  TRawPackage = record
    Name : string;
    Files : array of TRawPackageItem;
  end;

  TRawFile = Class(TInterfacedObject, IEgoFileManagerInterface)
    private 
	  LastError : string;
    BasePath : string;
    Mid : string;
    
    PackageList : array of TRawPackage;
    FOnSaveItemEnd : TPackageWorkEvent;
    FOnSavePackagesEnd : TPackageWorkEvent;                            
    function getReadFromFilePos(var StartPos, EndPos, Len: integer; var F : TFileStream) : boolean;
    function GetPackageKeyByName(Name : string) : integer;
    procedure unloadRaw;
		
    public
    property _BasePath : string read BasePath;
    property OnSaveItemEnd : TPackageWorkEvent read FOnSaveItemEnd write FOnSaveItemEnd;
    property OnSavePackagesEnd : TPackageWorkEvent read FOnSavePackagesEnd write FOnSavePackagesEnd;

    function getLastError : string;
    function PackagesCount : integer;

    function GetManagerId : string;
    function GetPackagePath(pkey : integer) : string;
    function GetPackageInfo(pkey: integer; var info : TPackageInfo) : boolean;
    function GetPackageItemInfo(pkey, fkey: integer; var info : TAudioInfo) : boolean;

    function SavePackageItem(pkey : integer; fkey : integer; saveTo, fname : string) : boolean;

    function LoadFileToBuffer(pkey : integer; fkey : integer; var buffer : TBytes) : boolean; // для проигрывания \ использования

    procedure ExecEventSaveItemEnd(State: TPackageWorkInfo);
    procedure ExecEventSavePackagesEnd(State: TPackageWorkInfo);
    
    function Load(RawFile : string) : boolean;

    Constructor Create;
    Destructor  Destroy; override;
  end;

implementation

Constructor TRawFile.Create;
begin
    Inherited Create;
    self._AddRef;
    SetLength(PackageList, 0);

	  BasePath := '';
    LastError := '';
    Mid := 'RAW';
end;

destructor TRawFile.Destroy;
begin
  unloadRaw;
  self._Release;
	inherited;
end;

{Private functions}

procedure TRawFile.unloadRaw;
begin
    SetLength(PackageList, 0);
end;

function TRawFile.getReadFromFilePos(var StartPos, EndPos, Len : integer; var F : TFileStream) : boolean;
begin
    StartPos := 0;
    EndPos := F.Size;

    Len := EndPos - StartPos;
    Result := true;
end;

function TRawFile.GetManagerId : string;
begin
  Result := Mid;
end;

{Public functions}

function TRawFile.getLastError : string;
begin
  result := self.LastError;
end;

function TRawFile.GetPackagePath(pkey : integer) : string;
begin
    Result := '';
    if High(PackageList) < pkey then exit;
	Result := BasePath + PackageList[pkey].Name;
end;

function TRawFile.GetPackageItemInfo(pkey, fkey: integer; var info : TAudioInfo) : boolean;
begin
    Result:= false; 
    if (High(PackageList) < pkey) or (High(PackageList[pkey].Files) < fkey) then exit;

    info.FileFormat := PackageList[pkey].Files[fkey].Format;
    info.FileName := PackageList[pkey].Files[fkey].Name + '.' + info.FileFormat;

    info.isStereo := true;
    info.Channels := 2;
    info.SamplesPerSec := 16000;
    info.wavType := $0001;
    info.BitsPerSample := 16;

    Result := true;
end;

function TRawFile.GetPackageInfo(pkey: integer; var info : TPackageInfo) : boolean;
begin
  Result := false;
  if (Length(PackageList) = 0) or (pkey > High(PackageList)) or (pkey < 0) then exit;
  info.PackageName := PackageList[pkey].Name;
  info.Format := '';
  info.FilesNum := Length(PackageList[pkey].Files);
  Result := true;
end;

function TRawFile.PackagesCount : integer;
begin
   Result := Length(PackageList);
end;

procedure TRawFile.ExecEventSaveItemEnd(State: TPackageWorkInfo);
begin
  if Assigned(FOnSaveItemEnd) then FOnSaveItemEnd(State);
end;

procedure TRawFile.ExecEventSavePackagesEnd(State: TPackageWorkInfo);
begin
  if Assigned(FOnSavePackagesEnd) then FOnSavePackagesEnd(State);
end;

function TRawFile.LoadFileToBuffer(pkey : integer; fkey : integer; var buffer : TBytes) : boolean;
var
 info : TAudioInfo;
 StartPos : integer;
 EndPos : integer;

 Len : integer;

 WavHeader : TNoPcmWaveHeader;

 PaddingByte : smallint;

 bufferSeek : integer;

 F : TFileStream;
begin   
    Result:= false; 
    if not GetPackageItemInfo(pkey, fkey, info) then exit;

    F := nil;

	if Length(PackageList[pkey].Files[fkey].Path) = 0 then begin
		LastError := 'File not found';
		Exit;
	end;  
    
	try
        try
            F := TFileStream.Create(PackageList[pkey].Files[fkey].Path, fmOpenRead);

            PaddingByte := 0;
            if not getReadFromFilePos(StartPos, EndPos, Len, F) then exit;
            if Odd(Len) then PaddingByte := 1;

            bufferSeek := sizeof(WavHeader);
            if not CreateNoPcmWaveHeader(
                    Len, 
                    PaddingByte, 
                    info.SamplesPerSec, 
                    info.BitsPerSample, 
                    info.Channels, 
                    info.WavType, 
                    WavHeader) then begin
                LastError := 'Create wave header fail';
                Exit;
            end;
            
            SetLength(buffer, bufferSeek);
            Move(WavHeader, buffer[0], bufferSeek);
            
            SetLength(buffer, Length(buffer) + Len);
            
            try
                F.Seek(StartPos, soFromBeginning);
                F.Read(buffer[bufferSeek], Len);
            except 
                LastError := 'Read to buffer fail';
                Exit;
            end;
            
            if (PaddingByte > 0) then begin
                SetLength(buffer, Length(buffer)+1);
                buffer[Length(buffer)-1] := $00;
            end;
            
            Result := true;
        except 
            LastError := 'Read to buffer fail';
            Exit;
        end;
	finally
        if F <> nil then F.Free;
	end;
end;

function TRawFile.SavePackageItem(pkey : integer; fkey : integer; saveTo, fname : string) : boolean;
var 
 NewF : TFileStream;
 buffer : TBytes;
begin

    Result:= false;
    if (High(PackageList) < pkey) or (High(PackageList[pkey].Files) < fkey) then
    begin
        exit;
    end;
    NewF := nil;

    if fname = '' then fname := PackageList[pkey].Files[fkey].Name + '.' + PackageList[pkey].Files[fkey].Format;

	  try
        if not LoadFileToBuffer(pkey, fkey, buffer) then begin
           Exit;
         end;

        try
            if saveTo[length(saveTo)] <> '\' then saveTo := saveTo + '\';
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

function TRawFile.GetPackageKeyByName(Name : string) : integer;
var i : integer;
begin
    Result := -1;
    if Name = '' then exit;
    if (Length(PackageList) = 0) then exit;
    for i := 0 to Length(PackageList)-1 do begin
        if PackageList[i].Name = Name then begin 
            Result := i;
            exit;
        end;
    end;
end;

function TRawFile.Load(RawFile : string) : boolean;
var
  AudioFileList : TStringList;
  i : integer;
  PackageName : string;
  PackageIndex : integer;
  FileIndex : integer;
begin
    Result := true;
    BasePath := ExtractFileDir(ExtractFileDir(RawFile)) + '/';
    if not DirectoryExists(BasePath) then begin
        setLength(PackageList, 1);
        PackageList[0].Name := ExtractFileName(ExtractFileDir(RawFile));
        setLength(PackageList[0].Files, 1);
        PackageList[0].Files[0].Name := ChangeFileExt(ExtractFileName(RawFile), '');
        PackageList[0].Files[0].Format := 'wav';
        PackageList[0].Files[0].Path := RawFile;
        exit;
    end;

    
    unloadRaw;
    AudioFileList := TStringList.Create;

    FileSearchFindFiles(AudioFileList, BasePath, '*.raw', 2, 1);


    for i := 0 to AudioFileList.Count-1 do begin
      
        PackageName := ExtractFileName(ExtractFileDir(AudioFileList[i]));
        if PackageName = '' then continue;

        PackageIndex := GetPackageKeyByName(PackageName);
        if PackageIndex = -1 then begin 
            PackageIndex := Length(PackageList);
            setLength(PackageList, Length(PackageList)+1);
            setLength(PackageList[PackageIndex].Files, 0);
        end;
        PackageList[PackageIndex].Name := PackageName;

        FileIndex := Length(PackageList[PackageIndex].Files);
        setLength(PackageList[PackageIndex].Files, Length(PackageList[PackageIndex].Files)+1);

        PackageList[PackageIndex].Files[FileIndex].Path := AudioFileList[i];
        PackageList[PackageIndex].Files[FileIndex].Format := 'wav';
        PackageList[PackageIndex].Files[FileIndex].Name := ChangeFileExt(ExtractFileName(AudioFileList[i]), '');
    end;

    if Length(PackageList) = 0 then Result := false;
    AudioFileList.Free;
end;

end.