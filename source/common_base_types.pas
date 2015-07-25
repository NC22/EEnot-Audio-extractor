unit common_base_types;

interface

type
    TBytes = array of Byte;

    TPackageInfo = record
        PackageName : string;
        FilesNum : integer;
        Format : string;
    end;

    TAudioInfo = record
        wavType : smallint;

        isStereo : boolean;

        FileName : string;
        FileFormat : string;

        SamplesPerSec : longint;
        BitsPerSample : smallint;
        Channels : smallint;
    end;
   
    TPackageWorkInfo = record
        fname      : string[255];
        fkey       : integer;
        pkey       : integer;
        state      : string[255];
        notice     : string[255];
    end;

    TPackageWorkEvent = procedure(State: TPackageWorkInfo) of object;

   IEgoFileManagerInterface = Interface(IInterface)
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

    Destructor  Destroy;
  end;
    
implementation


end.