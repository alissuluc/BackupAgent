unit BackupAgent.Terminal.UIAssets;

interface

procedure ExtractUIDependencies(const APath: string);
procedure ExtractWebView2Loader;

implementation

uses System.Classes, System.SysUtils, Winapi.Windows;

const
  HTML_CONTENT = 
    '<!DOCTYPE html>' +
    '<html lang="pt-BR">' +
    '<head>' +
    '    <meta charset="UTF-8">' +
    '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
    '    <title>BackupAgent UI</title>' +
    '    <style>' +
    '        body { background: #f8fafc; color: #334155; font-family: "Segoe UI", sans-serif; margin: 0; padding: 1rem; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; box-sizing: border-box; overflow: hidden; }' +
    '        .card { background: #ffffff; border-radius: 12px; padding: 1.5rem; width: 100%; max-width: 600px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; border-top: 5px solid #e31e24; box-sizing: border-box; }' +
    '        h1 { margin-top: 0; font-size: 1.5rem; color: #58595b; display: flex; align-items: center; justify-content: center; gap: 10px; }' +
    '        .highlight { color: #e31e24; font-weight: 800; }' +
    '        .progress-wrapper { background: #e2e8f0; border-radius: 999px; height: 20px; width: 100%; margin: 1.5rem 0; overflow: hidden; position: relative; }' +
    '        .progress-fill { background: linear-gradient(90deg, #e31e24, #ff4b4b); height: 100%; width: 0%; transition: width 0.4s cubic-bezier(0.4, 0, 0.2, 1); position: relative; }' +
    '        .progress-fill::after { content: ""; position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: linear-gradient(90deg, transparent, rgba(255,255,255,0.4), transparent); animation: shimmer 1.5s infinite; }' +
    '        @keyframes shimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(100%); } }' +
    '        .status-box { background: #f1f5f9; border-radius: 8px; padding: 1rem; font-family: monospace; color: #475569; height: 110px; overflow-y: auto; font-size: 0.85rem; line-height: 1.6; border: 1px solid #cbd5e1; box-sizing: border-box; }' +
    '        .btn { background: #e31e24; color: #ffffff; border: none; padding: 0.85rem 1.5rem; border-radius: 8px; font-weight: bold; cursor: pointer; transition: all 0.2s; font-size: 1rem; margin-top: 1.5rem; width: 100%; box-shadow: 0 4px 6px -1px rgba(227, 30, 36, 0.2); }' +
    '        .btn:hover { background: #b9181d; transform: translateY(-2px); box-shadow: 0 8px 12px -3px rgba(227, 30, 36, 0.3); }' +
    '        .btn:active { transform: translateY(0); }' +
    '        .btn-close { background: transparent; color: #64748b; border: 1px solid #cbd5e1; padding: 0.6rem 1.5rem; border-radius: 8px; font-weight: 600; cursor: pointer; transition: all 0.2s; font-size: 0.9rem; margin-top: 0.5rem; width: 100%; }' +
    '        .btn-close:hover:not(:disabled) { background: #f1f5f9; border-color: #94a3b8; color: #334155; }' +
    '        .btn-close:disabled { opacity: 0.35; cursor: not-allowed; }' +
    '        .size-info { background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: 0.6rem 1rem; color: #166534; font-size: 0.82rem; font-weight: 600; margin-top: 0.75rem; display: none; }' +
    '        .footer { margin-top: 1rem; color: #94a3b8; font-size: 0.8rem; text-align: center; }' +
    '    </style>' +
    '</head>' +
    '<body>' +
    '    <div class="card">' +
    '        <h1><span class="highlight">Digifarma</span> BackupAgent</h1>' +
    '        <div style="display: flex; justify-content: space-between; align-items: flex-end;">' +
    '           <span id="lbl-status" style="color: #64748b; font-weight: 500;">Aguardando inicializa&ccedil;&atilde;o...</span>' +
    '           <span id="lbl-pct" style="color: #e31e24; font-weight: bold; font-size: 1.2rem;">0%</span>' +
    '        </div>' +
    '        <div class="progress-wrapper">' +
    '            <div id="progress" class="progress-fill"></div>' +
    '        </div>' +
    '        <div class="status-box" id="log-box"></div>' +
    '        <button id="btn-start" class="btn" onclick="triggerDelphiBackup()">Disparar Backup Seguro</button>' +
    '        <div id="size-info" class="size-info"></div>' +
    '        <button id="btn-close" class="btn-close" onclick="closeApp()">Fechar</button>' +
    '    </div>' +
    '    <div class="footer">' +
    '        Arquitetura de Alta Resili&ecirc;ncia - Digifarma (Web Engine)<br>' +
    '        <a href="#" onclick="closeHTML()" style="color: #94a3b8; text-decoration: underline; margin-top: 10px; display: inline-block;">Voltar para Modo Cl&aacute;ssico (VCL)</a>' +
    '    </div>' +
    '    <script>' +
    '        function closeApp() {' +
    '            document.title = "CLOSE_APP";' +
    '        }' +
    '        function closeHTML() {' +
    '            document.title = "CLOSE_HTML";' +
    '        }' +
    '        function showFileSize(sizeBytes) {' +
    '            var mb = (sizeBytes / 1048576).toFixed(1);' +
    '            var gb = (sizeBytes / 1073741824).toFixed(2);' +
    '            var display = sizeBytes > 1073741824 ? gb + " GB" : mb + " MB";' +
    '            var el = document.getElementById("size-info");' +
    '            el.innerHTML = "&#128230; Arquivo pronto para download: <strong>" + display + "</strong>";' +
    '            el.style.display = "block";' +
    '        }' +
    '        function setInProgress(inProgress) {' +
    '            document.getElementById("btn-close").disabled = inProgress;' +
    '        }' +
    '        function updateStatus(stateCode, pct, msg) {' +
    '            document.getElementById("progress").style.width = pct + "%";' +
    '            document.getElementById("lbl-pct").innerText = pct + "%";' +
    '            document.getElementById("lbl-status").innerHTML = "Processando...";' +
    '            if (pct === 100) document.getElementById("lbl-status").innerHTML = "Conclu&iacute;do!";' +
    '            if (msg) {' +
    '                const box = document.getElementById("log-box");' +
    '                box.innerHTML += "<div>> " + msg + "</div>";' +
    '                box.scrollTop = box.scrollHeight;' +
    '            }' +
    '        }' +
    '        function setLog(msg) {' +
    '            const box = document.getElementById("log-box");' +
    '            box.innerHTML += "<div>> " + msg + "</div>";' +
    '            box.scrollTop = box.scrollHeight;' +
    '        }' +
    '        function triggerDelphiBackup() {' +
    '            document.getElementById("btn-start").innerText = "Executando...";' +
    '            document.getElementById("btn-start").style.opacity = "0.5";' +
    '            document.getElementById("btn-start").disabled = true;' +
    '            document.title = "START_BACKUP";' +
    '            setTimeout(() => document.title = "BackupAgent UI", 500);' +
    '        }' +
    '        function resetUI() {' +
    '            document.getElementById("btn-start").innerText = "Disparar Backup Seguro";' +
    '            document.getElementById("btn-start").style.opacity = "1";' +
    '            document.getElementById("btn-start").disabled = false;' +
    '        }' +
    '    </script>' +
    '</body>' +
    '</html>';

procedure ExtractUIDependencies(const APath: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SL.Text := HTML_CONTENT;
    SL.SaveToFile(APath + 'index.html', TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

procedure ExtractWebView2Loader;
var
  ResStream: TResourceStream;
  FileStream: TFileStream;
  DllPath: string;
begin
  DllPath := ExtractFilePath(ParamStr(0)) + 'WebView2Loader.dll';
  if not FileExists(DllPath) then
  begin
    if FindResource(HInstance, 'WEBVIEW2LOADER', RT_RCDATA) <> 0 then
    begin
      ResStream := TResourceStream.Create(HInstance, 'WEBVIEW2LOADER', RT_RCDATA);
      try
        FileStream := TFileStream.Create(DllPath, fmCreate);
        try
          FileStream.CopyFrom(ResStream, 0);
        finally
          FileStream.Free;
        end;
      finally
        ResStream.Free;
      end;
    end;
  end;
end;

end.
