// Build with Build-DesktopInstaller.ps1. .NET Framework 4.5+; no admin rights.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

class EeglabSetup : Form
{
    Label status = new Label(), matlabLabel = new Label();
    Button install = new Button(), browse = new Button(), details = new Button();
    TextBox log = new TextBox();
    ProgressBar progress = new ProgressBar();
    string matlab, payload, destination, cache, desktop;
    bool noOpen, busy, complete;
    Process worker;

    [STAThread]
    static void Main(string[] args)
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        try {
            if(args.Contains("--launch")) {
                var home=GetArg(args,"--home");
                var mode=GetArg(args,"--mode") ?? "open";
                if(home==null || !new[]{"open","practice","rollback"}.Contains(mode)) throw new ArgumentException("Invalid launcher settings. Please run setup again.");
                var script=Path.Combine(Path.GetFullPath(home),"Launch-EEGLAB.ps1");
                if(!File.Exists(script)) throw new FileNotFoundException("The launcher is incomplete. Please run setup again.");
                Process.Start(new ProcessStartInfo {
                    FileName=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"),
                    Arguments="-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "+Quote(script)+" -HomeRoot "+Quote(home)+" -Mode "+mode,
                    UseShellExecute=false,CreateNoWindow=true
                });
                return;
            }
            Application.Run(new EeglabSetup(args));
        }
        catch (Exception ex) { MessageBox.Show("Setup could not open. Please send Matt this message:\n\n" + ex.Message, "EEGLAB setup"); }
    }

    EeglabSetup(string[] args)
    {
        Text = "EEGLAB 2026 Setup";
        Font = new Font("Segoe UI", 13);
        AutoScaleMode = AutoScaleMode.Dpi;
        ClientSize = new Size(720, 510);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        var title = new Label { Text = "Your updated EEGLAB", Font = new Font("Segoe UI",24,FontStyle.Bold), AutoSize = true, Location = new Point(28,22) };
        var intro = new Label { Text = "Click the button below. Setup downloads EEGLAB and your plugins,\nadds desktop shortcuts, and opens EEGLAB in MATLAB.", AutoSize = false, Size = new Size(660,76), Location = new Point(30,85) };
        var note = new Label { Text = "Internet and an installed, licensed MATLAB are required.\nAbout 1 GB. Your shortcut will check for tested updates.", AutoSize = false, Size = new Size(660,65), Location = new Point(30,162) };
        matlabLabel.SetBounds(30,240,490,55);
        browse.Text = "Choose MATLAB..."; browse.SetBounds(530,237,160,48); browse.Font = new Font("Segoe UI",10);
        browse.Click += delegate { ChooseMatlab(); };
        install.Text = "Install and open EEGLAB"; install.SetBounds(30,306,660,62);
        install.Font = new Font("Segoe UI",17,FontStyle.Bold);
        install.Click += async delegate { if (complete) Close(); else await Install(); };
        progress.SetBounds(30,385,660,18); progress.Visible = false;
        status.SetBounds(30,412,660,55); status.Text = "Ready when you are.";
        details.Text = "Show details"; details.SetBounds(30,468,150,30); details.Font = new Font("Segoe UI",10);
        details.Click += delegate { log.Visible = !log.Visible; ClientSize = new Size(720,log.Visible ? 720 : 510); details.Text = log.Visible ? "Hide details" : "Show details"; };
        log.SetBounds(30,515,660,180); log.Multiline=true; log.ReadOnly=true; log.ScrollBars=ScrollBars.Vertical; log.Visible=false; log.Font=new Font("Consolas",9);
        Controls.AddRange(new Control[]{title,intro,note,matlabLabel,browse,install,progress,status,details,log});
        AcceptButton = install;
        destination = GetArg(args,"--destination"); cache=GetArg(args,"--cache"); desktop=GetArg(args,"--desktop");
        noOpen = args.Contains("--no-open");
        matlab = GetArg(args,"--matlab") ?? FindMatlab();
        UpdateMatlab();
        payload = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"MPG-EEGLAB-Setup","setup-2",Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(payload);
        using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("SetupPayload.zip"))
        using (var zip = new ZipArchive(stream,ZipArchiveMode.Read))
        {
            foreach (var entry in zip.Entries)
            {
                var path = Path.GetFullPath(Path.Combine(payload,entry.FullName));
                if (!path.StartsWith(payload + Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase)) throw new IOException("Invalid installer payload.");
                if (entry.FullName.EndsWith("/")) continue;
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                entry.ExtractToFile(path);
            }
        }
        FormClosing += delegate(object sender, FormClosingEventArgs e) {
            if (!busy) return;
            if (MessageBox.Show("Stop this installation? You can run Setup again later.","EEGLAB setup",MessageBoxButtons.YesNo)==DialogResult.No) { e.Cancel=true; return; }
            try { if (worker!=null && !worker.HasExited) worker.Kill(); } catch { }
        };
    }

    static string GetArg(string[] args,string name) { var i=Array.IndexOf(args,name); return i>=0 && i+1<args.Length ? args[i+1] : null; }
    void UpdateMatlab() { matlabLabel.Text = matlab == null ? "MATLAB was not found.\nPlease choose it before installing." : "MATLAB found:\n" + Directory.GetParent(Path.GetDirectoryName(matlab)).Name; }
    void ChooseMatlab()
    {
        using (var dialog=new OpenFileDialog { Title="Choose MATLAB (matlab.exe)", Filter="MATLAB|matlab.exe", InitialDirectory=Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles) })
            if (dialog.ShowDialog()==DialogResult.OK) { matlab=dialog.FileName; UpdateMatlab(); }
    }
    static string FindMatlab()
    {
        var paths=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var view in new[]{RegistryView.Registry64,RegistryView.Registry32})
        foreach (var hive in new[]{RegistryHive.LocalMachine,RegistryHive.CurrentUser})
        {
            try {
                using(var root=RegistryKey.OpenBaseKey(hive,view))
                using(var key=root.OpenSubKey(@"SOFTWARE\MathWorks\MATLAB"))
                { if(key!=null) foreach(var name in key.GetSubKeyNames()) using(var release=key.OpenSubKey(name)) { var dir=release.GetValue("MATLABROOT") as string; if(!String.IsNullOrEmpty(dir)) paths.Add(Path.Combine(dir,"bin","matlab.exe")); } }
            } catch(System.Security.SecurityException) { }
        }
        var baseDir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"MATLAB");
        if(Directory.Exists(baseDir)) foreach(var dir in Directory.GetDirectories(baseDir)) paths.Add(Path.Combine(dir,"bin","matlab.exe"));
        return paths.Where(File.Exists).OrderByDescending(p=>FileVersionInfo.GetVersionInfo(p).FileMajorPart).ThenByDescending(p=>FileVersionInfo.GetVersionInfo(p).FileMinorPart).FirstOrDefault();
    }
    // Windows CommandLineToArgvW quoting, including spaces and trailing slashes.
    static string Quote(string value)
    {
        var result=new StringBuilder("\""); int slashes=0;
        foreach(char c in value) {
            if(c=='\\') { slashes++; continue; }
            if(c=='\"') { result.Append('\\',slashes*2+1); result.Append(c); }
            else { result.Append('\\',slashes); result.Append(c); }
            slashes=0;
        }
        result.Append('\\',slashes*2); result.Append('"'); return result.ToString();
    }
    void Output(string line)
    {
        if(String.IsNullOrEmpty(line) || IsDisposed) return;
        BeginInvoke((Action)delegate {
            log.AppendText(line+Environment.NewLine);
            if(line.StartsWith("Downloading ") || line.StartsWith("Installed ") || line.StartsWith("Opening ") || line.StartsWith("Checking ")) status.Text=line;
        });
    }
    async Task Install()
    {
        if(matlab==null || !File.Exists(matlab)) { ChooseMatlab(); if(matlab==null) return; }
        busy=true; install.Enabled=false; browse.Enabled=false; progress.Visible=true; progress.Style=ProgressBarStyle.Marquee;
        status.Text="Preparing your installation. Please keep this window open.";
        try {
            var args="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " + Quote(Path.Combine(payload,"desktop","Complete-DesktopSetup.ps1")) + " -MatlabExe " + Quote(matlab) + " -LauncherExe " + Quote(Assembly.GetExecutingAssembly().Location);
            if(destination!=null) args+=" -Destination "+Quote(destination);
            if(cache!=null) args+=" -Cache "+Quote(cache);
            if(desktop!=null) args+=" -Desktop "+Quote(desktop);
            if(noOpen) args+=" -NoOpen";
            worker=new Process { StartInfo=new ProcessStartInfo { FileName=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"), Arguments=args, UseShellExecute=false, CreateNoWindow=true, RedirectStandardOutput=true, RedirectStandardError=true } };
            worker.OutputDataReceived += (s,e)=>Output(e.Data); worker.ErrorDataReceived += (s,e)=>Output(e.Data);
            worker.Start(); worker.BeginOutputReadLine(); worker.BeginErrorReadLine();
            await Task.Run(()=>worker.WaitForExit());
            if(worker.ExitCode!=0) throw new Exception("Installation did not finish. Click Show details and send Matt the message. You can run Setup again to retry.");
            complete=true; install.Text="Finished - close this window";
            status.Text="Ready. Next time, double-click EEGLAB 2026 on your desktop.\nUse EEGLAB Practice to try the example data.";
        } catch(Exception ex) { status.Text="Setup needs help. Your old EEGLAB is still available."; Output(ex.ToString()); MessageBox.Show(ex.Message,"EEGLAB setup needs help"); }
        finally { busy=false; install.Enabled=true; browse.Enabled=!complete; progress.Visible=false; }
    }
}
