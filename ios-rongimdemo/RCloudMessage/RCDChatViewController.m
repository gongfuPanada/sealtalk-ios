//
//  RCDChatViewController.m
//  RCloudMessage
//
//  Created by Liv on 15/3/13.
//  Copyright (c) 2015年 RongCloud. All rights reserved.
//

#import "RCDAddFriendViewController.h"
#import "RCDChatViewController.h"
#import "RCDChatViewController.h"
#import "RCDContactSelectedTableViewController.h"
#import "RCDDiscussGroupSettingViewController.h"
#import "RCDGroupSettingsTableViewController.h"
#import "RCDHttpTool.h"
#import "RCDPersonDetailViewController.h"
#import "RCDPrivateSettingViewController.h"
#import "RCDPrivateSettingsTableViewController.h"
#import "RCDRCIMDataSource.h"
#import "RCDRoomSettingViewController.h"
#import "RCDTestMessage.h"
#import "RCDTestMessageCell.h"
#import "RCDUIBarButtonItem.h"
#import "RCDUserInfoManager.h"
#import "RCDUtilities.h"
#import "RCDataBaseManager.h"
#import "RCDataBaseManager.h"
#import "RealTimeLocationEndCell.h"
#import "RealTimeLocationStartCell.h"
#import "RealTimeLocationStatusView.h"
#import "RealTimeLocationViewController.h"
#import <RongIMKit/RongIMKit.h>
#import "RCDCustomerEmoticonTab.h"
#import "RCDReceiptDetailsTableViewController.h"

@interface RCDChatViewController () <
    UIActionSheetDelegate, RCRealTimeLocationObserver,
    RealTimeLocationStatusViewDelegate, UIAlertViewDelegate,
    RCMessageCellDelegate>
@property(nonatomic, weak) id<RCRealTimeLocationProxy> realTimeLocation;
@property(nonatomic, strong)
    RealTimeLocationStatusView *realTimeLocationStatusView;
@property(nonatomic, strong) RCDGroupInfo *groupInfo;

-(UIView *)loadEmoticonView:(NSString *)identify index:(int)index;
@end

NSMutableDictionary *userInputStatus;

@implementation RCDChatViewController
- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
    NSString *userInputStatusKey = [NSString stringWithFormat:@"%lu--%@",(unsigned long)self.conversationType,self.targetId];
    if (userInputStatus && [userInputStatus.allKeys containsObject:userInputStatusKey]) {
        KBottomBarStatus inputType = (KBottomBarStatus)[userInputStatus[userInputStatusKey] integerValue];
        //输入框记忆功能，如果退出时是语音输入，再次进入默认语音输入
        if (inputType == KBottomBarRecordStatus) {
            self.defaultInputType = RCChatSessionInputBarInputVoice;
        }else if (inputType == KBottomBarPluginStatus){
            //      self.defaultInputType = RCChatSessionInputBarInputExtention;
        }
    }
  
  [self refreshTitle];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    KBottomBarStatus inputType = self.chatSessionInputBarControl.currentBottomBarStatus;
    if (!userInputStatus) {
        userInputStatus = [NSMutableDictionary new];
    }
    NSString *userInputStatusKey = [NSString stringWithFormat:@"%lu--%@",(unsigned long)self.conversationType,self.targetId];
    [userInputStatus setObject:[NSString stringWithFormat:@"%ld",(long)inputType]  forKey:userInputStatusKey];
}
- (void)viewDidLoad {
  [super viewDidLoad];
  self.enableSaveNewPhotoToLocalSystem = YES;
  [UIApplication sharedApplication].statusBarStyle =
      UIStatusBarStyleLightContent;

  if (self.conversationType != ConversationType_CHATROOM) {
    if (self.conversationType == ConversationType_DISCUSSION) {
      [[RCIMClient sharedRCIMClient] getDiscussion:self.targetId
          success:^(RCDiscussion *discussion) {
            if (discussion != nil && discussion.memberIdList.count > 0) {
              if ([discussion.memberIdList
                      containsObject:[RCIMClient sharedRCIMClient]
                                         .currentUserInfo.userId]) {
                [self setRightNavigationItem:[UIImage
                                                 imageNamed:@"Private_Setting"]
                                   withFrame:CGRectMake(15, 3.5, 16, 18.5)];
              } else {
                self.navigationItem.rightBarButtonItem = nil;
              }
            }
          }
          error:^(RCErrorCode status){

          }];
    } else if (self.conversationType == ConversationType_GROUP) {
      [self setRightNavigationItem:[UIImage imageNamed:@"Group_Setting"]
                         withFrame:CGRectMake(10, 3.5, 21, 19.5)];
    } else {
      [self setRightNavigationItem:[UIImage imageNamed:@"Private_Setting"]
                         withFrame:CGRectMake(15, 3.5, 16, 18.5)];
    }

  } else {
    self.navigationItem.rightBarButtonItem = nil;
  }

  /*******************实时地理位置共享***************/
  [self registerClass:[RealTimeLocationStartCell class]
      forMessageClass:[RCRealTimeLocationStartMessage class]];
  [self registerClass:[RealTimeLocationEndCell class]
      forMessageClass:[RCRealTimeLocationEndMessage class]];

  __weak typeof(&*self) weakSelf = self;
  [[RCRealTimeLocationManager sharedManager]
      getRealTimeLocationProxy:self.conversationType
      targetId:self.targetId
      success:^(id<RCRealTimeLocationProxy> realTimeLocation) {
        weakSelf.realTimeLocation = realTimeLocation;
        [weakSelf.realTimeLocation addRealTimeLocationObserver:self];
        [weakSelf updateRealTimeLocationStatus];
      }
      error:^(RCRealTimeLocationErrorCode status) {
        NSLog(@"get location share failure with code %d", (int)status);
      }];

  /******************实时地理位置共享**************/

  ///注册自定义测试消息Cell
  [self registerClass:[RCDTestMessageCell class]
      forMessageClass:[RCDTestMessage class]];

  [self notifyUpdateUnreadMessageCount];

  //加号区域增加发送文件功能，Kit中已经默认实现了该功能，但是为了SDK向后兼容性，目前SDK默认不开启该入口，可以参考以下代码在加号区域中增加发送文件功能。
  UIImage *imageFile = [RCKitUtility imageNamed:@"actionbar_file_icon"
                                       ofBundle:@"RongCloud.bundle"];

  
  [self.pluginBoardView insertItemWithImage:imageFile
                                      title:NSLocalizedStringFromTable(
                                                @"File", @"RongCloudKit", nil)
                                    atIndex:3
                                        tag:PLUGIN_BOARD_ITEM_FILE_TAG];

  //    self.chatSessionInputBarControl.hidden = YES;
  //    CGRect intputTextRect = self.conversationMessageCollectionView.frame;
  //    intputTextRect.size.height = intputTextRect.size.height+50;
  //    [self.conversationMessageCollectionView setFrame:intputTextRect];
  //    [self scrollToBottomAnimated:YES];
  /***********如何自定义面板功能***********************
   自定义面板功能首先要继承RCConversationViewController，如现在所在的这个文件。
   然后在viewDidLoad函数的super函数之后去编辑按钮：
   插入到指定位置的方法如下：
   [self.pluginBoardView insertItemWithImage:imagePic
                                       title:title
                                     atIndex:0
                                         tag:101];
   或添加到最后的：
   [self.pluginBoardView insertItemWithImage:imagePic
                                       title:title
                                         tag:101];
   删除指定位置的方法：
   [self.pluginBoardView removeItemAtIndex:0];
   删除指定标签的方法：
   [self.pluginBoardView removeItemWithTag:101];
   删除所有：
   [self.pluginBoardView removeAllItems];
   更换现有扩展项的图标和标题:
   [self.pluginBoardView updateItemAtIndex:0 image:newImage title:newTitle];
   或者根据tag来更换
   [self.pluginBoardView updateItemWithTag:101 image:newImage title:newTitle];
   以上所有的接口都在RCPluginBoardView.h可以查到。

   当编辑完扩展功能后，下一步就是要实现对扩展功能事件的处理，放开被注掉的函数
   pluginBoardView:clickedItemWithTag:
   在super之后加上自己的处理。

   */

  //默认输入类型为语音
  // self.defaultInputType = RCChatSessionInputBarInputExtention;

  /***********如何在会话界面插入提醒消息***********************

      RCInformationNotificationMessage *warningMsg =
     [RCInformationNotificationMessage
     notificationWithMessage:@"请不要轻易给陌生人汇钱！" extra:nil];
      BOOL saveToDB = NO;  //是否保存到数据库中
      RCMessage *savedMsg ;
      if (saveToDB) {
          savedMsg = [[RCIMClient sharedRCIMClient]
     insertOutgoingMessage:self.conversationType targetId:self.targetId
     sentStatus:SentStatus_SENT content:warningMsg];
      } else {
          savedMsg =[[RCMessage alloc] initWithType:self.conversationType
     targetId:self.targetId direction:MessageDirection_SEND messageId:-1
     content:warningMsg];//注意messageId要设置为－1
      }
      [self appendAndDisplayMessage:savedMsg];
  */
  //    self.enableContinuousReadUnreadVoice = YES;//开启语音连读功能

  //刷新个人或群组的信息
  [self refreshUserInfoOrGroupInfo];
  
  if (self.conversationType == ConversationType_GROUP) {
    //群组改名之后，更新当前页面的Title
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTitleForGroup:)
                                                 name:@"UpdeteGroupInfo"
                                               object:nil];

  }

  //清除历史消息
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(clearHistoryMSG:)
                                               name:@"ClearHistoryMsg"
                                             object:nil];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(updateForSharedMessageInsertSuccess:)
             name:@"RCDSharedMessageInsertSuccess"
           object:nil];

//  //表情面板添加自定义表情包
//  UIImage *icon = [RCKitUtility imageNamed:@"emoji_btn_normal"
//                                  ofBundle:@"RongCloud.bundle"];
//  RCDCustomerEmoticonTab *emoticonTab1 = [RCDCustomerEmoticonTab new];
//  emoticonTab1.identify = @"1";
//  emoticonTab1.image = icon;
//  emoticonTab1.pageCount = 2;
//  emoticonTab1.chartView = self;
//
//  [self.emojiBoardView addEmojiTab:emoticonTab1];
//
//  RCDCustomerEmoticonTab *emoticonTab2 = [RCDCustomerEmoticonTab new];
//  emoticonTab2.identify = @"2";
//  emoticonTab2.image = icon;
//  emoticonTab2.pageCount = 4;
//  emoticonTab2.chartView = self;
//
//  [self.emojiBoardView addEmojiTab:emoticonTab2];
}

/**
 *  返回的 view 大小必须等于 contentViewSize （宽度 = 屏幕宽度，高度 = 186）
 *
 *  @param identify 表情包标示
 *  @param index    index
 *
 *  @return view
 */
- (UIView *)loadEmoticonView:(NSString *)identify index:(int)index {
  UIView *view11 = [[UIView alloc]
      initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 186)];
  view11.backgroundColor = [UIColor blackColor];
  switch (index) {
  case 1:
    view11.backgroundColor = [UIColor yellowColor];
    break;
  case 2:
    view11.backgroundColor = [UIColor redColor];
    break;
  case 3:
    view11.backgroundColor = [UIColor greenColor];
    break;
  case 4:
    view11.backgroundColor = [UIColor grayColor];
    break;

  default:
    break;
  }
  return view11;
}

- (void)updateForSharedMessageInsertSuccess:(NSNotification *)notification {
  RCMessage *message = notification.object;
  if (message.conversationType == self.conversationType &&
      [message.targetId isEqualToString:self.targetId]) {
    [self appendAndDisplayMessage:message];
  }
}

- (void)setRightNavigationItem:(UIImage *)image withFrame:(CGRect)frame {
  RCDUIBarButtonItem *rightBtn = [[RCDUIBarButtonItem alloc]
      initContainImage:image
        imageViewFrame:frame
           buttonTitle:nil
            titleColor:nil
            titleFrame:CGRectZero
           buttonFrame:CGRectMake(0, 0, 25, 25)
                target:self
                action:@selector(rightBarButtonItemClicked:)];
  self.navigationItem.rightBarButtonItem = rightBtn;
}

- (void)updateTitleForGroup:(NSNotification *)notification {
  NSString *groupId = notification.object;
  if ([groupId isEqualToString:self.targetId]) {
    RCDGroupInfo *tempInfo = [[RCDataBaseManager shareInstance] getGroupByGroupId:self.targetId];
    
    int count = tempInfo.number.intValue;
    dispatch_async(dispatch_get_main_queue(), ^{
      self.title = [NSString stringWithFormat:@"%@(%d)",tempInfo.groupName,count];
    });
  }
}

- (void)clearHistoryMSG:(NSNotification *)notification {
  [self.conversationDataRepository removeAllObjects];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.conversationMessageCollectionView reloadData];
  });
}

- (void)leftBarButtonItemPressed:(id)sender {
  if ([self.realTimeLocation getStatus] ==
          RC_REAL_TIME_LOCATION_STATUS_OUTGOING ||
      [self.realTimeLocation getStatus] ==
          RC_REAL_TIME_LOCATION_STATUS_CONNECTED) {
    UIAlertView *alertView = [[UIAlertView alloc]
            initWithTitle:nil
                  message:
                      @"离开聊天，位置共享也会结束，确认离开"
                 delegate:self
        cancelButtonTitle:@"取消"
        otherButtonTitles:@"确定", nil];
    [alertView show];
  } else {
    [self popupChatViewController];
  }
}

- (void)popupChatViewController {
  [super leftBarButtonItemPressed:nil];
  [self.realTimeLocation removeRealTimeLocationObserver:self];
  if (_needPopToRootView == YES) {
    [self.navigationController popToRootViewControllerAnimated:YES];
  } else {
    [self.navigationController popViewControllerAnimated:YES];
  }
}

/**
 *  此处使用自定义设置，开发者可以根据需求自己实现
 *  不添加rightBarButtonItemClicked事件，则使用默认实现。
 */
- (void)rightBarButtonItemClicked:(id)sender {
  if (self.conversationType == ConversationType_PRIVATE) {
    RCDPrivateSettingsTableViewController *settingsVC = [RCDPrivateSettingsTableViewController privateSettingsTableViewController];
    settingsVC.userId = self.targetId;
    [self.navigationController pushViewController:settingsVC animated:YES];
  } else if (self.conversationType == ConversationType_DISCUSSION) {
    RCDDiscussGroupSettingViewController *settingVC =
        [[RCDDiscussGroupSettingViewController alloc] init];
    settingVC.conversationType = self.conversationType;
    settingVC.targetId = self.targetId;
    settingVC.conversationTitle = self.userName;
    //设置讨论组标题时，改变当前聊天界面的标题
    settingVC.setDiscussTitleCompletion = ^(NSString *discussTitle) {
      self.title = discussTitle;
    };
    //清除聊天记录之后reload data
    __weak RCDChatViewController *weakSelf = self;
    settingVC.clearHistoryCompletion = ^(BOOL isSuccess) {
      if (isSuccess) {
        [weakSelf.conversationDataRepository removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
          [weakSelf.conversationMessageCollectionView reloadData];
        });
      }
    };

    [self.navigationController pushViewController:settingVC animated:YES];
  }
  //群组设置
  else if (self.conversationType == ConversationType_GROUP) {
    RCDGroupSettingsTableViewController *settingsVC =
        [RCDGroupSettingsTableViewController groupSettingsTableViewController];
    if (_groupInfo == nil) {
      settingsVC.Group =
          [[RCDataBaseManager shareInstance] getGroupByGroupId:self.targetId];
    } else {
      settingsVC.Group = _groupInfo;
    }
    [self.navigationController pushViewController:settingsVC animated:YES];
  }
  //客服设置
  else if (self.conversationType == ConversationType_CUSTOMERSERVICE ||
           self.conversationType == ConversationType_SYSTEM) {
    RCDSettingBaseViewController *settingVC =
        [[RCDSettingBaseViewController alloc] init];
    settingVC.conversationType = self.conversationType;
    settingVC.targetId = self.targetId;
    //清除聊天记录之后reload data
    __weak RCDChatViewController *weakSelf = self;
    settingVC.clearHistoryCompletion = ^(BOOL isSuccess) {
      if (isSuccess) {
        [weakSelf.conversationDataRepository removeAllObjects];
        dispatch_async(dispatch_get_main_queue(), ^{
          [weakSelf.conversationMessageCollectionView reloadData];
        });
      }
    };
    [self.navigationController pushViewController:settingVC animated:YES];
  } else if (ConversationType_APPSERVICE == self.conversationType ||
             ConversationType_PUBLICSERVICE == self.conversationType) {
    RCPublicServiceProfile *serviceProfile = [[RCIMClient sharedRCIMClient]
        getPublicServiceProfile:(RCPublicServiceType)self.conversationType
                publicServiceId:self.targetId];

    RCPublicServiceProfileViewController *infoVC =
        [[RCPublicServiceProfileViewController alloc] init];
    infoVC.serviceProfile = serviceProfile;
    infoVC.fromConversation = YES;
    [self.navigationController pushViewController:infoVC animated:YES];
  }
}

/**
 *  打开大图。开发者可以重写，自己下载并且展示图片。默认使用内置controller
 *
 *  @param imageMessageContent 图片消息内容
 */
- (void)presentImagePreviewController:(RCMessageModel *)model {
  RCImageSlideController *previewController =
      [[RCImageSlideController alloc] init];
  previewController.messageModel = model;

  UINavigationController *nav = [[UINavigationController alloc]
      initWithRootViewController:previewController];
  [self.navigationController presentViewController:nav
                                          animated:YES
                                        completion:nil];
}

- (void)didLongTouchMessageCell:(RCMessageModel *)model inView:(UIView *)view {
  [super didLongTouchMessageCell:model inView:view];
  NSLog(@"%s", __FUNCTION__);
}

/**
 *  更新左上角未读消息数
 */
- (void)notifyUpdateUnreadMessageCount {
  __weak typeof(&*self) __weakself = self;
  int count = [[RCIMClient sharedRCIMClient] getUnreadCount:@[
    @(ConversationType_PRIVATE),
    @(ConversationType_DISCUSSION),
    @(ConversationType_APPSERVICE),
    @(ConversationType_PUBLICSERVICE),
    @(ConversationType_GROUP)
  ]];
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *backString = nil;
    if (count > 0 && count < 1000) {
      backString = [NSString stringWithFormat:@"返回(%d)", count];
    } else if (count >= 1000) {
      backString = @"返回(...)";
    } else {
      backString = @"返回";
    }
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(0, 6, 87, 23);
    UIImageView *backImg = [[UIImageView alloc]
        initWithImage:[UIImage imageNamed:@"navigator_btn_back"]];
    backImg.frame = CGRectMake(-6, 4, 10, 17);
    [backBtn addSubview:backImg];
    UILabel *backText =
        [[UILabel alloc] initWithFrame:CGRectMake(9, 4, 85, 17)];
    backText.text = backString; // NSLocalizedStringFromTable(@"Back",
                                // @"RongCloudKit", nil);
    //   backText.font = [UIFont systemFontOfSize:17];
    [backText setBackgroundColor:[UIColor clearColor]];
    [backText setTextColor:[UIColor whiteColor]];
    [backBtn addSubview:backText];
    [backBtn addTarget:__weakself
                  action:@selector(leftBarButtonItemPressed:)
        forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *leftButton =
        [[UIBarButtonItem alloc] initWithCustomView:backBtn];
    [__weakself.navigationItem setLeftBarButtonItem:leftButton];
  });
}

- (void)saveNewPhotoToLocalSystemAfterSendingSuccess:(UIImage *)newImage {
  //保存图片
  UIImage *image = newImage;
  UIImageWriteToSavedPhotosAlbum(
      image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}
- (void)image:(UIImage *)image
    didFinishSavingWithError:(NSError *)error
                 contextInfo:(void *)contextInfo {
}

- (void)setRealTimeLocation:(id<RCRealTimeLocationProxy>)realTimeLocation {
  _realTimeLocation = realTimeLocation;
}

- (void)pluginBoardView:(RCPluginBoardView *)pluginBoardView
     clickedItemWithTag:(NSInteger)tag {
  switch (tag) {
  case PLUGIN_BOARD_ITEM_LOCATION_TAG: {
    if (self.realTimeLocation) {
      UIActionSheet *actionSheet = [[UIActionSheet alloc]
                   initWithTitle:nil
                        delegate:self
               cancelButtonTitle:@"取消"
          destructiveButtonTitle:nil
               otherButtonTitles:@"发送位置", @"位置实时共享", nil];
      [actionSheet showInView:self.view];
    } else {
      [super pluginBoardView:pluginBoardView clickedItemWithTag:tag];
    }

  } break;
  default:
    [super pluginBoardView:pluginBoardView clickedItemWithTag:tag];
    break;
  }
}
- (RealTimeLocationStatusView *)realTimeLocationStatusView {
  if (!_realTimeLocationStatusView) {
    _realTimeLocationStatusView = [[RealTimeLocationStatusView alloc]
        initWithFrame:CGRectMake(0, 62, self.view.frame.size.width, 0)];
    _realTimeLocationStatusView.delegate = self;
    [self.view addSubview:_realTimeLocationStatusView];
  }
  return _realTimeLocationStatusView;
}
#pragma mark - RealTimeLocationStatusViewDelegate
- (void)onJoin {
  [self showRealTimeLocationViewController];
}
- (RCRealTimeLocationStatus)getStatus {
  return [self.realTimeLocation getStatus];
}

- (void)onShowRealTimeLocationView {
  [self showRealTimeLocationViewController];
}
- (RCMessageContent *)willSendMessage:(RCMessageContent *)messageCotent {
  //可以在这里修改将要发送的消息
  if ([messageCotent isMemberOfClass:[RCTextMessage class]]) {
    // RCTextMessage *textMsg = (RCTextMessage *)messageCotent;
    // textMsg.extra = @"";
  }
  return messageCotent;
}

#pragma mark override
- (void)didTapMessageCell:(RCMessageModel *)model {
  [super didTapMessageCell:model];
  if ([model.content isKindOfClass:[RCRealTimeLocationStartMessage class]]) {
    [self showRealTimeLocationViewController];
  }
}

- (NSArray<UIMenuItem *> *)getLongTouchMessageCellMenuList:
    (RCMessageModel *)model {
  NSMutableArray<UIMenuItem *> *menuList =
      [[super getLongTouchMessageCellMenuList:model] mutableCopy];
  /*
  在这里添加删除菜单。
  [menuList enumerateObjectsUsingBlock:^(UIMenuItem * _Nonnull obj, NSUInteger
 idx, BOOL * _Nonnull stop) {
    if ([obj.title isEqualToString:@"删除"] || [obj.title
 isEqualToString:@"delete"]) {
      [menuList removeObjectAtIndex:idx];
      *stop = YES;
    }
  }];

 UIMenuItem *forwardItem = [[UIMenuItem alloc] initWithTitle:@"转发"
 action:@selector(onForwardMessage:)];
 [menuList addObject:forwardItem];

  如果您不需要修改，不用重写此方法，或者直接return［super
 getLongTouchMessageCellMenuList:model]。
  */
  return menuList;
}

- (void)didTapCellPortrait:(NSString *)userId {
  if (self.conversationType == ConversationType_GROUP ||
      self.conversationType == ConversationType_DISCUSSION) {
    if (![userId isEqualToString:[RCIM sharedRCIM].currentUserInfo.userId]) {
      [[RCDUserInfoManager shareInstance]
          getFriendInfo:userId
             completion:^(RCUserInfo *user) {
               [[RCIM sharedRCIM] refreshUserInfoCache:user
                                            withUserId:user.userId];
               [self gotoNextPage:user];
             }];
    } else {
      [[RCDUserInfoManager shareInstance]
          getUserInfo:userId
           completion:^(RCUserInfo *user) {
             [[RCIM sharedRCIM] refreshUserInfoCache:user
                                          withUserId:user.userId];
             [self gotoNextPage:user];
           }];
    }
  }
  if (self.conversationType == ConversationType_PRIVATE) {
    [[RCDUserInfoManager shareInstance] getUserInfo:userId
                                         completion:^(RCUserInfo *user) {
                                           [[RCIM sharedRCIM]
                                            refreshUserInfoCache:user
                                            withUserId:user.userId];
                                           [self gotoNextPage:user];
                                         }];
  }
}

- (void)gotoNextPage:(RCUserInfo *)user {
  NSArray *friendList = [[RCDataBaseManager shareInstance] getAllFriends];
  BOOL isGotoDetailView = NO;
  for (RCDUserInfo *friend in friendList) {
    if ([user.userId isEqualToString:friend.userId] &&
        [friend.status isEqualToString:@"20"]) {
      isGotoDetailView = YES;
    } else if ([user.userId
                   isEqualToString:[RCIM sharedRCIM].currentUserInfo.userId]) {
      isGotoDetailView = YES;
    }
  }
  if (isGotoDetailView == YES) {
      RCDPersonDetailViewController *temp =
      [[RCDPersonDetailViewController alloc]init];
    temp.userId = user.userId;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.navigationController pushViewController:temp animated:YES];
    });
  } else {
    RCDAddFriendViewController *vc = [[RCDAddFriendViewController alloc] init];
    vc.targetUserInfo = user;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.navigationController
       pushViewController:vc
       animated:YES];
    });
  }
}

///**
// *  重写方法实现未注册的消息的显示
// *
// 如：新版本增加了某种自定义消息，但是老版本不能识别，开发者可以在旧版本中预先自定义这种未识别的消息的显示
// *  需要设置RCIM showUnkownMessage属性
// **

#pragma mark override
- (void)resendMessage:(RCMessageContent *)messageContent {
  if ([messageContent isKindOfClass:[RCRealTimeLocationStartMessage class]]) {
    [self showRealTimeLocationViewController];
  } else {
    [super resendMessage:messageContent];
  }
}
#pragma mark - UIActionSheet Delegate
- (void)actionSheet:(UIActionSheet *)actionSheet
    clickedButtonAtIndex:(NSInteger)buttonIndex {
  switch (buttonIndex) {
  case 0: {
    [super pluginBoardView:self.pluginBoardView
        clickedItemWithTag:PLUGIN_BOARD_ITEM_LOCATION_TAG];
  } break;
  case 1: {
    [self showRealTimeLocationViewController];
  } break;
  }
}

- (void)willPresentActionSheet:(UIActionSheet *)actionSheet {
  SEL selector = NSSelectorFromString(@"_alertController");

  if ([actionSheet respondsToSelector:selector]) {
    UIAlertController *alertController =
        [actionSheet valueForKey:@"_alertController"];
    if ([alertController isKindOfClass:[UIAlertController class]]) {
      alertController.view.tintColor = [UIColor blackColor];
    }
  } else {
    for (UIView *subView in actionSheet.subviews) {
      if ([subView isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)subView;
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
      }
    }
  }
}

#pragma mark - RCRealTimeLocationObserver
- (void)onRealTimeLocationStatusChange:(RCRealTimeLocationStatus)status {
  __weak typeof(&*self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf updateRealTimeLocationStatus];
  });
}

- (void)onReceiveLocation:(CLLocation *)location fromUserId:(NSString *)userId {
  __weak typeof(&*self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf updateRealTimeLocationStatus];
  });
}

- (void)onParticipantsJoin:(NSString *)userId {
  __weak typeof(&*self) weakSelf = self;
  if ([userId isEqualToString:[RCIMClient sharedRCIMClient]
                                  .currentUserInfo.userId]) {
    [self notifyParticipantChange:@"你加入了地理位置共享"];
  } else {
    [[RCIM sharedRCIM]
            .userInfoDataSource
        getUserInfoWithUserId:userId
                   completion:^(RCUserInfo *userInfo) {
                     if (userInfo.name.length) {
                       [weakSelf
                           notifyParticipantChange:
                               [NSString stringWithFormat:@"%@加入地理位置共享",
                                                          userInfo.name]];
                     } else {
                       [weakSelf
                           notifyParticipantChange:
                               [NSString
                                   stringWithFormat:@"user<%@>加入地理位置共享",
                                                    userId]];
                     }
                   }];
  }
}

- (void)onParticipantsQuit:(NSString *)userId {
  __weak typeof(&*self) weakSelf = self;
  if ([userId isEqualToString:[RCIMClient sharedRCIMClient]
                                  .currentUserInfo.userId]) {
    [self notifyParticipantChange:@"你退出地理位置共享"];
  } else {
    [[RCIM sharedRCIM]
            .userInfoDataSource
        getUserInfoWithUserId:userId
                   completion:^(RCUserInfo *userInfo) {
                     if (userInfo.name.length) {
                       [weakSelf
                           notifyParticipantChange:
                               [NSString stringWithFormat:@"%@退出地理位置共享",
                                                          userInfo.name]];
                     } else {
                       [weakSelf
                           notifyParticipantChange:
                               [NSString
                                   stringWithFormat:@"user<%@>退出地理位置共享",
                                                    userId]];
                     }
                   }];
  }
}

- (void)onRealTimeLocationStartFailed:(long)messageId {
  dispatch_async(dispatch_get_main_queue(), ^{
    for (int i = 0; i < self.conversationDataRepository.count; i++) {
      RCMessageModel *model = [self.conversationDataRepository objectAtIndex:i];
      if (model.messageId == messageId) {
        model.sentStatus = SentStatus_FAILED;
      }
    }
    NSArray *visibleItem =
        [self.conversationMessageCollectionView indexPathsForVisibleItems];
    for (int i = 0; i < visibleItem.count; i++) {
      NSIndexPath *indexPath = visibleItem[i];
      RCMessageModel *model =
          [self.conversationDataRepository objectAtIndex:indexPath.row];
      if (model.messageId == messageId) {
        [self.conversationMessageCollectionView
            reloadItemsAtIndexPaths:@[ indexPath ]];
      }
    }
  });
}

- (void)notifyParticipantChange:(NSString *)text {
  __weak typeof(&*self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf.realTimeLocationStatusView updateText:text];
    [weakSelf performSelector:@selector(updateRealTimeLocationStatus)
                   withObject:nil
                   afterDelay:0.5];
  });
}

- (void)onFailUpdateLocation:(NSString *)description {
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView
    clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == 1) {
    [self.realTimeLocation quitRealTimeLocation];
    [self popupChatViewController];
  }
}

- (RCMessage *)willAppendAndDisplayMessage:(RCMessage *)message {
  return message;
}

/*******************实时地理位置共享***************/
- (void)showRealTimeLocationViewController {
  RealTimeLocationViewController *lsvc =
      [[RealTimeLocationViewController alloc] init];
  lsvc.realTimeLocationProxy = self.realTimeLocation;
  if ([self.realTimeLocation getStatus] ==
      RC_REAL_TIME_LOCATION_STATUS_INCOMING) {
    [self.realTimeLocation joinRealTimeLocation];
  } else if ([self.realTimeLocation getStatus] ==
             RC_REAL_TIME_LOCATION_STATUS_IDLE) {
    [self.realTimeLocation startRealTimeLocation];
  }
  [self.navigationController presentViewController:lsvc
                                          animated:YES
                                        completion:^{

                                        }];
}
- (void)updateRealTimeLocationStatus {
  if (self.realTimeLocation) {
    [self.realTimeLocationStatusView updateRealTimeLocationStatus];
    __weak typeof(&*self) weakSelf = self;
    NSArray *participants = nil;
    switch ([self.realTimeLocation getStatus]) {
    case RC_REAL_TIME_LOCATION_STATUS_OUTGOING:
      [self.realTimeLocationStatusView updateText:@"你正在共享位置"];
      break;
    case RC_REAL_TIME_LOCATION_STATUS_CONNECTED:
    case RC_REAL_TIME_LOCATION_STATUS_INCOMING:
      participants = [self.realTimeLocation getParticipants];
      if (participants.count == 1) {
        NSString *userId = participants[0];
        [weakSelf.realTimeLocationStatusView
            updateText:[NSString
                           stringWithFormat:@"user<%@>正在共享位置", userId]];
        [[RCIM sharedRCIM]
                .userInfoDataSource
            getUserInfoWithUserId:userId
                       completion:^(RCUserInfo *userInfo) {
                         if (userInfo.name.length) {
                           dispatch_async(dispatch_get_main_queue(), ^{
                             [weakSelf.realTimeLocationStatusView
                                 updateText:[NSString stringWithFormat:
                                                          @"%@正在共享位置",
                                                          userInfo.name]];
                           });
                         }
                       }];
      } else {
        if (participants.count < 1)
          [self.realTimeLocationStatusView removeFromSuperview];
        else
          [self.realTimeLocationStatusView
              updateText:[NSString stringWithFormat:@"%d人正在共享地理位置",
                                                    (int)participants.count]];
      }
      break;
    default:
      break;
    }
  }
}

- (void)refreshUserInfoOrGroupInfo {
  //打开单聊强制从demo server 获取用户信息更新本地数据库

  if (self.conversationType == ConversationType_PRIVATE) {
    if (![self.targetId
            isEqualToString:[RCIM sharedRCIM].currentUserInfo.userId]) {
      __weak typeof(self) weakSelf = self;
      [[RCDRCIMDataSource shareInstance]
          getUserInfoWithUserId:self.targetId
                     completion:^(RCUserInfo *userInfo) {
                       [[RCDHttpTool shareInstance]
                           updateUserInfo:weakSelf.targetId
                           success:^(RCDUserInfo *user) {
                             RCUserInfo *updatedUserInfo =
                                 [[RCUserInfo alloc] init];
                             updatedUserInfo.userId = user.userId;
                             if (user.displayName.length > 0) {
                               updatedUserInfo.name = user.displayName;
                             } else {
                               updatedUserInfo.name = user.name;
                             }
                             updatedUserInfo.portraitUri = user.portraitUri;
                             weakSelf.navigationItem.title =
                                 updatedUserInfo.name;
                             [[RCIM sharedRCIM]
                                 refreshUserInfoCache:updatedUserInfo
                                           withUserId:updatedUserInfo.userId];
                           }
                           failure:^(NSError *err){

                           }];
                     }];
    }
      }
  //刷新自己头像昵称
      [[RCDUserInfoManager shareInstance]
       getUserInfo:[RCIM sharedRCIM].currentUserInfo.userId
       completion:^(RCUserInfo *user) {
           [[RCIM sharedRCIM] refreshUserInfoCache:user
                                        withUserId:user.userId];
       }];
       

  //打开群聊强制从demo server 获取群组信息更新本地数据库
  if (self.conversationType == ConversationType_GROUP) {
    __weak typeof(self) weakSelf = self;
    [RCDHTTPTOOL getGroupByID:self.targetId
            successCompletion:^(RCDGroupInfo *group) {
              RCGroup *Group =
                  [[RCGroup alloc] initWithGroupId:weakSelf.targetId
                                         groupName:group.groupName
                                       portraitUri:group.portraitUri];
              [[RCIM sharedRCIM] refreshGroupInfoCache:Group
                                           withGroupId:weakSelf.targetId];
              dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf refreshTitle];
              });
            }];
  }
  //更新群组成员用户信息的本地缓存
  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    NSMutableArray *groupList =
        [[RCDataBaseManager shareInstance] getGroupMember:self.targetId];
    NSArray *resultList =
        [[RCDUserInfoManager shareInstance] getFriendInfoList:groupList];
    groupList = [[NSMutableArray alloc] initWithArray:resultList];
    for (RCUserInfo *user in groupList) {
      if ([user.portraitUri isEqualToString:@""]) {
        user.portraitUri = [RCDUtilities defaultUserPortrait:user];
      }
      if ([user.portraitUri hasPrefix:@"file:///"]) {
        NSString *filePath = [RCDUtilities
            getIconCachePath:[NSString
                                 stringWithFormat:@"user%@.png", user.userId]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
          NSURL *portraitPath = [NSURL fileURLWithPath:filePath];
          user.portraitUri = [portraitPath absoluteString];
        } else {
          user.portraitUri = [RCDUtilities defaultUserPortrait:user];
        }
      }
      [[RCIM sharedRCIM] refreshUserInfoCache:user withUserId:user.userId];
    }
  });
}

- (void)refreshTitle{
  if (self.userName == nil) {
    return;
  }
    int count = [[[RCDataBaseManager shareInstance] getGroupByGroupId:self.targetId].number intValue];
    if(self.conversationType == ConversationType_GROUP && count > 0){
        self.title = [NSString stringWithFormat:@"%@(%d)",self.userName,count];
    }else{
        self.title = self.userName;
    }
}

- (void)didTapReceiptCountView:(RCMessageModel *)model {
  if ([model.content isKindOfClass:[RCTextMessage class]]) {
    RCDReceiptDetailsTableViewController *vc = [[RCDReceiptDetailsTableViewController alloc] init];
    RCTextMessage *messageContent = (RCTextMessage *)model.content;
   NSString *sendTime = [RCKitUtility ConvertMessageTime:model.sentTime/1000];
    RCMessage *message = [[RCIMClient sharedRCIMClient] getMessageByUId:model.messageUId];
    NSMutableDictionary *readReceiptUserList = message.readReceiptInfo.userIdList;
    NSArray *hasReadUserList = [readReceiptUserList allKeys];
    if (hasReadUserList.count > 1) {
      hasReadUserList = [self sortForHasReadList:readReceiptUserList];
    }
    vc.targetId = self.targetId;
    vc.messageContent = messageContent.content;
    vc.messageSendTime = sendTime;
    vc.hasReadUserList = hasReadUserList;
    [self.navigationController pushViewController:vc animated:YES];
  }
}

-(NSArray *)sortForHasReadList: (NSDictionary *)readReceiptUserDic {
  NSArray *result;
  NSArray *sortedKeys = [readReceiptUserDic keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    if ([obj1 integerValue] > [obj2 integerValue]) {
      return (NSComparisonResult)NSOrderedDescending;
    }
    if ([obj1 integerValue] < [obj2 integerValue]) {
      return (NSComparisonResult)NSOrderedAscending;
    }
    return (NSComparisonResult)NSOrderedSame;
  }];
  result = [sortedKeys copy];
  return result;
}


@end
