//
//  CLDeviceEntity.h
//  CLBLE
//
//  Created by MyLee on 2018/8/7.
//  Copyright © 2018年 MyLee. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CLDeviceEntity : NSObject

@property (nonatomic, strong) id peripheral;//设备
@property (nonatomic, assign) BOOL connected;//是否已经连接

@end
