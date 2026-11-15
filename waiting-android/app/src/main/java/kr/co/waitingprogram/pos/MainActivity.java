package kr.co.waitingprogram.pos;
import android.app.Activity;
import android.os.Bundle;
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
  view.setWebViewClient(new WebViewClient());view.setWebChromeClient(new WebChromeClient());
  try(InputStream in=getAssets().open("index.html");ByteArrayOutputStream out=new ByteArrayOutputStream()){
   byte[] bytes=new byte[8192];int n;while((n=in.read(bytes))!=-1)out.write(bytes,0,n);
   view.loadDataWithBaseURL("https://appassets.androidplatform.net/",out.toString("UTF-8"),"text/html","UTF-8",null);
  }catch(Exception ex){Toast.makeText(this,"접수 화면을 불러오지 못했습니다.",Toast.LENGTH_LONG).show();}
 }
 @Override public void onBackPressed(){if(view!=null)view.evaluateJavascript("kioskBack()",null);}
 @Override protected void onDestroy(){if(view!=null){view.destroy();view=null;}super.onDestroy();}
}