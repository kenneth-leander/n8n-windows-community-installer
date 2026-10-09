// ---------------------------------------------------------------------------
// wsl.iss - n8n inside a Linux distribution in WSL2   (placeholder, being written)
// ---------------------------------------------------------------------------

function WslDataDisplay: String;
begin
  Result := 'inside ' + Cfg.WslDistro;
end;

procedure SaveWslState;
begin
end;

procedure InstallWsl;
begin
  Fail('The Linux (WSL2) option is not finished yet.');
end;

procedure UninstallWslInstall;
begin
end;
