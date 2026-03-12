unit Infrastructure.Database.Oracle;

interface

// Jeśli jest ODAC
// {$DEFINE USE_DEVART_ODAC}

uses
  System.SysUtils,
  System.Classes,
  Core.Interfaces,
  Data.DB
{$IFDEF USE_DEVART_ODAC}
    ,
  Ora,
  DBAccess,
  MemDS
{$ELSE}
    ,
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
  FireDAC.Phys.ODBCBase,
  FireDAC.Phys.ODBCCli,
  FireDAC.Phys.ODBCWrapper,
  FireDAC.VCLUI.Wait
{$ENDIF};

type
  TDbOracleManager = class(TInterfacedObject, IDatabaseManager)
  private
    FLogger: IAppLogger;
{$IFNDEF USE_DEVART_ODAC}
    class function GetPooledConnection: TFDConnection;
{$ENDIF}
  public
    constructor Create(const ALogger: IAppLogger);
    class procedure InitializePool(const AConnectionString: string);
    class procedure DestroyPool;
    class procedure InitializeDatabase;

    procedure SaveData(const AJsonData: string);
    function GetDataAsJson: string;
  end;

const
  ORACLE_POOL_DEF_NAME = 'MyDataSyncOraclePool';

{$IFDEF USE_DEVART_ODAC}

var
  GlobalOraSession: TOraSession; // ODAC używa głównej sesji z włączonym Pooling=True
{$ENDIF}

implementation

constructor TDbOracleManager.Create(const ALogger: IAppLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

class procedure TDbOracleManager.InitializePool(const AConnectionString: string);
{$IFNDEF USE_DEVART_ODAC}
var
  LParams: TStringList;
begin
  LParams := TStringList.Create;
  try
    LParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
    LParams.Add('Pooled=True');
    LParams.Add('POOL_MaximumItems=50');

    FDManager.AddConnectionDef(ORACLE_POOL_DEF_NAME, 'ODBC', LParams);
    FDManager.Active := True;
  finally
    LParams.Free;
  end;
end;
{$ELSE}

begin
  // Inicjalizacja puli połączeń dla Devart ODAC
  GlobalOraSession := TOraSession.Create(nil);
  GlobalOraSession.ConnectString := AConnectionString;
  GlobalOraSession.Options.UseUnicode := True;
  GlobalOraSession.Pooling := True;
  GlobalOraSession.PoolingOptions.MaxPoolSize := 50;
  GlobalOraSession.Connect;
end;
{$ENDIF}

class procedure TDbOracleManager.DestroyPool;
begin
{$IFNDEF USE_DEVART_ODAC}
  FDManager.Close;
{$ELSE}
  if Assigned(GlobalOraSession) then
  begin
    GlobalOraSession.Disconnect;
    FreeAndNil(GlobalOraSession);
  end;
{$ENDIF}
end;

{$IFNDEF USE_DEVART_ODAC}

class function TDbOracleManager.GetPooledConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.ConnectionDefName := ORACLE_POOL_DEF_NAME;
  Result.Open;
end;
{$ENDIF}

class procedure TDbOracleManager.InitializeDatabase;
{$IFNDEF USE_DEVART_ODAC}
var
  LConn: TFDConnection;
begin
  LConn := GetPooledConnection;
  try
    LConn.ExecSQL('DECLARE ' + '  cnt NUMBER; ' + 'BEGIN ' +
      '  SELECT count(*) INTO cnt FROM user_tables WHERE table_name = ''MYTABLE''; ' + '  IF cnt = 0 THEN ' +
      '    EXECUTE IMMEDIATE ''CREATE TABLE MYTABLE (Id NUMBER GENERATED ALWAYS AS IDENTITY, Data CLOB NOT NULL, CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''; '
      + '  END IF; ' + 'END;');
  finally
    LConn.Free;
  end;
end;
{$ELSE}

var
  LQuery: TOraQuery;
begin
  LQuery := TOraQuery.Create(nil);
  try
    LQuery.Session := GlobalOraSession;
    LQuery.SQL.Text := 'DECLARE ' + '  cnt NUMBER; ' + 'BEGIN ' +
      '  SELECT count(*) INTO cnt FROM user_tables WHERE table_name = ''MYTABLE''; ' + '  IF cnt = 0 THEN ' +
      '    EXECUTE IMMEDIATE ''CREATE TABLE MYTABLE (Id NUMBER GENERATED ALWAYS AS IDENTITY, Data CLOB NOT NULL, CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''; '
      + '  END IF; ' + 'END;';
    LQuery.Execute;
  finally
    LQuery.Free;
  end;
end;
{$ENDIF}

procedure TDbOracleManager.SaveData(const AJsonData: string);
{$IFNDEF USE_DEVART_ODAC}
var
  LConn: TFDConnection;
begin
  LConn := GetPooledConnection;
  try
    LConn.StartTransaction;
    try
      LConn.ExecSQL('INSERT INTO MYTABLE (Data) VALUES (:data)', [AJsonData]);
      LConn.Commit;
      FLogger.LogInfo('Zsynchronizowano dane (Oracle ODBC).');
    except
      on E: Exception do
      begin
        LConn.Rollback;
        FLogger.LogError('Błąd Oracle ODBC: ' + E.Message);
      end;
    end;
  finally
    LConn.Free;
  end;
end;
{$ELSE}

var
  LQuery: TOraQuery;
begin
  LQuery := TOraQuery.Create(nil);
  try
    LQuery.Session := GlobalOraSession;
    LQuery.SQL.Text := 'INSERT INTO MYTABLE (Data) VALUES (:data)';
    LQuery.ParamByName('data').AsString := AJsonData;

    GlobalOraSession.StartTransaction;
    try
      LQuery.Execute;
      GlobalOraSession.Commit;
      FLogger.LogInfo('Zsynchronizowano dane (Oracle ODAC).');
    except
      on E: Exception do
      begin
        GlobalOraSession.Rollback;
        FLogger.LogError('Błąd Oracle ODAC: ' + E.Message);
      end;
    end;
  finally
    LQuery.Free;
  end;
end;
{$ENDIF}

function TDbOracleManager.GetDataAsJson: string;
{$IFNDEF USE_DEVART_ODAC}
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
      LQuery.SQL.Text := 'SELECT Data FROM MYTABLE ORDER BY Id DESC FETCH FIRST 1 ROWS ONLY';
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
{$ELSE}

var
  LQuery: TOraQuery;
begin
  Result := '';
  LQuery := TOraQuery.Create(nil);
  try
    LQuery.Session := GlobalOraSession;
    LQuery.SQL.Text := 'SELECT Data FROM MYTABLE ORDER BY Id DESC FETCH FIRST 1 ROWS ONLY';
    LQuery.Open;
    if not LQuery.IsEmpty then
      Result := LQuery.FieldByName('Data').AsString;
  finally
    LQuery.Free;
  end;
end;
{$ENDIF}

end.
