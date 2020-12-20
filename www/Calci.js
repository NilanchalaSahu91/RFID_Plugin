var exec = require('cordova/exec');
var cordova = require('cordova');
var channel = require('cordova/channel');

function CountDownTimer() {
    this.tickSec = 'unknown';
}

CountDownTimer.prototype.add = function (arg0, success, error) {
    exec(success, error, 'Calci', 'add', [arg0]);
};

CountDownTimer.prototype.substract = function (arg0, success, error) {
    exec(success, error, 'Calci', 'substract', [arg0]);
};

CountDownTimer.prototype.startCountDownTimer = function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, 'Calci', 'startTimer', []);
};

var countDownTimer = new CountDownTimer();

channel.createSticky('onCordovaConnectionReady');
channel.waitForInitialization('onCordovaConnectionReady');

channel.onCordovaReady.subscribe(function() {
    countDownTimer.startCountDownTimer(function(info) {
        console.log('BRIDGE: successCallback called');
        if(info.eventType === 'ontick'){
            countDownTimer.tickSec = info.eventValue;
            console.log('BRIDGE: firing countdowntimerontick event');
            cordova.fireDocumentEvent('countdowntimerontick');    
        }else
        if(info.eventType === 'onfinish'){
            console.log('BRIDGE: firing countdowntimeronfinish event');
            cordova.fireDocumentEvent('countdowntimeronfinish');    
        }
       
        // should only fire this once
        if (channel.onCordovaConnectionReady.state !== 2) {
            channel.onCordovaConnectionReady.fire();
        }
    },
    function(e) {
        // If we can't get the network info we should still tell Cordova
        // to fire the deviceready event.
        if (channel.onCordovaConnectionReady.state !== 2) {
            channel.onCordovaConnectionReady.fire();
        }
        console.log('BRIDGE: Error initializing CountDownTimer: ' + e);
    });
});

module.exports = countDownTimer;
