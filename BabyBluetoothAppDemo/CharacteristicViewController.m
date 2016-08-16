//
//  CharacteristicViewController.m
//  BabyBluetoothAppDemo
//
//  Created by 刘彦玮 on 15/8/7.
//  Copyright (c) 2015年 刘彦玮. All rights reserved.
//

#import "CharacteristicViewController.h"
#import "SVProgressHUD.h"

//定义指令,专门有一个类用结构体定义好这些指令
// 其实这里有个坑，当单个数据的大小为2字节或以上时，我们用UInt16或UInt32去定义，会有「自动对齐」的问题，就是接到的数据，没有按指令定义的顺序对齐，导致数据不正确，这时候可以在struct后面加关键字：「__attribute__((packed))」。(我掉这个坑好久，最后上StackOverflow提问解决)
typedef struct {
    UInt8 starBit;
    UInt8 cmd;
    UInt8 colourR;//取值范围；0-255
    UInt8 colourG;
    UInt8 colourB;
    UInt8 brightnessValue;//取值范围：0-255，0为灭，255为最亮
    UInt8 reserved;
    UInt8 chechsum;

} D2MDeviceParamRespose;;



@interface CharacteristicViewController (){

}

@property (nonatomic,strong)NSMutableData *pData;


@end

#define width [UIScreen mainScreen].bounds.size.width
#define height [UIScreen mainScreen].bounds.size.height
#define isIOS7  ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
#define navHeight ( isIOS7 ? 64 : 44)  //导航栏高度
#define channelOnCharacteristicView @"CharacteristicView"


@implementation CharacteristicViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createUI];
    //初始化数据
    sect = [NSMutableArray arrayWithObjects:@"read value",@"write value",@"desc",@"properties", nil];
    readValueArray = [[NSMutableArray alloc]init];
    descriptors = [[NSMutableArray alloc]init];
    //配置ble委托
    [self babyDelegate];
    //读取服务
    baby.channel(channelOnCharacteristicView).characteristicDetails(self.currPeripheral,self.characteristic);
   
}


-(void)createUI{
    //headerView
    UIView *headerView = [[UIView alloc]initWithFrame:CGRectMake(0, navHeight, width, 100)];
    [headerView setBackgroundColor:[UIColor darkGrayColor]];
    [self.view addSubview:headerView];
    
    NSArray *array = [NSArray arrayWithObjects:self.currPeripheral.name,[NSString stringWithFormat:@"%@", self.characteristic.UUID],self.characteristic.UUID.UUIDString, nil];

    for (int i=0;i<array.count;i++) {
        UILabel *lab = [[UILabel alloc]initWithFrame:CGRectMake(0, 30*i, width, 30)];
        [lab setText:array[i]];
        [lab setBackgroundColor:[UIColor whiteColor]];
        [lab setFont:[UIFont fontWithName:@"Helvetica" size:18]];
        [headerView addSubview:lab];
    }

    //tableView
    self.tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, array.count*30+navHeight, width, height-navHeight-array.count*30)];
    [self.view addSubview:self.tableView];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
}

-(void)babyDelegate{

    __weak typeof(self)weakSelf = self;
    //设置读取characteristics的委托
    [baby setBlockOnReadValueForCharacteristicAtChannel:channelOnCharacteristicView block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
//        NSLog(@"CharacteristicViewController===characteristic name:%@ value is:%@",characteristics.UUID,characteristics.value);
        NSLog(@"设置读取characteristics的委托 value:%@",characteristics.value);
        if (characteristics.value && characteristics.value.length > 3 ) {
            [weakSelf reseiveImageData:characteristics.value];
        }
        
        [weakSelf insertReadValues:characteristics];
    }];
    //设置发现characteristics的descriptors的委托
    [baby setBlockOnDiscoverDescriptorsForCharacteristicAtChannel:channelOnCharacteristicView block:^(CBPeripheral *peripheral, CBCharacteristic *characteristic, NSError *error) {
//        NSLog(@"CharacteristicViewController===characteristic name:%@",characteristic.service.UUID);
        for (CBDescriptor *d in characteristic.descriptors) {
//            NSLog(@"CharacteristicViewController CBDescriptor name is :%@",d.UUID);
            [weakSelf insertDescriptor:d];
        }
    }];
    //设置读取Descriptor的委托
    [baby setBlockOnReadValueForDescriptorsAtChannel:channelOnCharacteristicView block:^(CBPeripheral *peripheral, CBDescriptor *descriptor, NSError *error) {
        for (int i =0 ; i<descriptors.count; i++) {
            if (descriptors[i]==descriptor) {
                UITableViewCell *cell = [weakSelf.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:2]];
//                NSString *valueStr = [[NSString alloc]initWithData:descriptor.value encoding:NSUTF8StringEncoding];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",descriptor.value];
            }
        }
        NSLog(@"CharacteristicViewController Descriptor name:%@ value is:%@",descriptor.characteristic.UUID, descriptor.value);
    }];
    
    //设置写数据成功的block
    //__weak typeof(self) weakself = self;
    [baby setBlockOnDidWriteValueForCharacteristicAtChannel:channelOnCharacteristicView block:^(CBCharacteristic *characteristic, NSError *error) {
         //NSLog(@"setBlockOnDidWriteValueForCharacteristicAtChannel characteristic:%@ and new value:%@",characteristic.UUID, characteristic.value);
        //[weakself.currPeripheral readValueForCharacteristic:weakself.characteristic];
    }];
    
    //设置通知状态改变的block
    [baby setBlockOnDidUpdateNotificationStateForCharacteristicAtChannel:channelOnCharacteristicView block:^(CBCharacteristic *characteristic, NSError *error) {
        NSLog(@"uid:%@,isNotifying:%@",characteristic.UUID,characteristic.isNotifying?@"on":@"off");
    }];
    
    //读取RSSI的委托
    //- (void)setBlockOnDidReadRSSIAtChannel
    [baby setBlockOnDidReadRSSIAtChannel:channelOnCharacteristicView block:^(NSNumber *RSSI, NSError *error) {
        int rssi = abs([RSSI intValue]);
        CGFloat ci = (rssi - 49) / (10 * 4.);
        NSLog(@"%@",[NSString stringWithFormat:@"发现BLT4.0热点:%@,距离:%.1fm",channelOnCharacteristicView,pow(10,ci)]);
        
    }];
    
    
    
}

//插入描述
-(void)insertDescriptor:(CBDescriptor *)descriptor{
    [self->descriptors addObject:descriptor];
    NSMutableArray *indexPahts = [[NSMutableArray alloc]init];
    NSIndexPath *indexPaht = [NSIndexPath indexPathForRow:self->descriptors.count-1 inSection:2];
    [indexPahts addObject:indexPaht];
    [self.tableView insertRowsAtIndexPaths:indexPahts withRowAnimation:UITableViewRowAnimationAutomatic];
}
//插入读取的值
-(void)insertReadValues:(CBCharacteristic *)characteristics{
    [self->readValueArray addObject:[NSString stringWithFormat:@"%@",characteristics.value]];
    NSMutableArray *indexPaths = [[NSMutableArray alloc]init];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self->readValueArray.count-1 inSection:0];
    NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:self->readValueArray.count-1 inSection:0];
    [indexPaths addObject:indexPath];
    [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.tableView scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

//写一个值
-(void)writeValue{
//    int i = 1;
//    Byte b = 0X01;
//    NSData *data = [NSData dataWithBytes:&b length:sizeof(b)];
    
    
    // 打印机支持的文字编码
//    NSMutableArray *goodsArray = [NSMutableArray array];
//    
//    // 用到的goodsArray跟github中的商品数组是一样的。
//    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
//    
//    NSString *title = @"测试电商";
//    NSString *str1 = @"测试电商服务中心(销售单)";
//    NSString *line = @"- - - - - - - - - - - - - - - -";
//    NSString *time = @"时间:2016-04-27 10:01:50";
//    NSString *orderNum = @"订单编号:4000020160427100150";
//    NSString *address = @"地址:深圳市南山区学府路东科技园店";
//    
//    //初始化打印机
//    Byte initBytes[] = {0x1B,0x40};
//    NSData *initData = [NSData dataWithBytes:initBytes length:sizeof(initBytes)];
//    
//    //换行
//    Byte nextRowBytes[] = {0x0A};
//    NSData *nextRowData = [NSData dataWithBytes:nextRowBytes length:sizeof(nextRowBytes)];
//    
//    //居中
//    Byte centerBytes[] = {0x1B,0x61,1};
//    NSData *centerData= [NSData dataWithBytes:centerBytes length:sizeof(centerBytes)];
//    
//    //居左
//    Byte leftBytes[] = {0x1B,0x61,0};
//    NSData *leftdata= [NSData dataWithBytes:leftBytes length:sizeof(leftBytes)];
//    
//    NSMutableData *mainData = [[NSMutableData alloc]init];
//    
//    //初始化打印机
//    [mainData appendData:initData];
//    //设置文字居中/居左
//    [mainData appendData:centerData];
//    [mainData appendData:[title dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    [mainData appendData:[str1 dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    
//    //            UIImage *qrImage =[MMQRCode createBarImageWithOrderStr:@"RN3456789012"];
////                UIImage *qrImage =[MMQRCode qrCodeWithString:@"http://www.sina.com" logoName:nil size:400];
////                qrImage = [self scaleCurrentImage:qrImage];
////    
////                NSData *data = [IGThermalSupport imageToThermalData:qrImage];
////                [mainData appendData:centerData];
////                [mainData appendData:data];
////                [mainData appendData:nextRowData];
//    
//    [mainData appendData:leftdata];
//    [mainData appendData:[line dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    [mainData appendData:[time dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    [mainData appendData:[orderNum dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    [mainData appendData:[address dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    
//    [mainData appendData:[line dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    NSString *name = @"商品";
//    NSString *number = @"数量";
//    NSString *price = @"单价";
//    [mainData appendData:leftdata];
//    [mainData appendData:[name dataUsingEncoding:enc]];
//    
//    Byte spaceBytes1[] = {0x1B, 0x24, 150 % 256, 0};
//    NSData *spaceData1 = [NSData dataWithBytes:spaceBytes1 length:sizeof(spaceBytes1)];
//    [mainData appendData:spaceData1];
//    [mainData appendData:[number dataUsingEncoding:enc]];
//    
//    Byte spaceBytes2[] = {0x1B, 0x24, 300 % 256, 1};
//    NSData *spaceData2 = [NSData dataWithBytes:spaceBytes2 length:sizeof(spaceBytes2)];
//    [mainData appendData:spaceData2];
//    [mainData appendData:[price dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    
//    CGFloat total = 0.0;
//    for (NSDictionary *dict in goodsArray) {
//        [mainData appendData:[dict[@"name"] dataUsingEncoding:enc]];
//        
//        Byte spaceBytes1[] = {0x1B, 0x24, 150 % 256, 0};
//        NSData *spaceData1 = [NSData dataWithBytes:spaceBytes1 length:sizeof(spaceBytes1)];
//        [mainData appendData:spaceData1];
//        [mainData appendData:[dict[@"amount"] dataUsingEncoding:enc]];
//        
//        Byte spaceBytes2[] = {0x1B, 0x24, 300 % 256, 1};
//        NSData *spaceData2 = [NSData dataWithBytes:spaceBytes2 length:sizeof(spaceBytes2)];
//        [mainData appendData:spaceData2];
//        [mainData appendData:[dict[@"price"] dataUsingEncoding:enc]];
//        [mainData appendData:nextRowData];
//        
//        total += [dict[@"price"] floatValue] * [dict[@"amount"] intValue];
//    }
//    
//    [mainData appendData:[line dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    [mainData appendData:[@"总计:" dataUsingEncoding:enc]];
//    Byte spaceBytes[] = {0x1B, 0x24, 300 % 256, 1};
//    NSData *spaceData = [NSData dataWithBytes:spaceBytes length:sizeof(spaceBytes)];
//    [mainData appendData:spaceData];
//    NSString *totalStr = [NSString stringWithFormat:@"%.2f",total];
//    [mainData appendData:[totalStr dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    
//    [mainData appendData:[line dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];
//    [mainData appendData:centerData];
//    [mainData appendData:[@"谢谢惠顾，欢迎下次光临!" dataUsingEncoding:enc]];
//    [mainData appendData:nextRowData];

    //数据太大写不过去
    UIImage *testImage = [UIImage imageNamed:@"icon_front_page@3x"];
//    UIImage *testImage = [UIImage imageNamed:@"pg-1@2x"];
    NSData *mainData = UIImagePNGRepresentation(testImage);
    int BLE_SEND_MAX_LEN = 400;
    
    for (int i = 0 ; i < [mainData length]; i += BLE_SEND_MAX_LEN) {
        //预加 最大包的长度，如果依然小于总数据长度，可以取最大包数据大小
        if ((i + BLE_SEND_MAX_LEN) < [mainData length]) {
            NSString *rangStr = [NSString stringWithFormat:@"%i,%i",i,BLE_SEND_MAX_LEN];
            NSData *subData = [mainData subdataWithRange:NSRangeFromString(rangStr)];
            NSMutableData *lData = [[NSMutableData alloc] init];
            if (i == 0) {
                Byte pakgeBytes[] = {0x01, 0x01, 0x01};
                NSData *spaceData = [NSData dataWithBytes:pakgeBytes length:sizeof(pakgeBytes)];
                [lData appendData:spaceData];
                [lData appendData:subData];
                
            }else{
                Byte pakgeBytes[] = {0x02, 0x02, 0x02};
                NSData *spaceData = [NSData dataWithBytes:pakgeBytes length:sizeof(pakgeBytes)];
                [lData appendData:spaceData];
                [lData appendData:subData];
            }
            
            NSLog(@"%@",lData);
            [self.currPeripheral writeValue:lData forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
            //向外设读数据
            [self.currPeripheral readValueForCharacteristic:self.characteristic];
            //根据接收模块的处理能力做相应的延时
            usleep(20 * 100);
        }else{
            NSString *rangStr = [NSString stringWithFormat:@"%i,%i",i, (int)([mainData length] - i)];
            NSData *subData = [mainData subdataWithRange:NSRangeFromString(rangStr)];
            NSMutableData *lData = [[NSMutableData alloc] init];
            Byte pakgeBytes[] = {0x03, 0x03, 0x03};
            NSData *spaceData = [NSData dataWithBytes:pakgeBytes length:sizeof(pakgeBytes)];
            [lData appendData:spaceData];
            [lData appendData:subData];
            NSLog(@"%@",lData);
            [self.currPeripheral writeValue:lData forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
            //向外设读数据
            [self.currPeripheral readValueForCharacteristic:self.characteristic];
            //根据接收模块的处理能力做相应的延时
            usleep(20 * 100);
        }
            
    }
    
    //生成0-9随机数
//    int x = arc4random()% 10;
//    Byte spaceBytes[] = {x};
//    NSData *mainData = [NSData dataWithBytes:spaceBytes length:sizeof(spaceBytes)];
    
//    [self.currPeripheral writeValue:mainData forCharacteristic:self.characteristic type:CBCharacteristicWriteWithResponse];
//    //在第二个请求为发送之前，读到的数据是同一个数据
//    
//    [self.currPeripheral readValueForCharacteristic:self.characteristic];//请求回应
    

    
}


//订阅一个值
-(void)setNotifiy:(id)sender{
    
    __weak typeof(self)weakSelf = self;
    UIButton *btn = sender;
    if(self.currPeripheral.state != CBPeripheralStateConnected) {
        [SVProgressHUD showErrorWithStatus:@"peripheral已经断开连接，请重新连接"];
        return;
    }
    if (self.characteristic.properties & CBCharacteristicPropertyNotify ||  self.characteristic.properties & CBCharacteristicPropertyIndicate) {
        
        if(self.characteristic.isNotifying) {
            [baby cancelNotify:self.currPeripheral characteristic:self.characteristic];
            [btn setTitle:@"通知" forState:UIControlStateNormal];
        }else{
            [weakSelf.currPeripheral setNotifyValue:YES forCharacteristic:self.characteristic];
            [btn setTitle:@"取消通知" forState:UIControlStateNormal];
            [baby notify:self.currPeripheral
          characteristic:self.characteristic
                   block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
                NSLog(@"notify block");
                NSLog(@"new value %@",characteristics.value);
                [self insertReadValues:characteristics];
            }];
        }
    }
    else{
        [SVProgressHUD showErrorWithStatus:@"这个characteristic没有nofity的权限"];
        return;
    }
    
}

#pragma mark -Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    
    return sect.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    switch (section) {
        case 0:
            //read value
            return readValueArray.count;
            break;
        case 1:
            //write value
            return 1;
            break;
        case 2:
            //desc
            return descriptors.count;
            break;
        case 3:
            //properties
            return 1;
            break;
        default:
            return 0 ;break;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
   
    NSString *cellIdentifier = @"characteristicDetailsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    switch (indexPath.section) {
        case 0:
            //read value
        {
            cell.textLabel.text = [readValueArray objectAtIndex:indexPath.row];
            NSDateFormatter *formatter = [[NSDateFormatter alloc]init];
            [formatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
            cell.detailTextLabel.text = [formatter stringFromDate:[NSDate date]];
//            cell.textLabel.text = [readValueArray valueForKey:@"value"];
//            cell.detailTextLabel.text = [readValueArray valueForKey:@"stamp"];
        }
            break;
        case 1:
            //write value
        {
            cell.textLabel.text = @"write a new value";
            
        }
            break;
        case 2:
        //desc
        {
            CBDescriptor *descriptor = [descriptors objectAtIndex:indexPath.row];
            cell.textLabel.text = [NSString stringWithFormat:@"%@",descriptor.UUID];

        }
            break;
        case 3:
            //properties
        {
//            CBCharacteristicPropertyBroadcast												= 0x01,
//            CBCharacteristicPropertyRead													= 0x02,
//            CBCharacteristicPropertyWriteWithoutResponse									= 0x04,
//            CBCharacteristicPropertyWrite													= 0x08,
//            CBCharacteristicPropertyNotify													= 0x10,
//            CBCharacteristicPropertyIndicate												= 0x20,
//            CBCharacteristicPropertyAuthenticatedSignedWrites								= 0x40,
//            CBCharacteristicPropertyExtendedProperties										= 0x80,
//            CBCharacteristicPropertyNotifyEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)		= 0x100,
//            CBCharacteristicPropertyIndicateEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)	= 0x200
            
            CBCharacteristicProperties p = self.characteristic.properties;
            cell.textLabel.text = @"";
            
            if (p & CBCharacteristicPropertyBroadcast) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | Broadcast"];
            }
            if (p & CBCharacteristicPropertyRead) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | Read"];
            }
            if (p & CBCharacteristicPropertyWriteWithoutResponse) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | WriteWithoutResponse"];
            }
            if (p & CBCharacteristicPropertyWrite) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | Write"];
            }
            if (p & CBCharacteristicPropertyNotify) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | Notify"];
            }
            if (p & CBCharacteristicPropertyIndicate) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | Indicate"];
            }
            if (p & CBCharacteristicPropertyAuthenticatedSignedWrites) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | AuthenticatedSignedWrites"];
            }
            if (p & CBCharacteristicPropertyExtendedProperties) {
                cell.textLabel.text = [cell.textLabel.text stringByAppendingString:@" | ExtendedProperties"];
            }
            
        }
            default:
            break;
    }

    
    return cell;
}


-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section{
    switch (section) {
        case 1:
            //write value
        {
            UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, width, 30)];
            [view setBackgroundColor:[UIColor darkGrayColor]];
            
            UILabel *title = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 100, 30)];
            title.text = [sect objectAtIndex:section];
            [title setTextColor:[UIColor whiteColor]];
            [view addSubview:title];
            UIButton *setNotifiyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            [setNotifiyBtn setFrame:CGRectMake(100, 0, 100, 30)];
            [setNotifiyBtn setTitle:self.characteristic.isNotifying?@"取消通知":@"通知" forState:UIControlStateNormal];
            [setNotifiyBtn setBackgroundColor:[UIColor darkGrayColor]];
            [setNotifiyBtn addTarget:self action:@selector(setNotifiy:) forControlEvents:UIControlEventTouchUpInside];
            //恢复状态
            if(self.characteristic.isNotifying) {
                [baby notify:self.currPeripheral characteristic:self.characteristic block:^(CBPeripheral *peripheral, CBCharacteristic *characteristics, NSError *error) {
                    NSLog(@"resume notify block");
                    [self insertReadValues:characteristics];
                }];
            }
            
            [view addSubview:setNotifiyBtn];
            UIButton *writeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            [writeBtn setFrame:CGRectMake(200, 0, 100, 30)];
            [writeBtn setTitle:@"写(0x01)" forState:UIControlStateNormal];
            [writeBtn setBackgroundColor:[UIColor darkGrayColor]];
            [writeBtn addTarget:self action:@selector(writeValue) forControlEvents:UIControlEventTouchUpInside];
            [view addSubview:writeBtn];
            return view;
        }
            break;
        default:
        {
            UILabel *title = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 100, 50)];
            title.text = [sect objectAtIndex:section];
            [title setTextColor:[UIColor whiteColor]];
            [title setBackgroundColor:[UIColor darkGrayColor]];
            return title;
        }
    }
    return  nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 30.0f;
}


-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)reseiveImageData:(NSData *)data
{
    //前面包长度
    int page = 3;
    //1、1截取前面3个字节进行判断，是开始还是中间
    NSString *rangStr = [NSString stringWithFormat:@"%i,%i",0,page];
    NSString *mrangStr = [NSString stringWithFormat:@"%i,%i",page,(int)([data length] - page)];
    NSData *sData = [data subdataWithRange:NSRangeFromString(rangStr)];
    NSData *mData = [data subdataWithRange:NSRangeFromString(mrangStr)];
    Byte *sByte = (Byte *)[sData bytes];
    int a = sByte[0];
    int b = sByte[1];
    int c = sByte[2];
    if (a == b && b == c) {
        switch (b) {
            case 1:
            {
                //1、如果是第一个数据，将之前的数据清除
                self.pData  = [[NSMutableData alloc] init];
                [self.pData appendData:mData];
            }
                break;
            case 2:
            {
                //2、如果是中间的数据，直接添加
                [self.pData appendData:mData];
                
            }
                break;
            case 3:
            {
                //3、如果是最后的数据，添加后显示图片
                if (self.pData) {
                    [self.pData appendData:mData];
                    [self setADView:self.pData];
                }
            }
                break;
                
            default:
                NSLog(@"other");
                break;
        }
        
    }else
    {
        NSLog(@"异常数据");
    }
  
}


//发过去的图片发过来看下
#pragma mark privad  私有方法
- (void)setADView:(NSData *) data
{
    //设置启动页面
    NSLog(@"%@",data);
    UIView *adView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    //UIImageView *adBottomImg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"adBottom.png" ]];
    //
    UIImageView *adBottomImg = [[UIImageView alloc] initWithImage:[[UIImage alloc] initWithData:data]];
    
    [adView addSubview:adBottomImg];

    adBottomImg.frame = self.view.bounds ;

    adView.alpha = 0.99f;
    [self.view addSubview:adView];
    [UIView animateWithDuration:3 animations:^{
        adView.alpha =1.0f;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.5 animations:^{
            adView.alpha = 0.0f;
        }completion:^(BOOL finished) {
            [adView removeFromSuperview];
        }];
    }];
}
@end
