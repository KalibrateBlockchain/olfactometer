unit ufmSettings;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.ListBox,
  FMX.Layouts, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Edit, FMX.EditBox,
  FMX.SpinBox, FMX.Media;

type
  TfmSettings = class(TForm)
    tbToolbar: TToolBar;
    lTitle: TLabel;
    btnBack: TSpeedButton;
    cbShowFrame: TCheckBox;
    gbQ: TGroupBox;
    rbPhoto: TRadioButton;
    rbMedium: TRadioButton;
    rbHigh: TRadioButton;
    paCoef: TPanel;
    Label1: TLabel;
    sbCoef: TSpinBox;
    cbSaveDebugImages: TCheckBox;
    paFrame: TPanel;
    Label2: TLabel;
    sbFrame: TSpinBox;
    Label3: TLabel;
    Panel3: TPanel;
    cbShowRes: TCheckBox;
    gbShowImage: TGroupBox;
    rbShowOrig: TRadioButton;
    rbShowMask: TRadioButton;
    rbShowContours: TRadioButton;
    paHole: TPanel;
    Label4: TLabel;
    sbHole: TSpinBox;
    rbLowQ: TRadioButton;
  private
    { Private declarations }
  public
    Camera: TCameraComponent;
  end;

var
  fmSettings: TfmSettings;

implementation

{$R *.fmx}

end.
