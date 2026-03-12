unit Infrastructure.Config;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  Core.Interfaces;

type
  TAppConfig = class(TInterfacedObject, IAppConfig)
  private
    FApiUrl: string;
    FApiKey: string;
    FDbType: TSupportedDatabase;
    FDbConnectionString: string;
    FLogPath: string;
    FWorkerInterval: Integer;
    FHorsePort: Integer;
    function StringToDbType(const ATypeStr: string): TSupportedDatabase;
    procedure LoadFromFile(const AFileName: string);
    procedure CreateDefault(const AFileName: string);
  public
    constructor Create(const AFileName: string);
    function GetDbType: TSupportedDatabase;
    function GetDbConnectionString: string;
    function GetApiUrl: string;
    function GetApiKey: string;
    function GetLogPath: string;
    function GetWorkerInterval: Integer;
    function GetHorsePort: Integer;
  end;

implementation

constructor TAppConfig.Create(const AFileName: string);
begin
  inherited Create;
  if TFile.Exists(AFileName) then
    LoadFromFile(AFileName)
  else
    CreateDefault(AFileName);
end;

procedure TAppConfig.CreateDefault(const AFileName: string);
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    FApiUrl := 'https://randomuser.me/api';
    FDbType := dbSQLite;
    // Dla Oracle @ ODBC := "ODBCDriver=Oracle in OraClient11g_home1;DataSource=MójTNSName;User_Name=admin;Password=tajne"
    // Dla MS SQL @ ODBC := "Driver={ODBC Driver 17 for SQL Server};Server=ADRES_IP_LUB_NAZWA;Database=NAZWA_BAZY;Uid=UZYTKOWNIK;Pwd=HASLO;"
    FDbConnectionString := 'database.db';
    FLogPath := 'log.txt';
    FWorkerInterval := 60000;
    FHorsePort := 9000;
    FApiKey := 'SECRET_TOKEN_123'; // Domyślny klucz zabezpieczający
    LJson.AddPair('apiUrl', FApiUrl);
    // Wartości: sqlite, oracle, firebird, mssql
    LJson.AddPair('dbType', 'sqlite');
    LJson.AddPair('dbConnectionString', FDbConnectionString);
    LJson.AddPair('logPath', FLogPath);
    LJson.AddPair('workerIntervalMs', TJSONNumber.Create(FWorkerInterval));
    LJson.AddPair('horsePort', TJSONNumber.Create(FHorsePort));
    LJson.AddPair('apiKey', FApiKey);

    TFile.WriteAllText(AFileName, LJson.Format(2), TEncoding.UTF8);
  finally
    LJson.Free;
  end;
end;

function TAppConfig.StringToDbType(const ATypeStr: string): TSupportedDatabase;
begin
  if SameText(ATypeStr, 'sqlite') then
    Result := dbSQLite
  else
    if SameText(ATypeStr, 'oracle') then
      Result := dbOracle
    else
      if SameText(ATypeStr, 'firebird') then
        Result := dbFirebird
      else
        if SameText(ATypeStr, 'mssql') then
          Result := dbMSSQL
        else
          Result := dbUnknown;
end;

procedure TAppConfig.LoadFromFile(const AFileName: string);
var
  LJsonStr, LDbString: string;
  LJson: TJSONObject;
begin
  LJsonStr := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
  if Assigned(LJson) then
    try
      FApiUrl := LJson.GetValue('apiUrl').Value;
      LDbString := LJson.GetValue('dbType').Value;
      FDbType := StringToDbType(LDbString);
      FDbConnectionString := LJson.GetValue('dbConnectionString').Value;
      FLogPath := LJson.GetValue('logPath').Value;
      FWorkerInterval := (LJson.GetValue('workerIntervalMs') as TJSONNumber).AsInt;
      FHorsePort := (LJson.GetValue('horsePort') as TJSONNumber).AsInt;
      FApiKey := LJson.GetValue('apiKey').Value;
    finally
      LJson.Free;
    end;
end;

function TAppConfig.GetApiUrl: string;
begin
  Result := FApiUrl;
end;

function TAppConfig.GetApiKey: string;
begin
  Result := FApiKey;
end;

function TAppConfig.GetLogPath: string;
begin
  Result := FLogPath;
end;

function TAppConfig.GetWorkerInterval: Integer;
begin
  Result := FWorkerInterval;
end;

function TAppConfig.GetHorsePort: Integer;
begin
  Result := FHorsePort;
end;

function TAppConfig.GetDbType: TSupportedDatabase;
begin
  Result := FDbType;
end;

function TAppConfig.GetDbConnectionString: string;
begin
  Result := FDbConnectionString;
end;

end.
