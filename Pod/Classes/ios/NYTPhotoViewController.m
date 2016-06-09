//
//  NYTPhotoViewController.m
//  Pods
//
//  Created by Brian Capps on 2/11/15.
//
//

#import "NYTPhotoViewController.h"
#import "NYTPhoto.h"
#import "NYTScalingImageView.h"

static CGAffineTransform DeviceOrientationToAffineTransform(UIDeviceOrientation orientation)
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    if (UIDeviceOrientationIsPortrait(orientation)) {
        transform = CGAffineTransformMakeRotation(0);
    } else if (orientation == UIDeviceOrientationLandscapeLeft) {
        transform = CGAffineTransformMakeRotation(M_PI / 2);
    } else if (orientation == UIDeviceOrientationLandscapeRight) {
        transform = CGAffineTransformMakeRotation(-M_PI / 2);
    }
    
    return transform;
}


NSString * const NYTPhotoViewControllerPhotoImageUpdatedNotification = @"NYTPhotoViewControllerPhotoImageUpdatedNotification";

@interface NYTPhotoViewController () <UIScrollViewDelegate>

@property (nonatomic) id <NYTPhoto> photo;
@property(nonatomic) BOOL controllerIsVisible;

@property (nonatomic) NYTScalingImageView *scalingImageView;
@property (nonatomic) UIView *loadingView;
@property (nonatomic) NSNotificationCenter *notificationCenter;
@property (nonatomic) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;

@end

@implementation NYTPhotoViewController

#pragma mark - NSObject

- (void)dealloc {
    _scalingImageView.delegate = nil;
    
    [_notificationCenter removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithPhoto:nil loadingView:nil notificationCenter:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.notificationCenter addObserver:self selector:@selector(photoImageUpdatedWithNotification:) name:NYTPhotoViewControllerPhotoImageUpdatedNotification object:nil];
    
    self.scalingImageView.frame = self.view.bounds;
    [self.view addSubview:self.scalingImageView];
    
    [self.view addSubview:self.loadingView];
    [self.loadingView sizeToFit];
    
    [self.view addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:self.longPressGestureRecognizer];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIDevice *device = [UIDevice currentDevice];
    UIDeviceOrientation deviceOrientation = device.orientation;
    CGAffineTransform transform = DeviceOrientationToAffineTransform(deviceOrientation);
    
    [UIView performWithoutAnimation:^{
        self.scalingImageView.transform = transform;
    }];
}


- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.scalingImageView.frame = self.view.bounds;
    
    [self.loadingView sizeToFit];
    self.loadingView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
}

#pragma mark - NYTPhotoViewController

- (instancetype)initWithPhoto:(id <NYTPhoto>)photo loadingView:(UIView *)loadingView notificationCenter:(NSNotificationCenter *)notificationCenter {
    self = [super initWithNibName:nil bundle:nil];
    
    if (self) {
        _photo = photo;
        
        UIImage *photoImage = photo.image ?: photo.placeholderImage;
        
        _scalingImageView = [[NYTScalingImageView alloc] initWithImage:photoImage frame:CGRectZero];
        _scalingImageView.delegate = self;
        
        if (!photo.image) {
            [self setupLoadingView:loadingView];
        }
        
        _notificationCenter = notificationCenter;
        
        [self setupGestureRecognizers];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    
    return self;
}

- (void)setupLoadingView:(UIView *)loadingView {
    self.loadingView = loadingView;
    if (!loadingView) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityIndicator startAnimating];
        self.loadingView = activityIndicator;
    }
}

- (void)photoImageUpdatedWithNotification:(NSNotification *)notification {
    id <NYTPhoto> photo = notification.object;
    if ([photo conformsToProtocol:@protocol(NYTPhoto)] && [photo isEqual:self.photo]) {
        [self updateImage:photo.image];
    }
}

- (void)updateImage:(UIImage *)image {
    [self.scalingImageView updateImage:image];
    
    if (image) {
        [self.loadingView removeFromSuperview];
        self.loadingView = nil;
    }
}

#pragma mark - Gesture Recognizers

- (void)setupGestureRecognizers {
    self.doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTapWithGestureRecognizer:)];
    self.doubleTapGestureRecognizer.numberOfTapsRequired = 2;
    
    self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWithGestureRecognizer:)];
}

- (void)didDoubleTapWithGestureRecognizer:(UITapGestureRecognizer *)recognizer {
    CGPoint pointInView = [recognizer locationInView:self.scalingImageView.imageView];
    
    CGFloat newZoomScale = self.scalingImageView.maximumZoomScale;
    
    if (self.scalingImageView.zoomScale >= self.scalingImageView.maximumZoomScale) {
        newZoomScale = self.scalingImageView.minimumZoomScale;
    }
    
    CGSize scrollViewSize = self.scalingImageView.bounds.size;
    
    CGFloat width = scrollViewSize.width / newZoomScale;
    CGFloat height = scrollViewSize.height / newZoomScale;
    CGFloat originX = pointInView.x - (width / 2.0);
    CGFloat originY = pointInView.y - (height / 2.0);
    
    CGRect rectToZoomTo = CGRectMake(originX, originY, width, height);
    
    [self.scalingImageView zoomToRect:rectToZoomTo animated:YES];
}

- (void)didLongPressWithGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([self.delegate respondsToSelector:@selector(photoViewController:didLongPressWithGestureRecognizer:)]) {
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            [self.delegate photoViewController:self didLongPressWithGestureRecognizer:recognizer];
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.scalingImageView.imageView;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    scrollView.panGestureRecognizer.enabled = YES;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    // There is a bug, especially prevalent on iPhone 6 Plus, that causes zooming to render all other gesture recognizers ineffective.
    // This bug is fixed by disabling the pan gesture recognizer of the scroll view when it is not needed.
    if (scrollView.zoomScale == scrollView.minimumZoomScale) {
        scrollView.panGestureRecognizer.enabled = NO;
    }
}

#pragma mark - UIDeviceOrientationDidChangeNotification

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    UIDevice *device = (id)notification.object;
    if (!device) {
        return;
    }
    
    UIDeviceOrientation deviceOrientation = device.orientation;
    CGAffineTransform transform = DeviceOrientationToAffineTransform(deviceOrientation);
    
    
    if (!self.controllerIsVisible) {
        [UIView performWithoutAnimation:^{
            self.scalingImageView.alpha = 0.0;
            self.scalingImageView.transform = transform;
            self.scalingImageView.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.2f animations:^{
            self.scalingImageView.transform = transform;
        }];
    }
}

#pragma mark - NYTPhotoViewController informal protocol

- (void)photoViewControllerIsVisible:(BOOL)visible {
    self.controllerIsVisible = visible;
}

@end
