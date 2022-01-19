//
//  MobA.h
//  IMYHiveMind
//
//  Created by ljh on 2022/1/1.
//  Copyright © 2022 ljh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Peoson
- (NSString *)say;
@end

@interface MobA : NSObject <Peoson>

@end

NS_ASSUME_NONNULL_END
