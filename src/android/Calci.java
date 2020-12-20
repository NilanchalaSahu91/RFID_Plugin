package com.balram.myfirstplugin;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import android.util.Log;
import org.apache.cordova.PluginResult;
import org.apache.cordova.CordovaWebView;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.os.CountDownTimer;

/**
 * This class echoes a string called from JavaScript.
 */
public class Calci extends CordovaPlugin {

    private static final String LOG_TAG = "Calci";
    private static final String LOG_PREFIX = "PLUGIN: ";
    private CallbackContext connectionCallbackContext;

    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        this.connectionCallbackContext = null;
        Log.d(LOG_TAG, LOG_PREFIX + "Calci initialized");
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        if (action.equals("add")) {
            this.add(args, callbackContext);
            return true;
        }
        if (action.equals("substract")) {
            this.substract(args, callbackContext);
            return true;
        }
        if (action.equals("startTimer")) {
            Log.d(LOG_TAG, LOG_PREFIX + "startTimer called");
            this.connectionCallbackContext = callbackContext;
            this.startCountDownTimer(200000);
            return true;
        }
        return false;
    }

    private void add(JSONArray args, CallbackContext callback) {
        if (args != null) {
            try {
                int p1 = Integer.parseInt(args.getJSONObject(0).getString("param1"));
                int p2 = Integer.parseInt(args.getJSONObject(0).getString("param2"));
                callback.success("addition result = " + (p1 + p2));
            } catch (Exception e) {
                callback.error("Please dont pass null value");
            }

        } else {
            callback.error("something went wrong");
        }
    }

    private void substract(JSONArray args, CallbackContext callback) {
        if (args != null) {
            try {
                int p1 = Integer.parseInt(args.getJSONObject(0).getString("param1"));
                int p2 = Integer.parseInt(args.getJSONObject(0).getString("param2"));
                callback.success("substract result = " + (p1 - p2));
            } catch (Exception e) {
                callback.error("Please dont pass null value");
            }

        } else {
            callback.error("something went wrong");
        }
    }

    // Declare timer
    CountDownTimer cTimer = null;

    // start timer function
    void startCountDownTimer(int setTimerValue) {
        stopCountDownTimer();
        cTimer = new CountDownTimer(setTimerValue, 1000) {
            public void onTick(long millisUntilFinished) {
                Log.d(LOG_TAG, LOG_PREFIX + "onTick called");
                if (Calci.this.webView != null) {
                    Log.d(LOG_TAG, LOG_PREFIX + "sending update tickSec: " + (millisUntilFinished / 1000));
                    sendUpdate(getJson("ontick", "" + (millisUntilFinished / 1000)), true);
                }
            }

            public void onFinish() {
                Log.d(LOG_TAG, LOG_PREFIX + "onFinish called");
                sendUpdate(getJson("onfinish", "Timer Finished"), false);
                // connectionCallbackContext.success("Timer Finished");
            }
        };
        cTimer.start();
    }

    // cancel timer
    void stopCountDownTimer() {
        if (cTimer != null) {
            cTimer.cancel();
            cTimer = null;
        }
    }

    /**
     * Create a new plugin result and send it back to JavaScript
     */
    private void sendUpdate(JSONObject info, boolean keepCallback) {
        if (this.connectionCallbackContext != null) {
            PluginResult result = new PluginResult(PluginResult.Status.OK, info);
            result.setKeepCallback(keepCallback);
            this.connectionCallbackContext.sendPluginResult(result);
        }
        // webView.postMessage("networkconnection", type);
    }

    /**
     * Creates a JSONObject with the countdown timer information
     * 
     * @return a JSONObject containing the timer information
     */
    private JSONObject getJson(String eventType, String eventValue) {
        JSONObject obj = new JSONObject();
        try {
            obj.put("eventType", eventType);
            obj.put("eventValue", eventValue);
        } catch (JSONException e) {
            Log.d(LOG_TAG, LOG_PREFIX + e.getMessage(), e);
        }
        return obj;
    }

}
