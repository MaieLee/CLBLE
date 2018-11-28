//
//  CLBLECustomCell.m
//  CLBLE
//
//  Created by MyLee on 2018/8/7.
//  Copyright © 2018年 CardLan. All rights reserved.
//

#import "CLBLECustomCell.h"

@interface CLBLECustomCell()

@end

@implementation CLBLECustomCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    [self.connectSwitch addTarget:self action:@selector(connect:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)connect:(UISwitch *)cSwitch
{
    cSwitch.on = !cSwitch.on;
    if ([self.delegate respondsToSelector:@selector(connectDev:)]) {
        [self.delegate connectDev:self.indexPath];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
