//
//  BBZVideoModel.m
//  BBZVideoEngine
//
//  Created by Hbo on 2020/4/20.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZVideoModel.h"

@interface BBZVideoModel ()
@property (nonatomic, strong) NSMutableArray<BBZBaseAsset *> *interAssetItems;
@property (nonatomic, strong) NSMutableArray<BBZAudioAsset *> * _Nullable interAudioItems;

@end

@implementation BBZVideoModel

- (instancetype)init {
    if(self = [super init]){
        _identifier = [NSString stringWithFormat:@"Model%.6f-%li",[NSDate timeIntervalSinceReferenceDate], (long)arc4random()];
        _interAssetItems = [NSMutableArray array];
        _interAudioItems = [NSMutableArray array];
    }
    return self;
}


#pragma mark - Asset
- (BOOL)addVideoSource:(NSString *)filePath {
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:filePath] options:nil];
    BBZVideoAsset *videoAsset = [BBZVideoAsset assetWithAVAsset:avAsset];
    [self.interAssetItems addObject:videoAsset];
    return YES;
}

- (BOOL)addVideoAsset:(AVAsset *)avAsset {
    BBZVideoAsset *videoAsset = [BBZVideoAsset assetWithAVAsset:avAsset];
    [self.interAssetItems addObject:videoAsset];
    return YES;
}

- (BOOL)addImageSource:(NSString *)filePath {
    BBZImageAsset *imageAsset = [BBZImageAsset assetWithFilePath:filePath];
    [self.interAssetItems addObject:imageAsset];
    return YES;
}

- (BOOL)addUIImage:(UIImage *)image {
    BBZImageAsset *imageAsset = [BBZImageAsset assetWithImage:image];
    [self.interAssetItems addObject:imageAsset];
    return YES;
}

- (NSArray *)assetItems {
    return self.interAssetItems;
}

- (NSArray *)audioItems {
    return self.interAudioItems;
}

#pragma mark - Filter

- (void)addFilterGroup:(NSString *)strDirectory {
    _filterModel = [[BBZFilterModel alloc] initWidthDir:strDirectory];
}

- (void)addTransitionGroup:(NSString *)strDirectory {
    _transitonModel = [[BBZTransitionModel alloc] initWidthDir:strDirectory];
}

#pragma mark - Timeline
- (void)buildTimeLine{
    
}

@end
