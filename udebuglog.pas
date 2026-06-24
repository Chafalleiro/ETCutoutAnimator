// File: uDebugLog.pas
unit uDebugLog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, ExtCtrls;

type
  TDebugLogLevel = (dllDebug, dllInfo, dllWarning, dllError);

  TDebugLogCallback = procedure(const Msg: String; Level: TDebugLogLevel) of object;

  { TDebugLogger }
  TDebugLogger = class
  private
    class var FLogCallback: TDebugLogCallback;
    class var FLogLevel: TDebugLogLevel;
    class var FLogFile: TextFile;
    class var FLogFileName: String;
    class var FQueue: TStringList;
    class var FCriticalSection: TCriticalSection;
    class var FTimer: TTimer;
    class var FFlushInterval: Integer; // en milisegundos
    class procedure InternalLog(const Msg: String; Level: TDebugLogLevel; const Routine, UnitFile: String; const Line: Integer);
    class procedure TimerHandler(Sender: TObject);
    class procedure FlushQueue; // escribe todos los mensajes pendientes
  public
    // Basic logging methods with optional context
    class procedure Log(const Msg: String; Level: TDebugLogLevel = dllInfo; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); overload;
    class procedure LogFmt(const FormatStr: String; const Args: array of const; Level: TDebugLogLevel = dllInfo; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); overload;

    // Convenience methods with optional context
    class procedure Info(const Msg: String; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;
    class procedure Warning(const Msg: String; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;
    class procedure Error(const Msg: String; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;
    class procedure Debug(const Msg: String; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;

    class procedure InfoFmt(const FormatStr: String; const Args: array of const; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;
    class procedure WarningFmt(const FormatStr: String; const Args: array of const; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;
    class procedure ErrorFmt(const FormatStr: String; const Args: array of const; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;
    class procedure DebugFmt(const FormatStr: String; const Args: array of const; const Routine: String = ''; const UnitFile: String = ''; const Line: Integer = 0); inline;

    // Configuration
    class procedure SetCallback(Callback: TDebugLogCallback);
    class procedure SetLogLevel(Level: TDebugLogLevel);
    class function GetLogLevel: TDebugLogLevel;
    class procedure SetLogFile(const FileName: String);
    class procedure SetFlushInterval(IntervalMs: Integer); // por defecto 5 ms

    // File management
    class procedure OpenLogFile;
    class procedure CloseLogFile;

    // Inicialización y finalización
    class constructor Create;
    class destructor Destroy;
  end;

implementation

uses
  DateUtils;

function GetLevelPrefix(Level: TDebugLogLevel): String;
begin
  case Level of
    dllInfo:    Result := 'INFO';
    dllWarning: Result := 'WARNING';
    dllError:   Result := 'ERROR';
    dllDebug:   Result := 'DEBUG';
  else
    Result := 'INFO';
  end;
end;

{ TDebugLogger }

class constructor TDebugLogger.Create;
begin
  FLogLevel := {$IFOPT D+}dllDebug{$ELSE}dllInfo{$ENDIF};
  FLogCallback := nil;
  FLogFileName := '';
  FQueue := TStringList.Create;
  FCriticalSection := TCriticalSection.Create;
  FFlushInterval := 15; // 5 ms por defecto
  FTimer := TTimer.Create(nil);
  FTimer.Interval := FFlushInterval;
  FTimer.OnTimer := @TimerHandler;
  FTimer.Enabled := False; // lo activamos cuando haya algo en la cola
  TTextRec(FLogFile).Mode := fmClosed;
end;

class destructor TDebugLogger.Destroy;
begin
  FTimer.Enabled := False;
  FlushQueue; // escribir pendientes
  CloseLogFile;
  FTimer.Free;
  FCriticalSection.Free;
  FQueue.Free;
end;

class procedure TDebugLogger.InternalLog(const Msg: String; Level: TDebugLogLevel; const Routine, UnitFile: String; const Line: Integer);
var
  LogMsg, FullMsg: String;
begin
  if Ord(Level) < Ord(FLogLevel) then Exit;

  // Construir mensaje con contexto si está disponible
  if (Routine <> '') and (UnitFile <> '') then
  begin
    if Line > 0 then
      FullMsg := Format('[%s:%s(%d)] %s', [ExtractFileName(UnitFile), Routine, Line, Msg])
    else
      FullMsg := Format('[%s:%s] %s', [ExtractFileName(UnitFile), Routine, Msg]);
  end
  else
    FullMsg := Msg;

  LogMsg := Format('%s: %s', [GetLevelPrefix(Level), FullMsg]);

  // Añadir a la cola
  FCriticalSection.Enter;
  try
    FQueue.Add(LogMsg);
    if not FTimer.Enabled then
      FTimer.Enabled := True; // activar el temporizador
  finally
    FCriticalSection.Leave;
  end;

  // Llamar callback inmediato (sigue siendo síncrono, pero puede ser útil)
  if Assigned(FLogCallback) then
    FLogCallback(LogMsg, Level);
end;

class procedure TDebugLogger.TimerHandler(Sender: TObject);
begin
  FTimer.Enabled := False; // desactivar mientras procesamos
  FlushQueue;
  // si quedan mensajes (por si llegaron mientras escribíamos), reactivar
  if FQueue.Count > 0 then
    FTimer.Enabled := True;
end;

class procedure TDebugLogger.FlushQueue;
var
  Msg: String;
  I: Integer;
begin
  // Sacamos todos los mensajes de la cola bajo protección
  FCriticalSection.Enter;
  try
    if FQueue.Count = 0 then Exit;
    // Hacemos una copia local para liberar rápido la sección crítica
    Msg := FQueue.Text; // Text incluye saltos de línea al final de cada elemento
    FQueue.Clear;
  finally
    FCriticalSection.Leave;
  end;

  // Escribir en consola (solo debug builds)
  {$IFOPT D+}
  Write(Msg); // Write sin salto extra, porque Msg ya tiene saltos
  {$ENDIF}

  // Escribir en archivo
  if FLogFileName <> '' then
  begin
    try
      Write(FLogFile, Msg);
      Flush(FLogFile);
    except
      // Ignorar errores
    end;
  end;
end;

class procedure TDebugLogger.Log(const Msg: String; Level: TDebugLogLevel; const Routine, UnitFile: String; const Line: Integer);
begin
  InternalLog(Msg, Level, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.LogFmt(const FormatStr: String; const Args: array of const; Level: TDebugLogLevel; const Routine, UnitFile: String; const Line: Integer);
begin
  InternalLog(Format(FormatStr, Args), Level, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.Info(const Msg: String; const Routine, UnitFile: String; const Line: Integer);
begin
  Log(Msg, dllInfo, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.Warning(const Msg: String; const Routine, UnitFile: String; const Line: Integer);
begin
  Log(Msg, dllWarning, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.Error(const Msg: String; const Routine, UnitFile: String; const Line: Integer);
begin
  Log(Msg, dllError, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.Debug(const Msg: String; const Routine, UnitFile: String; const Line: Integer);
begin
  Log(Msg, dllDebug, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.InfoFmt(const FormatStr: String; const Args: array of const; const Routine, UnitFile: String; const Line: Integer);
begin
  LogFmt(FormatStr, Args, dllInfo, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.WarningFmt(const FormatStr: String; const Args: array of const; const Routine, UnitFile: String; const Line: Integer);
begin
  LogFmt(FormatStr, Args, dllWarning, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.ErrorFmt(const FormatStr: String; const Args: array of const; const Routine, UnitFile: String; const Line: Integer);
begin
  LogFmt(FormatStr, Args, dllError, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.DebugFmt(const FormatStr: String; const Args: array of const; const Routine, UnitFile: String; const Line: Integer);
begin
  LogFmt(FormatStr, Args, dllDebug, Routine, UnitFile, Line);
end;

class procedure TDebugLogger.SetCallback(Callback: TDebugLogCallback);
begin
  FLogCallback := Callback;
end;

class procedure TDebugLogger.SetLogLevel(Level: TDebugLogLevel);
begin
  FLogLevel := Level;
end;

class function TDebugLogger.GetLogLevel: TDebugLogLevel;
begin
  Result := FLogLevel;
end;

class procedure TDebugLogger.SetLogFile(const FileName: String);
begin
  if FLogFileName <> FileName then
  begin
    CloseLogFile;
    FLogFileName := FileName;
    if FileName <> '' then
      OpenLogFile;
  end;
end;

class procedure TDebugLogger.SetFlushInterval(IntervalMs: Integer);
begin
  FFlushInterval := IntervalMs;
  FTimer.Interval := IntervalMs;
end;

class procedure TDebugLogger.OpenLogFile;
begin
  if FLogFileName <> '' then
  begin
    try
      AssignFile(FLogFile, FLogFileName);
      if FileExists(FLogFileName) then
        Append(FLogFile)
      else
        Rewrite(FLogFile);
      WriteLn(FLogFile, '');
      WriteLn(FLogFile, Format('===(uDebugLog) Log started at %s ===',
        [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
    except
      FLogFileName := '';
    end;
  end;
end;

class procedure TDebugLogger.CloseLogFile;
begin
  if FLogFileName <> '' then
  begin
    try
      if TTextRec(FLogFile).Mode <> fmClosed then
      begin
        WriteLn(FLogFile, Format('===(uDebugLog) Log ended at %s ===',
          [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)]));
        CloseFile(FLogFile);
      end;
    except
      // Ignore errors on close
    end;
  end;
end;

end.
