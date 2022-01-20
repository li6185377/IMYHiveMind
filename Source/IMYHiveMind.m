//
//  IMYHiveMind.m
//  IMYHiveMind
//
//  Created by ljh on 2022/1/1.
//  Copyright © 2022 ljh. All rights reserved.
//

#import "IMYHiveMind.h"
#import <objc/runtime.h>

// 读取 mach-o section 数据
static void * _imy_hive_copy_sections(const char *key,
                                      size_t sect_size,
                                      size_t *outCount);

// 单个配置
@interface IMYHiveEngine : NSObject
@property (nonatomic, strong) Class<IMYHiveInjector> clazz;
@property (nonatomic, strong) id instance;

@property (nonatomic, assign) BOOL singleton;
@property (nonatomic, assign) NSInteger priority;
@property (nonatomic, assign) BOOL hasCustomNew;
@property (nonatomic, assign) BOOL hasResponds;

- (BOOL)isBlanker;
- (BOOL)blankerAs:(IMYHiveEngine *)engine;

@end

@interface IMYHiveMind () {
    dispatch_semaphore_t _lock; // 缓存锁
    NSDictionary<NSString *, NSArray<IMYHiveEngine *> *> *_bindings; // 注入的绑定类
    NSDictionary<NSString *, id>  *_binderCache; // 单例缓存类
    NSDictionary<NSString *, NSArray<Class> *> *_registers; // 注入的配置类
}
@end

static inline __attribute__((always_inline)) NSString * kShortProtocolKey(NSString *fullName) {
    NSRange range = [fullName rangeOfString:@"_hive_" options:NSBackwardsSearch];
    if (range.location == NSNotFound) {
        return fullName;
    }
    return [fullName substringToIndex:range.location];
}

@implementation IMYHiveMind

+ (instancetype)sharedInstance {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = dispatch_semaphore_create(1);
        [self loadBindClasses];
        [self loadRegistClasses];
    }
    return self;
}

- (void)loadBindClasses {
    size_t sect_size = sizeof(struct _imy_hive_bind_class);
    size_t sect_count;
    struct _imy_hive_bind_class *sect_array = _imy_hive_copy_sections("__bind_hive",
                                                                      sect_size,
                                                                      &sect_count);
    if (sect_count == 0) {
        return;
    }
    NSMutableDictionary *allMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *classMap = [NSMutableDictionary dictionary];
    // 获取绑定配置
    for (int i = 0; i < sect_count; i++) {
        struct _imy_hive_bind_class bind = sect_array[i];
        Class clazz = objc_getClass(bind.clazz);
        if (!clazz) {
            NSAssert(NO, @"无法反序列化为 Class");
            continue;
        }
        NSString *protoName = [NSString stringWithUTF8String:bind.prot];
        NSString *key = kShortProtocolKey(protoName);
        IMYHiveEngine *engine = [IMYHiveEngine new];
        // Class
        engine.clazz = clazz;
        // 是否单例
        engine.singleton = bind.singleton || bind.iscls;
        // 类单例
        engine.instance = bind.iscls ? clazz : nil;
        // 优先级
        engine.priority = bind.priority;
        // 自定义初始化
        engine.hasCustomNew = [clazz respondsToSelector:@selector(hive_newWithParams:)];
        // 自定义响应
        engine.hasResponds = [clazz respondsToSelector:@selector(hive_respondsForParams:)];
        
        // 多个不同 Protocol 可绑定到同一个 engine(空白/无自定义)
        IMYHiveEngine *blanker = [classMap objectForKey:clazz];
        if (!blanker && engine.isBlanker) {
            [classMap setObject:engine forKey:(id)clazz];
        }
        if ([blanker blankerAs:engine]) {
            engine = blanker;
        }
        // 存储集合
        NSMutableArray<IMYHiveEngine *> *engines = [allMap objectForKey:key];
        if (!engines) {
            engines = [NSMutableArray array];
            [allMap setObject:engines forKey:key];
        }
        [engines addObject:engine];
    }
    // 内部再进行一次排序 + 不可变
    NSArray *allKeys = allMap.allKeys;
    for (NSString *key in allKeys) {
        NSMutableArray *engines = [allMap objectForKey:key];
        [engines sortUsingComparator:^NSComparisonResult(IMYHiveEngine *obj1, IMYHiveEngine *obj2) {
            if (obj1.priority > obj2.priority) {
                return NSOrderedAscending;
            } else if (obj1.priority < obj2.priority) {
                return NSOrderedDescending;
            }
            return NSOrderedSame;
        }];
        // 改为不可变
        [allMap setObject:[engines copy] forKey:key];
    }
    // copy（改为不可变）
    _bindings = [allMap copy];
    // 释放内存
    free(sect_array);
}

- (void)loadRegistClasses {
    size_t sect_size = sizeof(struct _imy_hive_bind_class);
    size_t sect_count;
    struct _imy_hive_bind_class *sect_array = _imy_hive_copy_sections("__regist_hive",
                                                                      sect_size,
                                                                      &sect_count);
    if (sect_count == 0) {
        return;
    }
    NSMutableDictionary *allMap = [NSMutableDictionary dictionary];
    // 获取绑定配置
    for (int i = 0; i < sect_count; i++) {
        struct _imy_hive_bind_class bind = sect_array[i];
        Class clazz = objc_getClass(bind.clazz);
        if (!clazz) {
            NSAssert(NO, @"无法反序列化为 Class");
            continue;
        }
        NSString *protoName = [NSString stringWithUTF8String:bind.prot];
        NSString *key = kShortProtocolKey(protoName);
        NSMutableArray *engines = [allMap objectForKey:key];
        if (!engines) {
            engines = [NSMutableArray array];
            [allMap setObject:engines forKey:key];
        }
        [engines addObject:clazz];
    }
    // 不可变
    NSArray *allKeys = allMap.allKeys;
    for (NSString *key in allKeys) {
        NSMutableArray *engines = [allMap objectForKey:key];
        // 改为不可变
        [allMap setObject:[engines copy] forKey:key];
    }
    // copy（改为不可变）
    _registers = [allMap copy];
    // 释放内存
    free(sect_array);
}

- (id)getBinder:(Protocol *)protocol {
    return [self getBinder:protocol withParams:nil];
}

- (id)getBinder:(Protocol *)protocol withParams:(id)params {
    NSString *protoName = NSStringFromProtocol(protocol);
    NSString *key = kShortProtocolKey(protoName);
    
    id binder = nil;
    if (!params && (binder = [_binderCache objectForKey:key])) {
        // 已有单例缓存
        return binder;
    }
    // 无缓存，则遍历查询
    IMYHiveEngine *hive = nil;
    NSArray<IMYHiveEngine *> *engines = [_bindings objectForKey:key];
    
    for (IMYHiveEngine *engine in engines) {
        if (engine.hasResponds && ![(engine.clazz ?: engine.instance) hive_respondsForParams:params]) {
            continue;
        }
        hive = engine;
        break;
    }
    if (hive.singleton) {
        // 单例模式
        if (!hive.instance) {
            @synchronized (hive) {
                if (!hive.instance) {
                    hive.instance = hive.hasCustomNew ? [hive.clazz hive_newWithParams:params] : [(Class)hive.clazz new];
                }
            }
        }
        binder = hive.instance;
        // 如果是无参数的单例，则进行缓存
        if (!params) {
            dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
            NSDictionary *oldCache = _binderCache;
            NSMutableDictionary *newCache = [NSMutableDictionary dictionaryWithDictionary:oldCache];
            [newCache setObject:binder forKey:key];
            _binderCache = [newCache copy];
            dispatch_semaphore_signal(_lock);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [oldCache class];
            });
        }
    } else {
        // 非单例模式，不存储实例
        binder = hive.hasCustomNew ? [hive.clazz hive_newWithParams:params] : [(Class)hive.clazz new];
    }
    return binder;
}

- (NSArray<Class> *)getRegisters:(Protocol *)protocol {
    NSString *protoName = NSStringFromProtocol(protocol);
    NSString *key = kShortProtocolKey(protoName);
    return [_registers objectForKey:key];
}

@end

@implementation IMYHiveEngine

- (BOOL)isBlanker {
    // 都没自定义
    return !self.priority && !self.hasCustomNew && !self.hasResponds;
}

- (BOOL)blankerAs:(IMYHiveEngine *)engine {
    // 只要判断单例属性是否一致即可
    return self.singleton == engine.singleton && self.instance == engine.instance;
}

@end

#pragma mark - section loader

#import <dlfcn.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>

#ifdef __LP64__

typedef struct mach_header_64 imy_match_header;
typedef struct section_64 imy_match_section;
#define imy_match_get_section_by_header getsectbynamefromheader_64
extern const struct mach_header_64* _NSGetMachExecuteHeader(void);

#else

typedef const struct mach_header imy_match_header;
typedef const struct section imy_match_section;
#define imy_match_get_section_by_header getsectbynamefromheader
extern const struct mach_header* _NSGetMachExecuteHeader(void);

#endif

static void * _imy_hive_copy_sections(const char *key,
                                      size_t sect_size,
                                      size_t *outCount) {
    // 由于 dladdr 耗时比较久，所以替换为 _NSGetMachExecuteHeader
    const imy_match_header *mach_header = _NSGetMachExecuteHeader();
    const imy_match_section *sections = imy_match_get_section_by_header(mach_header, "__DATA", key);
    if (sections == NULL) {
        Dl_info info;
        dladdr((const void *)&_imy_hive_copy_sections, &info);
        mach_header = info.dli_fbase;
        sections = imy_match_get_section_by_header(mach_header, "__DATA", key);
    }
    if (sections == NULL) {
        *outCount = 0;
        return NULL;
    }
    *outCount = (size_t)sections->size / sect_size;
    // copy 整个内存段
    void *result = malloc(sections->size);
    void *source = (void *)((size_t)mach_header + (size_t)sections->offset);
    memcpy(result, source, sections->size);
    return result;
}

#pragma mark - Debug环境下的 Protocol 验证

#ifdef DEBUG

#import <UIKit/UIKit.h>

@interface IMYHiveMindChecker : NSObject

@end

@implementation IMYHiveMindChecker

+ (void)load {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [IMYHiveMindChecker registerTests];
        [IMYHiveMindChecker binderTests];
    });
}

+ (void)showAlert:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:@"" delegate:nil cancelButtonTitle:@"确认" otherButtonTitles:nil];
        [alert show];
#pragma clang diagnostic pop
    });
}

+ (void)registerTests {
    NSDictionary *registers = [[IMYHiveMind sharedInstance] valueForKey:@"_registers"];
    [self testRequiredImpl:registers];
    
    NSDictionary *bindings = [[IMYHiveMind sharedInstance] valueForKey:@"_bindings"];
    [self testRequiredImpl:bindings];
}

/// 验证Class是否实现：协议必须接口
+ (void)testRequiredImpl:(NSDictionary *)allMap {
    [allMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSArray *array, BOOL *stop) {
        Protocol *standard = NSProtocolFromString(key);
        if (!standard) {
            [self showAlert:[NSString stringWithFormat:@"%@-无标准协议进行匹配！", key]];
            return;
        }
        NSDictionary *methodInfo = [self registerProtocolMethodsInfo:standard];
        for (IMYHiveEngine *engine in array) {
            [methodInfo enumerateKeysAndObjectsUsingBlock:^(NSString *s_key,
                                                            NSString *s_types,
                                                            BOOL *stop) {
                NSString *types = nil;
                Class clazz = NULL;
                BOOL isMeta = NO;
                /// 兼容 registers 和 bindings
                if (object_isClass(engine)) {
                    clazz = (id)engine;
                } else {
                    clazz = engine.clazz;
                    isMeta = object_isClass(engine.instance);
                }
                SEL sel = NSSelectorFromString([s_key substringFromIndex:1]);
                if ([s_key hasPrefix:@"+"] || isMeta) {
                    // 类单例，所有方法都采用 respondsToSelector: 判断
                    if ([clazz respondsToSelector:sel]) {
                        Method method = class_getClassMethod(clazz, sel);
                        struct objc_method_description *method_desc = method_getDescription(method);
                        types = [[NSString alloc] initWithUTF8String:method_desc->types];
                    }
                } else {
                    if ([clazz instancesRespondToSelector:sel]) {
                        Method method = class_getInstanceMethod(clazz, sel);
                        struct objc_method_description *method_desc = method_getDescription(method);
                        types = [[NSString alloc] initWithUTF8String:method_desc->types];
                    }
                }
                if (!types || ![types isEqualToString:s_types]) {
                    [self showAlert:[NSString stringWithFormat:@"%@-未实现指定方法：%@ - %@ ", NSStringFromClass(clazz), s_key, s_types]];
                }
            }];
        }
    }];
}

+ (NSDictionary *)registerProtocolMethodsInfo:(Protocol *)protocol {
    NSMutableDictionary *methods = [NSMutableDictionary dictionary];
    [self getProtocolInfo:protocol required:YES instance:YES toMap:methods];
    [self getProtocolInfo:protocol required:YES instance:NO toMap:methods];
    return methods.copy;
}

/// 判断协议定义是否有差异
+ (void)binderTests {
    unsigned int count = 0;
    Protocol * __unsafe_unretained *list = objc_copyProtocolList(&count);
    NSMutableDictionary *hiveMap = [NSMutableDictionary dictionary];
    for (int i = 0; i < count; i++) {
        Protocol *proto = list[i];
        NSString *protoName = NSStringFromProtocol(proto);
        // 命中IoC关键字
        if ([protoName containsString:@"_hive_"]) {
            NSString *key = kShortProtocolKey(protoName);
            NSMutableArray *names = [hiveMap objectForKey:key];
            if (!names) {
                names = [NSMutableArray array];
                [hiveMap setObject:names forKey:key];
            }
            [names addObject:protoName];
        }
    }
    free(list);
    
    [hiveMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSMutableArray *names, BOOL * _Nonnull stop) {
        // 排个序，优先不加 _hive_ 在前面
        [names sortUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
            return [obj1 compare:obj2];
        }];
        // 获取标准协议
        NSString *standardName = [key stringByAppendingString:@"_hive_impl"];
        Protocol *standard = NSProtocolFromString(standardName);
        NSDictionary *standardMethods = nil;
        if (!standard) {
            NSInteger maxMethodCount = 0;
            for (NSString *other in names) {
                Protocol *otherProtocol = NSProtocolFromString(other);
                NSDictionary *otherMethods = [self binderProtocolMethodsInfo:otherProtocol];
                if (otherMethods.count > maxMethodCount) {
                    standard = otherProtocol;
                    standardMethods = otherMethods;
                    maxMethodCount = otherMethods.count;
                }
            }
        } else {
            standardMethods = [self binderProtocolMethodsInfo:standard];
        }
        for (NSString *other in names) {
            Protocol *otherProtocol = NSProtocolFromString(other);
            NSDictionary *otherMethods = [self binderProtocolMethodsInfo:otherProtocol];
            [standardMethods enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
                if (![otherMethods[key] isEqual:obj]) {
                    NSString *title = [NSString stringWithFormat:@"%@\n%@\n协议不一致！", NSStringFromProtocol(standard), other];
                    [self showAlert:title];
                    *stop = YES;
                }
            }];
        }
    }];
    
    NSLog(@"IMYHiveMindChecker 扫描完成！");
}

+ (NSDictionary *)binderProtocolMethodsInfo:(Protocol *)protocol {
    NSMutableDictionary *methods = [NSMutableDictionary dictionary];
    [self getProtocolInfo:protocol required:YES instance:YES toMap:methods];
    [self getProtocolInfo:protocol required:YES instance:NO toMap:methods];
    [self getProtocolInfo:protocol required:NO instance:YES toMap:methods];
    [self getProtocolInfo:protocol required:NO instance:NO toMap:methods];
    return methods.copy;
}

+ (void)getProtocolInfo:(Protocol *)protocol
               required:(BOOL)required
               instance:(BOOL)instance
                  toMap:(NSMutableDictionary *)dict {
    NSString *name = NSStringFromProtocol(protocol);
    if ([name hasPrefix:@"NS"] ||
        [name hasPrefix:@"UI"] ||
        [name hasPrefix:@"WK"] ||
        [name hasPrefix:@"UN"]) {
        // 系统Protocol 不进行读取
        return;
    }
    // 读取继承协议的方法定义
    unsigned int dependCount = 0;
    Protocol * __unsafe_unretained * dependencies = protocol_copyProtocolList(protocol, &dependCount);
    for (int i = 0; i < dependCount; i++) {
        Protocol *dependProtocol = dependencies[i];
        [self getProtocolInfo:dependProtocol required:required instance:instance toMap:dict];
    }
    if (dependencies) {
        free(dependencies);
    }
    // 读取自身方法定义
    unsigned int count = 0;
    struct objc_method_description *list = protocol_copyMethodDescriptionList(protocol,
                                                                              required,
                                                                              instance,
                                                                              &count);
    for (int i = 0; i < count; i++) {
        struct objc_method_description method = list[i];
        NSString *sel = [NSString stringWithFormat:@"%@%@", instance ? @"-" : @"+", NSStringFromSelector(method.name)];
        NSString *types = [[NSString alloc] initWithUTF8String:method.types];
        [dict setObject:types forKey:sel];
    }
    if (list) {
        free(list);
    }
}

@end

#endif
