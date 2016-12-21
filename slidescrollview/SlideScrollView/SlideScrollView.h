//
//  SlideScrollView.h
//  SlideScrollView
//
//  Created by NetEase on 16/3/16.
//  Copyright © 2016年 NetEase. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SlideScrollView-Constants.h"

//////////////////////////////////////////////////////////////
#pragma mark Protocol GMGridViewDataSource
//////////////////////////////////////////////////////////////
@class SlideScrollView;
@protocol SlideScrollViewDataSource <NSObject>

@required
// Populating subview items
- (NSInteger)numberOfItemsInSlideScrollView:(SlideScrollView *)gridView;
- (CGSize)sizeForItemsInSlideScrollView:(SlideScrollView *)gridView;
- (UIView *)SlideScrollView:(SlideScrollView *)gridView cellForItemAtIndex:(NSInteger)index;

@optional
// Required to enable editing mode
- (void)SlideScrollView:(SlideScrollView *)gridView deleteItemAtIndex:(NSInteger)index;

@end

//////////////////////////////////////////////////////////////
#pragma mark Interface SlideScrollView
//////////////////////////////////////////////////////////////
@interface SlideScrollView : UIView

@property (nonatomic, gm_weak) UIView *mainSuperView;          // Default is self
@property (nonatomic, gm_weak) NSObject<SlideScrollViewDataSource> *dataSource;

// Reusable cells
- (UIView *)dequeueReusableCell;                              // Should be called in UIView:cellForItemAtIndex: to reuse a cell

// Cells
- (UIView *)cellForItemAtIndex:(NSInteger)position;           // Might return nil if cell not loaded for the specific index
- (UIView *)newItemSubViewForPosition:(NSInteger)position;
// Actions
- (void)reloadData;

@end
