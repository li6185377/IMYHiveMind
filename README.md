IMYHiveMind（IoC容器/控制反转）
=====

`IMYHiveMind` 是用于iOS的App模块化编程的框架实现方案，提供最基础依赖注入、依赖查找能力。<br>

## 功能
1. 完全解耦代码依赖
2. 运行时检测，保障模块协议一致性
3. 无需增加业务代码
4. 保留 Xcode 自动提示，无需担心写错单词
5. 极简、高性能、线程安全

> 不提供运行时绑定Class/注册依赖的能力，主要原因：  
> 1. 中途出现bug比较难排查     
> 2. 需要保证线程安全（加锁影响性能）   
> 3. 只想提供最少的API，最少的代码调用

## 简单用法

### 1. 集成
- 使用 `CocoaPods` 进行安装：

```
// Podfile
pod 'IMYHiveMind'

// 导入头文件
#import <IMYHiveMind/IMYHiveMind.h>
```

### 2. 模块注册

采用 `IMYHIVE_BIND_CLASS` 宏进行类注入。

``` objective-c
// 在A模块注入实现
@protocol ICar
- (void)awake;
@end
 
@implementation CarImpl

// 这个宏，你可以放在任意地方，不在 Class 内也没问题
IMYHIVE_BIND_CLASS(CarImpl, ICar, NO)

@end

```

`IMYHIVE_BIND_CLASS ` 主要由3个参数组成：

- `$class`：类名（具体实现类）
- `$protocol`：协议名（需要注入实现的协议）
- `$singleton`：是否单例（非单例每次依赖方调用都会进行实例化）

支持多个 Protocol 绑定到，同一个 Class，只会有一个实例（在无参数调用的情况下）

```
#define IMYHIVE_BIND_CLASS($class, $protocol, $singleton)
```

> PS：所有实现都是懒加载模式，只有依赖方主动调用时，注入类才会进行初始化。


### 3. 模块调用

采用 `IMYHIVE_BINDER` 宏进行调用。

``` objective-c 
// 在模块B调用，B模块完全不依赖A模块
// B模块的 ICar 声明，框架会进行两个协议一致性的校验（只在Debug包，不会影响用户体验）
@protocol ICar_hive_B
- (void)awake;
@end
 
// 获取具体的实现，底层会自动截取 _hive_ 字段的前缀
// 所以在框架内部 @protocol(ICar_hive_B) == @protocol(ICar)
[IMYHIVE_BINDER(ICar_hive_B) awake];
```

`IMYHIVE_BINDER ` 只有一个参数：

- `$protocol`：协议名（你所依赖的协议）

```
#define IMYHIVE_BINDER($protocol)
```

## 依赖列表

`依赖列表` 跟 `模块注册` 有点类似，但是两者的思想是不同的。

 - 模块注册：讲究的是 `单人`，实现者只选着一人，调用方无主动权
 - 依赖列表：获取的是 `多人`，调用方有最大的权利，可以先获取再挑选

### 1. 依赖注册

采用 `IMYHIVE_REGIST_CLASS` 宏进行依赖注册。

``` objective-c
@protocol ICar
- (void)awake;
+ (BOOL)filter;
+ (int)index;
@end

// 在 模块A 注册
@implementation CarA
IMYHIVE_REGIST_CLASS(CarA, ICar)
@end

// 在 模块B 注册
@implementation CarB
IMYHIVE_REGIST_CLASS(CarB, ICar)
@end
```

`IMYHIVE_REGIST_CLASS ` 主要由2个参数组成：

- `$class`：类名（具体实现类）
- `$protocol`：协议名（需要注入的依赖协议）

```
#define IMYHIVE_REGIST_CLASS($class, $protocol)
```

> PS：注册方将永远不会进行实例化，实例化过程交给依赖方(调用者)。

### 2. 获取注册列表

采用 `IMYHIVE_REGISTERS` 宏进行调用。

``` objective-c 
// 在模块C调用
@protocol ICar_hive_C
- (void)awake;
+ (BOOL)filter;
+ (int)index;
@end

// 获取所有 @protocol(ICar) 协议注册者
NSArray<Class<ICar_hive_C>> *registers = IMYHIVE_REGISTERS(ICar_hive_C);

// 注册者的过滤、排序、初始化、使用等等 都是由调用方决定，所以需要在协议处定好相关规则
// IoC容器不参与这种高复杂性工作

// 过滤
[registers filter];
// 排序
[registers sorting];
// 初始化
[registers map:^{ [$0 new] }]
// 调用
...

```

`IMYHIVE_REGISTERS ` 只有一个参数：

- `$protocol`：协议名（你所依赖的协议）

```
#define IMYHIVE_REGISTERS($protocol)
```

## 复杂用法

### 1. 复杂的模块注册

`IMYHIVE_BIND_CLASS_INTACT ` 主要新增2个参数：

- `$priority `：优先级（从大到小，可覆盖其他模块）
- `$iscls `：类单例（调用都是类方法，无需实例化）

```
#define IMYHIVE_BIND_CLASS_INTACT($class, $protocol, $singleton, $priority, $iscls)
```

### 2. 根据参数响应调用
 
当模块实现了 `IMYHiveInjector` 协议后，框架会按优先级进行回调，模块可根据参数进行响应，并且根据参数进行实例化。

```
@protocol IMYHiveInjector <NSObject>
@optional
// 是否响应该参数，默认：YES
+ (BOOL)hive_respondsForParams:(nullable id)params;

// 初始化调用API，默认：[class new]
+ (instancetype)hive_newWithParams:(nullable id)params;
@end
```

## 性能对比

... 未完待续，有兴趣的可以自己跑下
