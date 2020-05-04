//
//  BBZImageAction.m
//  BBZVideoEngine
//
//  Created by Hbo on 2020/4/29.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZImageAction.h"
#import "BBZImageAsset.h"

@implementation BBZImageAction
- (void)destroySomething {
    [((BBZImageAsset *)self.asset) unloadImage];
}

- (void)lock {
    [super lock];
    [((BBZImageAsset *)self.asset) loadImageWithCompletion:nil];
}

- (GPUImageFramebuffer *)frameBufferAtTime:(CMTime)time {
    return nil;
}

@end
