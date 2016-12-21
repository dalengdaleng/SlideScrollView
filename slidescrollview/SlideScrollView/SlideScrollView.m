//
//  SlideScrollView.m
//  SlideScrollView
//
//  Created by NetEase on 16/3/16.
//  Copyright © 2016年 NetEase. All rights reserved.
//

#import "SlideScrollView.h"
#import "GanScrollView.h"

@interface SlideScrollView()<UIScrollViewDelegate>
{
    CGPoint _minPossibleContentOffset;
    CGPoint _maxPossibleContentOffset;
}

@property (nonatomic, strong) GanScrollView *scrollView;
@property (nonatomic, assign) NSInteger numberTotalItems;
@property (nonatomic, assign) CGSize itemSize;
@property (nonatomic, assign) BOOL rotationActive;
@property (nonatomic, strong) NSMutableSet *reusableCells;
@property (nonatomic, readonly) BOOL itemsSubviewsCacheIsValid;
@property (nonatomic, strong) NSArray *itemSubviewsCache;

@property (nonatomic, assign) NSInteger firstPositionLoaded;
@property (nonatomic, assign) NSInteger lastPositionLoaded;

// Lazy loading
- (void)loadRequiredItems;
- (void)cleanupUnseenItems;
- (void)queueReusableCell:(UIView *)cell;

// Memory warning
- (void)receivedMemoryWarningNotification:(NSNotification *)notification;

// Rotation handling
- (void)willRotate:(NSNotification *)notification;

- (NSArray *)itemSubviews;
- (UIView *)cellForItemAtIndex:(NSInteger)position;

- (void)setSubviewsCacheAsInvalid;
@end

@implementation SlideScrollView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        _scrollView = [[GanScrollView alloc] initWithFrame:[self bounds]];
        [_scrollView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        //    self.contentScrollView.decelerationRate =  UIScrollViewDecelerationRateNormal;
        _scrollView.pagingEnabled= YES;
        _scrollView.scrollsToTop = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.backgroundColor = [UIColor clearColor];
        _scrollView.delegate = self;
        [self addSubview:_scrollView];
        
        _minPossibleContentOffset = CGPointMake(0, 0);
        _maxPossibleContentOffset = CGPointMake(0, 0);
        
        self.mainSuperView = self;
        
        _reusableCells = [[NSMutableSet alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedMemoryWarningNotification:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willRotate:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
    }
    
    return self;
}

//////////////////////////////////////////////////////////////
#pragma mark loading/destroying items & reusing cells
//////////////////////////////////////////////////////////////
- (void)prepareForReuse
{

}

- (void)recomputeSize
{
    CGSize contentSize = CGSizeMake(_itemSize.width * _numberTotalItems, _itemSize.height);
    
    _minPossibleContentOffset = CGPointMake(0, 0);
    _maxPossibleContentOffset = CGPointMake(contentSize.width - _scrollView.bounds.size.width + _scrollView.contentInset.right,
                                            contentSize.height - _scrollView.bounds.size.height + _scrollView.contentInset.bottom);
    
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         if (!CGSizeEqualToSize(_scrollView.contentSize, contentSize))
                         {
                             _scrollView.contentSize = contentSize;
                         }
                     }
                     completion:nil];
}


- (NSRange)rangeOfPositionsInBoundsFromOffset:(CGPoint)offset
{
    CGPoint contentOffset = CGPointMake(MAX(0, offset.x),
                                        MAX(0, offset.y));
    
    CGFloat itemWidth = _itemSize.width;
    
    CGFloat firstRow = MAX(0, (int)(contentOffset.x / itemWidth) - 1);
    
    CGFloat lastRow = ceil(contentOffset.x / itemWidth);
    
    NSInteger firstPosition = firstRow;
    NSInteger lastPosition  = lastRow + 1;
    
    return NSMakeRange(firstPosition, (lastPosition - firstPosition));
}

//添加Items
- (void)loadRequiredItems
{
    NSRange rangeOfPositions = [self rangeOfPositionsInBoundsFromOffset: _scrollView.contentOffset];
    NSRange loadedPositionsRange = NSMakeRange(self.firstPositionLoaded, self.lastPositionLoaded - self.firstPositionLoaded);
    
    BOOL forceLoad = self.firstPositionLoaded == GMGV_INVALID_POSITION || self.lastPositionLoaded == GMGV_INVALID_POSITION;
    NSInteger positionToLoad;
    
    for (int i = 0; i < rangeOfPositions.length; i++)
    {
        positionToLoad = i + rangeOfPositions.location;
        
        if ((forceLoad || !NSLocationInRange(positionToLoad, loadedPositionsRange)) && positionToLoad < _numberTotalItems)
        {
            if (![self cellForItemAtIndex:positionToLoad])
            {
                UIView *cell = [self newItemSubViewForPosition:i];
                [_scrollView addSubview:cell];
                
                cell.backgroundColor = [UIColor redColor];
            }
        }
    }
    
    self.firstPositionLoaded = self.firstPositionLoaded == GMGV_INVALID_POSITION ? rangeOfPositions.location : MIN(self.firstPositionLoaded, rangeOfPositions.location);
    self.lastPositionLoaded  = self.lastPositionLoaded == GMGV_INVALID_POSITION ? NSMaxRange(rangeOfPositions) : MAX(self.lastPositionLoaded, rangeOfPositions.length + rangeOfPositions.location);
    NSLog(@"firstPositionLoaded is %d,self.lastPositionLoaded is%d",self.firstPositionLoaded,self.lastPositionLoaded);
    //用来设置contentScrollView的contentSize的大小
//    CGSize size = CGSizeMake(_itemSize.width * _numberTotalItems, _itemSize.height);
//    [_scrollView setContentSize:size];
    
    [self setSubviewsCacheAsInvalid];
    
    [self cleanupUnseenItems];
}


- (void)cleanupUnseenItems
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSRange rangeOfPositions = [self rangeOfPositionsInBoundsFromOffset: _scrollView.contentOffset];
        UIView *cell;
        if (rangeOfPositions.location > self.firstPositionLoaded)
        {
            for (NSInteger i = self.firstPositionLoaded; i < rangeOfPositions.location; i++)
            {
                cell = [self cellForItemAtIndex:i];
                if(cell)
                {
                    NSLog(@"Removing item at position %zd", i);
                    [self queueReusableCell:cell];
                    [cell removeFromSuperview];
                }
            }
            
            self.firstPositionLoaded = rangeOfPositions.location;
            [self setSubviewsCacheAsInvalid];
        }
        
        if (NSMaxRange(rangeOfPositions) < self.lastPositionLoaded)
        {
            for (NSInteger i = NSMaxRange(rangeOfPositions); i <= self.lastPositionLoaded; i++)
            {
                cell = [self cellForItemAtIndex:i];
                if(cell)
                {
                    //NSLog(@"Removing item at position %d", i);
                    [self queueReusableCell:cell];
                    [cell removeFromSuperview];
                }
            }
            
            self.lastPositionLoaded = NSMaxRange(rangeOfPositions);
            [self setSubviewsCacheAsInvalid];
        }
    });
}

- (void)queueReusableCell:(UIView *)cell
{
    if (cell)
    {
//        [cell prepareForReuse];
        cell.alpha = 1;
        [_reusableCells addObject:cell];
    }
}

- (UIView *)dequeueReusableCell
{
    UIView *cell = [_reusableCells anyObject];
    
    if (cell)
    {
        cell.backgroundColor = [UIColor purpleColor];
        [_reusableCells removeObject:cell];
        NSLog(@"dequeueReusableCell");
    }
    
    return cell;
}

- (void)receivedMemoryWarningNotification:(NSNotification *)notification
{
    [_reusableCells removeAllObjects];
}

- (void)willRotate:(NSNotification *)notification
{
    _rotationActive = YES;
}

- (void)reloadData
{
    CGPoint previousContentOffset = _scrollView.contentOffset;
    
    [[self itemSubviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *stop){
        [(UIView *)obj removeFromSuperview];
    }];
    
    self.firstPositionLoaded = GMGV_INVALID_POSITION;
    self.lastPositionLoaded  = GMGV_INVALID_POSITION;
    
    [self setSubviewsCacheAsInvalid];
    
    NSUInteger numberItems = [self.dataSource numberOfItemsInSlideScrollView:self];
    _itemSize = [self.dataSource sizeForItemsInSlideScrollView:self];
    _numberTotalItems = numberItems;
    
    for (int i = 0; i < _numberTotalItems; i++)
    {
        if (![self cellForItemAtIndex:i])
        {
            UIView *cell = [self newItemSubViewForPosition:i];
            [_scrollView addSubview:cell];
            
            /*test code*/
            if(i == 0)
            {
                cell.backgroundColor = [UIColor greenColor];
            }
            else if(i == 1)
            {
                cell.backgroundColor = [UIColor redColor];
            }
            else if(i == 2)
            {
                cell.backgroundColor = [UIColor blackColor];
            }
            else if(i == 3)
            {
                cell.backgroundColor = [UIColor yellowColor];
            }
            else if(i == 4)
            {
                cell.backgroundColor = [UIColor orangeColor];
            }
        }
    }

    
    //计算UIScrollView的contentSize
    [self recomputeSize];
    
    //新的偏移量
    CGPoint newContentOffset = CGPointMake(MIN(_maxPossibleContentOffset.x, previousContentOffset.x), MIN(_maxPossibleContentOffset.y, previousContentOffset.y));
    newContentOffset = CGPointMake(MAX(newContentOffset.x, _minPossibleContentOffset.x), MAX(newContentOffset.y, _minPossibleContentOffset.y));
    
    _scrollView.contentOffset = newContentOffset;
    
    //添加Cell
    [self loadRequiredItems];

    [self setSubviewsCacheAsInvalid];
    [self setNeedsLayout];
}

- (void)setSubviewsCacheAsInvalid
{
    _itemsSubviewsCacheIsValid = NO;
}

- (NSArray *)itemSubviews
{
    NSArray *subviews = nil;
    
    if (self.itemsSubviewsCacheIsValid)
    {
        subviews = [self.itemSubviewsCache copy];
    }
    else
    {
        @synchronized(_scrollView)
        {
            NSMutableArray *itemSubViews = [[NSMutableArray alloc] initWithCapacity:_numberTotalItems];
            
            for (UIView * v in [_scrollView subviews])
            {
                if ([v isKindOfClass:[UIView class]])
                {
                    [itemSubViews addObject:v];
                }
            }
            
            subviews = itemSubViews;
            
            self.itemSubviewsCache = [subviews copy];
            _itemsSubviewsCacheIsValid = YES;
        }
    }
    
    return subviews;
}

- (UIView *)cellForItemAtIndex:(NSInteger)position
{
    UIView *view = nil;
    
    for (UIView *v in [self itemSubviews])
    {
        if (v.tag == position)
        {
            view = v;
            break;
        }
    }
    
    return view;
}

- (UIView *)newItemSubViewForPosition:(NSInteger)position
{
    UIView *cell = [self.dataSource SlideScrollView:self cellForItemAtIndex:position];
    CGRect frame = CGRectMake(_itemSize.width * position, 0, _itemSize.width, _itemSize.height);
    [cell setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight];
    [cell setFrame:frame];
    cell.tag = position;
    return cell;
}


//////////////////////////////////////////////////////////////
#pragma mark Setters / getters
//////////////////////////////////////////////////////////////

- (void)setDataSource:(NSObject<SlideScrollViewDataSource> *)dataSource
{
    _dataSource = dataSource;
    [self reloadData];
}

- (void)setMainSuperView:(UIView *)mainSuperView
{
    _mainSuperView = mainSuperView != nil ? mainSuperView : self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    void (^layoutBlock)(void) = ^{
        [self loadRequiredItems];
    };
    
    if (_rotationActive)
    {
        CATransition *transition = [CATransition animation];
        transition.duration = 0.25f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [_scrollView.layer addAnimation:transition forKey:@"rotationAnimation"];
        _rotationActive = NO;
        
        [UIView animateWithDuration:0
                              delay:0
                            options:UIViewAnimationOptionOverrideInheritedDuration
                         animations:^{
                             layoutBlock();
                         }
                         completion:nil
         ];
    }
    else
    {
        layoutBlock();
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self loadRequiredItems];
}
@end
