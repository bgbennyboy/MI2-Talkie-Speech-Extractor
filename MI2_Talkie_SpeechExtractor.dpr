program MI2_Talkie_SpeechExtractor;

uses
  Vcl.Forms,
  formMain in 'formMain.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
