#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

double animationDurationFactorImpl();

CABasicAnimation * _Nonnull makeSpringAnimationImpl(NSString * _Nonnull keyPath, double duration);
CABasicAnimation * _Nonnull make26SpringAnimationImpl(NSString * _Nonnull keyPath, double duration);
CASpringAnimation * _Nonnull makeSpringBounceAnimationImpl(NSString * _Nonnull keyPath, CGFloat initialVelocity, CGFloat damping);
CGFloat springAnimationValueAtImpl(CABasicAnimation * _Nonnull animation, CGFloat t);

UIBlurEffect * _Nonnull makeCustomZoomBlurEffectImpl(bool isLight);
void applySmoothRoundedCornersImpl(CALayer * _Nonnull layer);

@protocol UIKitPortalViewProtocol <NSObject>

@property(nonatomic) __weak UIView * _Nullable sourceView;
@property(nonatomic) _Bool forwardsClientHitTestingToSourceView;
@property(nonatomic) _Bool allowsHitTesting; // @dynamic allowsHitTesting;
@property(nonatomic) _Bool allowsBackdropGroups; // @dynamic allowsBackdropGroups;
@property(nonatomic) _Bool matchesPosition; // @dynamic matchesPosition;
@property(nonatomic) _Bool matchesTransform; // @dynamic matchesTransform;
@property(nonatomic) _Bool matchesAlpha; // @dynamic matchesAlpha;
@property(nonatomic) _Bool hidesSourceView; // @dynamic hidesSourceView;

@end

UIView<UIKitPortalViewProtocol> * _Nullable makePortalView(bool matchPosition);
bool isViewPortalView(UIView * _Nonnull view);
UIView * _Nullable getPortalViewSourceView(UIView * _Nonnull portalView);

NSObject * _Nullable makeBlurFilter();
NSObject * _Nullable makeLuminanceToAlphaFilter();
NSObject * _Nullable makeColorInvertFilter();
NSObject * _Nullable makeMonochromeFilter();

void setLayerDisableScreenshots(CALayer * _Nonnull layer, bool disableScreenshots);
bool getLayerDisableScreenshots(CALayer * _Nonnull layer);

void setLayerContentsMaskMode(CALayer * _Nonnull layer, bool maskMode);

void setMonochromaticEffectImpl(UIView * _Nonnull view, bool isEnabled);

@protocol _CABackdropLayer<NSObject>

@end

CALayer<_CABackdropLayer> * _Nullable createCABackdropLayer(void);

@protocol _CAFilter<NSObject>
-(void)setValue:(id _Nullable)value forKey:(NSString * _Nonnull)key;
@end

NSObject<_CAFilter> * _Nullable createCAFilter(NSString * _Nonnull name);

@protocol _CAMutableMeshTransform<NSObject>
-(void)setSubdivisionSteps:(int)arg1;
@end

typedef struct CAPoint3D {
    CGFloat x;
    CGFloat y;
    CGFloat z;
} CAPoint3D;

typedef struct CAMeshVertex {
    CGPoint from;
    CAPoint3D to;
} CAMeshVertex;

typedef struct CAMeshFace {
    unsigned int indices[4];
    float w[4];
} CAMeshFace;

extern NSString * _Nullable const kCADepthNormalizationNone;
extern NSString * _Nullable const kCADepthNormalizationWidth;
extern NSString * _Nullable const kCADepthNormalizationHeight;
extern NSString * _Nullable const kCADepthNormalizationMin;
extern NSString * _Nullable const kCADepthNormalizationMax;
extern NSString * _Nullable const kCADepthNormalizationAverage;

NSObject<_CAMutableMeshTransform> * _Nullable createCAMutableMeshTransform(
                                                                           NSUInteger vertexCount,
                                                                           CAMeshVertex * _Nonnull vertices,
                                                                           NSUInteger faceCount,
                                                                           CAMeshFace * _Nonnull faces,
                                                                           NSString * _Nullable depthNormalization
                                                                           );
