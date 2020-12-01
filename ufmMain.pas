unit ufmMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Threading, System.Math, System.Permissions,

  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Media,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Memo, FMX.Controls.Presentation,
  FMX.StdCtrls, FMX.Objects, FMX.Platform, FMX.DialogService,
  FMX.Surfaces, FMX.Helpers.Android, FMX.Edit, FMX.Layouts,

  Android.OpenCV, Android.BitmapHelpers, AndroidApi.JNI.Media,
  AndroidApi.JNI.GraphicsContentViewText, AndroidApi.JNI.Os,
  AndroidApi.JNI.JavaTypes, AndroidApi.Helpers, FMX.Effects;

const
  borderDXpercent = 2;
  borderDYpercent = 2;
  aspectRatio = 1.25; //of crop bar
  debugImgExt = 'jpg';

var
  cameraQuality:TVideoCaptureQuality = TVideoCaptureQuality.HighQuality;
  numOfFrame: Integer = 4; // Number of frame that will be processed
  coef: Integer = 85;
  HolePercent: Integer = 5;

type
  TfmMain = class(TForm)
    Camera: TCameraComponent;
    Image1: TImage;
    Panel1: TPanel;
    Memo1: TMemo;
    Panel2: TPanel;
    Button1: TButton;
    Button2: TButton;
    Layout1: TLayout;
    Timer1: TTimer;
    TopLayout: TLayout;
    BottomLayout: TLayout;
    Panel3: TPanel;
    Edit1: TEdit;
    buSettings: TButton;
    procedure Button2Click(Sender: TObject);
    procedure CameraSampleBufferReady(Sender: TObject; const ATime: TMediaTime);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure buSettingsClick(Sender: TObject);
  private
    // FCamera: TCamera;
    ShowImageMode : Integer;
    ShowRes, UseCropFrame, SaveDebugImages: boolean;
    FOpenCVInProgress: Boolean;
    wellW, wellH, mwH, mwW: Integer;
    FCamBitmap: TBitmap;
    mskBitmap,cntBitmap: TBitmap;
    FImageStream: TMemoryStream;
    fFrameTake, oldF: Integer;
    OutRes: Boolean;
    borderX, borderY: Integer;
    procedure ChangeButtonText;
    procedure CalcImgBorders;
    procedure MyBeep;
    procedure DrawStatus(bmp: TBitmap = nil);
    procedure ProcessImg;
    procedure ParseBitmap;
    procedure AddWorkLayer;
    procedure SaveSettings;
    procedure LoadSettings;
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    procedure DisplayRationale(Sender: TObject;
      const APermissions: TArray<string>; const APostRationaleProc: TProc);
    procedure TakePicturePermissionRequestResult(Sender: TObject;
      const APermissions: TArray<string>;
      const AGrantResults: TArray<TPermissionStatus>);
  public
  end;

var
  fmMain: TfmMain;

implementation

uses System.IOUtils, System.IniFiles, {FMX.Graphics.Android, FMX.Consts,} ufmSettings;

{$R *.fmx}

function TfmMain.AppEvent(AAppEvent: TApplicationEvent;
  AContext: TObject): Boolean;
begin
  case AAppEvent of
    TApplicationEvent.WillBecomeInactive:
      Camera.Active := False;
    TApplicationEvent.EnteredBackground:
      Camera.Active := False;
    TApplicationEvent.WillTerminate:
      Camera.Active := False;
  end;
end;

procedure TfmMain.buSettingsClick(Sender: TObject);
//var
//  SavedCameraActive: Boolean;
begin
//  SavedCameraActive := Camera.Active;
  fmSettings.Camera := Camera;
  Camera.Active := False;
  Timer1.Enabled := False;
  Image1.Bitmap.Clear(0);
  Button1.Text := 'Go!';
  Edit1.Text := '';

  case cameraQuality of
    TVideoCaptureQuality.PhotoQuality : fmSettings.rbPhoto.IsChecked  := true;
    TVideoCaptureQuality.HighQuality  : fmSettings.rbHigh.IsChecked   := true;
    TVideoCaptureQuality.MediumQuality: fmSettings.rbMedium.IsChecked := true;
    else fmSettings.rbLowQ.IsChecked := True;
  end;
  fmSettings.cbShowRes.IsChecked := ShowRes;
  fmSettings.cbShowFrame.IsChecked := UseCropFrame;
  fmSettings.sbHole.Value := HolePercent;
  fmSettings.sbCoef.Value := coef;
  fmSettings.sbFrame.Value:= numOfFrame;
  fmSettings.cbSaveDebugImages.IsChecked := SaveDebugImages;
  case ShowImageMode of
    0: fmSettings.rbShowOrig.IsChecked := true;
    1: fmSettings.rbShowMask.IsChecked := true;
    2: fmSettings.rbShowContours.IsChecked := true;
  end;

  fmSettings.ShowModal(procedure (AResult: TModalResult)
  begin
    Camera.FocusMode := FMX.Media.TFocusMode.ContinuousAutoFocus;

    if fmSettings.rbPhoto.IsChecked then
      cameraQuality := TVideoCaptureQuality.PhotoQuality
    else if fmSettings.rbHigh.IsChecked then
      cameraQuality := TVideoCaptureQuality.HighQuality
    else if fmSettings.rbMedium.IsChecked then
      cameraQuality := TVideoCaptureQuality.MediumQuality
    else cameraQuality := TVideoCaptureQuality.LowQuality;
    Camera.Quality := cameraQuality;
    ShowRes := fmSettings.cbShowRes.IsChecked;
    UseCropFrame := fmSettings.cbShowFrame.IsChecked;
    HolePercent := Trunc(fmSettings.sbHole.Value);
    Coef := Trunc(fmSettings.sbCoef.Value);
    numOfFrame := Trunc(fmSettings.sbFrame.Value);
    SaveDebugImages := fmSettings.cbSaveDebugImages.IsChecked;
    if fmSettings.rbShowOrig.IsChecked then
      ShowImageMode := 0;
    if fmSettings.rbShowMask.IsChecked then
      ShowImageMode := 1;
    if fmSettings.rbShowContours.IsChecked then
      ShowImageMode := 2;

    SaveSettings;
//    Camera.Active := SavedCameraActive;
  end);
end;

procedure TfmMain.Button1Click(Sender: TObject);
begin
  if button1.Text = 'Go!' then
  begin
    Timer1.Enabled := true;
    PermissionsService.RequestPermissions
      ([JStringToString(TJManifest_permission.JavaClass.Camera)],
      TakePicturePermissionRequestResult, DisplayRationale);
  end
  else
  begin
    Camera.Active := false;
    Timer1.Enabled := false;
  end;

  ChangeButtonText;
end;

procedure TfmMain.Button2Click(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TfmMain.CameraSampleBufferReady(Sender: TObject;
  const ATime: TMediaTime);
begin
  TThread.Synchronize(TThread.CurrentThread,
    procedure
    begin
      ParseBitmap
    end);
end;

procedure TfmMain.ChangeButtonText;
begin
  if Button1.Text = 'Go!' then
    Button1.Text := 'Stop!'
  else Button1.Text := 'Go!';
end;

procedure TfmMain.DisplayRationale(Sender: TObject;
const APermissions: TArray<string>; const APostRationaleProc: TProc);
var
  I: Integer;
  RationaleMsg: string;
begin
  for I := 0 to High(APermissions) do
  begin
    if APermissions[I] = JStringToString(TJManifest_permission.JavaClass.Camera)
    then
      RationaleMsg := RationaleMsg + 'The app needs to access the camera'
  end;
  TDialogService.ShowMessage(RationaleMsg,
    procedure(const AResult: TModalResult)
    begin
      APostRationaleProc;
    end)
end;

procedure TfmMain.FormCreate(Sender: TObject);
var
  AppEventSvc: IFMXApplicationEventService;
begin
  OutRes := False;
  ShowRes := True;
  UseCropFrame := False;
  SaveDebugImages := False;

  FCamBitmap := TBitmap.Create(Trunc(Image1.Width), Trunc(Image1.Height));
  mskBitmap := TBitmap.Create(Trunc(Image1.Width), Trunc(Image1.Height));
  mskBitmap.Clear(0);
  cntBitmap := TBitmap.Create(Trunc(Image1.Width), Trunc(Image1.Height));
  cntBitmap.Clear(0);

  PermissionsService.RequestPermissions
    ([JStringToString(TJManifest_permission.JavaClass.WRITE_EXTERNAL_STORAGE),
      JStringToString(TJManifest_permission.JavaClass.READ_EXTERNAL_STORAGE)], nil);

  LoadSettings;

  if TPlatformServices.Current.SupportsPlatformService
    (IFMXApplicationEventService, IInterface(AppEventSvc)) then
    AppEventSvc.SetApplicationEventHandler(AppEvent);
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  FCamBitmap.Free;
  mskBitmap.Free;
  cntBitmap.Free;
end;

procedure TfmMain.LoadSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFIle.Create(TPath.Combine(TPath.GetDocumentsPath, 'settings.ini'));
  try
    cameraQuality  := TVideoCaptureQuality(Ini.ReadInteger('Settings','cameraQuality', byte(TVideoCaptureQuality.HighQuality)));
    numOfFrame     := Ini.ReadInteger('Settings', 'numOfFrame', 4);
    coef           := Ini.ReadInteger('Settings', 'coef', 90);
    HolePercent    := Ini.ReadInteger('Settings', 'HolePercent', 5);
    ShowRes        := Ini.ReadBool('Settings', 'ShowRes', True);
    UseCropFrame   := Ini.ReadBool('Settings', 'UseCropFrame', False);
    SaveDebugImages:= Ini.ReadBool('Settings', 'SaveDebugImages', False);
    ShowImageMode  := Ini.ReadInteger('Settings', 'ShowImageMode', 0);
  finally
    Ini.Free;
  end;
end;

procedure TfmMain.MyBeep;
var
  Volume: Integer;
  StreamType: Integer;
  ToneType: Integer;
  ToneGenerator: JToneGenerator;
begin
  Volume := TJToneGenerator.JavaClass.MAX_VOLUME;
  StreamType := TJAudioManager.JavaClass.STREAM_NOTIFICATION;
  ToneType := TJToneGenerator.JavaClass.TONE_CDMA_EMERGENCY_RINGBACK;
  try
    ToneGenerator := TJToneGenerator.JavaClass.init(StreamType, Volume);
    ToneGenerator.startTone(ToneType, 777);
  finally
    ToneGenerator.release;
  end;
end;

procedure TfmMain.DrawStatus;
const
  ddx: Single = 0.2;
  ddy: Single = 0.2;
var
  w, h: Integer;
  d: Single;
  dx, dy: Single;
begin
  if bmp = nil then
    bmp := FCamBitmap;
  w := bmp.Width;
  h := bmp.Height;
  d := 0.01 * min(w, h);
  dx := borderDXpercent / 100;
  dy := borderDYpercent / 100;
  bmp.Canvas.BeginScene();
  bmp.Canvas.Stroke.Thickness := 2 * d;
  if OutRes then
    bmp.Canvas.Stroke.Color := $FF00FF00 // Green (OK)
  else
    bmp.Canvas.Stroke.Color := $FFFF0000; // Red
  with bmp.Canvas do
  begin
    DrawLine(PointF(dx * w + borderX, dy * h + borderY),
      PointF(ddx * w + borderX, dy * h + borderY), 1);
    DrawLine(PointF(dx * w + borderX, dy * h - d + borderY),
      PointF(dx * w + borderX, ddy * h + borderY), 1);
    DrawLine(PointF((1 - dx) * w - borderX, dy * h + borderY),
      PointF((1 - ddx) * w - borderX, dy * h + borderY), 1);
    DrawLine(PointF((1 - dx) * w - borderX, dy * h - d + borderY),
      PointF((1 - dx) * w - borderX, ddy * h + borderY), 1);
    DrawLine(PointF((1 - dx) * w - borderX, (1 - dy) * h - borderY),
      PointF((1 - ddx) * w - borderX, (1 - dy) * h - borderY), 1);
    DrawLine(PointF((1 - dx) * w - borderX, (1 - dy) * h + d - borderY),
      PointF((1 - dx) * w - borderX, (1 - ddy) * h - borderY), 1);
    DrawLine(PointF(dx * w + borderX, (1 - dy) * h - borderY),
      PointF(ddx * w + borderX, (1 - dy) * h - borderY), 1);
    DrawLine(PointF(dx * w + borderX, (1 - dy) * h + d - borderY),
      PointF(dx * w + borderX, (1 - ddy) * h - borderY), 1);
  end;
  bmp.Canvas.EndScene;
end;

procedure TfmMain.ParseBitmap;
begin

  if FOpenCVInProgress then
    exit;

  Camera.SampleBufferToBitmap(FCamBitmap, True);

  CalcImgBorders;

  OutRes := False;

  if UseCropFrame then
    DrawStatus;

  Image1.Bitmap.Assign(FCamBitmap);

  if SaveDebugImages then
    FCamBitmap.SaveToFile(TPath.Combine(TPath.GetSharedDocumentsPath,
      Format('%s.%s',[FormatDateTime('dd.mm.yy-hh.nn.ss.zzz', Now),debugImgExt])));

  if ShowImageMode <> 0 then
    AddWorkLayer;

  inc(fFrameTake);
  if (fFrameTake mod numOfFrame <> 0) then
  begin
    exit;
  end;

  ProcessImg;

  if SaveDebugImages then
    FCamBitmap.SaveToFile(TPath.Combine(TPath.GetSharedDocumentsPath,
      Format('%s_mask.%s',[FormatDateTime('dd.mm.yy-hh.nn.ss.zzz', Now),debugImgExt])));

  if ShowImageMode = 1 then
  begin
    if mskBitmap.Size <> FCamBitmap.Size then
    begin
      mskBitmap.SetSize(FCamBitmap.Size);
      mskBitmap.Clear(0);
    end;
    mskBitmap.CopyFromBitmap(FCamBitmap);
  end;


  // Process Thread
  TThread.CreateAnonymousThread(
  // TTask.Run(
    procedure
    const
      delta = 10;
    type
      TElem = record
        x, y, w, h, f: Integer;
        c: JMatOfPoint;
      end;
    var
      LSrcMat, LDstMat, LDstMat2, LDstMat3, LDstMat4, maskMat, mat1, mat2: JMat;
      LHierarchyMat, M: JMat;
      // LThreshold: Double;
      LJBitmap, LJBitmap2, LJBitmap3, JmaskBitmap: JBitmap;
      LContoursList: JList;
      LSurface: TBitmapSurface;
      LContourPoly: JMatOfPoint2f;
      LContoursPoly: JList;
      LTempContour: JMatOfPoint2f;
      LContours: JMatOfPoint;
      LContourArea: Single;
      c: JMatOfPoint;
      arcLen: Integer;
      r: Jcore_Rect;
      // f : boolean;
      a, b: array of TElem;
      q: TElem;
      jrect, jtrect: JMatOfPoint2f;
      l: JList;
      topr, bottomr: array [0 .. 3] of TElem;
      z: array [0 .. 47] of Integer;
      procedure EndProc(msg: String; res: Boolean = False);
      begin
        // release it?
        // LSrcMat, LDstMat, LDstMat2, LDstMat3, LDstMat4, maskMat
        // LJBitmap, LJBitmap2, LJBitmap3, JmaskBitmap
        TThread.Synchronize(TThread.CurrentThread,
          procedure
          begin
            Memo1.Lines.Add(msg);
            Memo1.GoToTextEnd
          end);
      end;

    begin
      FOpenCVInProgress := True;
      try
        try
          LSrcMat := TJMat.JavaClass.init;
          LDstMat := TJMat.JavaClass.init;
          LDstMat2 := TJMat.JavaClass.init;
          LDstMat3 := TJMat.JavaClass.init;
          LDstMat4 := TJMat.JavaClass.init;
          maskMat := TJMat.JavaClass.init;
          LHierarchyMat := TJMat.JavaClass.init;
          LContoursList := JList(TJArrayList.JavaClass.init(0));

          LJBitmap := TJBitmap.JavaClass.createBitmap(Trunc(FCamBitmap.Width),
            Trunc(FCamBitmap.Height), TJBitmap_Config.JavaClass.ARGB_8888);

          // Init JBitmap2
          LJBitmap2 := TJBitmap.JavaClass.createBitmap(Trunc(FCamBitmap.Width),
            Trunc(FCamBitmap.Height), TJBitmap_Config.JavaClass.RGB_565);
          // RGB_565 for speedup - native android bitmap format
          TJandroid_Utils.JavaClass.bitmapToMat(LJBitmap2, LDstMat2);

          // Init JBitmap2
          JmaskBitmap := TJBitmap.JavaClass.createBitmap(Trunc(FCamBitmap.Width)
            + 2, Trunc(FCamBitmap.Height) + 2,
            TJBitmap_Config.JavaClass.RGB_565); // RGB_565 for speedup
          TJandroid_Utils.JavaClass.bitmapToMat(JmaskBitmap, maskMat);

          TJandroid_Utils.JavaClass.bitmapToMat
            (BitmapToJBitmap(FCamBitmap), LSrcMat);

          TJImgproc.JavaClass.cvtColor(maskMat, maskMat,
            TJImgproc.JavaClass.COLOR_RGB2GRAY);
          TJImgproc.JavaClass.cvtColor(LSrcMat, LSrcMat,
            TJImgproc.JavaClass.COLOR_RGB2GRAY);
          TJImgproc.JavaClass.cvtColor(LDstMat2, LDstMat2,
            TJImgproc.JavaClass.COLOR_RGB2GRAY);
          LDstMat := LSrcMat.clone;

          TJImgproc.JavaClass.findContours(LDstMat, LContoursList,
            LHierarchyMat, TJImgproc.JavaClass.RETR_EXTERNAL,
            TJImgproc.JavaClass.CHAIN_APPROX_SIMPLE);

          LContoursPoly := JList(TJArrayList.JavaClass.init);
          var I: Integer;
          var k: Single;
          //search for a contour that matches the array cell parameters
          for I := 0 to Pred(JArrayList(LContoursList).Size) do
          begin
            LContourPoly := TJMatOfPoint2f.JavaClass.init;
            c := TJMatOfPoint.Wrap(JArrayList(LContoursList).get(I));
            r := TJImgproc.JavaClass.boundingRect(c);
            k := r.Width / r.Height;
            // parameters of cells
            if (r.Width > wellW) and (r.Height > wellH) and
              (r.Width < mwW) and (r.Height < mwH) and
            // (k > 0.4) and (k < 2.5)
              (k > 1) and (k < 2.5) then
            begin
              JArrayList(LContoursPoly).Add(c); // LTempContour
              q.x := r.x;
              q.y := r.y;
              q.w := r.Width;
              q.h := r.Height;
              // q.c := c;
              // q.ofs := r.x + r.y * FCamBitmap.Width;
              SetLength(a, Length(a) + 1);
              a[Length(a) - 1] := q;
            end;
            // LContourPoly.release;
          end;

          TJImgproc.JavaClass.drawContours(LDstMat2, LContoursPoly, -1,
            TJScalar.JavaClass.init(255, 0, 0), 1); // LDstMat2

          if SaveDebugImages or (ShowImageMode = 2) then
          begin
            TJandroid_Utils.JavaClass.MatToBitmap(LDstMat2, LJBitmap2);
            LSurface := TBitmapSurface.Create;
            try
                JBitmapToSurface(LJBitmap2, LSurface);
                cntBitmap.Assign(LSurface);
            finally
                LSurface.Free;
            end;
            if SaveDebugImages then
              cntBitmap.SaveToFile(TPath.Combine(TPath.GetSharedDocumentsPath,
                Format('%s_contours.%s',[FormatDateTime('dd.mm.yy-hh.nn.ss.zzz', Now),debugImgExt])));
          end;

          if JArrayList(LContoursPoly).Size <> 48 then
          begin
            EndProc('regions num=' + IntToStr(JArrayList(LContoursPoly).Size));
            exit;
          end;

          for I := 0 to 47 do
            TJImgproc.JavaClass.floodFill(LDstMat2, maskMat,
              TJcore_Point.JavaClass.init(a[I].x + a[I].w div 2,
              a[I].y + a[I].h div 2), TJScalar.JavaClass.init(255, 0, 0));

          // detect corners
          TThread.Synchronize(TThread.CurrentThread,
            procedure
            begin
              Memo1.Lines.Add('Warp..');
              Memo1.GoToTextEnd
            end);

          var
            ymin, ymax: Integer;
          ymin := 37000; // max size in pixels in any image
          ymax := 0;
          for I := 0 to High(a) do
          begin
            if a[I].y < ymin then
              ymin := a[I].y;
            if a[I].y > ymax then
              ymax := a[I].y;
          end;

          // detect top and bottom elemnts row
          var
            ti, bi: Integer;
          ti := 0;
          bi := 0;
          for I := 0 to High(a) do
          begin
            if a[I].y - a[I].h div 2 < ymin then
            begin
              topr[ti] := a[I];
              inc(ti);
            end;
            if a[I].y + a[I].h div 2 > ymax then
            begin
              bottomr[bi] := a[I];
              inc(bi);
            end;
          end;
          if (ti <> 4) or (bi <> 4) then
          begin
            EndProc(Format('Wrong format of rows. top=%d, bottom=%d',
              [ti, bi]));
            exit;
          end;

          // detect corners
          var
            tmaxx, tminx, bmaxx, bminx, tidx: Integer;
          var
            tl, tr, br, bl: TElem;
          tmaxx := 0;
          tminx := 37000;
          bmaxx := 0;
          bminx := 37000;
          tidx := 0;
          // corner elements indexes
          for I := 0 to 3 do
          begin
            if topr[I].x > tmaxx then
            begin
              tmaxx := topr[I].x;
              tr := topr[I];
              tr.f := 777; // flag
            end;
            if topr[I].x < tminx then
            begin
              tminx := topr[I].x;
              tl := topr[I];
              tl.f := 777;
            end;
            if bottomr[I].x > bmaxx then
            begin
              bmaxx := bottomr[I].x;
              br := bottomr[I];
              br.f := 777;
            end;
            if bottomr[I].x < bminx then
            begin
              bminx := bottomr[I].x;
              bl := bottomr[I];
              bl.f := 777;
            end;
          end;
          if (tr.f <> 777) or (tl.f <> 777) or (br.f <> 777) or (bl.f <> 777)
          then
          begin
            EndProc(Format
              ('Cant find corner elements. [tl=%d, tr=%d, br=%d, bl=%d]',
              [byte(tl.f = 777), byte(tr.f = 777), byte(br.f = 777),
              byte(bl.f = 777)]));
            exit;
          end;

          // reverse perspective transformation
          var
            maxw, maxh: Integer;
          maxw := Round(max(sqrt(sqr(br.x - bl.x) + sqr(br.y - bl.y)),
            sqrt(sqr(tr.x - tl.x) + sqr(tr.y - tl.y))));
          maxh := Round(max(sqrt(sqr(tr.x - br.x) + sqr(tr.y - br.y)),
            sqrt(sqr(tl.x - bl.x) + sqr(tl.y - bl.y))));

          jrect := TJMatOfPoint2f.JavaClass.init;
          jtrect := TJMatOfPoint2f.JavaClass.init;
          l := JList(TJArrayList.JavaClass.init);

          JArrayList(l).Add(TJcore_Point.JavaClass.init(tl.x, tl.y));
          JArrayList(l).Add(TJcore_Point.JavaClass.init(tr.x + tr.w, tr.y));
          JArrayList(l).Add(TJcore_Point.JavaClass.init(br.x + br.w,
            br.y + br.h));
          JArrayList(l).Add(TJcore_Point.JavaClass.init(bl.x, bl.y + bl.h));
          jrect.fromList(l);

          l.clear;
          JArrayList(l).Add(TJcore_Point.JavaClass.init(0, 0));
          JArrayList(l).Add(TJcore_Point.JavaClass.init(maxw - 1, 0));
          JArrayList(l).Add(TJcore_Point.JavaClass.init(maxw - 1, maxh - 1));
          JArrayList(l).Add(TJcore_Point.JavaClass.init(0, maxh - 1));
          jtrect.fromList(l);

          // Init JBitmap3
          LJBitmap3 := TJBitmap.JavaClass.createBitmap(maxw, maxh,
            TJBitmap_Config.JavaClass.RGB_565); // RGB_565
          TJandroid_Utils.JavaClass.bitmapToMat(LJBitmap3, LDstMat3);
          TJImgproc.JavaClass.cvtColor(LDstMat3, LDstMat3,
            TJImgproc.JavaClass.COLOR_RGB2GRAY);
          LDstMat4 := LDstMat3.clone;

          M := TJMat.JavaClass.init();
          M := TJImgproc.JavaClass.getPerspectiveTransform(jrect, jtrect);
          TJImgproc.JavaClass.warpPerspective(LDstMat2, LDstMat3, M,
            TJCore_Size.JavaClass.init(maxw, maxh));
          TJImgproc.JavaClass.warpPerspective(LDstMat, LDstMat4, M,
            TJCore_Size.JavaClass.init(maxw, maxh));

          LContoursList.clear;
          TJImgproc.JavaClass.findContours(LDstMat3, LContoursList,
            LHierarchyMat, TJImgproc.JavaClass.RETR_EXTERNAL,
            TJImgproc.JavaClass.CHAIN_APPROX_SIMPLE);

          if JArrayList(LContoursList).Size <> 48 then
          begin
            if SaveDebugImages then
            begin
              TJandroid_Utils.JavaClass.MatToBitmap(LDstMat3, LJBitmap3);
              LSurface := TBitmapSurface.Create;
              try
                JBitmapToSurface(LJBitmap3, LSurface);
                FCamBitmap.Assign(LSurface);
              finally
                LSurface.Free;
              end;
              FCamBitmap.SaveToFile(TPath.Combine(TPath.GetSharedDocumentsPath,
                Format('%s_wrp.%s',[FormatDateTime('dd.mm.yy-hh.nn.ss.zzz',Now), debugImgExt])));
            end;

            EndProc('WarpRegs=' + IntToStr(JArrayList(LContoursList).Size));
            exit;
          end;

          //search the cells with holes
          var dx, dy, n1, n2, n: Integer;
          var s: string;
          s := 'Elements: ';
          dx := maxw div 4;
          dy := maxh div 12;
          for I := 0 to 47 do
          begin
            c := TJMatOfPoint.Wrap(JArrayList(LContoursList).get(I));
            r := TJImgproc.JavaClass.boundingRect(c);
            mat1 := TJMat.JavaClass.init(LDstMat3, r);
            // LDstMat3.locateROI(TJcore_Size.JavaClass.init(r.Width, r.Height),
            // TJcore_Point.JavaClass.init(r.x, r.y));
            n1 := TJCore.JavaClass.countNonZero(mat1);
            mat2 := TJMat.JavaClass.init(LDstMat4, r);
            // LDstMat4.locateROI(TJcore_Size.JavaClass.init(r.Width, r.Height),
            // TJcore_Point.JavaClass.init(r.x, r.y));
            TJCore.JavaClass.bitwise_and(mat1, mat2, mat2);
            n2 := TJCore.JavaClass.countNonZero(mat2);

            n := n2 * 100 div n1;
            a[I].x := r.x;
            a[I].y := r.y;
            a[I].w := r.Width;
            a[I].h := r.Height;
            z[I] := n;
            if n < 100-HolePercent then // 5% for hole at element
              s := s + Format('#%d=%d%%; ',
                [((r.x + r.Width div 2) div dx) + 1 + ((r.y + r.Height div 2)
                div dy) * 4, n]);
          end;
          TThread.Synchronize(TThread.CurrentThread,
            procedure
            begin
              Edit1.Text := s
            end);

          TThread.Synchronize(TThread.CurrentThread,
            procedure
            begin
              Memo1.Lines.Add('Reverse perspective warping was successfull!');
              Memo1.GoToTextEnd
            end);
          TJandroid_Utils.JavaClass.MatToBitmap(LDstMat4, LJBitmap3);
          OutRes := True;
          TThread.Synchronize(TThread.CurrentThread,
            procedure
            begin
              MyBeep;
              DrawStatus(Image1.Bitmap);
              Image1.Repaint;
              ChangeButtonText;
              Camera.Active := False;
              Timer1.Enabled := False;
            end);
          EndProc('SUCCESS!!!', True);
        except
          on E: Exception do
          begin
            EndProc('Exception: ' + E.Message);
            ChangeButtonText;
            Camera.Active := False;
            Timer1.Enabled := False;
          end;
        end;
      finally
        FOpenCVInProgress := False;
      end;

    end).Start;
end;

procedure TfmMain.ProcessImg;
var
  I, j: Integer;
  Data: TBitmapData;
  q: Cardinal;
  r: Integer;
  dx, dy, cf: Integer;
begin
  { if FCamBitmap.Width > FCamBitmap.Height then
    begin
    wellW := FCamBitmap.Height div 24; //maybe 30 - for long distance
    wellH := wellW;
    end
    else
    begin
    wellW := FCamBitmap.Width div 24;
    wellH := wellW;
    end ; }
  //wellW := FCamBitmap.Width div 20;
  wellH := FCamBitmap.Height div 30;
  wellW := wellH;
  mwW := FCamBitmap.Width div 8;
  mwH := FCamBitmap.Height div 12;

  if FCamBitmap.Map(TMapAccess.ReadWrite, Data) then
    try
      cf := Round(1.27*Coef); //little optimize for "shr 7" instead "div 100"
      if UseCropFrame then
      begin
        dx := borderX + borderDXpercent * FCamBitmap.Width div 100;
        dy := borderY + borderDXpercent * FCamBitmap.Height div 100;

        // erase the borders
        for j := 0 to dy - 1 do
          for I := 0 to FCamBitmap.Width - 1 do
          begin
            Data.SetPixel(I, j, $FF000000);
            Data.SetPixel(I, FCamBitmap.Height - j, $FF000000);
          end;
        for j := 0 to FCamBitmap.Height - 1 do
          for I := 0 to dx - 1 do
          begin
            Data.SetPixel(I, j, $FF000000);
            Data.SetPixel(FCamBitmap.Width - I, j, $FF000000);
          end;
      end
      else
      begin
        dx := 0;
        dy := 0;
      end;

      // find and mark red pixels
      for j := dy to FCamBitmap.Height - dy - 1 do
        for I := dx to FCamBitmap.Width - dx - 1 do
        begin
          q := Data.GetPixel(I, j);
          r := Cf * TAlphaColorRec(q).r shr 7;
          if (r > TAlphaColorRec(q).G) and (r > TAlphaColorRec(q).b) then
            Data.SetPixel(I, j, $FFFFFFFF)
          else
            Data.SetPixel(I, j, $FF000000);
        end;
    finally
      FCamBitmap.Unmap(Data);
    end;
end;

procedure TfmMain.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(TPath.Combine(TPath.GetDocumentsPath, 'settings.ini'));
  try
    Ini.WriteInteger('Settings', 'cameraQuality',   integer(cameraQuality));
    Ini.WriteInteger('Settings', 'numOfFrame',      numOfFrame);
    Ini.WriteInteger('Settings', 'coef',            coef);
    Ini.WriteInteger('Settings', 'HolePercent',     HolePercent);
    Ini.WriteBool   ('Settings', 'ShowRes',         ShowRes);
    Ini.WriteBool   ('Settings', 'UseCropFrame',    UseCropFrame);
    Ini.WriteBool   ('Settings', 'SaveDebugImages', SaveDebugImages);
    Ini.WriteInteger('Settings', 'ShowImageMode',   ShowImageMode);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TfmMain.AddWorkLayer;
var
  I, j: Integer;
  Data, data2: TBitmapData;
  q: Cardinal;
  r,g,b,r2,g2,b2: Integer;
  tmpBitmap: TBitmap;
begin
  if ShowImageMode = 1 then
    tmpBitmap := mskBitmap
  else if ShowImageMode = 2 then
    tmpBitmap := cntBitmap
  else exit;

  if Image1.Bitmap.Map(TMapAccess.ReadWrite, Data)
    and tmpBitmap.Map(TMapAccess.Read, Data2) then
    try
      for j := 0 to Image1.Bitmap.Height -1 do
        for I := 0 to Image1.Bitmap.Width -1 do
        begin
          q := Data.GetPixel(I, j);
          r := TAlphaColorRec(q).r;
          g := TAlphaColorRec(q).g;
          b := TAlphaColorRec(q).b;
          q := Data2.GetPixel(I, j);
          r2 := TAlphaColorRec(q).r;
          g2 := TAlphaColorRec(q).g;
          b2 := TAlphaColorRec(q).b;

          TAlphaColorRec(q).r := (r shr 1) + (r2 shr 1);
          TAlphaColorRec(q).g := (g shr 1) + (g2 shr 1);
          TAlphaColorRec(q).b := (b shr 1) + (b2 shr 1);

          Data.SetPixel(I, j, q)
        end;
    finally
      Image1.Bitmap.Unmap(Data);
      tmpBitmap.Unmap(Data);
    end;
end;

procedure TfmMain.CalcImgBorders;
var
  deltaX, deltaY: Integer;
  w, h: Integer;
  d: Single;
  Width, Height: Integer;
begin
  try
    deltaX := 0;
    deltaY := 0;
    d := 1;
    w := 100; // 1.25 - array aspect ratio, but real aspect ratio ~1.5
    h := Round(100 * aspectRatio);
    Width := Round((1 - borderDXpercent / 100) * FCamBitmap.Width);
    Height := Round((1 - borderDYpercent / 100) * FCamBitmap.Height);

    if (w < Width) and (h < Height) then // if small image - zoomIn
    begin
      if w / Width > h / Height then
      begin
        h := Trunc(h * (Width / w));
        w := Width;
        deltaY := Trunc((Height - h) / 2);
      end
      else
      begin
        w := Trunc(w * (Height / h));
        h := Height;
        deltaX := Trunc((Width - w) / 2);
      end
    end;

    if w > Width then
    begin
      d := w / Width;
      deltaY := Trunc((Height - h / d) / 2);
    end;
    if (h > Height) and (h / Height > d) then
    begin
      d := h / Height;
      deltaX := Trunc((Width - w / d) / 2);
      deltaY := 0;
    end;
    if (Width > w) and (Height > h) then
    begin
      deltaX := Trunc((Width - w / d) / 2);
      deltaY := Trunc((Height - h / d) / 2);
    end;
    w := Round(w / d);
    h := Round(h / d);

    borderX := deltaX;
    borderY := deltaY;
  except
  end;
end;

procedure TfmMain.TakePicturePermissionRequestResult(Sender: TObject;
const APermissions: TArray<string>;
const AGrantResults: TArray<TPermissionStatus>);
begin
  if (AGrantResults[0] = TPermissionStatus.Granted) then
  begin

    try
      Camera.Active := False;
      Camera.Quality := FMX.Media.TVideoCaptureQuality.LowQuality;
      Camera.Active := True;
    finally

      FOpenCVInProgress := False;

      Camera.Active := False;
      Camera.Kind := FMX.Media.TCameraKind.BackCamera;
      Camera.FocusMode := FMX.Media.TFocusMode.ContinuousAutoFocus;
      Camera.Quality := cameraQuality; // MediumQuality;
      Camera.Active := True;

    end;

    // FCamera.IsActive := True;
  end
  else
  begin
    TDialogService.ShowMessage
      ('Required camera permissions are not all granted!');
  end;
end;

procedure TfmMain.Timer1Timer(Sender: TObject);
begin
  if ShowRes then
  TTask.Run(
    procedure
    begin
      Edit1.Text := Format('Res: %dx%d, %dfps', [Image1.Bitmap.Width,
        Image1.Bitmap.Height, fFrameTake - oldF]);
      oldF := fFrameTake;
    end)
end;

initialization
  if not TJOpenCVLoader.JavaClass.initDebug then
    TDialogService.ShowMessage('Cant load OpenCV!')
end.
