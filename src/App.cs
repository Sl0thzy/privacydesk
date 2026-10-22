using System;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace PrivacyDesk {
 public class ControlRow : INotifyPropertyChanged {
  public string Id {get;set;} public string Category {get;set;} public string Title {get;set;} public string Status {get;set;} public string Impact {get;set;} public string Details {get;set;}
  public bool Safe {get;set;} public bool Available {get;set;} public string Level {get{return Category=="Advanced"?"Advanced":(Safe?"Low impact":"Feature change");}}
  bool selected; public bool Selected {get{return selected;}set{selected=value;if(PropertyChanged!=null)PropertyChanged(this,new PropertyChangedEventArgs("Selected"));}}
  public event PropertyChangedEventHandler PropertyChanged;
 }
 public class TargetRow {public string Control{get;set;} public string Target{get;set;} public string Address{get;set;} public string Status{get;set;} public string Current{get;set;} public string Desired{get;set;}}
 public class SecurityRow {public string Name{get;set;} public string State{get;set;}}
 public class SnapshotRow {public string Id{get;set;} public string Status{get;set;} public int Count{get;set;} public string Error{get;set;}}
 public class Program {
  const string BitcoinWallet="3AGX6413JJXpcWuDc8AQExDVgHNAkxwJMA";
  const string RepositoryUrl="https://github.com/Sl0thzy/privacydesk";
  const string LinktreeUrl="https://linktr.ee/mrsquidsloth";
  Window window; ObservableCollection<ControlRow> controls=new ObservableCollection<ControlRow>();
  ObservableCollection<SecurityRow> security=new ObservableCollection<SecurityRow>(); ObservableCollection<SnapshotRow> snapshots=new ObservableCollection<SnapshotRow>();
  ObservableCollection<TargetRow> auditTargets=new ObservableCollection<TargetRow>();
  bool busy, audited; string dataRoot, enginePath, logPath, smokeFolder; JavaScriptSerializer json=new JavaScriptSerializer(){MaxJsonLength=4000000};
  static Mutex mutex;
  T Find<T>(string name) where T:class {return window.FindName(name) as T;}
  [STAThread] public static int Main(string[] args) {
   bool owns;mutex=new Mutex(true,"Local\\PrivacyDesk.App",out owns);
   if(!owns){MessageBox.Show("PrivacyDesk is already running.");return 1;}
   try {
    var app=new Application(); var program=new Program();program.Build();
    if(args.Length==2 && args[0]=="--preview") {program.Preview(args[1]);return 0;}
    if(args.Length==3 && args[0]=="--ui-test") {program.UiTest(args[1],args[2]);return 0;}
    if(args.Length==2 && args[0]=="--smoke-live")program.smokeFolder=args[1];
    program.Initialize();app.Run(program.window);return 0;
   } catch(Exception ex){if(args.Length>0){File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"ui-error.txt"),ex.ToString());}else{MessageBox.Show(ex.ToString(),"PrivacyDesk could not start");}return 1;}
   finally{mutex.ReleaseMutex();mutex.Dispose();}
  }
  void Build(){using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("Main.xaml")){window=(Window)XamlReader.Load(stream);}
   Find<DataGrid>("ControlsGrid").ItemsSource=controls;Find<DataGrid>("SecurityGrid").ItemsSource=security;Find<DataGrid>("SnapshotsGrid").ItemsSource=snapshots;
   Find<DataGrid>("ChangesAuditGrid").ItemsSource=auditTargets;
   using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.png")) {
    var logo=new BitmapImage();logo.BeginInit();logo.CacheOption=BitmapCacheOption.OnLoad;logo.StreamSource=stream;logo.EndInit();logo.Freeze();Find<Image>("BrandLogo").Source=logo;
   }
   using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("logo.ico")){window.Icon=BitmapFrame.Create(stream,BitmapCreateOptions.None,BitmapCacheOption.OnLoad);}
   Find<Button>("UpdatesButton").Click+=(s,e)=>{try{Process.Start(new ProcessStartInfo(RepositoryUrl){UseShellExecute=true});}catch(Exception){MessageBox.Show(window,"Could not open your browser. Visit "+RepositoryUrl,"Check for updates");}};
   Find<Button>("RecommendedButton").Click+=(s,e)=>{foreach(var r in controls)r.Selected=r.Available&&r.Safe;};
   Find<Button>("LocationButton").Click+=(s,e)=>{foreach(var r in controls)if(r.Id=="location"||r.Id=="find-device")r.Selected=r.Available;};
   Find<Button>("ClearButton").Click+=(s,e)=>{foreach(var r in controls)r.Selected=false;};
   Find<TextBox>("BitcoinAddress").Text=BitcoinWallet;
   Find<Button>("CopyBitcoinButton").Click+=(s,e)=>{try{Clipboard.SetText(BitcoinWallet);Find<Button>("CopyBitcoinButton").Content="Copied!";}catch(Exception){MessageBox.Show(window,"The clipboard is busy. You can select and copy the address directly.","Copy address");}};
   Find<Button>("LinktreeButton").Click+=(s,e)=>{try{Process.Start(new ProcessStartInfo(LinktreeUrl){UseShellExecute=true});}catch(Exception){MessageBox.Show(window,"Could not open your browser. Visit "+LinktreeUrl,"Linktree");}};
  }
  void Initialize(){
   dataRoot=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"PrivacyDesk"); Directory.CreateDirectory(dataRoot);
   var runtime=Path.Combine(dataRoot,"Runtime",Guid.NewGuid().ToString("N"));Directory.CreateDirectory(runtime);enginePath=Path.Combine(runtime,"Engine.ps1");
   using(var input=Assembly.GetExecutingAssembly().GetManifestResourceStream("Engine.ps1"))using(var output=File.Create(enginePath)){input.CopyTo(output);}
   var logs=Path.Combine(dataRoot,"Logs");Directory.CreateDirectory(logs);logPath=Path.Combine(logs,DateTime.Now.ToString("yyyyMMdd-HHmmss")+".log");
   Find<Button>("ScanButton").Click+=async(s,e)=>await Scan();
   Find<Button>("SnapshotButton").Click+=async(s,e)=>await ApplyOrSnapshot(false);
   Find<Button>("ApplyButton").Click+=async(s,e)=>await ApplyOrSnapshot(true);
   Find<Button>("RefreshSnapshotsButton").Click+=async(s,e)=>await Run("List",null,null);
   Find<Button>("RestoreButton").Click+=async(s,e)=>await Restore();
   Find<Button>("OpenFolderButton").Click+=(s,e)=>{Process.Start(new ProcessStartInfo("explorer.exe",Quote(dataRoot)){UseShellExecute=true});};
   Find<DataGrid>("ControlsGrid").SelectionChanged+=(s,e)=>{var r=Find<DataGrid>("ControlsGrid").SelectedItem as ControlRow;if(r!=null){Find<TextBlock>("DetailTitle").Text=r.Title;Find<TextBlock>("DetailText").Text=r.Impact;Find<TextBox>("ObservedText").Text=r.Details;}};
   window.Closing+=(s,e)=>{if(busy){e.Cancel=true;MessageBox.Show(window,"Wait for the current operation to finish. Its activity and restore snapshot are being saved.","Operation in progress");}};
   window.Closed+=(s,e)=>{try{File.Delete(enginePath);Directory.Delete(runtime);}catch{}};
   window.Loaded+=async(s,e)=>{await Scan();await Run("List",null,null);if(smokeFolder!=null){Directory.CreateDirectory(smokeFolder);Render(Path.Combine(smokeFolder,"live-app.png"));File.WriteAllText(Path.Combine(smokeFolder,"live-smoke.txt"),(audited&&controls.Count==21?"PASS":"FAIL")+": packaged executable launched its embedded engine, completed read-only audit, parsed "+controls.Count+" controls and "+security.Count+" security checks, loaded restore history. No changes applied.");window.Close();}};
   Log("PrivacyDesk 1.1 started. No controls are selected automatically.");SetBusy(false);
  }
  static string Quote(string s){return "\""+s.Replace("\"", "")+"\"";}
  void Log(string text){Find<TextBox>("LogBox").AppendText(text+Environment.NewLine);Find<TextBox>("LogBox").ScrollToEnd();if(logPath!=null)File.AppendAllText(logPath,text+Environment.NewLine);}
  void SetBusy(bool value){busy=value;foreach(string name in new[]{"ScanButton","RecommendedButton","LocationButton","ClearButton","SnapshotButton","ApplyButton","RefreshSnapshotsButton","RestoreButton"})Find<Button>(name).IsEnabled=!value;
   Find<DataGrid>("ControlsGrid").IsEnabled=!value;Find<DataGrid>("SnapshotsGrid").IsEnabled=!value;Find<ProgressBar>("Progress").Visibility=value?Visibility.Visible:Visibility.Collapsed;
   if(!value){Find<Button>("ApplyButton").IsEnabled=audited;Find<Button>("SnapshotButton").IsEnabled=audited;}
  }
  async Task Scan(){audited=false;controls.Clear();security.Clear();auditTargets.Clear();Find<TextBlock>("SelectionLabel").Text="0 selected";await Run("Audit",null,null);}
  async Task ApplyOrSnapshot(bool apply){
   var chosen=controls.Where(r=>r.Selected&&r.Available).ToList();if(chosen.Count==0){MessageBox.Show(window,"Select one or more controls first.","Nothing selected");return;}
   if(apply){string text="Apply these "+chosen.Count+" controls? A restore snapshot will be saved first.\n\n"+string.Join("\n",chosen.Select(r=>"• "+r.Title))+"\n\n"+string.Join("\n\n",chosen.Where(r=>!r.Safe).Select(r=>r.Title+": "+r.Impact));
    if(MessageBox.Show(window,text,"Review changes",MessageBoxButton.OKCancel,MessageBoxImage.Information)!=MessageBoxResult.OK)return;
   }
   await Run(apply?"Apply":"Snapshot",string.Join(",",chosen.Select(r=>r.Id)),null);
   await Run("List",null,null);
   if(apply)await Scan();
  }
  async Task Restore(){var s=Find<DataGrid>("SnapshotsGrid").SelectedItem as SnapshotRow;if(s==null){MessageBox.Show(window,"Select a snapshot in the history first.");return;}
   if(s.Status=="Snapshot only"||s.Status=="Restored"){MessageBox.Show(window,"This snapshot has no pending applied changes to undo.");return;}
   if(MessageBox.Show(window,"Restore "+s.Id+"?\n\nUndo newest runs first. This replaces later manual edits to the same targets with their saved original values. Unrelated values are left intact.","Review restore",MessageBoxButton.OKCancel,MessageBoxImage.Warning)!=MessageBoxResult.OK)return;
   await Run("Restore",null,s.Id);await Run("List",null,null);await Scan();
  }
  async Task Run(string mode,string ids,string snapshot){
   if(busy)return;string previousStatus=Find<TextBlock>("StatusLabel").Text;SetBusy(true);Find<TextBlock>("StatusLabel").Text=mode=="Audit"?"Reading current configuration…":mode+" in progress…";
   bool failed=false;
   try{
    string exe=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),"System32","WindowsPowerShell","v1.0","powershell.exe");
    string arguments="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "+Quote(enginePath)+" -Mode "+mode+" -DataRoot "+Quote(dataRoot);
    if(ids!=null)arguments+=" -Ids "+Quote(ids);if(snapshot!=null)arguments+=" -SnapshotId "+Quote(snapshot);
    var info=new ProcessStartInfo(exe,arguments){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true,StandardOutputEncoding=Encoding.UTF8,StandardErrorEncoding=Encoding.UTF8};
    using(var process=new Process(){StartInfo=info}){
     process.Start();
     var output=Task.Run(()=>{string line;while((line=process.StandardOutput.ReadLine())!=null){var copy=line;window.Dispatcher.Invoke(new Action(()=>{try{Handle(copy);}catch(Exception ex){failed=true;Log("Output error: "+ex.Message+" / "+copy);}}));}});
     var error=Task.Run(()=>{string line;while((line=process.StandardError.ReadLine())!=null){var copy=line;window.Dispatcher.Invoke(new Action(()=>Log("ERROR: "+copy)));}});
     await Task.Run(()=>process.WaitForExit());await Task.WhenAll(output,error);
     if(process.ExitCode!=0){failed=true;Find<TextBlock>("StatusLabel").Text="Operation failed or partially completed. See log and restore history.";Log("Worker exit code: "+process.ExitCode);}
    }
    if(mode=="Audit"&&!failed&&controls.Count>0){audited=true;Find<TextBlock>("StatusLabel").Text="Audit complete. Select controls and review their effects before applying.";}
    else if(!failed&&mode=="List")Find<TextBlock>("StatusLabel").Text=previousStatus;
   }catch(Exception ex){failed=true;Log("ERROR: "+ex.Message);Find<TextBlock>("StatusLabel").Text="Operation could not complete. See activity log.";}
   finally{SetBusy(false);}
  }
  void Handle(string line){
   var message=json.Deserialize<Dictionary<string,object>>(line);string type=Convert.ToString(message["type"]);object value=message["data"];
   if(type=="log"){Log(Convert.ToString(value));return;}if(type=="error"){Log("ERROR: "+Convert.ToString(value));return;}
   if(type=="target"){
    var d=(Dictionary<string,object>)value;auditTargets.Add(new TargetRow(){Control=S(d,"Control"),Target=S(d,"Target"),Address=S(d,"Address"),Status=S(d,"Status"),Current=S(d,"Current"),Desired=S(d,"Desired")});
   }else if(type=="control"){
    var d=(Dictionary<string,object>)value;var r=new ControlRow(){Id=S(d,"Id"),Title=S(d,"Title"),Category=S(d,"Category"),Impact=S(d,"Impact"),Details=S(d,"Details"),Status=S(d,"Status"),Safe=Convert.ToBoolean(d["Safe"]),Available=Convert.ToBoolean(d["Available"])};
    r.PropertyChanged+=(s,e)=>Find<TextBlock>("SelectionLabel").Text=controls.Count(x=>x.Selected)+" selected";controls.Add(r);
   }else if(type=="audit"){
    var d=(Dictionary<string,object>)value;Find<TextBlock>("DeviceLabel").Text="Windows "+S(d,"Edition")+" · "+S(d,"Version")+" · Build "+S(d,"Build")+" · Scanned "+DateTime.Now.ToString("HH:mm");
    Find<TextBlock>("PrivacyCount").Text=S(d,"Configured")+" / "+S(d,"Total")+" configured";
    foreach(Dictionary<string,object> c in (IEnumerable)d["Checks"])security.Add(new SecurityRow(){Name=S(c,"Name"),State=S(c,"State")});
    int attention=security.Count(x=>x.State=="Disabled"||x.State.StartsWith("Unknown")||x.State.StartsWith("Unavailable"));Find<TextBlock>("SecurityCount").Text=attention==0?"Checks available":attention+" to review";
   }else if(type=="snapshots"){
    snapshots.Clear();foreach(Dictionary<string,object> d in (IEnumerable)value)snapshots.Add(new SnapshotRow(){Id=S(d,"Id"),Status=S(d,"Status"),Count=Convert.ToInt32(d["Count"]),Error=S(d,"Error")});
   }else if(type=="result"){var d=(Dictionary<string,object>)value;Log(S(d,"Message")+" Snapshot: "+S(d,"Snapshot"));Find<TextBlock>("StatusLabel").Text=S(d,"Message");}
  }
  static string S(Dictionary<string,object> d,string key){return d.ContainsKey(key)?Convert.ToString(d[key]):"";}
  void Preview(string path){
   Find<TextBlock>("DeviceLabel").Text="Preview data · Windows Professional · Build 26300";Find<TextBlock>("PrivacyCount").Text="12 / 21 configured";Find<TextBlock>("SecurityCount").Text="9 checks available";
   var examples=new[]{new[]{"Diagnostics","Minimum diagnostic data","Configured"},new[]{"Diagnostics","Limit diagnostic logs and dumps","Configured"},new[]{"Personalization","Disable advertising ID","Configured"},new[]{"Personalization","Disable personalized offers","Configured"},new[]{"Location","Block Windows location access","Not configured"},new[]{"Advanced","Disable Connected User Experiences service","Not configured"}};
   foreach(var e in examples)controls.Add(new ControlRow(){Category=e[0],Title=e[1],Status=e[2],Available=true,Safe=e[0]!="Advanced"&&e[0]!="Location",Selected=e[0]=="Location"});
   Find<TextBlock>("SelectionLabel").Text="1 selected";Find<TextBlock>("DetailTitle").Text="Block Windows location access";Find<TextBlock>("DetailText").Text="Blocks Windows location services and app access. Automatic time zones and location-based apps may be affected. IP-based location inference remains possible.";
   Log("08:42:01  Reading Windows privacy policies, services and scheduled tasks…");Log("08:42:04  Audit complete. No system settings were changed.");Log("08:42:04  Select a control to review its effects. A snapshot is saved before every apply.");
   window.Width=1280;window.Height=960;window.Show();Render(path);window.Close();
  }
  void Render(string path){
   window.UpdateLayout();window.Dispatcher.Invoke(System.Windows.Threading.DispatcherPriority.ApplicationIdle,new Action(()=>{}));window.UpdateLayout();
   var bitmap=new RenderTargetBitmap((int)window.ActualWidth,(int)window.ActualHeight,96,96,PixelFormats.Pbgra32);bitmap.Render(window);var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(bitmap));using(var file=File.Create(path))encoder.Save(file);
  }
  void UiTest(string auditPath,string folder){
   Directory.CreateDirectory(folder);
   foreach(var line in File.ReadAllLines(auditPath)){if(!string.IsNullOrWhiteSpace(line))Handle(line);}
   if(controls.Count!=21||security.Count<7)throw new Exception("Audit UI parsing failed.");
   if(auditTargets.Count<controls.Count||auditTargets.Any(r=>string.IsNullOrEmpty(r.Current)||string.IsNullOrEmpty(r.Desired)))throw new Exception("Per-target audit data is missing.");
   Find<Button>("RecommendedButton").RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
   if(controls.Count(r=>r.Selected)!=controls.Count(r=>r.Available&&r.Safe))throw new Exception("Low-impact selection omitted eligible controls.");
   if(controls.Any(r=>r.Available&&r.Safe&&r.Status=="Configured"&&!r.Selected))throw new Exception("Already-configured low-impact controls were skipped.");
   if(controls.Any(r=>r.Selected&&(!r.Safe||!r.Available)))throw new Exception("Ineligible control was selected.");
   Find<Button>("ClearButton").RaiseEvent(new RoutedEventArgs(Button.ClickEvent));
   if(controls.Any(r=>r.Selected))throw new Exception("Clear selection failed.");
   if(Find<Image>("BrandLogo").Source==null||window.Icon==null)throw new Exception("Embedded branding did not load.");
   var selected=controls.First(r=>r.Available);selected.Selected=true;
   if(Find<TextBlock>("SelectionLabel").Text!="1 selected")throw new Exception("Selection binding failed.");
   selected.Selected=false;
   Handle("{\"type\":\"snapshots\",\"data\":[]}");
   if(snapshots.Count!=0)throw new Exception("Empty snapshot handling failed.");
   Handle("{\"type\":\"snapshots\",\"data\":[{\"Id\":\"preview-only\",\"Status\":\"Applied\",\"Count\":12,\"Error\":\"\"}]}");
   if(snapshots.Count!=1)throw new Exception("Snapshot history parsing failed.");
   window.Show();Render(Path.Combine(folder,"audit-ui.png"));
   Find<TabControl>("Tabs").SelectedIndex=1;Render(Path.Combine(folder,"security-ui.png"));
   Find<TabControl>("AuditTabs").SelectedIndex=1;Render(Path.Combine(folder,"protections-ui.png"));
   Find<TabControl>("Tabs").SelectedIndex=2;Render(Path.Combine(folder,"restore-ui.png"));
   File.WriteAllText(Path.Combine(folder,"ui-tests.txt"),"PASS: real audit JSON decoding; every target current/desired/status; low-impact button includes configured controls and excludes advanced/unavailable controls; clear selection; logo and icon embedded; restore lists; four tab layouts rendered. No apply or restore invoked.");window.Close();
  }
 }
}
