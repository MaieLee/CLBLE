//
//  CLBLECustomCell.h
//  CLBLE
//
//  Created by MyLee on 2018/8/7.
//  Copyright © 2018年 MyLee. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CLBLECustomCellDelegate <NSObject>

@optional
- (void)connectDev:(NSIndexPath *)indexPath;

@end

@interface CLBLECustomCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UISwitch *connectSwitch;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, weak) id<CLBLECustomCellDelegate> delegate;

@end
