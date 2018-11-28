//
//  CLBLEHelper.h
//  CLBLE
//
//  Created by MyLee on 2018/8/6.
//  Copyright © 2018年 MyLee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define IsStrEmpty(_ref) (((_ref) == nil) || ([(_ref) isEqual:[NSNull null]]) ||([(_ref)isEqualToString:@""]))

typedef void(^UpdateSearchDevBlock)(CBPeripheral *device);//搜索设备回调
typedef void (^FinishConnectBlock)(BOOL connected,CBPeripheral *device,NSError *error);//连接|断开设备回调
typedef void(^LogBlock)(NSString *log, BOOL isRFIDLog);//日志信息
typedef void(^ROrWLogBlock)(NSString *log);//读写信息
typedef void(^InterruptBlock)(CBPeripheral *device);//意外中断连接回调

@interface CLBLEHelper : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic, strong) CBCentralManager   *manager; //中心管理者
@property (nonatomic, strong) CBPeripheral *currPeripheral;//正连接的设备,目前只支持单连接

@property (nonatomic, copy) UpdateSearchDevBlock updateDev;
@property (nonatomic, copy) LogBlock logBlock;
@property (nonatomic, copy) InterruptBlock interruptBlock;

+ (CLBLEHelper *)sharedManger;

/**
 * 扫描外设
 **/
- (void)scan;

/**
 * 停止扫描设备，断开连接
 **/
- (void)clear;

/**
 * 连接设备
 *
 * @param dev 要连接的设备
 * @param finish typeof block 连接结果回调
 **/
- (void)connectDevcie:(CBPeripheral *)dev finishConnectBlock:(FinishConnectBlock)finish;

/**
 * 断开连接
 *
 * @param dev 要断开连接的设备
 * @param finish typeof block 结果回调
 **/
- (void)disconnectDevice:(CBPeripheral *)dev finishConnectBlock:(FinishConnectBlock)finish;

/**
 * 写入数据
 *
 * @param byteData 写入内容
 **/
- (void)writeData:(Byte[])byteData length:(NSInteger)length;

@end
