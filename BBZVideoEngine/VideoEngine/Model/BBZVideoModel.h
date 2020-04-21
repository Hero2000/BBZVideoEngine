//
//  BBZVideoModel.h
//  BBZVideoEngine
//
//  Created by Hbo on 2020/4/20.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BBZImageAsset.h"
#import "BBZVideoAsset.h"
#import "BBZAudioAsset.h"
NS_ASSUME_NONNULL_BEGIN

@interface BBZVideoModel : NSObject
@property (nonatomic, strong, readonly) NSString *identifier;
/// video and image
@property (nonatomic, strong, readonly) NSArray<BBZBaseAsset *> *assetItems;
@property (nonatomic, strong, readonly) NSArray<BBZAudioAsset *> * _Nullable audioItems;


- (BOOL)addVideoSource:(NSString *)filePath;
- (BOOL)addVideoAsset:(AVAsset *)avAsset;
- (BOOL)addImageSource:(NSString *)filePath;
- (BOOL)addUIImage:(UIImage *)image;

@end




NS_ASSUME_NONNULL_END
