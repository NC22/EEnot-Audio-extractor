unit c_player;

interface

uses windows, SysUtils, Classes, ExtCtrls, mmsystem, wavutils, common_base_types;

type

  Tplayer = Class

    private
     fileName  : string;
     time      : shortstring;
     
     startTimeMSec : double;
     durationMSec : double;
     playing : boolean;
     PlayStream : TMemoryStream;

     FOnMusicEnd : TNotifyEvent;

     OnEndTimer : TTimer;
    public
     property OnMusicEnd : TNotifyEvent read FOnMusicEnd write FOnMusicEnd;
     procedure ExecEventMusicEnd(Sender: TObject); dynamic;
     function IsStoped : boolean;
     function IsPlaying : boolean;
     function GetTitle : string; // pase xml by file name in future
     function GetTime : string;
     procedure Stop;
     function Play(name : string; var buffer : TBytes) : boolean;
     property  Duration : shortstring read time;
     Constructor Create;
     Destructor  Destroy; override;

     class function GetFormatedTimeFromSec(time : DWORD) : shortstring;
  end;

implementation

class function Tplayer.GetFormatedTimeFromSec(time : DWORD) : shortstring;
var
  min,sec : smallint;
begin
    min := time div 60;
    sec := time mod 60;

    if min > 9  then Result := IntToStr(min)
    else Result := '0' + IntToStr(min);

    Result := Result + ':';

    if sec > 9 then Result := Result + IntToStr(sec)
    else Result := Result + '0' + IntToStr(sec);
end;

procedure Tplayer.ExecEventMusicEnd(Sender: TObject);
begin
  Stop;

  if Assigned(FOnMusicEnd) then FOnMusicEnd(Sender);
end;

Constructor Tplayer.Create; 
begin
   Inherited;
   
   PlayStream := nil;
   fileName := '';
   time := '00:00';
   FOnMusicEnd := nil;
   playing := false;
   OnEndTimer := nil;
end;

destructor Tplayer.Destroy;
begin
  Stop;
  inherited;
end;

function TPlayer.IsStoped : boolean;
begin
 result := true;
 if PlayStream <> nil then result := false;
end;

function TPlayer.IsPlaying : boolean;
begin
 result := false;
 if PlayStream <> nil then result := true;
end;

function TPlayer.GetTitle : string;
begin
   result := filename;
end;

function TPlayer.Play(name : string; var buffer : TBytes) : boolean;
var
    WavHeader : TNoPcmWaveHeader;
begin
    Result := false;
    Stop;
    Move(buffer[0], WavHeader, SizeOf(TNoPcmWaveHeader));
    
    if not ValidateNoPcmWaveHeader(WavHeader) then exit;
    
    filename := name;
    
    PlayStream := TMemoryStream.Create;
    PlayStream.Seek(0, soFromBeginning);
    PlayStream.Write(buffer[0], Length(buffer));
    
    if not playsound(PlayStream.Memory, 0, SND_MEMORY or SND_ASYNC) then exit;
    
    durationMSec := GetWaveTime(WavHeader) * 1000;    
    startTimeMSec := GetTickCount; 
    
    time := GetFormatedTimeFromSec(Round(durationMSec / 1000));
    
    OnEndTimer := TTimer.Create(nil); 
    OnEndTimer.interval:= Round(durationMSec);
    OnEndTimer.OnTimer:= ExecEventMusicEnd;
    OnEndTimer.Enabled := true;

    Result := true;
end;

function TPlayer.GetTime : string;
var
    diffMSec : double;
begin
    result := '00:00';
    if IsStoped then exit;

    diffMSec := GetTickCount() - startTimeMSec; 
    if diffMSec > durationMSec then diffMSec := durationMSec;

    diffMSec := diffMSec; // обратный отсчет durationMSec - diffMSec;
    diffMSec := diffMSec / 1000;

    result := GetFormatedTimeFromSec(Round(diffMSec));
end;

procedure TPlayer.Stop;
begin
  if PlayStream <> nil then begin
    PlayStream.Free;
    PlayStream := nil;
   end;
   
  if OnEndTimer <> nil then begin
    OnEndTimer.Free;
    OnEndTimer := nil;
   end;
   
  startTimeMSec := 0;
  durationMSec := 0;
  time := '00:00';
  playsound(nil, 0, 0);
end;

end.
