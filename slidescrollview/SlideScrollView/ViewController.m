//
//  ViewController.m
//  SlideScrollView
//
//  Created by NetEase on 16/3/16.
//  Copyright © 2016年 NetEase. All rights reserved.
//

#import "ViewController.h"
#import "SlideScrollView.h"

@interface ViewController ()<SlideScrollViewDataSource>
{
    __gm_weak SlideScrollView *_slideGridView;
    
}
@property (weak, nonatomic) IBOutlet UIButton *addButton;
@property (nonatomic, strong) NSMutableArray *data;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _data = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < 5; i ++)
    {
        [_data addObject:[NSString stringWithFormat:@"%d", i]];
    }
    CGRect rect = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height/2);
    SlideScrollView *slideGridView = [[SlideScrollView alloc] initWithFrame:rect];
    slideGridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    slideGridView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:slideGridView];
    _slideGridView = slideGridView;
    
    _slideGridView.dataSource = self;
    _slideGridView.mainSuperView = self.view;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    _slideGridView = nil;
}

//////////////////////////////////////////////////////////////
#pragma mark GMGridViewDataSource
//////////////////////////////////////////////////////////////

- (NSInteger)numberOfItemsInSlideScrollView:(SlideScrollView *)gridView
{
    return [_data count];
}

- (CGSize)sizeForItemsInSlideScrollView:(SlideScrollView *)gridView
{
    return CGSizeMake(self.view.frame.size.width/2, self.view.frame.size.height/2);
}

- (UIView *)SlideScrollView:(SlideScrollView *)gridView cellForItemAtIndex:(NSInteger)index
{
    //NSLog(@"Creating view indx %d", index);
    
    UIView *cell = (UIView *)[gridView dequeueReusableCell];
    
    if (!cell)
    {
        cell = [[UIView alloc] init];
    }
    
    return cell;
}

- (IBAction)addButton:(id)sender {
    for (int i = 5; i < 7; i ++)
    {
        [_data addObject:[NSString stringWithFormat:@"%d", i]];
    }
    
    [_slideGridView reloadData];
}

@end
