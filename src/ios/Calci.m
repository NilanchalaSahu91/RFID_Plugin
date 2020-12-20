/********* Calci.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "ISbtSdkApi.h"
#import "SbtScannerInfo.h"
#import "SbtSdkFactory.h"
#import "ScannerAppEngine.h"

#import <TSLAsciiCommands/TSLAsciiCommands.h>
#import <TSLAsciiCommands/TSLBinaryEncoding.h>

#import "TSLAppDelegate.h"
#import "TSLSelectReaderViewController.h"

// RFID UUIDs
#define UUID_RFID_SERVICE @"F000AA00-0451-4000-B000-000000000000"

// This could be simplified to "SensorTag" and check if it's a substring...
#define SENSOR_TAG_NAME @"CC2650 SensorTag"

#define TIMER_PAUSE_INTERVAL 10.0
#define TIMER_SCAN_INTERVAL  2.0

@interface Calci : CDVPlugin <ISbtSdkApiDelegate,CBCentralManagerDelegate, CBPeripheralDelegate> {
  // Member variables go here.
    id <ISbtSdkApi> m_DcsSdkApi;   
    NSInteger intcount;
    NSInteger intseconds;
    NSTimer *timer;
    NSString *callBackID;
    NSMutableArray *m_ScannerInfoList;

    // TSL properties
    
    NSArray * _accessoryList;
    
    TSLAsciiCommander *_commander;
    
    NSString *_partialResultMessage;
    
    NSString *_transponderIdentifier;
    TSL_DataBank _memoryBank;
    int _startAddress;
    int _readLength;
    NSString *_data;
    
    NSMutableDictionary<NSString *, TSLTransponderData *> *_transpondersRead;
}
@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *sensorTag;
@property (nonatomic, assign) BOOL keepScanning;

- (void)substract:(CDVInvokedUrlCommand*)command;
- (void)add:(CDVInvokedUrlCommand*)command;
- (void)startTimer:(CDVInvokedUrlCommand*)command;
@end

@implementation Calci

- (void)add:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSNumber *param1 = [[command.arguments objectAtIndex:0] valueForKey:@"param1"];
    NSNumber *param2 = [[command.arguments objectAtIndex:0] valueForKey:@"param2"];

    if(param1 >=0 && param2 >=0)
    {
        NSNumber *sum = [NSNumber numberWithFloat:([param1 floatValue] + [param2 floatValue])];
        NSString *total = [NSString stringWithFormat:@"%@", sum];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:total];
    }else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)substract:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSNumber *param1 = [[command.arguments objectAtIndex:0] valueForKey:@"param1"];
    NSNumber *param2 = [[command.arguments objectAtIndex:0] valueForKey:@"param2"];

    if(param1 >=0 && param2 >=0)
    {
        NSNumber *substratction = [NSNumber numberWithFloat:([param1 floatValue] - [param2 floatValue])];
        NSString *total = [NSString stringWithFormat:@"%@", substratction];
       
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:total];
    }else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startTimer:(CDVInvokedUrlCommand*)command
{
    callBackID = nil;
    intcount = 0;
    intseconds = 20;
    NSLog(@"TImer started");

    m_DcsSdkApi = [SbtSdkFactory createSbtSdkApiInstance]; // Initialize SDK instance.
    //[m_DcsSdkApi sbtSetDelegate:self];
    
    NSLog(@"SBT SDK version: %@", [m_DcsSdkApi sbtGetVersion]); // SDK log here

    // Get version information for the reader
    // Use the TSLVersionInformationCommand synchronously as the returned information is needed below
    TSLVersionInformationCommand * versionCommand = [TSLVersionInformationCommand synchronousCommand];
    [_commander executeCommand:versionCommand];
    TSLBatteryStatusCommand *batteryCommand = [TSLBatteryStatusCommand synchronousCommand];
    [_commander executeCommand:batteryCommand];

    // Create a central Manager Object
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];

    timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                              target:self
                                           selector:@selector(subtractTime)
                                            userInfo:nil
                                             repeats:YES];
    callBackID = command.callbackId;

    NSArray *availableScanner = [self getAvailableScannersList];
    // run timer event and discover of availble scanner in background thread.
    NSLog(@"Availble scanner: %@", availableScanner);
}

- (void)subtractTime
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary *startEvent = [[NSDictionary alloc]init];
    startEvent = @{@"eventType":@"ontick",@"eventValue": [NSString stringWithFormat:@"%li",(long)intseconds]};
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:startEvent];
    pluginResult.keepCallback = [NSNumber numberWithBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callBackID];
    intseconds--;
    NSLog(@"CountDown Timer: %ld",(long)intseconds);
    
    if (intseconds == 0)
    {
        pluginResult.keepCallback = [NSNumber numberWithBool:NO];
        NSDictionary *finishEvent =  [[NSDictionary alloc]init];
        finishEvent = @{@"eventType":@"onfinish",@"eventValue":@"Timer Finished"};
        [timer invalidate];
        timer = nil;
        NSLog(@"TImer Stopped as maximum time is reached");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:finishEvent];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callBackID];
    }
}

//***** Scan For Available Zebra RFID *****//

- (NSArray*)getAvailableScannersList
{
    NSMutableArray *availableScanners = [[NSMutableArray alloc] init];
    
    for (SbtScannerInfo *info in [m_ScannerInfoList copy] )
    {
        if ([info isAvailable])
        {
            [availableScanners addObject:info];
        }
    }
    
    return availableScanners;
}

#pragma mark Zebra RFID Delegate Methods

- (void)sbtEventBarcode:(NSString *)barcodeData barcodeType:(int)barcodeType fromScanner:(int)scannerID {
    
}

- (void)sbtEventBarcodeData:(NSData *)barcodeData barcodeType:(int)barcodeType fromScanner:(int)scannerID {
    
}

- (void)sbtEventCommunicationSessionEstablished:(SbtScannerInfo *)activeScanner {
    
}

- (void)sbtEventCommunicationSessionTerminated:(int)scannerID {
    
}

- (void)sbtEventFirmwareUpdate:(FirmwareUpdateEvent *)fwUpdateEventObj {
    
}

- (void)sbtEventImage:(NSData *)imageData fromScanner:(int)scannerID {
    
}

- (void)sbtEventScannerAppeared:(SbtScannerInfo *)availableScanner {
    // @Nilanchala: Right logic to read
    NSLog(@"SCANNER APPEARED");
    
}

- (void)sbtEventScannerDisappeared:(int)scannerID {
    
}

- (void)sbtEventVideo:(NSData *)videoFrame fromScanner:(int)scannerID {

}

#pragma mark BLE

//****** Scan Pause and Resume *******//

- (void)pauseScan {
    // Scanning uses up battery on phone, so pause the scan process for the designated interval.
    NSLog(@"*** PAUSING SCAN...");
    [NSTimer scheduledTimerWithTimeInterval:TIMER_PAUSE_INTERVAL target:self selector:@selector(resumeScan) userInfo:nil repeats:NO];
    [self.centralManager stopScan];
}

- (void)resumeScan {
    if (self.keepScanning) {
        // Start scanning again...
        NSLog(@"*** RESUMING SCAN!");
        [NSTimer scheduledTimerWithTimeInterval:TIMER_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    }
}

- (void)cleanup {
    [_centralManager cancelPeripheralConnection:self.sensorTag];
}
#pragma mark - CBCentralManagerDelegate methods

//****** Discover Near by Bluetooth Devices (RFID Readers) *******//

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    BOOL showAlert = YES;
    NSString *state = @"";
    switch ([central state])
    {
        case CBManagerStateUnsupported:
            state = @"This device does not support Bluetooth Low Energy.";
            NSLog(@"%@", state);
            break;
        case CBManagerStateUnauthorized:
            state = @"This app is not authorized to use Bluetooth Low Energy.";
            NSLog(@"%@", state);
            break;
        case CBManagerStatePoweredOff:
            state = @"Bluetooth on this device is currently powered off.";
            NSLog(@"%@", state);
            break;
        case CBManagerStateResetting:
            state = @"The BLE Manager is resetting; a state update is pending.";
            NSLog(@"%@", state);
            break;
        case CBManagerStatePoweredOn:
            showAlert = NO;
            state = @"Bluetooth LE is turned on and ready for communication.";
            NSLog(@"%@", state);
            self.keepScanning = YES;
            [NSTimer scheduledTimerWithTimeInterval:TIMER_SCAN_INTERVAL target:self selector:@selector(pauseScan) userInfo:nil repeats:NO];
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
            break;
        case CBManagerStateUnknown:
            state = @"The state of the BLE Manager is unknown.";
            NSLog(@"%@", state);
            break;
        default:
            state = @"The state of the BLE Manager is unknown.";
            NSLog(@"%@", state);
    }
    
    
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // Retrieve the peripheral name from the advertisement data using the "kCBAdvDataLocalName" key
    NSString *peripheralName = [advertisementData objectForKey:@"kCBAdvDataLocalName"];
    NSLog(@"NEXT PERIPHERAL: %@ (%@)", peripheralName, peripheral.identifier.UUIDString);
    if (peripheralName) {
        if ([peripheralName isEqualToString:SENSOR_TAG_NAME]) {
            self.keepScanning = NO;
            
            // save a reference to the sensor tag
            self.sensorTag = peripheral;
        }
    }
}

#pragma mark - CBPeripheralDelegate methods

// When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service: %@", service);
        if (([service.UUID isEqual:[CBUUID UUIDWithString:UUID_RFID_SERVICE]])) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

@end
