//
//  AppModel.h
//  01-cellImageDownload（cell图片下载）
//
//  Created by  a on 16/3/29.
//  Copyright © 2016年 eva. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppModel : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *download;
/**
 *  应用图标的URL 
 */
@property (nonatomic, copy) NSString *icon;

+ (instancetype)appWithDict:(NSDictionary *)dict;
@end
