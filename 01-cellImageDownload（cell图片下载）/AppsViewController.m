//
//  AppsViewController.m
//  01-cellImageDownload（cell图片下载）
//
//  Created by  a on 16/3/29.
//  Copyright © 2016年 eva. All rights reserved.
//

/** 图片只下载一次的具体思路
 1. 每个cell的图片都有一个对应的url (保存在plist文件中)
 2. 检查该url的下载操作是否存在 : if(op == nil) 如果不存在/从未下载过 -> 将该操作放入一个blockOperation中 添加进队列 异步执行
 3. 将已经发生过的下载操作包装成value 保存到字典当中
 4. 当tableView再次滚动的时候 再次进入该方法 遇到  NSBlockOperation *op = self.operations[app.icon]; 语句。 此时可以从字典中取出对应操作 (op不为nil)
 不会再次创建新的下载操作
 * 一个url 对应一个 operation ---> 图片只下载一次达成
 */


#import "AppsViewController.h"
#import "AppModel.h"

@interface AppsViewController ()
/**
 *  可变数组，存放所有的应用的数据
 */
@property (nonatomic, strong) NSMutableArray *apps;
/**
 *  存放所有的下载图片操作的队列 (避免重复创建队列)
 */
@property (nonatomic, strong) NSOperationQueue *queue;
/**
 *  使用字典来存放所有的下载操作 (one by one) url = Key operation = Value
 */
@property (nonatomic, strong) NSMutableDictionary *operations;
/**
 *  使用字典来存放所有的已下载的图片
 */
@property (nonatomic, strong) NSMutableDictionary *images;
@end

@implementation AppsViewController
// 懒加载

- (NSMutableDictionary *)images {
    if (!_images) {
        self.images = [[NSMutableDictionary alloc] init];
    }
    return _images;
}


- (NSMutableDictionary *)operations {
    if (!_operations) {
        self.operations = [[NSMutableDictionary alloc] init];
    }
    return _operations;
}


- (NSOperationQueue *)queue {
    if (!_queue) {
        self.queue = [[NSOperationQueue alloc] init];
    }
    return _queue;
}


- (NSMutableArray *)apps {
    if (!_apps) {
        // self.apps = [NSMutableArray array];
        NSMutableArray *arrayM = [NSMutableArray array];
        
        // 1. 加载plist文件
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"apps.plist" ofType:nil];
        NSArray *array = [NSArray arrayWithContentsOfFile:filePath];
        
        // 2. 字典转模型
        for (NSDictionary *dict in array) {
            AppModel *app = [AppModel appWithDict:dict];
            [arrayM addObject:app];
        }
        // 3. 赋值
        self.apps = arrayM;
    }
    return _apps;
}


- (void)viewDidLoad {
    [super viewDidLoad];
}

// 图片下载太多，会触发内存警告
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    // 取消所有队列中的操作
    [self.queue cancelAllOperations];
    // 移除所有下载/操作的缓存
    [self.images removeAllObjects];
    [self.operations removeAllObjects];
}

#pragma mark - Table view data source
// 多少组的已经删除  如果没书写相关代码默认为1组

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.apps.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // 缓存池三部曲……
    static NSString *ID = @"app";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ID];
    }
    
    // 取出模型
    AppModel *app = self.apps[indexPath.row];
    
    // 设置cell的标题/下载量 (两个自带的label)
    cell.textLabel.text = app.name;           // App名称
    cell.detailTextLabel.text = app.download; // App下载量
    
    // 先从images字典 混存中取出图片url对应的UIImage
    UIImage *image = self.images[app.icon];
    // 判断image的状态
    if (image) { // 来到这里说明图片已经下载成功 (成功缓存)
        cell.imageView.image = image;
        
        // 验证滚动tableView时 是否从缓存中取得图片
         NSLog(@"从缓存中取得图片——————%d",indexPath.row);
    }
    else { // 来到这里说明并未下载成功 (并未缓存)
        // 出于可重用cell的考虑，如果下拉滚动条时，需要正确显示的图片还未下载完毕，系统可能调用已在缓存池中的cell --> 会出现重复图片 并 与cell的label不匹配的情况
        
        // 解决方法，显示占位图片 (图片一旦下载好，就会覆盖掉站位图片)
        cell.imageView.image = [UIImage imageNamed:@"placeholder"];
        
        [self download:app.icon indexPath:indexPath];
    }
    return cell;
}

// 将下载图片的相关操作抽取出来，方法的设定上根据需要创建两个接口填入数据
- (void)download:(NSString *)imageUrl indexPath:(NSIndexPath *)indexPath {
    // 开始下载图片 (此时再执行判断下载图片的操作是否完成的代码)
    NSBlockOperation *op = self.operations[imageUrl];
    // 如果操作为空(此时的确为空) 为其赋值
    if (op) {
        return;
    }
    
    // 使用__weak 解决block 中关于循环引用的问题 (使用一个弱指针的控制器代替所有的self.xxx 操作)
    // __weak AppsViewController *appsVc = self;
    __weak typeof(self) appsVc = self; // 上一句的另一种写法 (更简洁，适用性更高 typeof(self) 可以自动判断当前self类型 )
    
    op = [NSBlockOperation blockOperationWithBlock:^{
        NSURL *url = [NSURL URLWithString:imageUrl]; // 从模型中取出url
        NSData *data = [NSData dataWithContentsOfURL:url]; // 转化为data
        UIImage *image = [UIImage imageWithData:data]; // (转化为image也是耗时操作，所以放在子线程)
        
        // 回到主线程进行显示
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // 直接设置cell图片会有隐患 因为可重用cell的关系,显示的可能不是需要的图片
            // 解决: 图片下载完毕后应该刷新那行对应的cell而不是之前内存地址对应的cell --> 刷新表格即可
            // cell.imageView.image = image; // 设置图片
            
            /**
            存放图片到images字典中
              self.images[app.icon] = image;
              如果图片为nil 即字典的value为nil ---> 报错
              解决方法: 再嵌套一个if判断语句
             */
            if (image) { // 只有image有值的时候才会将图片添加进字典
                appsVc.images[imageUrl] = image;
            }
            
            // 从字典中移除下载操作
            // 1. 为了防止下载失败时 程序运行到此处直接跳过
            // 2. 防止字典过大
            [appsVc.operations removeObjectForKey:imageUrl];
            
            // 刷新表格 使图片对应每一行的cell
            // [self.tableView reloadData]; // 直接reloadData太消耗性能
            [appsVc.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }];
    }];
    // 将操作添加进队列
    [self.queue addOperation:op];
    
    // 添加到字典中 --> 加入字典可以阻止重复下载
    self.operations[imageUrl] = op;
    // [self.operations setObject:op forKey:app.icon]; 等价与该行代码


}

#pragma mark - 用户体验相关
// 当用户准备开始拖拽表格的时候 暂停下载队列
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.queue setSuspended:YES];
}

// 当用户停止拖拽的的时候 恢复下载队列
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.queue setSuspended:NO];
}

- (void)downloadImagesForOnetime {
#pragma mark 下载并显示cell对应的图片
    // 需求：1.不可重复下载(每张图片仅下载1此)
    /**
     设置cell的图片 (使用NSBlockOperation)
     需要保证每张图片仅下载一次
     -> 解决：使用字典，使一个url对应一个operation
     */
    
    // 取出当前图片的url对应的下载操作 (operation 操作)
    // 代码运行到底部时，所有的图片的下载操作已经保存进了字典
    // 字典对应的key value 第一次加载时，这两个属性都不存在，加进字典后，这些对象都为存在
    // 当再次滚动tableView调用这个方法来到下面的代码的时候，会从字典中直接取出对应的值 ---> 不会重复下载
    
//    NSBlockOperation *op = self.operations[app.icon];
//    // 如果操作为空(此时的确为空) 为其赋值
//    if (op == nil) {
//        op = [NSBlockOperation blockOperationWithBlock:^{
//            NSURL *url = [NSURL URLWithString:app.icon]; // 从模型中取出url
//            NSData *data = [NSData dataWithContentsOfURL:url]; // 转化为data
//            UIImage *image = [UIImage imageWithData:data]; // (转化为image也是耗时操作，所以放在子线程)
//            
//            // 回到主线程进行显示
//            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//                cell.imageView.image = image; // 设置图片
//                
//                // 存放图片到images字典中
//                self.images[app.icon] = image;
//                
//                // 从字典中移除下载操作
//                // 1. 为了防止下载失败时 程序运行到此处直接跳过
//                // 2. 防止字典过大
//                [self.operations removeObjectForKey:app.icon];
//            }];
//        }];
//        
//        // 监听下载完毕
//        
//        // 将操作添加进队列
//        [self.queue addOperation:op];
//        
//        // 添加到字典中
//        self.operations[app.icon] = op;
//    }
//
}

#pragma mark - 不建议使用
/**
缺点：
  异步下载图片，cell会在图片下载完成前先行返回，再次滚动tableView的时候会刷新图片
  还是会重复刷新图片
 */
- (void)downloadImageWithBasicQueue {
//    // 设置cell的图片 (使用NSBlockOperation)
//    // 需要保证每张图片仅下载一次
//    // -> 解决：使用字典，使一个url对应一个operation
//    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
//        NSURL *url = [NSURL URLWithString:app.icon]; // 从模型中取出url
//        NSData *data = [NSData dataWithContentsOfURL:url]; // 转化为data
//        
//        // 回到主线程进行显示
//        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
//            cell.imageView.image = [UIImage imageWithData:data];
//        }];
//        
//    }];
//    
//    // 将操作添加进队列
//    [self.queue addOperation:op];
}

// 直接在主线程中调用模型的url数据并对cell的image进行赋值
- (void)basicDownloadImages {
//    // 设置cell的图片
//    /**
//     这样写的确可以从远程下载图片并将图片显示在cell上 但有缺陷
//     1. 下载的工作是在主线程中进行，会阻塞主线程进行工作  -> 影响用户体验 (卡)
//     2. 重复下载 (该方法在tableView滚动的时候就会调用)  -> 浪费流量/浪费时间/影响性能
//     */
//    NSURL *url = [NSURL URLWithString:app.icon]; // 从模型中取出url
//    NSData *data = [NSData dataWithContentsOfURL:url];
//    cell.imageView.image = [UIImage imageWithData:data];
}

@end
