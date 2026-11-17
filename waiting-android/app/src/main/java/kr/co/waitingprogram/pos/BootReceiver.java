package kr.co.waitingprogram.pos;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Best-effort automatic launch after boot.
 * New Android devices may prohibit background activity starts;
 * selecting this app as default HOME provides reliable kiosk startup.
 */
public final class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "WaitingBootReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            return;
        }
        Log.i(TAG, "Received BOOT_COMPLETED; attempting waiting kiosk launch");
        Intent kiosk = new Intent(context, MainActivity.class);
        kiosk.setAction(Intent.ACTION_MAIN);
        kiosk.addCategory(Intent.CATEGORY_LAUNCHER);
        kiosk.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_CLEAR_TOP
                | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        try {
            context.startActivity(kiosk);
            Log.i(TAG, "Kiosk launch requested after boot");
        } catch (RuntimeException error) {
            Log.w(TAG, "Boot launch blocked by Android or device policy", error);
        }
    }
}
