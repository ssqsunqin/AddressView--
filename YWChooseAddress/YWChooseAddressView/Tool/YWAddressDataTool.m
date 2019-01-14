//
//  YWAddressDataTool.m
//  YWChooseAddressView
//
//  Created by 90Candy on 17/12/25.
//  Copyright © 2017年 apple. All rights reserved.
//

#import "YWAddressDataTool.h"
#import "FMDB.h"
#import "YWAddressModel.h"

static NSString * const dbName = @"YWAddressDB.db";
static NSString * const locationTabbleName = @"addressTabble";

@interface YWAddressDataTool ()
@property (nonatomic,strong) NSMutableArray * dataArray;
@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, assign) BOOL isCreateTable;
@end

@implementation YWAddressDataTool

static YWAddressDataTool *shareInstance = nil;

// 懒加载数据库队列
- (FMDatabaseQueue *)queue {
    if (_queue == nil) {
        _queue = [FMDatabaseQueue databaseQueueWithPath:[self pathForName:dbName]];
    }
    return _queue;
}

#pragma mark - Singleton
+ (instancetype)sharedManager {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [[self alloc] init];
    });
    return shareInstance;
   
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shareInstance = [super allocWithZone:zone];
    });
    return shareInstance;
    
}

- (id)copy {
    return shareInstance;
}

//获得指定名字的文件的全路径
//- (NSString *)pathForName:(NSString *)name {
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentDirectory = [paths lastObject];
//    NSString *dbPath = [documentDirectory stringByAppendingPathComponent:name];
//    NSLog(@"数据库地址：\n%@", dbPath);
//    return dbPath;
//}

- (NSString *)pathForName:(NSString *)name{
    
    NSString *daPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:name];
    return daPath;
    
}
/**
  1.获取数据库地址
  2.创建表格
  3.数据的插入
  4.数据的查询
 */

//创建表
- (BOOL)createTable {
    
    __block  BOOL result = NO;
    
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *sql = [NSString stringWithFormat:@"create table if not exists %@ (code text primary key,sheng text,di text,xian text,name text,level text);",locationTabbleName];
        result = [db executeUpdate:sql];
        if (!result) {
            NSLog(@"创建地址表失败");
            
        } else {
            
            NSLog(@"创建地址表成功");
        }
    }];
    return result;
}

//发送网络请求，获取省市区数据，这里用的是本地json数据---
- (void)requestGetData {
    // 开启异步线程初始化数据
    __block BOOL isNext = NO;
    [self.queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        FMResultSet *rs = [db executeQuery:@"SELECT count(*) as 'count' FROM sqlite_master WHERE type = 'table' and name = ?",locationTabbleName];
        NSInteger count = [rs intForColumn:@"count"];

        while ([rs next]) {
            if (0 == count) {
                NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"Cities" ofType:@"json"];
                NSData *data=[NSData dataWithContentsOfFile:jsonPath];
                NSError *error;
                NSArray * jsonObjectArray =[NSJSONSerialization JSONObjectWithData:data
                                                                           options:kNilOptions
                                                                             error:&error];
                for (NSDictionary * dict in jsonObjectArray) {
                    YWAddressModel * item = [[YWAddressModel alloc] initWithDict:dict];
                    [self.dataArray addObject:item];
                }
                isNext = YES;
            } else {
                isNext = NO;
            }
        }
        
    }];
  
    if(self.dataArray.count > 0  && isNext && [self createTable]) {
      
        [self insertRecords];
    }
}

//往表插入数据
- (void)insertRecords {
    
    NSDate *startTime = [NSDate date];
    
    [self.queue inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        for (YWAddressModel *item in self.dataArray) {
            if (item.level.intValue == 3 && [item.name isEqualToString:@"市辖区"]) {
                continue;
            }
            NSString *insertSql= [NSString stringWithFormat:
                                  @"INSERT INTO %@ ('code','sheng','di','xian','name', 'level') VALUES ('%@','%@','%@','%@','%@','%@')",
                                  locationTabbleName,item.code, item.sheng,item.di,item.xian ,item.name, item.level];
            BOOL result = [db executeUpdate:insertSql];
            if (!result) {
                NSLog(@"插入地址信息数据失败");
                *rollback = YES;
                return ;
            }else{
                NSLog(@"pp批量s插入地址数据成功");
            }
        }
        NSDate *endTime = [NSDate date];
        NSTimeInterval a = [endTime timeIntervalSince1970] - [startTime timeIntervalSince1970];
        NSLog(@"使用事务批量插入地址信息用时%.3f秒",a);
    }];
    
    
    
//    [self.queue inDatabase:^(FMDatabase * _Nonnull db) {
//        for (YWAddressModel *item in self.dataArray) {
//            if (item.level.intValue == 3 && [item.name isEqualToString:@"市辖区"]) {
//                continue;
//            }
//            NSString *insertSql= [NSString stringWithFormat:
//                                  @"INSERT INTO %@ ('code','sheng','di','xian','name', 'level') VALUES ('%@','%@','%@','%@','%@','%@')",
//                                  locationTabbleName,item.code, item.sheng,item.di,item.xian ,item.name, item.level];
//            BOOL result = [db executeUpdate:insertSql];
//            if (!result) {
//                NSLog(@"插入地址信息数据失败");
//            }else{
//                NSLog(@"pp批量s插入地址数据成功");
//            }
//        }
//        NSDate *endTime = [NSDate date];
//        NSTimeInterval a = [endTime timeIntervalSince1970] - [startTime timeIntervalSince1970];
//        NSLog(@"使用事务批量插入地址信息用时%.3f秒",a);
//
//    }];
    
}


// 删除表
- (BOOL)deleteTable {
    
    __block BOOL isDele = YES;
    [self.queue inDatabase:^(FMDatabase *db) {
        NSString *sqlstr = [NSString stringWithFormat:@"DROP TABLE %@", locationTabbleName];

        if (![db executeUpdate:sqlstr])
        {
            [db close];
            isDele = NO;
        }
    }];

    return isDele;
}

//根据areaLevel 查询
- (NSMutableArray *)queryAllProvince {
    __block NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];;
    
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE `level` = 1", locationTabbleName];
        FMResultSet *result = [db  executeQuery:sql];
        //'code','sheng','di','xian','name', 'level'
        while ([result next]) {
            YWAddressModel *model = [[YWAddressModel alloc] init];
            model.code = [result stringForColumn:@"code"];
            model.sheng = [result stringForColumn:@"sheng"];
            model.di = [result stringForColumn:@"di"];
            model.xian = [result stringForColumn:@"xian"];
            model.name = [result stringForColumn:@"name"];
            model.level = [result stringForColumn:@"level"];
            [array addObject:model];
        }
        //        [result close];
    }];
    return array;
    
}

//根据areaCode, 查询地址
- (NSString *)queryAllRecordWithAreaCode:(NSString *)areaCode {
    
    __block YWAddressModel * models = [[YWAddressModel alloc] init];;
    
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE  `code` = %@"  , locationTabbleName,areaCode];
        FMResultSet *result = [db  executeQuery:sql];
        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];
        //'code','sheng','di','xian','name', 'level'
        while ([result next]) {
            YWAddressModel *model = [[YWAddressModel alloc] init];
            model.code = [result stringForColumn:@"code"];
            model.sheng = [result stringForColumn:@"sheng"];
            model.di = [result stringForColumn:@"di"];
            model.xian = [result stringForColumn:@"xian"];
            model.name = [result stringForColumn:@"name"];
            model.level = [result stringForColumn:@"level"];
            [array addObject:model];
        }
        [db close];
        if (array.count > 0) {
            YWAddressModel * model = array.firstObject;
            models = model;
        }
    }];
    return models.name;
}

//根据areaLevel级别，省ID 查询 市
- (NSMutableArray *)queryAllRecordWithSheng:(NSString *)sheng {
    __block NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];;
    
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE `level` = 2 AND  `sheng` = %@"  , locationTabbleName,sheng];
        FMResultSet *result = [db  executeQuery:sql];
        //        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];
        //'code','sheng','di','xian','name', 'level'
        while ([result next]) {
            YWAddressModel *model = [[YWAddressModel alloc] init];
            model.code = [result stringForColumn:@"code"];
            model.sheng = [result stringForColumn:@"sheng"];
            model.di = [result stringForColumn:@"di"];
            model.xian = [result stringForColumn:@"xian"];
            model.name = [result stringForColumn:@"name"];
            model.level = [result stringForColumn:@"level"];
            [array addObject:model];
        }
        //        [db close];
        //        shengBlock(array);
    }];
    return array;
}

//根据areaLevel级别,省ID(sheng)  ,查询 市
- (NSMutableArray *)queryAllRecordWithShengID:(NSString *)sheng {
    __block NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE `level` = 2 AND  `sheng` = %@ "  , locationTabbleName,sheng];
        FMResultSet *result = [db  executeQuery:sql];
        //        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];
        while ([result next]) {
            YWAddressModel *model = [[YWAddressModel alloc] init];
            model.code = [result stringForColumn:@"code"];
            model.sheng = [result stringForColumn:@"sheng"];
            model.di = [result stringForColumn:@"di"];
            model.xian = [result stringForColumn:@"xian"];
            model.name = [result stringForColumn:@"name"];
            model.level = [result stringForColumn:@"level"];
            [array addObject:model];
        }
        //        [db close];
        //        shengBlock(array);
    }];
    return array;
}


//根据areaLevel级别,省ID(sheng) , 市ID(di) ,查询 县
- (NSMutableArray *)queryAllRecordWithShengID:(NSString *)sheng cityID:(NSString *)di {
    __block NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];;
    [_queue inDatabase:^(FMDatabase * _Nonnull db) {
        
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE `level` = 3 AND  `sheng` = %@  AND `di` = '%@'"  , locationTabbleName,sheng,di];
        FMResultSet *result = [db  executeQuery:sql];
        //        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:0];
        while ([result next]) {
            YWAddressModel *model = [[YWAddressModel alloc] init];
            model.code = [result stringForColumn:@"code"];
            model.sheng = [result stringForColumn:@"sheng"];
            model.di = [result stringForColumn:@"di"];
            model.xian = [result stringForColumn:@"xian"];
            model.name = [result stringForColumn:@"name"];
            model.level = [result stringForColumn:@"level"];
            [array addObject:model];
        }
    }];
    return array;
}

- (NSMutableArray *)dataArray {
    
    if (!_dataArray) {
        _dataArray = [[NSMutableArray alloc]init];
    }
    return _dataArray;
}

@end
