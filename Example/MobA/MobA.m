//
//  MobA.m
//  IMYHiveMind
//
//  Created by ljh on 2022/1/1.
//  Copyright © 2022 ljh. All rights reserved.
//

#import "MobA.h"
#import <IMYHiveMind/IMYHiveMind.h>

// MobB 会来调用 monther saying
@protocol Mother_hive_A
- (NSString *)saying;
@end

// 跟 MobB 定义不一致，会弹窗警告
@protocol Warning_hive_A
- (void)showTitle:(NSString *)title;
@end

@interface MobA () <Mother_hive_A, Warning_hive_A>

@end

@implementation MobA

// 非单例，每次调用都会被初始化
IMYHIVE_BIND_CLASS(MobA, Peoson, NO);
// 单例
IMYHIVE_BIND_CLASS(MobA, Warning_hive_A, YES);

// 使用 类单例，所有API调用的都是类方法
IMYHIVE_BIND_CLASS_INTACT(MobA, Mother_hive_A, YES, 0, YES);

- (NSString *)say {
    return @"I’am MobA!";
}

+ (NSString *)saying {
    return @"listen to mom!";
}

@end


