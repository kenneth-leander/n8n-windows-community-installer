// ---------------------------------------------------------------------------
// docker.iss - n8n in a Docker container
//
//   container   Cfg.DockerName    runs the n8n image, restarts with Docker Desktop
//   volume      Cfg.DockerVolume  keeps your workflows and passwords; survives updates and removal
// ---------------------------------------------------------------------------

function ContainerExists(const Name: String): Boolean;
var
  Lines: TArrayOfString;
  Code, I: Integer;
begin
  Result := False;
  if CaptureCmd('docker ps -a --filter "name=^/' + Name + '$" --format "{{.Names}}"', Lines, Code) and (Code = 0) then
    for I := 0 to GetArrayLength(Lines) - 1 do
      if Trim(Lines[I]) = Name then
        Result := True;
end;

// True when a container of that name is running right now (not just present).
function ContainerRunning(const Name: String): Boolean;
var
  Lines: TArrayOfString;
  Code, I: Integer;
begin
  Result := False;
  if CaptureCmd('docker ps --filter "name=^/' + Name + '$" --format "{{.Names}}"', Lines, Code) and (Code = 0) then
    for I := 0 to GetArrayLength(Lines) - 1 do
      if Trim(Lines[I]) = Name then
        Result := True;
end;

// The tag of the image to install, from the choice on the Docker page.
function ResolveDockerTag: String;
var
  Lines: TArrayOfString;
  I: Integer;
  Head, Tail, V2, V3: String;
begin
  if Cfg.DockerChannel = ChannelCustom then
  begin
    Result := Cfg.DockerCustomTag;
    Exit;
  end;
  V2 := '';
  V3 := '';
  if not GDryRun then
  begin
    RunHelperCapture('docker-tag.ps1', '', Lines);
    for I := 0 to GetArrayLength(Lines) - 1 do
    begin
      SplitOnce(Trim(Lines[I]), '=', Head, Tail);
      if (Head = 'v2') and IsTagSafe(Tail) then V2 := Tail;
      if (Head = 'v3') and IsTagSafe(Tail) then V3 := Tail;
    end;
  end;
  if Cfg.DockerChannel = ChannelNewest3 then
  begin
    if V3 = '' then
      Fail('The n8n 3 preview could not be found on Docker Hub right now. Choose the stable n8n 2.x instead, or try again later.');
    Result := V3;
  end
  else
  begin
    if V2 = '' then
    begin
      LogLine('Could not ask Docker Hub for the newest release, so the built-in version ' + DockerFallbackTag + ' is used.');
      V2 := DockerFallbackTag;
    end;
    Result := V2;
  end;
end;

procedure InstallDocker;
var
  Tag, Bind, Extra: String;
  Code: Integer;
begin
  Step('Checking that Docker is running');
  if not GDryRun then
  begin
    DetectDocker;
    if not DockerReady then
      Fail(DockerStatusText);
  end;

  Step('Looking up which n8n version to install');
  Tag := ResolveDockerTag;
  GDockerImage := DockerImage + ':' + Tag;
  LogLine('n8n image: ' + GDockerImage);

  Step('Downloading n8n for Docker. This is about 1 GB and takes a few minutes.');
  Working(True);
  Code := RunCmd('docker pull ' + GDockerImage, '');
  if Code <> 0 then
  begin
    // n8n's own address did not answer; the same image is also on Docker Hub.
    LogLine('That did not work. Trying Docker Hub instead...');
    GDockerImage := 'n8nio/n8n:' + Tag;
    Code := RunCmd('docker pull ' + GDockerImage, '');
  end;
  Working(False);
  if Code <> 0 then
    Fail('Docker could not download n8n (exit code ' + IntToStr(Code) + ').' + #13#10#13#10 + LastLinesText);

  Step('Starting n8n');
  if ContainerExists(Cfg.DockerName) then
  begin
    LogLine('Replacing the existing container "' + Cfg.DockerName + '". Its data volume is not touched.');
    RunCmd('docker rm -f ' + Cfg.DockerName, '');
  end;
  if RunCmd('docker volume create ' + Cfg.DockerVolume, '') <> 0 then
    Fail('Docker could not create the data volume "' + Cfg.DockerVolume + '".' + #13#10#13#10 + LastLinesText);

  // Docker publishes the port on every network card unless told otherwise, so say "this computer only".
  if Cfg.Lan then Bind := '' else Bind := '127.0.0.1:';
  Extra := '';
  if Cfg.Lan then Extra := Extra + ' -e N8N_SECURE_COOKIE=false';
  if Cfg.Port <> DefaultPort then Extra := Extra + ' -e WEBHOOK_URL=' + LocalUrl(Cfg.Port) + '/';
  Code := RunCmd('docker run -d --name ' + Cfg.DockerName + ' --restart unless-stopped' +
    ' -p ' + Bind + IntToStr(Cfg.Port) + ':5678' +
    ' -e GENERIC_TIMEZONE=' + Cfg.DockerTz + ' -e TZ=' + Cfg.DockerTz + Extra +
    ' -v ' + Cfg.DockerVolume + ':/home/node/.n8n ' + GDockerImage, '');
  if Code <> 0 then
    Fail('Docker could not start n8n (exit code ' + IntToStr(Code) + ').' + #13#10#13#10 + LastLinesText);

  Step('Waiting for n8n to answer (the first start takes a minute)');
  Working(True);
  Code := RunHelperLive('wait-n8n.ps1', '-Url ' + Q(LocalUrl(Cfg.Port)) + ' -TimeoutSec 240');
  Working(False);
  if Code <> 0 then
  begin
    RunCmd('docker logs --tail 30 ' + Cfg.DockerName, '');
    if ContainerRunning(Cfg.DockerName) then
      LogLine('n8n has not answered yet. It may still be starting; the container is running. Check:  docker logs ' + Cfg.DockerName)
    else
      Fail('The n8n container stopped right after it started.' + #13#10#13#10 + LastLinesText);
  end;
  GN8nVersion := Tag;

  Step('Creating the Start n8n and Stop n8n shortcuts');
  SetCommonVars;
  SetVar('DOCKER_NAME', Cfg.DockerName);
  SetVar('DOCKER_VOLUME', Cfg.DockerVolume);
  SetVar('IMAGE', GDockerImage);
  SetVar('TZ', Cfg.DockerTz);
  WriteFromTemplate('start-docker.cmd', AppDir + '\start-n8n.cmd');
  WriteFromTemplate('stop-docker.cmd', AppDir + '\stop-n8n.cmd');
end;
