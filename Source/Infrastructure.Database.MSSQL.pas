unit Infrastructure.Database.MSSQL;

interface

uses
  System.SysUtils, System.Classes, Core.Interfaces, Data.DB,
  FireDAC.Comp.Client, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.ODBCBase, FireDAC.Phys.ODBCCli, FireDAC.Phys.ODBCWrapper,
  FireDAC.VCLUI.Wait;

type
  TDbMSSQLManager = class(TInterfacedObject, IDatabaseManager)
  private
    FLogger: IAppLogger;
    class function GetPooledConnection: TFDConnection;
  public
    constructor Create(const ALogger: IAppLogger);
    class procedure InitializePool(const AConnectionString: string);
    class procedure DestroyPool;
    class procedure InitializeDatabase;

    procedure SaveData(const AJsonData: string);
    function GetDataAsJson: string;
  end;

const
  MSSQL_ODBC_POOL_DEF_NAME = 'MyDataSyncMSSQLOdbcPool';

implementation

constructor TDbMSSQLManager.Create(const ALogger: IAppLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

class procedure TDbMSSQLManager.InitializePool(const AConnectionString: string);
var
  LParams: TStringList;
begin
  LParams := TStringList.Create;
  try
    LParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
    LParams.Add('Pooled=True');
    LParams.Add('POOL_MaximumItems=50');

    // Rejestrujemy pulę z wykorzystaniem ODBC
    FDManager.AddConnectionDef(MSSQL_ODBC_POOL_DEF_NAME, 'ODBC', LParams);
    FDManager.Active := True;
  finally
    LParams.Free;
  end;
end;

class procedure TDbMSSQLManager.DestroyPool;
begin
  FDManager.Close;
end;

class function TDbMSSQLManager.GetPooledConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.ConnectionDefName := MSSQL_ODBC_POOL_DEF_NAME;
  Result.Open;
end;

class procedure TDbMSSQLManager.InitializeDatabase;
var
  LConn: TFDConnection;
begin
  LConn := GetPooledConnection;
  try
    // Dialekt T-SQL przesyłany przez ODBC
    LConn.ExecSQL(
      'IF NOT EXISTS (SELECT * FROM sysobjects WHERE name=''MyTable'' and xtype=''U'') ' +
      'BEGIN ' +
      '  CREATE TABLE MyTable (Id INT IDENTITY(1,1) PRIMARY KEY, ' +
      '  Data NVARCHAR(MAX) NOT NULL, CreatedAt DATETIME DEFAULT GETDATE()) ' +
      'END'
    );
  finally
    LConn.Free;
  end;
end;

procedure TDbMSSQLManager.SaveData(const AJsonData: string);
var
  LConn: TFDConnection;
begin
  LConn := GetPooledConnection;
  try
    LConn.StartTransaction;
    try
      LConn.ExecSQL('INSERT INTO MyTable (Data) VALUES (:data)', [AJsonData]);
      LConn.Commit;
      FLogger.LogInfo('Zsynchronizowano dane (MS SQL via ODBC).');
    except
      on E: Exception do
      begin
        LConn.Rollback;
        FLogger.LogError('Błąd MS SQL ODBC: ' + E.Message);
      end;
    end;
  finally
    LConn.Free;
  end;
end;

function TDbMSSQLManager.GetDataAsJson: string;
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
      // MS SQL używa TOP 1 do limitowania wyników
      LQuery.SQL.Text := 'SELECT TOP 1 Data FROM MyTable ORDER BY Id DESC';
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
