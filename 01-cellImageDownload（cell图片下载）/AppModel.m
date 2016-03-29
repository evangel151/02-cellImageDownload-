//
//  AppModel.m
//  01-cellImageDownload（cell图片下载）
//
//  Created by  a on 16/3/29.
//  Copyright © 2016年 eva. All rights reserved.
//

#import "AppModel.h"

@implementation AppModel

+ (instancetype)appWithDict:(NSDictionary *)dict {
    AppModel *app = [[self alloc] init];
    [app setValuesForKeysWithDictionary:dict];
    return app;
}

@end
