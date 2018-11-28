//
//  ViewController.m
//  CLBLE
//
//  Created by MyLee on 2018/8/6.
//  Copyright © 2018年 MyLee. All rights reserved.
//

#import "ViewController.h"
#import "CLBLEHelper.h"
#import "CLBLECustomCell.h"
#import "CLDeviceEntity.h"

#define bleCellIdentifier @"searchBleCellIdentifier"
#define WEAKSELF  typeof(self) __weak weakSelf = self;

@interface ViewController ()<UITableViewDelegate,UITableViewDataSource,CLBLECustomCellDelegate>

@property (nonatomic, strong) CLBLEHelper *bleHelper;
@property (weak, nonatomic) IBOutlet UITableView *bleTableView;
@property (weak, nonatomic) IBOutlet UILabel *countLabel;
@property (weak, nonatomic) IBOutlet UITextView *contentTextView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (nonatomic, strong) NSMutableArray *devs;
@property (nonatomic, strong) CLDeviceEntity *selDevice;
@property (nonatomic, assign) NSInteger dataCount;//数据条数
@property (nonatomic, strong) NSString *content;//数据
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
//    CLBLEHelper *bleHelper = [[CLBLEHelper alloc] init];
//    WEAKSELF
//    bleHelper.updateDev = ^(CBPeripheral *device) {
//        CLDeviceEntity *clDev = [[CLDeviceEntity alloc] init];
//        clDev.peripheral = device;
//        [weakSelf.devs addObject:clDev];
//        [self.bleTableView reloadData];
//    };
//    bleHelper.logBlock = ^(NSString *log, BOOL isRFIDLog) {
//        if (isRFIDLog) {
//            [weakSelf rfidData:log];
//        }else{
//            weakSelf.statusLabel.text = log;
//        }
//    };
//    bleHelper.interruptBlock = ^(CBPeripheral *device) {
//        [weakSelf findInterruptDev:device];
//    };
//    self.bleHelper = bleHelper;
//
//    self.bleTableView.delegate = self;
//    self.bleTableView.dataSource = self;
//    _devs = [NSMutableArray arrayWithCapacity:0];
//    self.content = @"";
    
    NSThread *curr = [NSThread currentThread];
    NSLog(@"%@",curr);
    NSLog(@"1");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSThread *disCurr = [NSThread currentThread];
        NSLog(@"%@",disCurr);
        NSLog(@"2");
    });
    NSLog(@"3");
}



- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.bleHelper clear];
}

- (void)findInterruptDev:(CBPeripheral *)device{
    NSInteger row = 0;
    for (CLDeviceEntity *dev in self.devs) {
        CBPeripheral *peripheral = (CBPeripheral *)dev.peripheral;
        if ([peripheral.name isEqualToString:device.name]) {
//            dev.connected = NO;
            [self.devs removeObject:dev];//意外断开，移除该蓝牙
            
            self.dataCount = 0;
            self.content = @"";
            self.countLabel.text = @"条数：0";
            self.contentTextView.text = self.content;
            break;
        }else{
            row ++;
        }
    }
    
    [self.bleTableView reloadData];
}

- (void)rfidData:(NSString *)dataStr{
    NSLog(@"数据:%@",dataStr);

    if ([dataStr isEqualToString:@"aa550121bbee"]) {
        //清除数据
        self.dataCount = 0;
        self.content = @"";
    }else{
        self.dataCount ++;
        //4条数据为一组，1条数据头部(aa550d20)，尾部(bbee)
        dataStr = [dataStr substringWithRange:NSMakeRange(8, dataStr.length-12)];
        
        if (dataStr) {
            self.content = [[self.content stringByAppendingString:dataStr] stringByAppendingString:@"\r\n"];
        }
    }
    
    self.countLabel.text = [NSString stringWithFormat:@"条数：%ld",(long)self.dataCount];
    self.contentTextView.text = self.content;
}

- (IBAction)operationFRIDStatus:(UIButton *)sender {
    sender.selected = !sender.selected;
    Byte head[2] = {0xAA,0x55};
    Byte len[1] = {0x02};
    Byte cmd[1] = {0x10};
    Byte tail[2] = {0xBB,0xEE};
    
    Byte payload[]={};
    if (sender.selected) {
        //off 0x00
        payload[0] = 0x00;
        [sender setTitle:@"off" forState:UIControlStateNormal];
    }else{
        //on 0x01
        payload[0] = 0x01;
        [sender setTitle:@"on" forState:UIControlStateNormal];
    }
    //BT_CMD_RF_TAG_ONOFF => ON:{0xAA,0x55,0x02,0x10,0x01,0xBB,0xEE};OF:{0xAA,0x55,0x02,0x10,0x00,0xBB,0xEE}
    Byte sendData[7] = {head[0],head[1],len[0],cmd[0],payload[0],tail[0],tail[1]};
    [self.bleHelper writeData:sendData length:7];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.devs.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"发现的设备";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CLBLECustomCell *cell = [tableView dequeueReusableCellWithIdentifier:bleCellIdentifier forIndexPath:indexPath];
    cell.delegate = self;
    CLDeviceEntity *device = self.devs[indexPath.row];
    CBPeripheral *peripheral = (CBPeripheral *)device.peripheral;
    cell.titleLabel.text = IsStrEmpty(peripheral.name) ? peripheral.identifier.UUIDString : peripheral.name;
    cell.connectSwitch.on = device.connected;
    cell.indexPath = indexPath;
    return cell;
}

#pragma mark - tableview Delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

#pragma mark - cell connect Delegate
- (void)connectDev:(NSIndexPath *)indexPath
{
    CLDeviceEntity *device = self.devs[indexPath.row];
    self.selDevice = device;
    CBPeripheral *peripheral = (CBPeripheral *)device.peripheral;
    WEAKSELF
    if (!device.connected) {
        [self.bleHelper connectDevcie:peripheral finishConnectBlock:^(BOOL connected, CBPeripheral *device, NSError *error) {
            weakSelf.selDevice.connected = connected;
            [weakSelf.bleTableView reloadData];
        }];
    }else{
        [self.bleHelper disconnectDevice:peripheral finishConnectBlock:^(BOOL connected, CBPeripheral *device, NSError *error) {
            weakSelf.selDevice.connected = !connected;
            [weakSelf.bleTableView reloadData];
        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
