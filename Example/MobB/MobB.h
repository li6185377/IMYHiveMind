//
//  MobB.h
//  IMYHiveMind
//
//  Created by ljh on 2022/1/1.
//  Copyright © 2022 ljh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 绑定的时候,会设置为高优先级
@protocol Peoson_hive_B
- (NSString *)say;
@end

// 跟 MobA 定义不一致，会弹窗警告
@protocol Warning_hive_B
- (void)showTitle:(NSInteger)title;
@end

@interface MobB : NSObject <Peoson_hive_B, Warning_hive_B>

@end

NS_ASSUME_NONNULL_END
