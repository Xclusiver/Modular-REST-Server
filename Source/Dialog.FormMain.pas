unit Dialog.FormMain;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Services.Sync,
  Services.HorseServer,
  Core.Interfaces,
  Infrastructure.Container;

type
  TFormMain = class(TForm)
    btnStartWorker: TButton;
    btnStopWorker: TButton;
    btnStartHorse: TButton;
    btnStopHorse: TButton;
    procedure btnStartWorkerClick(Sender: TObject);
    procedure btnStopWorkerClick(Sender: TObject);
    procedure btnStopHorseClick(Sender: TObject);
    procedure btnStartHorseClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FWorker: TWorkerThread;
    FHorseServer: THorseServerManager;
    FLogger: IAppLogger;
    FIsClosing: Boolean;
    procedure OnWorkerTerminated(Sender: TObject);
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.btnStartHorseClick(Sender: TObject);
begin
  FHorseServer.Start;
end;

procedure TFormMain.btnStartWorkerClick(Sender: TObject);
var
  LSyncService: ISyncService;
  LConfig: IAppConfig;
begin
  if not Assigned(FWorker) then
  begin
    LSyncService := TContainer.Resolve<ISyncService>;
    LConfig := TContainer.Resolve<IAppConfig>;

    // U¿ycie dynamicznego interwa³u
    FWorker := TWorkerThread.Create(LSyncService, FLogger, LConfig.GetWorkerInterval);
    FWorker.Start;
  end;
end;

procedure TFormMain.btnStopHorseClick(Sender: TObject);
begin
  FHorseServer.Stop;
end;

procedure TFormMain.btnStopWorkerClick(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    FWorker.OnTerminate := nil;
    FWorker.Terminate;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;
end;

procedure TFormMain.OnWorkerTerminated(Sender: TObject);
begin
  Close;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FIsClosing then
  begin
    CanClose := True;
    Exit;
  end;

  if Assigned(FHorseServer) then
    FHorseServer.Stop;

  if Assigned(FWorker) then
  begin
    CanClose := False;
    FIsClosing := True;

    FWorker.OnTerminate := OnWorkerTerminated;
    FWorker.Terminate;

    // Ukrywamy okno, VCL pozostaje responsywne i czeka na OnTerminate
    Self.Hide;
  end
  else
    CanClose := True;
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  LConfig: IAppConfig;
begin
  FIsClosing := False;
  FLogger := TContainer.Resolve<IAppLogger>;
  LConfig := TContainer.Resolve<IAppConfig>;

  FHorseServer := THorseServerManager.Create(FLogger, LConfig.GetHorsePort);
  FLogger.LogInfo('Aplikacja uruchomiona');
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  if Assigned(FWorker) then
  begin
    // Wraca natychmiast, bo w¹tek ju¿ siê zakoñczy³
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;

  if Assigned(FHorseServer) then
    FreeAndNil(FHorseServer);
end;

end.
