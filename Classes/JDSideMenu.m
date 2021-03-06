//
//  JDSideMenu.m
//  StatusBarTest
//
//  Created by Markus Emrich on 11/11/13.
//  Copyright (c) 2013 Markus Emrich. All rights reserved.
//

#import "JDSideMenu.h"

NSString * const JDSideMenuWillOpenNotification = @"JDSideMenuWillOpenNotification";
NSString * const JDSideMenuDidOpenNotification = @"JDSideMenuDidOpenNotification";
NSString * const JDSideMenuWillCloseNotification = @"JDSideMenuWillCloseNotification";
NSString * const JDSideMenuDidCloseNotification = @"JDSideMenuDidCloseNotification";

// constants
const CGFloat JDSideMenuMinimumRelativePanDistanceToOpen = 0.33;
const CGFloat JDSideMenuRatio = 0.8125;
const CGFloat JDSideMenuDefaultDamping = 0.5;
const CGFloat JDSideMenuDefaulPanWidth = 8;

// animation times
const CGFloat JDSideMenuDefaultOpenAnimationTime = 0.4;
const CGFloat JDSideMenuDefaultCloseAnimationTime = 0.4;

@interface JDSideMenu ()
@property (nonatomic, strong) UIImageView *backgroundView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic, strong) UITapGestureRecognizer *tapRecognizer;
@property (nonatomic, strong) UIView *panView;
@end

@implementation JDSideMenu

- (id)initWithContentController:(UIViewController*)contentController menuController:(UIViewController*)menuController {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _contentController = contentController;
        _menuController = menuController;
        
        _menuWidth = CGRectGetWidth([[UIScreen mainScreen] bounds]) * JDSideMenuRatio;
        _bounceOffset = 0.0;
    }
    return self;
}

- (void)setMenuEnabled:(BOOL)menuEnabled {
    _menuEnabled = menuEnabled;

    self.panView.hidden = !menuEnabled;
    self.panRecognizer.enabled = menuEnabled;
}

#pragma mark UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // add childcontroller
    [self addChildViewController:self.menuController];
    [self.menuController didMoveToParentViewController:self];
    [self addChildViewController:self.contentController];
    [self.contentController didMoveToParentViewController:self];
    
    // add subviews
    _containerView = [[UIView alloc] initWithFrame:self.view.bounds];
    _containerView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
    [self.containerView addSubview:self.contentController.view];
    self.contentController.view.frame = self.containerView.bounds;
    self.contentController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_containerView];
    
    UIView *panView = [[UIView alloc] init];
    panView.frame = CGRectMake(0, 0, JDSideMenuDefaulPanWidth, CGRectGetHeight(_containerView.bounds));
    [_containerView addSubview:panView];
    _panView = panView;
    
    // add shadow to container view
    
    if (self.shadowImage) {
        UIView *shadowView = [[UIView alloc] initWithFrame:CGRectMake(-1 * self.shadowImage.size.width, 0, self.shadowImage.size.width, CGRectGetHeight(self.view.bounds))];
        shadowView.backgroundColor = [UIColor colorWithPatternImage:self.shadowImage];
        [self.containerView addSubview:shadowView];
        self.containerView.clipsToBounds = NO;
    }
    
    // setup gesture recognizers
    self.panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panRecognized:)];
    self.panRecognizer.delegate = self;
    [panView addGestureRecognizer:self.panRecognizer];
    
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
}

- (void)setBackgroundImage:(UIImage*)image {
    if (!self.backgroundView && image) {
        self.backgroundView = [[UIImageView alloc] initWithImage:image];
        self.backgroundView.frame = self.view.bounds;
        self.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view insertSubview:self.backgroundView atIndex:0];
    } else if (image == nil) {
        [self.backgroundView removeFromSuperview];
        self.backgroundView = nil;
    } else {
        self.backgroundView.image = image;
    }
}

#pragma mark controller replacement
- (void)setContentController:(UIViewController*)contentController animated:(BOOL)animated {
    if (contentController == nil) return;
    
    if ([self.delegate respondsToSelector:@selector(sideMenuDidChangeContent)]) {
        [self.delegate sideMenuWillChangeContent];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:JDSideMenuWillCloseNotification object:self];

    UIViewController *previousController = self.contentController;
    _contentController = contentController;
    
    // add childcontroller
    [self addChildViewController:self.contentController];
    
    // add subview
    self.contentController.view.frame = self.containerView.bounds;
    self.contentController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // animate in
    __weak typeof(self) blockSelf = self;
    CGFloat offset = self.menuWidth + self.bounceOffset;
    if (animated) {
        [UIView animateWithDuration:JDSideMenuDefaultCloseAnimationTime/2.0 animations:^{
            blockSelf.containerView.transform = CGAffineTransformMakeTranslation(offset, 0);
        } completion:^(BOOL finished) {
            [self replaceControllersInBlockSelf:blockSelf previousController:previousController animated:YES];
        }];
    } else {
        [self replaceControllersInBlockSelf:blockSelf previousController:previousController animated:NO];
    }
}

- (void)replaceControllersInBlockSelf:(__weak JDSideMenu *)blockSelf previousController:(UIViewController *)previousController animated:(BOOL)animated {
    // move to container view
    [blockSelf.containerView addSubview:self.contentController.view];
    [blockSelf.contentController didMoveToParentViewController:blockSelf];
    
    // place pan view to the top of the content again
    [blockSelf.containerView bringSubviewToFront:blockSelf.panView];
    
    // remove old controller
    [previousController willMoveToParentViewController:nil];
    [previousController removeFromParentViewController];
    [previousController.view removeFromSuperview];
    
    if ([self.delegate respondsToSelector:@selector(sideMenuDidChangeContent)]) {
        [self.delegate sideMenuDidChangeContent];
    }
    
    [blockSelf hideMenuAnimated:animated];
}

- (void)hideMenuCopletionInBlockSelf:(__weak JDSideMenu *)blockSelf {
    if ([self.delegate respondsToSelector:@selector(sideMenuDidDisappear)]) {
        [self.delegate sideMenuDidDisappear];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:JDSideMenuDidCloseNotification object:self];
    
    [blockSelf.menuController.view removeFromSuperview];
    
    // enable user interaction in content view controller
    if ([self.contentController isKindOfClass:[UINavigationController class]]) {
        ((UINavigationController *)self.contentController).visibleViewController.view.userInteractionEnabled = YES;
    }
    else {
        self.contentController.view.userInteractionEnabled = YES;
    }
    
    // restore size of pan view when content visible
    self.panView.frame = CGRectMake(0, 0, JDSideMenuDefaulPanWidth, CGRectGetHeight(self.panView.bounds));
}

- (void)setContentControllerImmediately:(UIViewController *)contentController {
    if (contentController == nil) return;
    
    UIViewController *previousController = self.contentController;
    _contentController = contentController;
    
    // add childcontroller
    [self addChildViewController:self.contentController];
    
    self.contentController.view.frame = self.containerView.bounds;
    self.contentController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // move to container view
    [self.containerView addSubview:self.contentController.view];
    [self.contentController didMoveToParentViewController:self];
    
    // place pan view to the top of the content again
    [self.containerView bringSubviewToFront:self.panView];
    
    // remove old controller
    [previousController willMoveToParentViewController:nil];
    [previousController removeFromParentViewController];
    [previousController.view removeFromSuperview];
}

#pragma mark Animation
- (void)panRecognized:(UIPanGestureRecognizer*)recognizer {
    UIView *view = self.containerView;
    
    CGPoint translation = [recognizer translationInView:view];
    CGPoint velocity = [recognizer velocityInView:view];
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            [self addMenuControllerView];
            [recognizer setTranslation:CGPointMake(view.frame.origin.x, 0) inView:view];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGFloat translationX = MAX(0,translation.x);
            if (!self.shouldBounce) {
                if (translationX > self.menuWidth) translationX = self.menuWidth;
            }
            [view setTransform:CGAffineTransformMakeTranslation(translationX, 0)];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (velocity.x > 5.0 || (velocity.x >= -1.0 && translation.x > JDSideMenuMinimumRelativePanDistanceToOpen*self.menuWidth)) {
                CGFloat transformedVelocity = velocity.x/ABS(self.menuWidth - translation.x);
                CGFloat duration = JDSideMenuDefaultOpenAnimationTime * 0.66;
                [self showMenuAnimated:YES duration:duration initialVelocity:transformedVelocity];
            } else {
                [self hideMenuAnimated:YES];
            }
        }
        default:
            break;
    }
}

- (void)tapRecognized:(UITapGestureRecognizer *)recognizer {
    [self hideMenuAnimated:YES];
}

- (void)addMenuControllerView {
    if (self.menuController.view.superview == nil) {
        if ([self.delegate respondsToSelector:@selector(sideMenuWillAppear)]) {
            [self.delegate sideMenuWillAppear];
        }
        
        CGRect menuFrame, restFrame;
        CGRectDivide(self.view.bounds, &menuFrame, &restFrame, self.menuWidth, CGRectMinXEdge);
        self.menuController.view.frame = menuFrame;
        self.menuController.view.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleHeight;
        self.view.backgroundColor = self.menuController.view.backgroundColor;
        if (self.backgroundView) [self.view insertSubview:self.menuController.view aboveSubview:self.backgroundView];
        else [self.view insertSubview:self.menuController.view atIndex:0];
    }
}

- (void)showMenuAnimated:(BOOL)animated {
    [self showMenuAnimated:animated duration:JDSideMenuDefaultOpenAnimationTime initialVelocity:1.0];
}

- (void)showMenuAnimated:(BOOL)animated duration:(CGFloat)duration initialVelocity:(CGFloat)velocity {

    [[NSNotificationCenter defaultCenter] postNotificationName:JDSideMenuWillOpenNotification object:self];
    // add menu view
    [self addMenuControllerView];
    
    // disable user interactions when menu opened
    if ([self.contentController isKindOfClass:[UINavigationController class]]) {
        ((UINavigationController *)self.contentController).visibleViewController.view.userInteractionEnabled = NO;
    }
    else {
        self.contentController.view.userInteractionEnabled = NO;
    }
    
    // resize pan view width to easily drag back the content
    self.panView.frame = CGRectMake(0, 0, CGRectGetWidth(self.containerView.bounds) - self.menuWidth, CGRectGetHeight(self.panView.bounds));
    
    // allow tapping the visible part of content to hide the menu
    [self.panView addGestureRecognizer:self.tapRecognizer];
    
    // animate
    __weak typeof(self) blockSelf = self;

    void (^animationBlock)() = ^{
        blockSelf.containerView.transform = CGAffineTransformMakeTranslation(self.menuWidth, 0);
    };

    void (^completionBlock)(BOOL) = ^(BOOL finished) {
        if ([self.delegate respondsToSelector:@selector(sideMenuDidAppear)]) {
            [self.delegate sideMenuDidAppear];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:JDSideMenuDidOpenNotification object:self];
    };

    if (self.shouldBounce) {
        [UIView animateWithDuration:animated ? (duration * 3) : 0.0 delay:0 usingSpringWithDamping:JDSideMenuDefaultDamping initialSpringVelocity:velocity options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:completionBlock];
    }
    else {
        [UIView animateWithDuration:animated ? duration : 0.0 animations:animationBlock completion:completionBlock];
    }
}

- (void)hideMenuAnimated:(BOOL)animated {
    if ([self.delegate respondsToSelector:@selector(sideMenuWillDisappear)]) {
        [self.delegate sideMenuWillDisappear];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:JDSideMenuWillCloseNotification object:self];
    
    [self.panView removeGestureRecognizer:self.tapRecognizer];
    
    __weak typeof(self) blockSelf = self;
    if ( animated ) {
        [UIView animateWithDuration:JDSideMenuDefaultCloseAnimationTime animations:^{
            blockSelf.containerView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [self hideMenuCopletionInBlockSelf:blockSelf];
        }];
    } else {
        [self hideMenuCopletionInBlockSelf:blockSelf];
    }
}

#pragma mark State
- (BOOL)isMenuVisible {
    return !CGAffineTransformEqualToTransform(self.containerView.transform,
                                              CGAffineTransformIdentity);
}

@end
