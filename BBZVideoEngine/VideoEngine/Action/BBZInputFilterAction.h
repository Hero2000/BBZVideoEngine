//
//  BBZInputFilterAction.h
//  BBZVideoEngine
//
//  Created by Hbo on 2020/5/5.
//  Copyright © 2020 BBZ. All rights reserved.
//

#import "BBZFilterAction.h"
#import "BBZSourceAction.h"

@interface BBZInputFilterAction : BBZFilterAction
@property (nonatomic, weak) id<BBZOutputSourceProtocol> firstInputSource;
@property (nonatomic, weak) id<BBZOutputSourceProtocol> secondInputSource;
//@property (nonatomic, weak) id<BBZOutputSourceProtocol> thirdInputSource;
//@property (nonatomic, weak) id<BBZOutputSourceProtocol> fourthInputSource;

- (void)processAVSourceAtTime:(CMTime)time;

@end

