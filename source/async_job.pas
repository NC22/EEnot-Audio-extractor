unit async_job;


interface
 
uses common_base_types, Windows, SysUtils, classes;

type
  
  TrJobSelf = record
    Handle  : THandle;      // Handle link of thread process
    EgoFileManager : IEgoFileManagerInterface;
    SaveTo : string;
    AllInOneDir : boolean;
    Cancel : boolean;
    InUse : boolean;
  end;

  function ThreadJobInit : boolean;
  function ThreadJobSavePackages(EgoFManager : IEgoFileManagerInterface; saveDir : string; all : boolean) : boolean;

var

  ThreadJobThreadState : TrJobSelf;

implementation

// http://forum.doom9.org/archive/index.php/t-161792.html

function ThreadJobSavePackagesThread(param : pointer): integer;
var
  packDir : string;
  info : TAudioInfo;
  packageInfo : TPackageInfo;
  i, b : integer;
  state : TPackageWorkInfo;
  saveTo : string;
begin
  result := 0;
  saveTo := ThreadJobThreadState.SaveTo;

  state.fname := '';
  state.fkey := -1;
  state.pkey := -1;
  state.notice := '';
  state.state := 'fail';

  with ThreadJobThreadState do begin
  if Length(saveTo) = 0 then begin
     EgoFileManager.ExecEventSavePackagesEnd(state);
     InUse := False;
     state.notice := 'Save directory not setted';
     ExitThread(0);
     exit;
  end;

  if saveTo[length(saveTo)] <> '\' then
  saveTo := saveTo + '\';

  if not DirectoryExists(saveTo) and not ForceDirectories(saveTo) then begin
    EgoFileManager.ExecEventSavePackagesEnd(state);
    InUse := False;
    ExitThread(0);
    exit;
  end;

  packDir := '';
  for i := 0 to EgoFileManager.PackagesCount-1 do begin

      EgoFileManager.GetPackageInfo(i, packageInfo);

      if not ThreadJobThreadState.AllInOneDir then begin
          { If Not DirectoryExists(AppTempPath) then try ForceDirectories(AppTempPath);}
          packDir := saveTo + packageInfo.PackageName + '\';
          if not DirectoryExists(packDir) and not ForceDirectories(packDir) then begin
            EgoFileManager.ExecEventSavePackagesEnd(state);
            InUse := False;
            state.notice := 'Can not create new directory : ' + packDir;
            ExitThread(0);
            exit;
          end;
      end
      else packDir := saveTo;

      for b := 0 to packageInfo.FilesNum-1 do begin
          EgoFileManager.GetPackageItemInfo(i, b, info);

          state.fkey := b;
          state.pkey := i;
          state.fname := info.FileName;
          if (Cancel) then begin
              state.state := 'fail';
              EgoFileManager.ExecEventSavePackagesEnd(state);
              InUse := False;
              ExitThread(0);
              exit;
          end
          else if not EgoFileManager.SavePackageItem(i, b, packDir, info.FileName) then begin
            state.state := 'fail';
          end
          else begin
            state.state := 'ok';
          end;

          EgoFileManager.ExecEventSaveItemEnd(state);
      end;
  end;

    state.state := 'ok';
    EgoFileManager.ExecEventSavePackagesEnd(state);
    InUse := False;
    ExitThread(0);
  end;
end;

function ThreadJobSavePackagesFromAllThread(param : pointer): integer;
begin
    result := 0;
end;

function ThreadJobInit : boolean;
begin
  Result := true;
  ThreadJobThreadState.InUse := false;
end;

function ThreadJobSavePackages(EgoFManager : IEgoFileManagerInterface; saveDir : string; all : boolean) : boolean;
var
  TID: Cardinal;
begin
    result := false;

    with ThreadJobThreadState do begin
      if inUse then exit;

      InUse := true;
      AllInOneDir := all;
      Cancel := false;
      saveTo := saveDir;
      EgoFileManager := EgoFManager;
      Handle := BeginThread(nil, 0, ThreadJobSavePackagesThread, nil, 0, TID);
   end;

   result := true;
end;

end.