//
//  IMYHiveMind.h
//  IMYHiveMind
//
//  Created by ljh on 2022/1/1.
//  Copyright © 2022 ljh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 对所有 Protocol 会截取 _hive_ 之前的名称 当做统一的 Key
 在不同模块，可以定义类似的 Protocol 来避免代码依赖
 框架在Debug包运行时，会扫描所有相关 Protocol 的定义 跟 标准协议的定义 进行对比！
 标准协议：优先使用后缀是 _hive_impl 当做标准协议，无 则使用方法数最多的当标准协议

 在模块 A 注册:
         
 @protocol ICar
  - (void)awake;
 @end
 
 @implementation CarImpl

 IMYHIVE_BIND_CLASS(CarImpl, ICar, NO)
 
 @end
  
 在模块B调用：
 
 /// B模块的 ICar 声明
 @protocol ICar_hive_B
  - (void)awake;
 @end
 
 获取具体的实现，底层会自动截取 _hive_ 字段的前缀，所以可以获取到 模块A 内的注册
 
 [IMYHIVE_BINDER(ICar_hive_B) awake];
 
*/

#pragma mark - 绑定 Class to Protocol

// 绑定 Class<IMYHiveInjector> to Protocol （$singleton：是否单例）
#define IMYHIVE_BIND_CLASS($class, $protocol, $singleton) IMYHIVE_BIND_CLASS_INTACT($class, $protocol, $singleton, 0, NO)
// 完整的绑定方法，可调整优先级
#define IMYHIVE_BIND_CLASS_INTACT($class, $protocol, $singleton, $priority, $iscls) _imy_hive_bind_impl("bind", $protocol, $class, $priority, $singleton, $iscls, _imy_hive_func_register_name())

// 获取指定Protocol的实现者
#define IMYHIVE_BINDER($protocol) ((id<$protocol>)[[IMYHiveMind sharedInstance] getBinder:@protocol($protocol)])

// 注册对应类，不进行初始化操作，先不支持优先级排序操作，排序应该由使用方决定，而不是注册者
#define IMYHIVE_REGIST_CLASS($class, $protocol) _imy_hive_bind_impl("regist", $protocol, $class, 0, NO, NO, _imy_hive_func_register_name())

// 获取对应Protocol注册的类
#define IMYHIVE_REGISTERS($protocol) ((NSArray<Class<$protocol>> *)[[IMYHiveMind sharedInstance] getRegisters:@protocol($protocol)])

#pragma mark - IoC（控制反转）容器
/// IoC（控制反转）容器
@interface IMYHiveMind : NSObject

+ (instancetype)sharedInstance;

/// 获取 Protocol 对应的实例，请使用宏：IMYHIVE_BIND_CLASS  来绑定 Class
- (id)getBinder:(Protocol *)protocol;
- (id)getBinder:(Protocol *)protocol withParams:(nullable id)params;

/// 获取 Protocol 对应的注册列表，请使用宏：IMYHIVE_REGIST_CLASS  来注册 Class
- (NSArray<Class> *)getRegisters:(Protocol *)protocol;

/// 不提供运行时绑定Class的方法
/// 1. 中途出现bug比较难排查   2. 需要考虑线程安全（加锁影响性能）3. 口子开了,后续难收

@end


/// 响应依赖注入，可返回自定义实例
@protocol IMYHiveInjector <NSObject>
@optional

/// 是否响应该参数，默认：YES
+ (BOOL)hive_respondsForParams:(nullable id)params;

/// 初始化调用API，默认：[class new]
+ (instancetype)hive_newWithParams:(nullable id)params;

@end

#pragma mark - 注入 section data

/// 注入到 section data 的结构体
struct _imy_hive_bind_class {
    const char *prot; // 目标
    const char *clazz; // 绑定的类 Class<IMYHiveInjector>
    int priority;// 递减排序，值大的排前面
    BOOL singleton;// 是否单例
    BOOL iscls; // 类单例(都是调用类方法)
};

#define _imy_hive_bind_impl($hive_key, $protocol, $class, $priority, $singleton, $iscls, $hive_reg) \
static inline __attribute__((always_inline)) void __unused _imy_hive_func_impl_name()       \
(void) { __unused id<$protocol> _; @protocol($protocol); [$class class]; }                  \
__attribute__((used, section("__DATA," "__" $hive_key "_hive")))                            \
static const struct _imy_hive_bind_class $hive_reg = (struct _imy_hive_bind_class) {        \
    __IMYSTRING__($protocol),                                                               \
    __IMYSTRING__($class),                                                                  \
    $priority,                                                                              \
    $singleton,                                                                             \
    $iscls                                                                                  \
};

// 递增方法名，在一个文件中 可以注册多个 hive binder
#define _imy_hive_func_impl_name() _imy_hive_func_name_concat(_imy_hive_func_stage_, __COUNTER__)
#define _imy_hive_func_register_name() _imy_hive_func_name_concat(_imy_hive_func_register_, __COUNTER__)
#define _imy_hive_func_name_concat($prefix, $counter) _imy_hive_func_name_concat_impl($prefix, $counter)
#define _imy_hive_func_name_concat_impl($prefix, $counter) $prefix##$counter
#define __IMYCHARS__($str) #$str
#define __IMYSTRING__($str) __IMYCHARS__($str)

NS_ASSUME_NONNULL_END

