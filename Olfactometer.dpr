program Olfactometer;





uses
  System.StartUpCopy,
  FMX.Forms,
  ufmMain in 'ufmMain.pas' {fmMain},
  ufmSettings in 'ufmSettings.pas' {fmSettings},
  FMX.Media.Android in 'cameracomponent\Custom\FMX.Media.Android.pas',
  FastUtils in 'cameracomponent\SIMD\FastUtils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfmMain, fmMain);
  Application.CreateForm(TfmSettings, fmSettings);
  Application.Run;
end.
