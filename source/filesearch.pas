unit filesearch;

interface

uses sysutils, classes;

procedure FileSearchFindFiles(FilesList: TStringList; StartDir, FileMask: string; maxRLevel, curRLevel : integer);

implementation

procedure FileSearchFindFiles(FilesList: TStringList; StartDir, FileMask: string; maxRLevel, curRLevel : integer);
var
  SR: TSearchRec;
  DirList: TStringList;
  IsFound: Boolean;
  i: integer;
begin

  if curRLevel > maxRLevel then Exit;

  if StartDir[length(StartDir)] <> '\' then
    StartDir := StartDir + '\';

  { Build a list of the files in directory StartDir
     (not the directories!)                         }

  IsFound :=
    FindFirst(StartDir+FileMask, faAnyFile-faDirectory, SR) = 0;
  while IsFound do begin
    FilesList.Add(StartDir + SR.Name);
    IsFound := FindNext(SR) = 0;
  end;
  FindClose(SR);

  if curRLevel + 1 > maxRLevel then Exit; // can go deeper ?

  // Build a list of subdirectories
  DirList := TStringList.Create;
  IsFound := FindFirst(StartDir + '*.*', faAnyFile, SR) = 0;
  while IsFound do begin
    if ((SR.Attr and faDirectory) <> 0) and
         (SR.Name[1] <> '.') then
      DirList.Add(StartDir + SR.Name);
    IsFound := FindNext(SR) = 0;
  end;
  FindClose(SR);

  // Scan the list of subdirectories
  for i := 0 to DirList.Count - 1 do
    FileSearchFindFiles(FilesList, DirList[i], FileMask, maxRLevel, curRLevel + 1);

  DirList.Free;
end;

end.