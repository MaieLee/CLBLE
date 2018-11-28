//
//  CLBLEHelper.m
//  CLBLE
//
//  Created by MyLee on 2018/8/6.
//  Copyright © 2018年 CardLan. All rights reserved.
//

#import "CLBLEHelper.h"
#import "SwitchHeader.h"

@interface CLBLEHelper()

@property (nonatomic, strong) NSMutableArray *devIdentifiers;//
@property (nonatomic, strong) NSMutableArray *connectingDevs;//正在连接
@property (nonatomic, copy)   NSArray<CBUUID *> * searchArr;//需要搜索的设备，为nil时搜所有
@property (nonatomic, strong) NSMutableDictionary *finishConnectBlocks;
@property (nonatomic, strong) CBCharacteristic *writeCharacteristic;

@property (nonatomic, copy) FinishConnectBlock disconnectFinish;

@end

@implementation CLBLEHelper

+ (CLBLEHelper *)sharedManger
{
    static CLBLEHelper *bleHelper = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bleHelper = [[CLBLEHelper alloc] init];
    });
    return bleHelper;
}

- (instancetype)init{
    self = [super init];
    if (self) {
//        _searchArr = [NSArray arrayWithObject:[CBUUID UUIDWithString:@"FFB0"]];
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        _devIdentifiers = [NSMutableArray arrayWithCapacity:0];
        _finishConnectBlocks = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    
    return self;
}

- (void)scan
{
    if (@available(iOS 10.0, *)) {
        if (_manager.state == CBManagerStatePoweredOn) {
            [_manager scanForPeripheralsWithServices:_searchArr options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:YES]}];
        }
    } else {
        // Fallback on earlier versions
        [_manager scanForPeripheralsWithServices:_searchArr options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:YES]}];
    }
}

/**
 * 监听蓝牙状态
 **/
-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBManagerStatePoweredOn:
        {
            NSLog(@"蓝牙已打开,请扫描外设");
            // 第一个参数填nil代表扫描所有蓝牙设备,第二个参数options也可以写nil
            [_manager scanForPeripheralsWithServices:_searchArr options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:YES]}];
        }
            break;
        case CBManagerStatePoweredOff:
        {
            NSLog(@"蓝牙没有打开,请先打开蓝牙");
            
        }
            break;
        default:
        {
            NSLog(@"该设备不支持蓝牙功能,请检查系统设置");
        }
            break;
    }
}

/**
 * 查找外设
 **/
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (IsStrEmpty(peripheral.name)) {
        return;
    }
    
    if (![self.devIdentifiers containsObject:peripheral.identifier.UUIDString]) {
        //新发现的设备加入到列表
        NSLog(@"已发现 peripheral: %@ rssi: %@, UUID: %@ advertisementData: %@ ", peripheral.name, RSSI, peripheral.identifier, advertisementData);
        [self.devIdentifiers addObject:peripheral.identifier.UUIDString];
        
        if (self.updateDev) {
            self.updateDev(peripheral);
        }
    }
}

/**
 * 连接设备
 **/
- (void)connectDevcie:(CBPeripheral *)dev finishConnectBlock:(FinishConnectBlock)finish{
    if (self.currPeripheral) {
        self.logBlock(@"存在设备正在连接，请先断开后再连接",NO);
        return;
    }
    self.currPeripheral = dev;
    if (![self.connectingDevs containsObject:dev.identifier.UUIDString]) {
        self.logBlock([NSString stringWithFormat:@"正在连接%@..",dev.name],NO);
        self.finishConnectBlocks[dev.identifier] = finish;
        [self.connectingDevs addObject:dev.identifier.UUIDString];
        [self.manager connectPeripheral:dev options:nil];
    }else{
        self.logBlock(@"该设备正在连接中",NO);
    }
}

/**
 * 成功连接目标设备
 *
 * @param peripheral 要连接的设备
 **/
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    self.logBlock([NSString stringWithFormat:@"成功连接%@ UUID: %@",peripheral.name,peripheral.identifier],NO);
    [self.connectingDevs removeObject:peripheral.identifier.UUIDString];
    FinishConnectBlock finish = self.finishConnectBlocks[peripheral.identifier];
    if(finish){
        finish(YES,peripheral,nil);
    }
    [self.finishConnectBlocks removeObjectForKey:peripheral.identifier];
    
    //停止扫描
    [self.manager stopScan];
    
    //连接设备之后设置蓝牙对象的代理,扫描服务
    [peripheral setDelegate:self];
    //扫描已经连接的蓝牙设备中可用的服务
    [peripheral discoverServices:nil];
    NSLog(@"扫描服务");
}

/**
 * 连接失败
 **/
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@",error);
    self.logBlock(@"连接失败",NO);
    [self.connectingDevs removeObject:peripheral.identifier.UUIDString];
    FinishConnectBlock finish = self.finishConnectBlocks[peripheral.identifier];
    if(finish){
        finish(NO,peripheral,error);
    }
    [self.finishConnectBlocks removeObjectForKey:peripheral.identifier];
}

/**
 * 连接的设备信号强度
 **/
-(void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    int rssi = abs([RSSI intValue]);
    NSString *length = [NSString stringWithFormat:@"设备:%@,强度:%.1ddb",peripheral,rssi];
    if (self.logBlock) {
        self.logBlock(length,NO);
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    int i = 0;
    
    for (CBService *s in peripheral.services) {
        NSLog(@"发现%d :服务 UUID: %@(%@)",i,s.UUID.data,s.UUID);
        // 扫描到服务后,根据服务发现特征
        if ([s.UUID.UUIDString isEqualToString:@"FFB0"]) {
            [peripheral discoverCharacteristics:nil forService:s];
            break;
        }
        [peripheral discoverCharacteristics:nil forService:s];
        i++;
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if(error){
        NSLog(@"设备获取特征失败，设备名：%@", peripheral.name);
        return;
    }
    /**
     CBCharacteristicPropertyRead                                                    = 0x02,
     CBCharacteristicPropertyWriteWithoutResponse                                    = 0x04,
     CBCharacteristicPropertyWrite                                                   = 0x08,
     CBCharacteristicPropertyNotify                                                  = 0x10,
     */
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        NSLog(@"%@",characteristic);
        //发现特征
        //注意：uuid 分为可读，可写，要区别对待！！！
        if ([characteristic.UUID.UUIDString isEqualToString:@"FFB1"])
        {
            //FFB1 为设备自定义的写特征UUID
            //对设备写数据需要用到该特征
            BOOL isSupperWrite =  characteristic.properties & (CBCharacteristicPropertyWriteWithoutResponse | CBCharacteristicPropertyWrite);
            if (isSupperWrite) {
                self.writeCharacteristic = characteristic;
            }else{
                NSLog(@"不支持写");
            }
        }else if ([characteristic.UUID.UUIDString isEqualToString:@"FFB2"]){
            //FFB2 为设备自定义的读特征UUID
            //读该设备回应数据需要监听该特征
            if (characteristic.properties & CBCharacteristicPropertyNotify) {
                [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            }else{
                [peripheral readValueForCharacteristic:characteristic];
            }
        }else{
            if (characteristic.properties & CBCharacteristicPropertyWrite || (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)) {
                self.writeCharacteristic = characteristic;
            }
            if (characteristic.properties & CBCharacteristicPropertyRead || (characteristic.properties & CBCharacteristicPropertyNotify)) {
                if (characteristic.properties & CBCharacteristicPropertyNotify) {
                    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
                }else{
                    [peripheral readValueForCharacteristic:characteristic];
                }
            }
        }
    }
}

- (void)disconnectDevice:(CBPeripheral *)dev finishConnectBlock:(FinishConnectBlock)finish
{
    self.disconnectFinish = finish;
    [self.manager cancelPeripheralConnection:dev];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSString *connectLog = [NSString stringWithFormat:@"已断开与设备:[%@]的连接", peripheral.name];
    if (self.logBlock) {
        self.logBlock(connectLog,NO);
    }
    
    self.currPeripheral = nil;
    self.writeCharacteristic = nil;
    
    if (self.disconnectFinish) {
        self.disconnectFinish(YES,peripheral,error);
    }else{
        //这里处理意外断掉的连接
        [self.devIdentifiers removeObject:peripheral.identifier];//移除该蓝牙
        if (self.interruptBlock) {
            self.interruptBlock(peripheral);
        }
    }
    
    [self scan];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        [peripheral readValueForCharacteristic:characteristic];
    } else {
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self.manager cancelPeripheralConnection:peripheral];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error)
    {
        NSLog(@"Error updating value for characteristic %@ error: %@", characteristic.UUID, [error localizedDescription]);
        return;
    }
    
    NSString *hexString = [characteristic.value convertDataToHexStr];
    
    if(self.logBlock){
        self.logBlock(hexString,YES);
    }
}

- (void)writeData:(Byte[])byteData length:(NSInteger)length{
    if (self.writeCharacteristic) {
        NSData *wData = [[NSData alloc] initWithBytes:byteData length:length];
        
        if (self.writeCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) {
            [self.currPeripheral writeValue:wData forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithoutResponse];
        }else{
            [self.currPeripheral writeValue:wData forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
        }
        
        NSString *send = [wData convertDataToHexStr];
        self.logBlock([NSString stringWithFormat:@"发送:%@",send], NO);
    }else{
        self.logBlock(@"不可写入", NO);
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"=======%@",error.userInfo);
    }else{
        NSLog(@"发送数据成功");
    }
    
    /* When a write occurs, need to set off a re-read of the local CBCharacteristic to update its value */
    [peripheral readValueForCharacteristic:characteristic];
}

- (void)clear{
    if (@available(iOS 9.0, *)) {
        if(self.manager.isScanning){
            [self.manager stopScan];
        }
    } else {
        [self.manager stopScan];
    }
    
    [self.manager cancelPeripheralConnection:self.currPeripheral];
}

@end
