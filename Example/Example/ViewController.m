//
//  ViewController.m
//  Example
//
//  Created by ljh on 2019/6/27.
//  Copyright © 2019 ljh. All rights reserved.
//

#import "ViewController.h"
#import <MobA/MobA.h>
#import <IMYHiveMind/IMYHiveMind.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.titleLabel.text = [IMYHIVE_BINDER(Peoson) say];
}


@end
