unit Infrastructure.Database.SQLite;

interface

uses
  System.SysUtils,
  System.Classes,
  Core.Interfaces,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  FireDAC.VCLUI.Wait,
  Data.DB,
  FireDAC.DApt;

type
  TDbSQLiteManager = class(TInterfacedObject, IDatabaseManager)
  private
    FLogger: IAppLogger;
    function GetPooledConnection: TFDConnection;
  public
    constructor Create(const ALogger: IAppLogger);
    class procedure InitializePool(const ADatabasePath: string);
    class procedure DestroyPool;
    class procedure InitializeDatabase;
    procedure SaveData(const AJsonData: string);
    function GetDataAsJson: string;
  end;

const
  POOL_DEF_NAME = 'MyDataSyncPool';

implementation

constructor TDbSQLiteManager.Create(const ALogger: IAppLogger);
begin
  inherited Create;
  FLogger := ALogger; // Logger wstrzyknięty przez DI
end;

class procedure TDbSQLiteManager.InitializeDatabase;
var
  LConn: TFDConnection;
begin
  LConn := TFDConnection.Create(nil);
  try
    LConn.ConnectionDefName := POOL_DEF_NAME;
    LConn.Open;

    LConn.ExecSQL('CREATE TABLE IF NOT EXISTS MyTable (' + '  Id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      '  Data TEXT NOT NULL, ' + '  CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP' + ')');
  finally
    LConn.Free;
  end;
end;

class procedure TDbSQLiteManager.InitializePool(const ADatabasePath: string);
var
  LParams: TStringList;
begin
  LParams := TStringList.Create;
  try
    LParams.Add('Database=' + ADatabasePath);
    LParams.Add('LockingMode=Normal'); // Ważne dla SQLite przy wielowątkowości
    LParams.Add('Synchronous=Normal');
    LParams.Add('Pooled=True');
    LParams.Add('POOL_MaximumItems=50');

    FDManager.AddConnectionDef(POOL_DEF_NAME, 'SQLite', LParams);
    FDManager.Active := True;
  finally
    LParams.Free;
  end;
end;

class procedure TDbSQLiteManager.DestroyPool;
begin
  FDManager.Close;
end;

function TDbSQLiteManager.GetPooledConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.ConnectionDefName := POOL_DEF_NAME;
  // W momencie wykonania .Open(), FireDAC pobiera z puli otwarte fizyczne połączenie
  Result.Open;
end;

procedure TDbSQLiteManager.SaveData(const AJsonData: string);
var
  LConn: TFDConnection;
  LQuery: TFDQuery;
begin
  LConn := GetPooledConnection;
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := LConn;
      LConn.StartTransaction;
      try
        LQuery.SQL.Text := 'INSERT INTO MYTABLE (Data) VALUES (:data)';
        LQuery.ParamByName('data').AsString := AJsonData;
        LQuery.ExecSQL;
        LConn.Commit;
        FLogger.LogInfo('Pomyślnie zsynchronizowano dane do bazy.');
      except
        on E: Exception do
        begin
          LConn.Rollback;
          FLogger.LogError('Błąd podczas zapisu do bazy: ' + E.Message, E);
          raise;
        end;
      end;
    finally
      LQuery.Free;
    end;
  finally
    // Zwrócenie połączenia do puli
    LConn.Free;
  end;
end;

function TDbSQLiteManager.GetDataAsJson: string;
var
  LConn: TFDConnection;
  LQuery: TFDQuery;
begin
  Result := '';
  LConn := GetPooledConnection;
  try
    LQuery := TFDQuery.Create(nil);
    try
      LQuery.Connection := LConn;
      LQuery.SQL.Text := 'SELECT Data FROM MyTable ORDER BY Id DESC LIMIT 1';
      LQuery.Open;
      if not LQuery.IsEmpty then
        Result := LQuery.FieldByName('Data').AsString;
    finally
      LQuery.Free;
    end;
  finally
    LConn.Free;
  end;
end;

end.
