{
******************************************************
  Monkey Island 2 Talkie Speech Extractor
  By Bennyboy
  Http://quickandeasysoftware.net

  Quickly hacked together to extract the speech from the
  monster.sou file in the MI2 talkie prototype.
******************************************************
}

//The sounds inside the monster.sou in SBL blocks - which contain headerless Creative VOC audio.
//See https://wiki.scummvm.org/index.php/SCUMM/Technical_Reference/Sound_resources

unit formMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, System.ImageList, Vcl.ImgList,
  Vcl.StdCtrls, JvBaseDlg, JvBrowseFolder,
  uFileReader, uWaveWriter;

type
  TfrmMain = class(TForm)
    memoLog: TMemo;
    btnChooseSource: TButton;
    ImageListLarge: TImageList;
    OpenDialogFile: TOpenDialog;
    FileOpenDialogFolder: TFileOpenDialog;
    dlgBrowseForFolder: TJvBrowseForFolderDialog;
    procedure btnChooseSourceClick(Sender: TObject);
  private
    { Private declarations }
    MonsterFile: TExplorerFileStream;
    SourceFile, DestFolder: string;
    procedure Log(Text: string);
    procedure ParseMonsterSOU();
    procedure SaveVoxToFile(Datasize: integer; FileName: string);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.Log(Text: string);
begin
  memoLog.Lines.Add(Text);
end;

procedure TfrmMain.ParseMonsterSOU;
var
  BlockSize, FileNum: integer;
begin
  try
    MonsterFile := TExplorerFileStream.Create(SourceFile);

    MonsterFile.Position := 0;
    if MonsterFile.ReadBlockName <> 'SOU ' then
    begin
      Log('SOU block missing!');
      exit;
    end;
    MonsterFile.Seek(4, soFromCurrent); //0000  - should really be blocksize?

    //The rest of the file is SBL blocks - as found in MI1+2.
    //They contain headerless creative voc audio

    FileNum := 1;
    repeat
      if MonsterFile.ReadBlockName <> 'SBL ' then
      begin
        Log('SBL block missing! at offset ' + inttostr(MonsterFile.Position - 4));
        exit;
      end;
      MonsterFile.Seek(19, soFromCurrent); //Now at start of size block

      BlockSize := MonsterFile.ReadDWordBE;
      //Finally at the start of the data
      SaveVoxToFile(BlockSize, IncludeTrailingPathDelimiter(DestFolder) + IntToStr(FileNum) + '.wav');
      inc(FileNum);

    until (MonsterFile.Position >= MonsterFile.Size);

    Log('All done! ' + inttostr(FileNum -1) + ' files dumped');

  finally
    MonsterFile.Free;
  end;
end;

procedure TfrmMain.SaveVoxToFile(Datasize: integer; FileName: string);
var
  BlockType, FrequencyDivisor, CodecId, Temp: byte;
  BlockSize, Samplerate: integer;
  OutFile: TFileStream;
  WaveStream: TWaveStream;
begin
  { https://wiki.multimedia.cx/index.php/Creative_Voice
    Format is:
    byte  0      block type
    bytes 1-3    block size (NOT including this common header)

    Block type 0x00: Terminator
      This is a special block type as it's common header don't contain any size field.
      It indicate the end of the file. It is not mandatory (you can reach EOF without encountering this block type).

    Block type 0x01: Sound data
      byte  0      frequency divisor
      byte  1      codec id
      bytes 2..n   the audio data
  }

  //Expect stream to be at the beginning of the vox data
  BlockType := MonsterFile.ReadByte;
  if BlockType <> 1 then
  begin
    log('Unexpected blocktype of ' + inttostr(BlockType) + ' at offset ' + inttostr(MonsterFile.Position - 1));
    exit;
  end;

  BlockSize := MonsterFile.ReadTriByte;
  FrequencyDivisor := MonsterFile.ReadByte;
  CodecId := MonsterFile.ReadByte;

  if FrequencyDivisor = 256 then
  begin
    Log('Frequency divisor of 256! At offset ' + IntToStr(MonsterFile.Position - 2));
    exit;
  end;

  //From ScummVM voc.ccp getSampleRateFromVOCRate  Some samplerates are marked incorrectly so fix that here
  if (FrequencyDivisor =  $A5) or (FrequencyDivisor =  $A6) then
    Samplerate := 11025
  else if (FrequencyDivisor =  $D2) or (FrequencyDivisor =  $D3) then
    Samplerate := 22050
  else
    Samplerate := Round(1000000 / (256 - FrequencyDivisor));

  if CodecId <> 0 then
  begin
    Log('Unmanaged codec ' + inttostr(CodecId) + ' at offset ' + IntToStr(MonsterFile.Position -1) );
    exit;
  end;

  //Finally, we should be at the data
  OutFile := TFileStream.Create( FileName, fmOpenWrite or fmCreate);
  try
    WaveStream := TWaveStream.Create(OutFile, 1, 8, Samplerate);
    try
      WaveStream.CopyFrom(MonsterFile, BlockSize - 2);
    finally
      WaveStream.Free;
    end;
  finally
    OutFile.Free;
  end;

  //Check if there's a 0 terminator or even other block types
  if (Blocksize + 4) < Datasize then
  begin
    Temp := MonsterFile.ReadByte;
    if Temp <> 0 then
      Log('Terminator byte not 0! At offset ' + inttostr(MonsterFile .Position -1));
  end;

end;


procedure TfrmMain.btnChooseSourceClick(Sender: TObject);
begin
  SourceFile := '';
  DestFolder := '';

  //Choose monster.sou
  if OpenDialogFile.Execute = false then exit;
  SourceFile := OpenDialogFile.FileName;
  Log('************************************************');
  Log('Opened ' +  SourceFile);

  //Choose save dir
  if Win32MajorVersion >= 6 then //Vista and above
  begin
    if FileOpenDialogFolder.Execute then
      DestFolder := FileOpenDialogFolder.FileName;
  end
  else
  begin
    if dlgBrowseForFolder.Execute then
      DestFolder := dlgBrowseForFolder.Directory;
  end;
  if DestFolder = '' then exit;


  ParseMonsterSOU();
end;

end.
