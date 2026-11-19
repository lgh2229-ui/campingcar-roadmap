package kr.co.waitingprogram.pos;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.provider.Settings;
import android.webkit.JavascriptInterface;
import android.view.WindowManager;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
public final class MainActivity extends Activity {
 private WebView view;
 @Override public void onCreate(Bundle saved) {
  super.onCreate(saved);
  getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
  view=new WebView(this);setContentView(view);
  WebSettings settings=view.getSettings();
  settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(true);
  settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);
  settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
  settings.setDefaultTextEncodingName("UTF-8");
  view.addJavascriptInterface(this,"WaitingTabletPower");
  view.setWebViewClient(new WebViewClient());view.setWebChromeClient(new WebChromeClient());
  try(InputStream in=getAssets().open("index.html");ByteArrayOutputStream out=new ByteArrayOutputStream()){
   byte[] bytes=new byte[8192];int n;while((n=in.read(bytes))!=-1)out.write(bytes,0,n);
   view.loadDataWithBaseURL("https://appassets.androidplatform.net/",out.toString("UTF-8"),"text/html","UTF-8",null);
  }catch(Exception ex){Toast.makeText(this,"접수 화면을 불러오지 못했습니다.",Toast.LENGTH_LONG).show();}
 }

 // Lenovo TB-X304F (Android 7.1.1) exposes scheduled on/off in its system
 // settings, not via a public app-writable API. Never claim the app saved RTC.
 @JavascriptInterface
 public void openScheduledPowerSettings(){
  runOnUiThread(new Runnable(){
   @Override public void run(){
    boolean launched=false;
    try{
     PackageManager pm=getPackageManager();
     PackageInfo pkg=pm.getPackageInfo("com.android.settings",PackageManager.GET_ACTIVITIES);
     if(pkg.activities!=null){
      for(ActivityInfo activity:pkg.activities){
       if(!activity.exported)continue;
       String name=activity.name==null?"":activity.name.toLowerCase(java.util.Locale.ROOT);
       if((name.contains("power")&&(name.contains("schedule")||name.contains("timer"))) ||
           name.contains("schpwronoff")){
        try{
         Intent intent=new Intent();
         intent.setClassName(activity.packageName,activity.name);
         startActivity(intent);
         launched=true;
         break;
        }catch(Exception ignored){}
       }
      }
     }
    }catch(Exception ignored){}
    if(!launched){
     try{
      startActivity(new Intent(Settings.ACTION_SETTINGS));
      Toast.makeText(MainActivity.this,
       "태블릿 설정에서 '예약 전원 켜기/끄기'를 선택하세요.",Toast.LENGTH_LONG).show();
     }catch(Exception e){
      Toast.makeText(MainActivity.this,"시스템 설정을 열지 못했습니다.",Toast.LENGTH_LONG).show();
     }
    }
   }
  });
 }
 @Override public void onBackPressed(){if(view!=null)view.evaluateJavascript("kioskBack()",null);}
 @Override protected void onDestroy(){if(view!=null){view.destroy();view=null;}super.onDestroy();}
}