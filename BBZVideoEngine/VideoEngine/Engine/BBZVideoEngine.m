//
//  BBZVideoEngine.m
//  BBZVideoEngine
//
//  Created by Hbo on 2020/4/27.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZVideoEngine.h"
#import "BBZCompositonDirector.h"
#import "BBZFilterLayer.h"
#import "BBZFilterMixer.h"
#import "BBZVideoFilterLayer.h"
#import "BBZAudioFilterLayer.h"
#import "BBZEffetFilterLayer.h"
#import "BBZMaskFilterLayer.h"
#import "BBZOutputFilterLayer.h"
#import "BBZTransitionFilterLayer.h"
#import "BBZQueueManager.h"


typedef NS_ENUM(NSInteger, BBZFilterLayerType) {
    BBZFilterLayerTypeVideo,//视频 图片 背景图 拼接
    BBZFilterLayerTypeAudio,//音频
    BBZFilterLayerTypeTransition,//转场
    BBZFilterLayerTypeEffect,//特效
    BBZFilterLayerTypeMask,//水印
    BBZFilterLayerTypeOutput,//输出
    BBZFilterLayerTypeMax,
};


@interface BBZVideoEngine ()<BBZVideoWriteControl, BBZSegmentActionDelegate>
@property (nonatomic, strong) BBZVideoModel *videoModel;
@property (nonatomic, strong) BBZEngineContext *context;
//@property (nonatomic, strong) NSString *outputFile;
@property (nonatomic, strong) BBZFilterMixer *filterMixer;
@property (nonatomic, strong) BBZSchedule *schedule;
@property (nonatomic, strong) BBZCompositonDirector *director;
@property (nonatomic, strong) NSMutableDictionary *filterLayers; //@(BBZFilterLayerType):BBZFilterLayer
@property (nonatomic, strong) NSMutableSet *timePointSet;
@property (nonatomic, assign) NSUInteger intDuration;
@property (nonatomic, strong) NSMutableDictionary *timeSegments; // @(time): ActionTree



@end


@implementation BBZVideoEngine

- (instancetype)initWithModel:(BBZVideoModel *)videoModel
                context:(BBZEngineContext *)context
                   outputFile:(NSString *)outputFile {
    if(self = [super init]) {
        _videoModel = videoModel;
        _context = context;
        _timeSegments = [NSMutableDictionary dictionary];
        _timePointSet = [NSMutableSet set];
        _outputFile = outputFile;
        [self buildVideoEngine];
        [self buildFilterLayers];
    }
    return self;
}


+ (instancetype)videoEngineWithModel:(BBZVideoModel *)model
                             context:(BBZEngineContext *)context
                          outputFile:(NSString *)outputFile {
    BBZVideoEngine *videoEngine = [[BBZVideoEngine alloc] initWithModel:model context:context outputFile:outputFile];
    return videoEngine;
}

#pragma mark - Private

- (void)buildFilterLayers {
    self.filterLayers = [NSMutableDictionary dictionaryWithCapacity:BBZFilterLayerTypeMax];
    
    
    BBZVideoFilterLayer *videolayer = [[BBZVideoFilterLayer alloc] initWithModel:self.videoModel context:self.context];
        self.filterLayers[@(BBZFilterLayerTypeVideo)] = videolayer;
    BBZAudioFilterLayer *audioLayer = [[BBZAudioFilterLayer alloc] initWithModel:self.videoModel context:self.context];
    self.filterLayers[@(BBZFilterLayerTypeAudio)] = audioLayer;
    
    BBZTransitionFilterLayer *transitionLayer = [[BBZTransitionFilterLayer alloc] initWithModel:self.videoModel context:self.context];
    self.filterLayers[@(BBZFilterLayerTypeTransition)] = transitionLayer;
    
    BBZEffetFilterLayer *effectLayer = [[BBZEffetFilterLayer alloc] initWithModel:self.videoModel context:self.context];
    self.filterLayers[@(BBZFilterLayerTypeEffect)] = effectLayer;
    
    BBZMaskFilterLayer *maskLayer = [[BBZMaskFilterLayer alloc] initWithModel:self.videoModel context:self.context];
    self.filterLayers[@(BBZFilterLayerTypeMask)] = maskLayer;
    
    BBZOutputFilterLayer *outputLayer = [[BBZOutputFilterLayer alloc] initWithModel:self.videoModel context:self.context];
    self.filterLayers[@(BBZFilterLayerTypeOutput)] = outputLayer;
    outputLayer.outputFile = self.outputFile;
    outputLayer.writerControl = self;
    
    BBZActionBuilderResult *builerResult = nil;
    for (int i = BBZFilterLayerTypeVideo; i < BBZFilterLayerTypeMax; i++) {
        BBZFilterLayer *layer = self.filterLayers[@(i)];
        if(i == BBZFilterLayerTypeVideo || i == BBZFilterLayerTypeTransition) {
            BBZActionBuilderResult *currentResult = [layer buildTimelineNodes:builerResult];
            layer.builderResult = currentResult;
            if(currentResult) {
                builerResult = currentResult;
            }
        } else {
            BBZActionBuilderResult *currentResult = [layer buildTimelineNodes:builerResult];
            layer.builderResult = currentResult;
            [self addTimePointFrom:currentResult];
        }
    }
    [self addTimePointFrom:builerResult];
    self.intDuration = builerResult.startTime;
}

- (void)buildVideoEngine {
    self.director = [[BBZCompositonDirector alloc] init];
    self.schedule = [BBZSchedule scheduleWithMode:self.context.scheduleMode];
    self.schedule.observer = self.director;
}


- (void)prepareForStart {
    if(!self.director.timePointsArray) {
        NSMutableArray *mutableArray =  [NSMutableArray arrayWithArray:self.timePointSet.allObjects];
        [mutableArray sortUsingComparator:^NSComparisonResult(NSNumber  *obj1, NSNumber *obj2) {
            return (obj1.unsignedIntegerValue < obj2.unsignedIntegerValue) ? NSOrderedAscending : NSOrderedDescending;
        }];
        self.director.timePointsArray = mutableArray;
    }
    //进行滤镜链时间区间创建
    NSUInteger startTime = 0;
    NSUInteger endTime = 0;
    for (int timeIndex = 0; timeIndex < self.director.timePointsArray.count; timeIndex++) {
        startTime = endTime;
        NSNumber *number = [self.director.timePointsArray objectAtIndex:timeIndex];
        endTime = [number unsignedIntegerValue];
        if(timeIndex == 0) {
            NSAssert(endTime == 0, @"first time should be Zero");
            continue;
        }
        BBZActionTree *builderTree = [self builderChainFromLayer:BBZFilterLayerTypeVideo toLayer:BBZFilterLayerTypeTransition startTime:startTime endTime:endTime];
        for (int layerIndex = BBZFilterLayerTypeEffect; layerIndex < BBZFilterLayerTypeMax; layerIndex++) {
            if(layerIndex == BBZFilterLayerTypeAudio) {
                continue;
            }
            builderTree = [self builderChainFrom:builderTree layer:(BBZFilterLayerType)layerIndex startTime:startTime endTime:endTime];
        }
        [self.timeSegments setObject:builderTree forKey:@(endTime)];
    }
}

- (BBZActionTree *)builderChainFrom:(BBZActionTree *)fromTree
                              layer:(BBZFilterLayerType)layerType
                          startTime:(NSUInteger)startTime
                            endTime:(NSUInteger)endTime {
    BBZActionTree *builderTree = nil;
    NSArray *layerArray = [self actionTreeFromLayer:self.filterLayers[@(layerType)] startTime:startTime endTime:endTime];
    if(layerArray.count > 0) {
        builderTree = [layerArray objectAtIndex:0];
        [builderTree addSubTree:fromTree];
    } else  {
        builderTree = fromTree;
    }
    return builderTree;
}

- (BBZActionTree *)builderChainFromLayer:(BBZFilterLayerType )fromLayer
                              toLayer:(BBZFilterLayerType)toLayer
                          startTime:(NSUInteger)startTime
                            endTime:(NSUInteger)endTime {
    BBZActionTree *builderTree = nil;
    NSArray *fromLayerArray = [self actionTreeFromLayer:self.filterLayers[@(fromLayer)] startTime:startTime endTime:endTime];
    NSArray *toLayerArray = [self actionTreeFromLayer:self.filterLayers[@(toLayer)] startTime:startTime endTime:endTime];
    if(toLayerArray.count > 0 ) {
        builderTree = [toLayerArray objectAtIndex:0];
        if(toLayerArray.count > 1 || builderTree.subTrees.count != fromLayerArray.count) {
            BBZERROR(@"action tree error");
            NSAssert(false, @"action tree error");
        } else {
            [[builderTree subTreeAtIndex:0] addSubTree:[fromLayerArray objectAtIndex:0]];
            [[builderTree subTreeAtIndex:1] addSubTree:[fromLayerArray objectAtIndex:1]];
        }
    } else {
        builderTree = (BBZActionTree *)[fromLayerArray objectAtIndex:0];
    }
    return builderTree;
}

- (NSArray *)actionTreeFromLayer:(BBZFilterLayer *)layer startTime:(NSUInteger)startTime endTime:(NSUInteger)endTime {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:2];
    for (BBZActionTree *tree in layer.builderResult.groupActions) {
        BBZActionTree *subTree = [tree subTreeFromTime:startTime endTime:endTime];
        if(subTree) {
            [array addObject:subTree];
//        } else {
//            break;
        }
    }
    return array;
}


#pragma mark - Public


- (BOOL)start {
    [self prepareForStart];
    [self.director start];
    [self.schedule startTimeline];
    return YES;
}

- (BOOL)pause {
    [self.director pause];
    [self.schedule pauseTimeline];
    return YES;
}

- (BOOL)cancel {
    [self.director cancel];
    [self.schedule stopTimeline];
    return YES;
}

- (CGFloat)videoModelCombinedDuration {
    CGFloat duration  = self.intDuration / BBZVideoDurationScale;
    return duration;
}

#pragma mark - WriteControl Delegate

- (void)didWriteVideoFrame {
    if(self.context.scheduleMode == BBZEngineScheduleModeExport) {
        __weak typeof(self) weakSelf = self;
        BBZRunAsynchronouslyOnTaskQueue(^{
            __strong typeof(self) strongSelf = weakSelf;
            [strongSelf.schedule increaseTime];
        });
    }
}

- (void)didWriteAudioFrame {
    
}

#pragma mark - BBZSegmentActionDelegate

- (NSArray *)layerActionTreesBeforeTimePoint:(NSUInteger)timePoint {
    //进行滤镜链合并 , 创建实例实例filterAction;
    BBZActionTree *actonTree = [self.timeSegments objectForKey:@(timePoint)];
    NSArray *array = [self.filterMixer combineFiltersFromActionTree:actonTree];
    return array;
}


#pragma mark - Private

#pragma mark - TimePoint

- (void)addTimePointFrom:(BBZActionBuilderResult *)result {
    for (BBZActionTree *tree in result.groupActions) {
        for (BBZAction *action in tree.allActions) {
            [self.timePointSet addObject:@(action.startTime)];
            [self.timePointSet addObject:@(action.endTime)];
        }
    }
}

@end
