//
//  MobB.m
//  IMYHiveMind
//
//  Created by ljh on 2022/1/1.
//  Copyright © 2022 ljh. All rights reserved.
//

#import "MobB.h"
#import <IMYHiveMind/IMYHiveMind.h>

@protocol Mother
- (NSString *)saying;
@end


@implementation MobB

/// 优先级  比 MobA 高，所以返回的最终会是B
IMYHIVE_BIND_CLASS_INTACT(MobB, Peoson_hive_B, YES, 1, NO);

- (NSString *)say {
//    return @"I’am MobB!";
    return [IMYHIVE_BINDER(Mother) saying];
}

@end
