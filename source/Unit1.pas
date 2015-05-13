unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, wavutils, dicutils, rawutils, ComCtrls, ImgList, FileCtrl, Buttons,
  ExtCtrls, c_player, Menus, common_base_types, async_job;

type
  TTreeNodeData = class
     PackageKey : Integer;
     FileListKey : Integer;
  end;

  TForm1 = class(TForm)
    btn1: TButton;
    dlgOpen1: TOpenDialog;
    tv1: TTreeView;
    btnsave: TButton;
    btnsaveall: TButton;
    lblFileInfo: TLabel;
    lbl5: TLabel;
    lblAudioFileInfo: TLabel;
    il1: TImageList;
    btnplay: TBitBtn;
    mmo1: TMemo;
    btnstop: TButton;
    lblplaytime: TLabel;
    tmrsoundtick: TTimer;
    btn2: TButton;
    chkcreatesub: TCheckBox;
    btn3: TButton;

    procedure btn1Click(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure SelectTreeNode(Sender: TObject; Node: TTreeNode);
    procedure Init(Sender: TObject);
    procedure btnplayClick(Sender: TObject);
    procedure playtreeitem(Sender: TObject);
    procedure btnstopClick(Sender: TObject);
    procedure btn2Click(Sender: TObject);
    procedure btnsaveallClick(Sender: TObject);
    procedure tooglelogmmo(Sender: TObject);
    procedure CheckClose(Sender: TObject; var CanClose: Boolean);

  private
    currentDir : string;
    mode : string;

    beasy : boolean;
    closeOnbeasyEnd : boolean;

    TinyPlayer : Tplayer;
    DicFile : TDicFileManager;

    EgoFileManager : IEgoFileManagerInterface;

    RawFile : TRawFile;   // will be list by dirrectory names
    
    procedure log(text : string);
    procedure ExpandTree(Tree: TTreeView; Level: integer);
    procedure ClearTree(Tree: TTreeView);
 public
    procedure EventSaveItemEnd(State: TPackageWorkInfo);
    procedure EventSavePackagesEnd(State: TPackageWorkInfo);
  published
     procedure updateSoundTime(Sender: TObject);
     procedure onstopsound(Sender: TObject);
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

// on create

procedure TForm1.Init(Sender: TObject);
const
  Icons: array [0..4] of string = (
  'Music_1',
  'Folder_1',
  'Play_1',
  'Pause_1',
  'Document_1');
var
  i: integer;
  bm, mask: TBitmap;
begin
    ThreadJobInit;

    DicFile := TDicFileManager.Create;
    RawFile := TRawFile.Create;
    EgoFileManager := nil;

    TinyPlayer := Tplayer.Create;
    TinyPlayer.OnMusicEnd := Self.onstopsound;

    mode := '';

    beasy := false;
    closeOnbeasyEnd := false;

    currentDir := GetCurrentDir;

    bm := TBitmap.Create;
    mask := TBitmap.Create;

    for i := 0 to Length(Icons)-1 do begin

        bm.Handle := LoadBitmap( HInstance, PChar(Icons[i]) );
        bm.Width := 16;
        bm.Height := 16;
        bm.Transparent:=true;
        bm.TransparentMode:=tmAuto;


        mask.Assign( bm );
        mask.Mask( clBlue );

        tv1.Images.Add( bm, mask );
    end;

    bm.Free;
    mask.Free;

    il1.GetBitmap(2, btnplay.Glyph);
end;

procedure TForm1.log(text : string);
begin
    if text = '' then exit;
    if mmo1.Lines.Count > 100 then mmo1.Lines.Clear;

    mmo1.Lines.Add(text);
end;

procedure TForm1.btnSaveClick(Sender: TObject);
var
  KeyInfo : TTreeNodeData;
  chosenDirectory : string;
begin
  if (beasy) or (EgoFileManager = nil) then exit;

  if (tv1.Selected = nil) or (tv1.Selected.Data = nil) then exit;

  KeyInfo := TTreeNodeData(tv1.Selected.Data);
  if (KeyInfo.FileListKey <> -1) and (SelectDirectory('Select directory', '', chosenDirectory)) then begin
      EgoFileManager.SavePackageItem(KeyInfo.PackageKey, KeyInfo.FileListKey, chosenDirectory, '');
  end;
end;

procedure TForm1.ClearTree(Tree: TTreeView);
var i : Integer;
begin
    for i := 0 to tv1.Items.Count - 1 do
    begin
        if tv1.Items[i].Data <> nil then begin
          TTreeNodeData(tv1.Items[i].Data).Free;
          tv1.Items[i].Data := nil;
        end;
    end;

    tv1.Items.Clear;
end;

procedure TForm1.ExpandTree(Tree: TTreeView; Level: integer);
var
aNode : TTreeNode;
begin

  if Tree.Items.Count > 0 then begin
  aNode := Tree.Items[0];

  while aNode <> nil do begin
    if aNode.Level = Level then
    aNode.Expand(false);
    aNode := aNode.GetNext;
    end;
  end;
end;

procedure TForm1.btn1Click(Sender: TObject);
var
  i : Integer;
  b : integer;
  parent : TTreeNode;

  head : TTreeNode;
  headName : string;

  audioItemInfo : TAudioInfo;
  packageInfo : TPackageInfo;
begin
    if beasy then exit;

    self.btnstopClick(self);
    btnplay.Enabled := false;
    btnsaveall.Enabled := false;

    dlgOpen1.InitialDir := currentDir;

    if not dlgOpen1.Execute then Exit;

    // set to default previouse data
    ClearTree(tv1);

    // invalid pointer op пока не нужно т.к. load выгружает прошлое
    // if (mode = 'dic') and (DicFile <> nil) then begin
    //    DicFile.Free;
    //    DicFile := TDicFileManager.Create;
    // end;

    //  EgoFileManager := nil;

    mode := '';

    if ExtractFileExt(dlgOpen1.FileName) = '.dic' then begin

      if not DicFile.Load(dlgOpen1.FileName) then begin
        Log('Load dic fail. ' + DicFile.getLastError);
        exit;
      end;

      headName := ExtractFileName(ExtractFileDir(dlgOpen1.FileName));
      headName := headName + '/' + ExtractFileName(dlgOpen1.FileName);
      mode := 'dic';
      EgoFileManager := DicFile;

      DicFile.OnSaveItemEnd := self.EventSaveItemEnd;
      DicFile.OnSavePackagesEnd := self.EventSavePackagesEnd;
    end
    else begin
      if not RawFile.Load(dlgOpen1.FileName) then begin
        Log('Load raw fail. ' + RawFile.getLastError);
        exit;
      end;

      headName := RawFile._BasePath;

      mode := 'raw';
      EgoFileManager := RawFile;
      RawFile.OnSaveItemEnd := self.EventSaveItemEnd;
      RawFile.OnSavePackagesEnd := self.EventSavePackagesEnd;
    end;

    btnsaveall.Enabled := true;
    currentDir := extractFileDir(dlgOpen1.FileName);

    // add current

    tv1.Items.BeginUpdate;
    lblFileInfo.Caption := 'Total packages: ' + IntToStr(EgoFileManager.PackagesCount);

    head := tv1.Items.Add(nil, headName);
    head.ImageIndex := 4;
    head.SelectedIndex := 4;

    for i := 0 to EgoFileManager.PackagesCount-1 do begin
        EgoFileManager.GetPackageInfo(i, packageInfo);

        parent := tv1.Items.AddChild(head, packageInfo.PackageName);
        parent.Data := TTreeNodeData.Create;
        parent.ImageIndex := 1;
        parent.SelectedIndex := 1;
        TTreeNodeData(parent.Data).PackageKey := i;
        TTreeNodeData(parent.Data).FileListKey := -1;

        for b := 0 to packageInfo.FilesNum-1 do begin
            EgoFileManager.GetPackageItemInfo(i, b, audioItemInfo);
            with tv1.Items.AddChild(parent, audioItemInfo.FileName) do begin
                // Log(intToStr(i) + ' | ' + intTostr(b) + ' of ' + intToStr(Length(PackList[i].Files)-1)  + ' of ' + intToStr(Length(PackList)-1));
                Data := TTreeNodeData.Create;
                ImageIndex := 0;
                SelectedIndex := 0;
                TTreeNodeData(Data).PackageKey := i;
                TTreeNodeData(Data).FileListKey := b;
            end;
        end;
    end;
    tv1.Items.EndUpdate;
    ExpandTree(tv1, 0);
end;

procedure TForm1.SelectTreeNode(Sender: TObject; Node: TTreeNode);
var
  KeyInfo : TTreeNodeData;
  AudioFileInfo : TAudioInfo;
  PackageInfo : TPackageInfo;
begin
  if (EgoFileManager = nil) or (Node.Data = nil) then exit;

  lblAudioFileInfo.Caption := '';
  KeyInfo := TTreeNodeData(Node.Data);
  if not EgoFileManager.GetPackageInfo(KeyInfo.PackageKey, PackageInfo) then exit;

  btnsave.Enabled := false;
  btnplay.Enabled := false;

  lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'Package : ' + PackageInfo.PackageName + #13#10;
  lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'Audio files : ' + IntToStr(PackageInfo.FilesNum) + #13#10 + #13#10;

  if KeyInfo.FileListKey <> -1 then begin
    EgoFileManager.GetPackageItemInfo(KeyInfo.PackageKey, KeyInfo.FileListKey, AudioFileInfo);

    if EgoFileManager.GetPackagePath(KeyInfo.PackageKey) = '' then begin
        lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'PACKAGE NOT FOUND' + #13#10;
        log(EgoFileManager.getLastError);
    end
    else begin
       btnsave.Enabled := true;
       if AudioFileInfo.FileFormat = 'wav' then btnplay.Enabled := true;
    end;

    lblAudioFileInfo.Caption := lblAudioFileInfo.Caption  + 'File : ' + AudioFileInfo.FileName + #13#10;
    lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'Rate : ' + IntToStr(AudioFileInfo.SamplesPerSec) + 'Hz' + #13#10;

    lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'Channels : ';
    if (AudioFileInfo.isStereo) then
       lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'Stereo'
    else
       lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'Mono';

    // debug
    // lblAudioFileInfo.Caption := lblAudioFileInfo.Caption + 'End : ' + IntToStr(PackList[KeyInfo.PackageKey].Files[KeyInfo.FileListKey].Ending) + #13#10;
  end;
end;

procedure TForm1.btnplayClick(Sender: TObject);
var
  KeyInfo : TTreeNodeData;
  buffer : TBytes;
begin
  if (tv1.Selected = nil) or (tv1.Selected.Data = nil) or (beasy) or (EgoFileManager = nil) then Exit;

  KeyInfo := TTreeNodeData(tv1.Selected.Data);
  if KeyInfo.FileListKey = -1 then Exit;

  self.btnstopClick(nil);
  SetLength(buffer, 0);
  
  EgoFileManager.LoadFileToBuffer(KeyInfo.PackageKey, KeyInfo.FileListKey, buffer);

  if Length(buffer) = 0 then Exit;
  if not TinyPlayer.Play(tv1.Selected.Text, buffer) then exit;

  btnstop.Visible := true;
  tmrsoundtick.Interval := 500;
  tmrsoundtick.Enabled := true;

  Self.updateSoundTime(self);
end;

procedure TForm1.playtreeitem(Sender: TObject);
var
  Node : TTreeNode;
begin
  Node := tv1.GetNodeAt(ScreenToClient(Mouse.CursorPos).X, ScreenToClient(Mouse.CursorPos).Y);
  if (Node = nil) or (Node.Data = nil) or (tv1.Selected <> Node) then exit;

  self.btnplayClick(nil);
end;

procedure TForm1.btnstopClick(Sender: TObject);
begin
  if TinyPlayer.IsPlaying then TinyPlayer.Stop;
  self.onstopsound(nil);
end;

procedure TForm1.updateSoundTime(Sender: TObject);
begin
    lblplaytime.Caption := TinyPlayer.GetTime + ' / ' + TinyPlayer.Duration;
end;

procedure TForm1.onstopsound(Sender: TObject);
begin
    tmrsoundtick.Enabled := false;
    btnstop.Visible := false;
    lblplaytime.Caption := '';
end;

procedure TForm1.btnsaveallClick(Sender: TObject);
var
    chosenDirectory : string;
begin
    if beasy then begin
      ThreadJobThreadState.Cancel := true;
      btnsaveall.Caption := 'Stop...';
      exit;
    end;

    if (EgoFileManager = nil) or beasy then exit;

    if SelectDirectory('Select directory', '', chosenDirectory) then begin
        //EgoFileManagerInterface.SavePackages(chosenDirectory, chksaveallinonedir.Checked);
        beasy := true;
        if tv1.Visible then tooglelogmmo(self);

        btnsaveall.Caption := 'Stop';
        ThreadJobSavePackages(EgoFileManager, chosenDirectory, not chkcreatesub.Checked);
    end;
end;

procedure TForm1.btn2Click(Sender: TObject);
const
  codecs: array [0..15] of integer = (
  202,
  203,
  220,
  300,
  400,
  680,
  1000,
  1001,
  1002,
  1003,
  1004,
  1100,
  1400,
  1401,
  1500,
  2000
  );
var
  strType : string;
  chosenDirectory : string;
  b : integer;
  KeyInfo : TTreeNodeData;
begin
  if (tv1.Selected = nil) or (tv1.Selected.Data = nil) then exit;

  if (mode = 'raw') then exit;

  KeyInfo := TTreeNodeData(tv1.Selected.Data);
  if (KeyInfo.FileListKey = -1) or not (SelectDirectory('Select directory', '', chosenDirectory)) then Exit;

  // for b := 0 to length(codecs)-1 do begin
    for b := 0 to 200 do begin
       strType := IntToStr(b);

          if Length(strType) < 2 then strType := '000' + strType
     else if Length(strType) < 3 then strType := '00' + strType
     else if Length(strType) < 4 then strType := '0' + strType
     else strType := strType;

     DicFile.unknownType := StrToInt('$' + strType);

    if not DicFile.SavePackageItem(KeyInfo.PackageKey, KeyInfo.FileListKey, chosenDirectory,  strType + '_' + 'test.wav') then
    Log(EgoFileManager.getLastError);
  end;
end;

procedure TForm1.EventSaveItemEnd(State: TPackageWorkInfo);
var progress : string;
begin
   progress := IntToStr(
    Round((State.pkey) * 100 / EgoFileManager.PackagesCount)
   );

   // progress := IntToStr(State.fkey+1) + '/' + IntToStr(packageInfo.FilesNum);
   progress := '[' + progress + '%] ';

   if State.state = 'fail' then begin
      log(progress + 'File "' + State.fname + '" save fail');
      log(EgoFileManager.getLastError);
   end
   else begin
      log(progress + 'File "' + State.fname + '" saved');
   end;
end;

procedure TForm1.EventSavePackagesEnd(State: TPackageWorkInfo);
begin
    beasy := false;
    btnsaveall.Caption := 'Save all';
    if ThreadJobThreadState.Cancel then begin
       log('Action canceled');
    end
    else if State.state = 'fail' then begin
       log('Problem while save package : ' + state.notice);
       log(EgoFileManager.getLastError);
    end
    else begin
      log('Package data saved');
    end;

    if closeOnbeasyEnd then begin
        PostMessage(Application.Handle, WM_Close, 0, 0);
    end;
end;

procedure TForm1.tooglelogmmo(Sender: TObject);
begin
  if tv1.Visible then begin
    mmo1.Align := alLeft;
    mmo1.Visible := true;

    tv1.Visible := false;

    btn3.Caption := 'Show tree';
  end
  else begin
    mmo1.Visible := false;
    tv1.Visible := true;

    btn3.Caption := 'Show log';
  end;
end;

procedure TForm1.CheckClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := true;
  
  if beasy then begin
     ThreadJobThreadState.Cancel := true;
     closeOnbeasyEnd := true;
     CanClose := False;
  end;
end;

end.
