//
//  TKMiniWhiteBoardView.m
//  TKWhiteBoard
//
//  Created by 周洁 on 2019/1/7.
//  Copyright © 2019 MAC-MiNi. All rights reserved.
//

#import "TKMiniWhiteBoardView.h"
#import "Masonry.h"
#import <TKRoomSDK/TKRoomSDK.h>
#import <AWSS3/AWSS3.h>
#import "classroom-Swift.h"

#define ThemeKP(args) [@"TKNativeWB.LightWB." stringByAppendingString:args]
#define allTrim( object ) [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ]

NSString *const S3BucketName = @"tutorathome-test";
NSString *const MaterialsJson = @"materials.json";
NSString *const DrawingsJson = @"blackBoardCommon.json";
NSString *const RoomDirectory = @"classroom";
NSString *const SpaceReplace = @"&#&";

@implementation TKMiniWhiteBoardView
{
    UIButton *_closeBtn;
    UIView *_drawToolView;
    
    UIButton *_penBtn;
    UIButton *_textBtn;
    UIButton *_eraserBtn;
    UIButton *_leftArrowBtn;
    UIButton *_rightArrowBtn;
    UIButton *_cloudBtn;
    UIButton *_saveBtn;
    
    UIButton *_sendBtn;
    UIPanGestureRecognizer *_panG;
    
    NSMutableArray <NSDictionary *> *_prepareData;
    NSMutableArray <NSDictionary *> *_savedData;
    
    SelectionDialog *selClassDialog;
}

typedef enum {
    MATERIAL_JSON = 0,
    BACK_IMAGE = 1,
    DATA_JSON = 2,
} AWSData;

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)init
{
    if (self = [super init]) {
        _prepareData = [@[] mutableCopy];
        _savedData = [@[] mutableCopy];
        
        self.sakura.backgroundColor(ThemeKP(@"bg_color"));
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = 10 * Proportion;
        
        if ([TKEduSessionHandle shareInstance].localUser.role != TKUserType_Teacher) {
            _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            _closeBtn.sakura.backgroundImage(ThemeKP(@"tk_close"), UIControlStateNormal);
            [self addSubview:_closeBtn];
            [_closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.right.equalTo(self.mas_right).offset(-10 * Proportion);
                make.top.equalTo(self.mas_top).offset(10 * Proportion);
                make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(20 * Proportion, 20 * Proportion)]);
            }];
            [_closeBtn addTarget:self action:@selector(closeMiniWhiteBoard) forControlEvents:UIControlEventTouchUpInside];
        }
        
        _segmentCotnrol = [[TKStudentSegmentControl alloc] initWithDelegate:self];
        [self addSubview:_segmentCotnrol];
        [_segmentCotnrol mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.mas_left).offset(5 * Proportion);
            make.top.equalTo(self.mas_top).offset(5 * Proportion);
            make.height.equalTo(@((37 + 10) * Proportion));
            make.right.equalTo(self.mas_right).offset(-96 * Proportion);
        }];
        
        UIView *underDrawView = [[UIView alloc] init];
        underDrawView.sakura.backgroundColor(ThemeKP(@"tip_bg_nor_color"));
        [self addSubview:underDrawView];
        [underDrawView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.mas_left).offset(5 * Proportion);
            make.right.equalTo(self.mas_right).offset(-5 * Proportion);
            make.top.equalTo(self.mas_top).offset(42 * Proportion);
            make.bottom.equalTo(self.mas_bottom).offset(-53 * Proportion);
            //make.width.equalTo(underDrawView.mas_height).multipliedBy(16 / 9.0f).priorityHigh();
        }];
        
        _tkDrawView = [[TKDrawView alloc] initWithDelegate:self];
        _tkDrawView.sakura.backgroundColor(ThemeKP(@"tip_bg_sel_color"));
        [_tkDrawView setWorkMode:TKWorkModeControllor];
        [_tkDrawView switchToFileID:sBlackBoardCommon pageID:1 refreshImmediately:YES];
        [self addSubview:_tkDrawView];
        [_tkDrawView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(underDrawView.mas_top);
            make.bottom.equalTo(underDrawView.mas_bottom);
            make.centerX.equalTo(underDrawView.mas_centerX);
            make.height.equalTo(underDrawView.mas_height).priorityHigh();
            make.width.equalTo(_tkDrawView.mas_height).multipliedBy(16 / 9.0f).priorityHigh();
        }];
        
        TKStudentSegmentObject *teacher = [[TKStudentSegmentObject alloc] init];
        teacher.ID = sBlackBoardCommon;
        teacher.currentPage = 1;
        teacher.seq = @(0);
        _choosedStudent = teacher;
        
        _drawToolView = [[UIView alloc] init];
        [self addSubview:_drawToolView];
        
        _penBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _penBtn.sakura.backgroundImage(ThemeKP(@"tk_pen_swb_default"), UIControlStateNormal);
        _penBtn.sakura.backgroundImage(ThemeKP(@"tk_pen_swb_selected"), UIControlStateSelected);
        [_penBtn addTarget:self action:@selector(drawPen:) forControlEvents:UIControlEventTouchUpInside];
        _penBtn.selected = YES;
        [_drawToolView addSubview:_penBtn];
        [_penBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(_drawToolView.mas_left);
            make.centerY.equalTo(_drawToolView.mas_centerY);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(39 * Proportion, 25 * Proportion)]);
        }];
        
        _textBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _textBtn.sakura.backgroundImage(ThemeKP(@"tk_text_swb_default"), UIControlStateNormal);
        _textBtn.sakura.backgroundImage(ThemeKP(@"tk_text_swb_selected"), UIControlStateSelected);
        [_textBtn addTarget:self action:@selector(drawText:) forControlEvents:UIControlEventTouchUpInside];
        [_drawToolView addSubview:_textBtn];
        [_textBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(_penBtn.mas_right).offset(40 * Proportion);
            make.centerY.equalTo(_drawToolView.mas_centerY);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(39 * Proportion, 25 * Proportion)]);
        }];
        
        _eraserBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _eraserBtn.sakura.backgroundImage(ThemeKP(@"tk_xiangpi_swb_default"), UIControlStateNormal);
        _eraserBtn.sakura.backgroundImage(ThemeKP(@"tk_xiangpi_swb_selected"), UIControlStateSelected);
        [_eraserBtn addTarget:self action:@selector(drawEraser:) forControlEvents:UIControlEventTouchUpInside];
        [_drawToolView addSubview:_eraserBtn];
        [_eraserBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(_textBtn.mas_right).offset(40 * Proportion);
            make.centerY.equalTo(_drawToolView.mas_centerY);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(39 * Proportion, 25 * Proportion)]);
        }];
        
        if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
            _cloudBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            _cloudBtn.sakura.backgroundImage(ThemeKP(@"tk_cloud_default_mark"), UIControlStateNormal);
            _cloudBtn.sakura.backgroundImage(ThemeKP(@"tk_cloud_press_mark"), UIControlStateHighlighted);
            [_cloudBtn addTarget:self action:@selector(loadClassMaterial:) forControlEvents:UIControlEventTouchUpInside];
            [_drawToolView addSubview:_cloudBtn];
            [_cloudBtn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(_eraserBtn.mas_right).offset(40 * Proportion);
                make.centerY.equalTo(_drawToolView.mas_centerY);
                make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(30 * Proportion, 30 * Proportion)]);
            }];
        }
        
        _leftArrowBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _leftArrowBtn.sakura.backgroundImage(ThemeKP(@"tk_left_arrow_default_mark"), UIControlStateNormal);
        _leftArrowBtn.sakura.backgroundImage(ThemeKP(@"tk_left_arrow_press_mark"), UIControlStateHighlighted);
        [_leftArrowBtn addTarget:self action:@selector(goToPrevMaterial:) forControlEvents:UIControlEventTouchUpInside];
        [_drawToolView addSubview:_leftArrowBtn];
        [_leftArrowBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
                make.left.equalTo(_cloudBtn.mas_right).offset(40 * Proportion);
            } else {
                make.left.equalTo(_eraserBtn.mas_right).offset(40 * Proportion);
            }
            make.centerY.equalTo(_drawToolView.mas_centerY);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(30 * Proportion, 30 * Proportion)]);
        }];
        
        _rightArrowBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _rightArrowBtn.sakura.backgroundImage(ThemeKP(@"tk_right_arrow_default_mark"), UIControlStateNormal);
        _rightArrowBtn.sakura.backgroundImage(ThemeKP(@"tk_right_arrow_press_mark"), UIControlStateHighlighted);
        [_rightArrowBtn addTarget:self action:@selector(goToNextMaterial:) forControlEvents:UIControlEventTouchUpInside];
        [_drawToolView addSubview:_rightArrowBtn];
        [_rightArrowBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(_leftArrowBtn.mas_right).offset(40 * Proportion);
            make.centerY.equalTo(_drawToolView.mas_centerY);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(30 * Proportion, 30 * Proportion)]);
        }];
        
        _saveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _saveBtn.sakura.backgroundImage(ThemeKP(@"tk_save_default_mark"), UIControlStateNormal);
        _saveBtn.sakura.backgroundImage(ThemeKP(@"tk_save_press_mark"), UIControlStateHighlighted);
        [_saveBtn addTarget:self action:@selector(uploadClassMaterial:) forControlEvents:UIControlEventTouchUpInside];
        [_drawToolView addSubview:_saveBtn];
        [_saveBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(_rightArrowBtn.mas_right).offset(40 * Proportion);
            make.centerY.equalTo(_drawToolView.mas_centerY);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(30 * Proportion, 30 * Proportion)]);
        }];
        
        if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
            //_leftArrowBtn.hidden = YES;
            //_rightArrowBtn.hidden = YES;
            //_saveBtn.hidden = YES;
        }

        [_drawToolView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.mas_left).offset(31 * Proportion);
            make.right.equalTo(_saveBtn.mas_right);
            make.top.equalTo(_tkDrawView.mas_bottom);
            make.bottom.equalTo(self.mas_bottom);
        }];
        
        _selectorView = [[TKBrushSelectorView alloc] initWithDefaultColor:nil];
        _selectorView.clipsToBounds = YES;
        _selectorView.delegate = self;
        
        _sendBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _sendBtn.sakura.backgroundImage(ThemeKP(@"tk_button_send_default"), UIControlStateNormal);
        [_sendBtn addTarget:self action:@selector(sendState) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_sendBtn];
        [_sendBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.mas_right).offset(-12 * Proportion);
            make.bottom.equalTo(self.mas_bottom).offset(-4 * Proportion);
            make.size.equalTo([NSValue valueWithCGSize:CGSizeMake(115 * Proportion, 44 * Proportion)]);
        }];
        
        //_panG = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        //[self addGestureRecognizer:_panG];
        
        _classNames = [[NSMutableDictionary alloc] init];
        _pageIndexs = [[NSMutableDictionary alloc] init];
        _totalNumbers = [[NSMutableDictionary alloc] init];
        _backgroundImages = [[NSMutableDictionary alloc] init];
                
        [self setNeedsLayout];
        [self layoutIfNeeded];
    }
    
    return self;
}


- (void)panGesture:(UIPanGestureRecognizer *)panG
{
    CGPoint translatedPoint = [panG translationInView:self];
    CGFloat x = self.center.x + translatedPoint.x;
    CGFloat y = self.center.y + translatedPoint.y;
    if (panG.state == UIGestureRecognizerStateBegan) {
        if (CGRectContainsPoint(_tkDrawView.frame, [panG locationInView:self])) {
            panG.enabled = NO;
        }
    } else if (panG.state == UIGestureRecognizerStateChanged) {

        CGPoint deltaCenter = CGPointMake(x - self.superview.frame.size.width / 2, y - self.superview.frame.size.height / 2);
        
        [self mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.left.greaterThanOrEqualTo(self.superview.mas_left).priorityHigh();
            make.right.lessThanOrEqualTo(self.superview.mas_right).priorityHigh();
            make.bottom.greaterThanOrEqualTo(self.superview.mas_bottom).priorityHigh();
            make.top.lessThanOrEqualTo(self.superview.mas_top).priorityHigh();
            make.centerX.equalTo(self.superview.mas_centerX).offset(deltaCenter.x).priorityLow();
            make.centerY.equalTo(self.superview.mas_centerY).offset(deltaCenter.y).priorityLow();
            make.width.equalTo(@(self.frame.size.width));
            make.height.equalTo(@(self.frame.size.height));
        }];
    }
    
    [panG setTranslation:CGPointMake(0, 0) inView:self];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    //设定白板相对web比例
    _tkDrawView.iFontScale = _tkDrawView.frame.size.height / 960;
}

- (void)setDefaultDrawData
{
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
        [_tkDrawView setDrawType:TKDrawTypePen hexColor:@"#ED3E3A" progress:0.05f];
    }
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
        [_tkDrawView setDrawType:TKDrawTypePen hexColor:@"#160C30" progress:0.05f];
    }
}

- (void)sendStudent
{
    if (self.isBigRoom) {
        //大并发教室自己未上台则不发自己
        if ([TKEduSessionHandle shareInstance].localUser.publishState == 0) {
            return;
        }
    }
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
        __block BOOL has = NO;
        [_segmentCotnrol.students enumerateObjectsUsingBlock:^(TKStudentSegmentObject * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj.ID isEqualToString:[TKEduSessionHandle shareInstance].localUser.peerID]) {
                has = YES;
            }
        }];
        if (!has) {
            
            NSDictionary * pubDict = @{@"id" : [TKEduSessionHandle shareInstance].localUser.peerID, @"loginuserid" : _loginuserid,
                                       @"nickname" : [TKEduSessionHandle shareInstance].localUser.nickName, @"role" : @(2)};
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sUserHasNewBlackBoard
                                                                 ID:[NSString stringWithFormat:@"_%@",[TKEduSessionHandle shareInstance].localUser.peerID]
                                                                 To:sTellAll
                                                               Data:pubDict
                                                               Save:YES
                                                    AssociatedMsgID:sBlackBoard_new
                                                   AssociatedUserID:[TKEduSessionHandle shareInstance].localUser.peerID
                                                            expires:0
                                                         completion:nil];
        }
    }
}

//接收状态
- (void)switchStates:(TKMiniWhiteBoardState)state
{
    if (![_tkDrawView hasDraw]) {
        [self setDefaultDrawData];
    }
    self.state = state;
    switch (state) {
        case TKMiniWhiteBoardStatePrepareing:
        {
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                _segmentCotnrol.hidden = YES;
                _closeBtn.hidden = YES;
                _sendBtn.hidden = YES;
                _drawToolView.hidden = NO;
                _segmentCotnrol.userInteractionEnabled = NO;
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
                _segmentCotnrol.hidden = YES;
                _closeBtn.hidden = NO;
                _sendBtn.hidden = NO;
                _drawToolView.hidden = NO;
                _segmentCotnrol.userInteractionEnabled = YES;
                
                NSDictionary * pubDict = @{@"id" : sBlackBoardCommon, @"loginuserid" : _loginuserid, @"nickname" : [TKEduSessionHandle shareInstance].localUser.nickName, @"role" : @(0)};
                [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sUserHasNewBlackBoard
                                                                     ID:[NSString stringWithFormat:@"_%@",[TKEduSessionHandle shareInstance].localUser.peerID]
                                                                     To:sTellAll
                                                                   Data:pubDict
                                                                   Save:YES
                                                        AssociatedMsgID:sBlackBoard_new
                                                       AssociatedUserID:sBlackBoardCommon
                                                                expires:0
                                                             completion:nil];
            }
            
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                _segmentCotnrol.hidden = YES;
                _closeBtn.hidden = YES;
                _sendBtn.hidden = YES;
                _drawToolView.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = _drawToolView.userInteractionEnabled = _sendBtn.userInteractionEnabled = _closeBtn.userInteractionEnabled = _segmentCotnrol.userInteractionEnabled = NO;
            }
            
            [_sendBtn setAttributedTitle:[[NSAttributedString alloc] initWithString:TKMTLocalized(@"MiniWB.Dispense") attributes:@{NSForegroundColorAttributeName : UIColor.whiteColor, NSFontAttributeName : [UIFont systemFontOfSize:16 * Proportion]}] forState:UIControlStateNormal];

            break;
        }
        case TKMiniWhiteBoardStateDispenseed:
        {
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                 _segmentCotnrol.hidden = YES;
                _drawToolView.hidden = NO;
                _sendBtn.hidden = YES;
                _closeBtn.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = NO;
                [self sendStudent];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = NO;
                _sendBtn.hidden = NO;
                _closeBtn.hidden = NO;
                _segmentCotnrol.userInteractionEnabled = YES;
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = YES;
                _sendBtn.hidden = YES;
                _closeBtn.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = _drawToolView.userInteractionEnabled = _sendBtn.userInteractionEnabled = _closeBtn.userInteractionEnabled = _segmentCotnrol.userInteractionEnabled = NO;
            }
            
            [_sendBtn setAttributedTitle:[[NSAttributedString alloc] initWithString:TKMTLocalized(@"MiniWB.Recycle") attributes:@{NSForegroundColorAttributeName : UIColor.whiteColor, NSFontAttributeName : [UIFont systemFontOfSize:16 * Proportion]}] forState:UIControlStateNormal];
            
            break;
        }
        case TKMiniWhiteBoardStateAgainDispenseed:
        {
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                _segmentCotnrol.hidden = YES;
                _drawToolView.hidden = NO;
                _sendBtn.hidden = YES;
                _closeBtn.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = NO;
                [self sendStudent];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = NO;
                _sendBtn.hidden = NO;
                _closeBtn.hidden = NO;
                _segmentCotnrol.userInteractionEnabled = YES;
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = YES;
                _sendBtn.hidden = YES;
                _closeBtn.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = _drawToolView.userInteractionEnabled = _sendBtn.userInteractionEnabled = _closeBtn.userInteractionEnabled = _segmentCotnrol.userInteractionEnabled = NO;
            }
            
            [_sendBtn setAttributedTitle:[[NSAttributedString alloc] initWithString:TKMTLocalized(@"MiniWB.Recycle") attributes:@{NSForegroundColorAttributeName : UIColor.whiteColor, NSFontAttributeName : [UIFont systemFontOfSize:16 * Proportion]}] forState:UIControlStateNormal];
            break;
        }
        case TKMiniWhiteBoardStateRecycle:
        {
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = YES;
                _sendBtn.hidden = YES;
                _closeBtn.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = NO;
                [self sendStudent];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = NO;
                _sendBtn.hidden = NO;
                _closeBtn.hidden = NO;
                _segmentCotnrol.userInteractionEnabled = YES;
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                _segmentCotnrol.hidden = NO;
                _drawToolView.hidden = YES;
                _sendBtn.hidden = YES;
                _closeBtn.hidden = YES;
                _segmentCotnrol.userInteractionEnabled = YES;
                _segmentCotnrol.userInteractionEnabled = _drawToolView.userInteractionEnabled = _sendBtn.userInteractionEnabled = _closeBtn.userInteractionEnabled = _segmentCotnrol.userInteractionEnabled = NO;
            }

            [_sendBtn setAttributedTitle:[[NSAttributedString alloc] initWithString:TKMTLocalized(@"MiniWB.Redispense") attributes:@{NSForegroundColorAttributeName : UIColor.whiteColor, NSFontAttributeName : [UIFont systemFontOfSize:16 * Proportion]}] forState:UIControlStateNormal];
            break;
        }
        
        default:
            break;
    }
}

//老师点击按钮发送状态
- (void)sendState
{
    NSNumber *currentPage = [NSNumber numberWithInt:1];
    NSString *currentTapKey = [_tkDrawView fileid];
    if ([_pageIndexs objectForKey:currentTapKey]) {
        currentPage = [_pageIndexs objectForKey:currentTapKey];
    }
    
    switch (self.state) {
        case TKMiniWhiteBoardStateDispenseed:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_recycle", @"currentTapKey" : sBlackBoardCommon, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
        case TKMiniWhiteBoardStateAgainDispenseed:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_recycle", @"currentTapKey" : sBlackBoardCommon, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
        case TKMiniWhiteBoardStateRecycle:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_againDispenseed", @"currentTapKey" : sBlackBoardCommon, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
        case TKMiniWhiteBoardStatePrepareing:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_dispenseed", @"currentTapKey" : sBlackBoardCommon, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
            
        default:
            break;
    }
}

- (void)closeMiniWhiteBoard
{
    self.hidden = YES;
    [[TKEduSessionHandle shareInstance] sessionHandleDelMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{} completion:nil];
}

//增加学生画布
- (BOOL)addStudent:(TKStudentSegmentObject *)student
{
    return [_segmentCotnrol addStudent:student];
}

//移除学生画布
- (void)removeStudent:(TKStudentSegmentObject *)student
{
    [_segmentCotnrol removeStudent:student];
    [_tkDrawView clearOnePageWithFileID:student.ID pageNum:1];
}

//选中学生
- (void)didSelectStudent:(TKStudentSegmentObject *)student
{
    _choosedStudent = student;
    NSNumber *currentPage = [NSNumber numberWithInt:1];
    NSString *currentTapKey = student.ID;
    if ([_pageIndexs objectForKey:currentTapKey]) {
        currentPage = [_pageIndexs objectForKey:currentTapKey];
    }
    switch (self.state) {
        case TKMiniWhiteBoardStateDispenseed:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_dispenseed", @"currentTapKey" : student.ID, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
        case TKMiniWhiteBoardStateRecycle:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_recycle", @"currentTapKey" : student.ID, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
        case TKMiniWhiteBoardStateAgainDispenseed:
        {
            [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sBlackBoard_new ID:sBlackBoard_new To:sTellAll Data:@{@"blackBoardState" : @"_againDispenseed", @"currentTapKey" : student.ID, @"currentTapPage" : currentPage} Save:YES AssociatedMsgID:sClassBegin AssociatedUserID:nil expires:0 completion:nil];
            break;
        }
            
        default:
            break;
    }
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
        if ([student.ID isEqualToString:sBlackBoardCommon]) {
            _saveBtn.hidden = NO;
        } else {
            _saveBtn.hidden = YES;
        }
        
        if (student.loginuserid && [allTrim(student.loginuserid) length] > 0) {
            _selLoginuserid = student.loginuserid;
        } /*else {
            _selLoginuserid = nil;
        }*/
    }
    UIColor *backColor =  [_backgroundImages objectForKey:student.ID];
    if (backColor != nil) {
        _tkDrawView.backgroundColor = backColor;
    } else {
        _tkDrawView.sakura.backgroundColor(ThemeKP(@"tip_bg_sel_color"));
    }
    
}

- (void)chooseStudent:(TKStudentSegmentObject *)student
{
    _choosedStudent = student;
    [_segmentCotnrol chooseStudent:student];
    //老师在分发状态下只能在自己画布上绘制，回收状态可以在所有画布上绘制
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
        if ([student.ID isEqualToString:sBlackBoardCommon]) {
            _saveBtn.hidden = NO;
        } else {
            _saveBtn.hidden = YES;
        }
    }
    UIColor *backColor =  [_backgroundImages objectForKey:student.ID];
    if (backColor != nil) {
        _tkDrawView.backgroundColor = backColor;
    } else {
        _tkDrawView.sakura.backgroundColor(ThemeKP(@"tip_bg_sel_color"));
    }
}

- (void)drawPen:(UIButton *)btn
{
    _penBtn.selected = YES;
    _textBtn.selected = NO;
    _eraserBtn.selected = NO;
    
    [_selectorView showType:TKSelectorShowTypeMiddle];
    [_selectorView showOnMiniWhiteBoardAboveView:btn type:TKBrushToolTypeLine];
}

- (void)drawText:(UIButton *)btn
{
    _penBtn.selected = NO;
    _textBtn.selected = YES;
    _eraserBtn.selected = NO;
    
    [_selectorView showType:TKSelectorShowTypeMiddle];
    [_selectorView showOnMiniWhiteBoardAboveView:btn type:TKBrushToolTypeText];
}

- (void)drawEraser:(UIButton *)btn
{
    _penBtn.selected = NO;
    _textBtn.selected = NO;
    _eraserBtn.selected = YES;
    
    [_selectorView showType:TKSelectorShowTypeLow];
    [_selectorView showOnMiniWhiteBoardAboveView:btn type:TKBrushToolTypeEraser];
}

- (void)createRoomDirectory {
    
    _selLoginuserid = _loginuserid;
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *directory;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
      NSUserDomainMask, YES);
    
    if ([paths count] > 0)
    {
        directory = [[paths objectAtIndex:0]
              stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@", RoomDirectory]];
    }
    
    if (directory) {
        NSError *error = nil;
        BOOL isDir = YES;
        if([fileManager fileExistsAtPath:directory isDirectory:&isDir]) {
            [fileManager removeItemAtPath:directory error:&error];
        }
        
        if(![fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Error: Create folder failed %@: Error %@", directory, error);
        }
    }
}

- (NSString *)getLocalFilePath:(NSString*)fileName {
    
    NSString *jsonPath = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
      NSUserDomainMask, YES);
    
    if ([paths count] > 0)
    {
        if ([fileName isEqualToString:MaterialsJson]) {
            jsonPath = [[paths objectAtIndex:0]
                  stringByAppendingPathComponent:fileName];
        } else {
            jsonPath = [[paths objectAtIndex:0]
                  stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@/%@", RoomDirectory, fileName]];
        }
    }
    
    return jsonPath;
}

- (void)saveJsonMaterial
{
    if ([_savedData count] > 0 && [_pageIndexs objectForKey:[_tkDrawView fileid]]) {
        
        NSNumber *currentPage = [_pageIndexs objectForKey:[_tkDrawView fileid]];
        if (currentPage) {
            int pageIndex = [currentPage intValue];
            
            NSString *jsonFileName = [NSString stringWithFormat:@"%@_%@", _selLoginuserid, DrawingsJson];
            NSString *urlPath = [self getLocalFilePath:jsonFileName];
            if (urlPath != nil) {
                NSMutableDictionary *jsonDict;
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if ([fileManager fileExistsAtPath:urlPath]){
                    NSData* data = [NSData dataWithContentsOfFile:urlPath];
                    if (data != nil) {
                        NSError *error = nil;
                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                        if (json != nil) {
                            jsonDict = [json mutableCopy];
                        }
                    }
                }
                
                NSMutableArray *pageArray;
                if (jsonDict != nil) {
                    pageArray = [(NSArray*)[jsonDict objectForKey:@"datas"] mutableCopy];
                } else {
                    jsonDict = [[NSMutableDictionary alloc] init];
                }
                if (pageArray == nil) {
                    pageArray = [[NSMutableArray alloc] init];
                }
                
                
                NSMutableDictionary *pageDict = [[NSMutableDictionary alloc] init];
                [pageDict setObject:[NSNumber numberWithInt:pageIndex] forKey:@"pageid"];
                
                NSMutableArray *pageData;
                for (int num = 0; num < [pageArray count]; num++){
                    NSDictionary *pagedata = [pageArray objectAtIndex: num];
                    int pageId = [[pagedata objectForKey:@"pageid"] intValue];
                    if (pageId == pageIndex) {
                        NSArray *existData = [pagedata objectForKey:@"pagedata"];
                        if (existData != nil) {
                            pageData = [existData mutableCopy];
                        }
                        break;
                    }
                }
                
                if (pageData == nil) {
                    pageData = [[NSMutableArray alloc] init];
                }
                
                for (NSDictionary *dict in _savedData) {
                    NSDictionary *drawData = [dict objectForKey:@"data"];
                    if (drawData != nil) {
                        NSMutableDictionary *classDict = [[NSMutableDictionary alloc] init];
                        NSString *className = [drawData objectForKey:@"className"];
                        [classDict setObject:className forKey:@"className"];
                        
                        NSMutableDictionary *dataDict = [[NSMutableDictionary alloc] init];
                        NSDictionary *classData = [drawData objectForKey:@"data"];
                        if (classData != nil) {
                            if ([className isEqualToString:@"Text"]) {
                                double xPos = [[classData objectForKey:@"x"] doubleValue];
                                [dataDict setObject:[NSNumber numberWithDouble:xPos] forKey:@"x"];
                                
                                double yPos = [[classData objectForKey:@"y"] floatValue];
                                [dataDict setObject:[NSNumber numberWithDouble:yPos] forKey:@"y"];
                                
                                NSString *text = [classData objectForKey:@"text"];
                                if (text != nil) {
                                    [dataDict setObject:text forKey:@"text"];
                                }
                                
                                NSString *color = [classData objectForKey:@"color"];
                                if (color != nil) {
                                    [dataDict setObject:color forKey:@"color"];
                                }
                                
                                NSString *font = [classData objectForKey:@"font"];
                                if (font != nil) {
                                    [dataDict setObject:font forKey:@"font"];
                                }
                            } else {
                                int pointSize = [[classData objectForKey:@"pointSize"] intValue];
                                [dataDict setObject:[NSNumber numberWithInt:pointSize] forKey:@"pointSize"];
                                NSString *pointColor = [classData objectForKey:@"pointColor"];
                                if (pointColor != nil) {
                                    [dataDict setObject:pointColor forKey:@"pointColor"];
                                }
                                NSArray *pointCoordinatePairs = [classData objectForKey:@"pointCoordinatePairs"];
                                if (pointCoordinatePairs != nil) {
                                    [dataDict setObject:pointCoordinatePairs forKey:@"pointCoordinatePairs"];
                                }
                            }
                        }
                        
                        [classDict setObject:dataDict forKey:@"data"];
                        [pageData addObject:classDict];
                    }
                }
                [_savedData removeAllObjects];
                
                [pageDict setObject:pageData forKey:@"pagedata"];
                
                int replacedIndex = -1;
                for (int num = 0; num < [pageArray count]; num++){
                    NSDictionary *pagedata = [pageArray objectAtIndex: num];
                    int pageId = [[pagedata objectForKey:@"pageid"] intValue];
                    if (pageId == pageIndex) {
                        replacedIndex = num;
                        break;
                    }
                }
                
                if (replacedIndex < 0) {
                    [pageArray addObject:pageDict];
                } else {
                    [pageArray replaceObjectAtIndex:replacedIndex withObject:pageDict];
                }
                
                [jsonDict setObject:pageArray forKey:@"datas"];
                
                NSError *error;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict
                                                                   options:kNilOptions
                                                                     error:&error];

                if (! jsonData) {
                    NSLog(@"Got an error: %@", error);
                } else {
                    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
                     [jsonData writeToFile:urlPath atomically:YES];
                }
            }
        }
    }
}

- (void)downloadFileFromAWS:(NSString *)downloadKey filePath:(NSString *)urlPath dataType:(int)dataType
{
    AWSS3TransferUtilityDownloadCompletionHandlerBlock completionHandler = ^(AWSS3TransferUtilityDownloadTask *task, NSURL *location, NSData *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [[TKEduSessionHandle shareInstance] configureHUD:@"" aIsShow:NO];
                NSLog(@"error = %@", error);
            } else if (location) {
                if (dataType == MATERIAL_JSON) {
                    [self showDialog];
                } else if (dataType == BACK_IMAGE) {
                    [[TKEduSessionHandle shareInstance] configureHUD:@"" aIsShow:NO];
                    NSData* data = [NSData dataWithContentsOfFile:location.path];
                    if (data != nil) {
                        [self loadImageFromData:data];
                    }
                } else if (dataType == DATA_JSON) {
                    NSData* data = [NSData dataWithContentsOfFile:location.path];
                    if (data != nil) {
                        [self loadJsonFromData:data pageIndex:1];
                    }
                }
            }
        });
    };
    
    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility defaultS3TransferUtility];
    [[transferUtility downloadToURL:[NSURL fileURLWithPath:urlPath]
                             bucket:S3BucketName
                                key:downloadKey
                         expression:nil
                           completionHandler:completionHandler] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            [[TKEduSessionHandle shareInstance] configureHUD:@"" aIsShow:NO];
            NSLog(@"Error: %@", task.error);
        }
        return nil;
    }];
}

- (void)loadJsonFromData:(NSData*)jsonData pageIndex:(int)pageIndex
{
    NSError *error = nil;
    NSDictionary *dataDict = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
    if (dataDict) {
        NSArray *pageArray = [dataDict objectForKey:@"datas"];
        NSArray *drawingsArray = nil;
        for (NSDictionary *pagedata in pageArray){
            int pageId = [[pagedata objectForKey:@"pageid"] intValue];
            if (pageId == pageIndex) {
                drawingsArray = [pagedata objectForKey:@"pagedata"];
                break;
            }
        }
        
        if (drawingsArray != nil) {
            for (NSDictionary *drawingDict in drawingsArray){
                [self renderJsonData:drawingDict];
            }
        }
    }
}

- (void)loadImageFromData:(NSData *)jpegData {
    
    UIImage *backImage = [UIImage imageWithData:jpegData];
    if (backImage != nil) {
        
        //calculate rect
        CGFloat aspect = backImage.size.width / backImage.size.height;
        CGSize targetSize;
        CGRect targetRect;
        if (_tkDrawView.frame.size.width / aspect <= _tkDrawView.frame.size.height)
        {
            targetSize = CGSizeMake(_tkDrawView.frame.size.width, _tkDrawView.frame.size.width / aspect);
            //targetRect = CGRectMake(0.0f, (_tkDrawView.frame.size.height - targetSize.height)/2, targetSize.width, targetSize.height);
        }
        else
        {
            targetSize = CGSizeMake(_tkDrawView.frame.size.height * aspect, _tkDrawView.frame.size.height);
            //targetRect = CGRectMake((_tkDrawView.frame.size.width - targetSize.width)/2, 0.0f, targetSize.width, targetSize.height);
        }
        targetRect = CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height);
        
        //UIGraphicsBeginImageContext(_tkDrawView.frame.size);
        UIGraphicsBeginImageContextWithOptions(_tkDrawView.frame.size, NO, 0);
        [backImage drawInRect:targetRect];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIColor *backColor = [UIColor colorWithPatternImage:image];
        _tkDrawView.backgroundColor = backColor;
        [_backgroundImages setObject:backColor forKey:[_tkDrawView fileid]];
    }
}

- (void)uploadFileToAWS:(NSString *)uploadKey filePath:(NSString *)urlPath {

    AWSS3TransferUtilityUploadCompletionHandlerBlock completionHandler = ^(AWSS3TransferUtilityUploadTask *task, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *uploadResult = @"Successfully Uploaded";
            if (error) {
                uploadResult = @"Failed to Upload";
            }
            
            SelectionDialog *dialog = [[SelectionDialog alloc] initWithTitle:uploadResult closeButtonTitle:@"Ok"];
            [dialog show];
        });
    };
    
    AWSS3TransferUtility *transferUtility = [AWSS3TransferUtility defaultS3TransferUtility];
    [[transferUtility uploadFile:[NSURL fileURLWithPath:urlPath]
                          bucket:S3BucketName
                             key:uploadKey
                     contentType:@"application/json"
                      expression:nil
               completionHandler:completionHandler] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            NSLog(@"Error: %@", task.error);
        }
        return nil;
    }];
}

- (void)downloadMaterialsListFromAWS {
    
    if (_selLoginuserid) {
        NSString *fileName = MaterialsJson;
        NSString *downloadKey = [NSString stringWithFormat:@"user/%@/%@", _selLoginuserid, fileName];
        NSString *urlPath = [self getLocalFilePath:[NSString stringWithFormat:@"%@_%@", _selLoginuserid, fileName]];
        
        [self downloadFileFromAWS:downloadKey filePath:urlPath dataType:MATERIAL_JSON];
    }
}

- (void)uploadMaterialsJsonToAWS {
    
    NSString *currentTapKey = [_tkDrawView fileid];
    if ([_classNames count] > 0) {
        NSString *className = [_classNames objectForKey:currentTapKey];
        
        NSString *fileName = DrawingsJson;
        NSString *uploadKey = [NSString stringWithFormat:@"user/%@/%@/%@", _selLoginuserid, className, fileName];
        NSString *urlPath = [self getLocalFilePath:[NSString stringWithFormat:@"%@_%@", _selLoginuserid, fileName]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:urlPath]){
            [self uploadFileToAWS:uploadKey filePath:urlPath];
        }
    }
}

- (void)showDialog {
    NSString *urlPath = [self getLocalFilePath:[NSString stringWithFormat:@"%@_%@", _selLoginuserid, MaterialsJson]];
    
    if (urlPath != nil) {
        NSData *jsonData = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:urlPath]];
        NSError *error = nil;
        NSDictionary *materialDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        if (materialDict) {
            NSArray *materialArray = [materialDict objectForKey:@"materials"];
            if (materialArray != nil && [materialArray count] > 0) {
                if (selClassDialog == nil || [selClassDialog superview] == nil) {
                    selClassDialog = [[SelectionDialog alloc] initWithTitle:@"Select Material" closeButtonTitle:@"Close"];
                    __weak SelectionDialog *weakDialog = selClassDialog;
                    for (int index = 0; index < [materialArray count]; index++){
                        NSDictionary *materials = [materialArray objectAtIndex:index];
                        NSString *materialName = [materials objectForKey:@"name"];
                        NSArray *materialData = [materials objectForKey:@"data"];
                        
                        [selClassDialog addItemWithItem:materialName didTapHandler:^{
                            [weakDialog close];
                            [self sendMaterialsInfo:materialName totalNumber:(int)[materialData count] pageId:1];
                        }];
                    }
                    NSLog(@"superview: %@", [selClassDialog superview]);
                    [selClassDialog show];
                    NSLog(@"superview: %@", [selClassDialog superview]);
                }
            }
        }
    }
}

- (void)goToPrevMaterial:(UIButton *)btn
{
    NSString *currentTapKey = [_tkDrawView fileid];
    if ([_pageIndexs objectForKey:currentTapKey]) {
        NSNumber *currentPage = [_pageIndexs objectForKey:currentTapKey];
        if (currentPage) {
            NSNumber *totalNumber = [_totalNumbers objectForKey:currentTapKey];
            if ([currentPage intValue] > 1) {
                NSString *className = [_classNames objectForKey:currentTapKey];
                
                [self sendMaterialsInfo:className totalNumber:[totalNumber intValue] pageId:[currentPage intValue]-1];
            }
        }
    }
}

- (void)goToNextMaterial:(UIButton *)btn
{
    NSString *currentTapKey = [_tkDrawView fileid];
    if ([_pageIndexs objectForKey:currentTapKey]) {
        NSNumber *currentPage = [_pageIndexs objectForKey:currentTapKey];
        if (currentPage) {
            NSNumber *totalNumber = [_totalNumbers objectForKey:currentTapKey];
            if ([currentPage intValue] < [totalNumber intValue]) {
                NSString *className = [_classNames objectForKey:currentTapKey];
                
                [self sendMaterialsInfo:className totalNumber:[totalNumber intValue] pageId:[currentPage intValue]+1];
            }
        }
    }
}

- (void)uploadClassMaterial:(UIButton *)btn
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self.selLoginuserid isEqualToString:self.loginuserid]) {
            [self saveJsonMaterial];
        }
        [self uploadMaterialsJsonToAWS];
    });
}

- (void)loadClassMaterial:(UIButton *)btn
{
    [self downloadMaterialsListFromAWS];
}

- (void)sendMaterialsInfo:(NSString *)className totalNumber:(int)totalNumber pageId:(int)currentPage {
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    
    NSString *stateString;
    switch (self.state) {
        case TKMiniWhiteBoardStateDispenseed:
        {
            stateString = s_Dispenseed;
            break;
        }
        case TKMiniWhiteBoardStateAgainDispenseed:
        {
            stateString = s_AgainDispenseed;
            break;
        }
        case TKMiniWhiteBoardStateRecycle:
        {
            stateString = s_Recycle;
            break;
        }
        case TKMiniWhiteBoardStatePrepareing:
        {
            stateString = s_Prepareing;
            break;
        }
            
        default:
            break;
    }
    
    [dic setObject:stateString forKey:sBlackBoardState];
    [dic setObject:[_tkDrawView fileid] forKey:sCurrentTapKey];
    [dic setObject:[NSNumber numberWithInt:currentPage] forKey:sCurrentTapPage];
    [dic setObject:[TKEduSessionHandle shareInstance].localUser.peerID forKey:sFromId];
    
    NSMutableDictionary *filedata = [[NSMutableDictionary alloc] init];
    [filedata setObject:[NSNumber numberWithInt:currentPage] forKey:sCurrPage];
    [filedata setObject:[NSNumber numberWithInt:totalNumber] forKey:sPageNum];
    [filedata setObject:className forKey:sCourseWare];
    [filedata setObject:[NSString stringWithFormat:@"user/%@/%@/", _selLoginuserid, className] forKey:sSwfPath];
    
    [dic setObject:filedata forKey:sFileData];

    NSData *newData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    NSString *data = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
    NSString *sendData = [data stringByReplacingOccurrencesOfString:@"\n" withString:@""];

    [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sShowBoardPage ID:sDocumentFilePage_ShowPage To:sTellAll Data:sendData Save:YES AssociatedMsgID:nil AssociatedUserID:nil expires:0 completion:nil];
}

- (void)renderJsonData:(NSDictionary*)shapeData {
    NSString *shapeid = [NSString stringWithFormat:@"%p-%f", self, [[NSDate date] timeIntervalSince1970]];
    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
    
    [dic setObject:shapeData forKey:@"data"];
    [dic setObject:@"AddShapeAction" forKey:@"actionName"];
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
        [dic setObject:_tkDrawView.fileid forKey:@"whiteboardID"];
        switch (self.state) {
            case TKMiniWhiteBoardStateDispenseed:

            case TKMiniWhiteBoardStateRecycle:

            case TKMiniWhiteBoardStateAgainDispenseed:
            {
                [dic setObject:@(NO) forKey:@"isBaseboard"];
                break;
            }
            case TKMiniWhiteBoardStatePrepareing:
            {
                [dic setObject:@(YES) forKey:@"isBaseboard"];
                break;
            }
            default:
                break;
        }
    }
    
    int pageIndex = 1;
    NSString *currentTapKey = [_tkDrawView fileid];
    if ([_pageIndexs objectForKey:currentTapKey]) {
        NSNumber *currentPage = [_pageIndexs objectForKey:currentTapKey];
        if (currentPage) {
            [dic setObject:currentPage forKey:sCurrentTapPage];
            pageIndex = [currentPage intValue];
        }
    }
    [dic setObject:[NSNumber numberWithInt:pageIndex] forKey:@"currentTapPage"];
    
    NSString *shapeID = [NSString stringWithFormat:@"%@###_SharpsChange_%@_%d", shapeid, currentTapKey, pageIndex];
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
        [dic setObject:[TKEduSessionHandle shareInstance].localUser.peerID forKey:@"whiteboardID"];
        [dic setObject:@(NO) forKey:@"isBaseboard"];
    }
    
    [dic setObject:[TKEduSessionHandle shareInstance].localUser.nickName forKey:@"nickname"];

    NSData *newData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    NSString *data = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
    NSString *s1 = [data stringByReplacingOccurrencesOfString:@"\n" withString:@""];

    [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sSharpsChange ID:shapeID To:sTellAll Data:s1 Save:YES AssociatedMsgID:sBlackBoard_new AssociatedUserID:nil expires:0 completion:nil];
}

//选择画笔工具回调数据
- (void)brushSelectorViewDidSelectDrawType:(TKDrawType)type color:(NSString *)hexColor widthProgress:(float)progress
{
    [_tkDrawView setDrawType:type hexColor:hexColor progress:progress];
}

//发送小白板绘制数据
- (void)addSharpWithFileID:(NSString *)fileid shapeID:(NSString *)shapeID shapeData:(NSData *)shapeData
{
    [_selectorView removeFromSuperview];
    
    /******************************************************************************************************/
    //老师：回收状态下可以在任意画布上绘制，分发状态下只能在自己画布上绘制
    //学生：回收状态无法绘制，分发状态下可以在自己画布上绘制
    /*if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
        if (self.state == TKMiniWhiteBoardStateDispenseed || self.state == TKMiniWhiteBoardStateAgainDispenseed) {
            if (![fileid isEqualToString:sBlackBoardCommon]) {
                return;
            }
        }
    }*/
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
        if (self.state == TKMiniWhiteBoardStateDispenseed || self.state == TKMiniWhiteBoardStateAgainDispenseed) {
            if (![fileid isEqualToString:[TKEduSessionHandle shareInstance].localUser.peerID]) {
                return;
            }
        }
        if (self.state == TKMiniWhiteBoardStateRecycle) {
            return;
        }
    }
    /******************************************************************************************************/
    
    NSMutableDictionary *dic = [NSJSONSerialization JSONObjectWithData:shapeData options:NSJSONReadingMutableContainers error:nil];

    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
        [dic setObject:_tkDrawView.fileid forKey:@"whiteboardID"];
        switch (self.state) {
            case TKMiniWhiteBoardStateDispenseed:

            case TKMiniWhiteBoardStateRecycle:

            case TKMiniWhiteBoardStateAgainDispenseed:
            {
                [dic setObject:@(NO) forKey:@"isBaseboard"];
                break;
            }
            case TKMiniWhiteBoardStatePrepareing:
            {
                [dic setObject:@(YES) forKey:@"isBaseboard"];
                break;
            }
            default:
                break;
        }
    }
    
    NSString *currentTapKey = [_tkDrawView fileid];
    if ([_pageIndexs objectForKey:currentTapKey]) {
        NSNumber *currentPage = [_pageIndexs objectForKey:currentTapKey];
        if (currentPage) {
            [dic setObject:currentPage forKey:sCurrentTapPage];
        }
    }
    
    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
        [dic setObject:[TKEduSessionHandle shareInstance].localUser.peerID forKey:@"whiteboardID"];
        [dic setObject:@(NO) forKey:@"isBaseboard"];
    }
    
    [dic setObject:[TKEduSessionHandle shareInstance].localUser.nickName forKey:@"nickname"];

    NSData *newData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    NSString *data = [[NSString alloc] initWithData:newData encoding:NSUTF8StringEncoding];
    NSString *s1 = [data stringByReplacingOccurrencesOfString:@"\n" withString:@""];

    [[TKEduSessionHandle shareInstance] sessionHandlePubMsg:sSharpsChange ID:shapeID To:sTellAll Data:s1 Save:YES AssociatedMsgID:sBlackBoard_new AssociatedUserID:nil expires:0 completion:nil];
    
    _panG.enabled = YES;
}

//每次隐藏后清理数据
- (void)clear
{
    _choosedStudent = nil;
    [_tkDrawView clearDataAfterClass];
    [_tkDrawView setNeedsDisplay];
    [_segmentCotnrol resetUI];
}

//画笔工具超出了self，保证超出部分也可点击
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    //移除画笔选择工具
    if ([_selectorView pointInside:[self convertPoint:point toView:_selectorView] withEvent:event] == NO) {

        [_selectorView removeFromSuperview];
    }
        
    //触摸到就放置最前
    [self.superview bringSubviewToFront:self];
    
    _panG.enabled = YES;
    if (CGRectContainsPoint(self.bounds, point)) {
        return YES;
    }
    
    if (CGRectContainsPoint(_selectorView.frame, point)) {
        _panG.enabled = NO;
        return YES;
    }
    
    return NO;
}

- (void)handleSignal:(NSDictionary *)dictionary isDel:(BOOL)isDel
{
    if (!dictionary || dictionary.count == 0) {
        return;
    }
    
    //信令相关性
    NSString *associatedMsgID = [dictionary objectForKey:sAssociatedMsgID];
    
    //信令名
    NSString *msgName = [dictionary objectForKey:sName];
    
    //信令内容
    id dataObject = [dictionary objectForKey:@"data"];
    NSMutableDictionary *data = nil;
    if ([dataObject isKindOfClass:[NSDictionary class]]) {
        data = [NSMutableDictionary dictionaryWithDictionary:dataObject];
    }
    if ([dataObject isKindOfClass:[NSString class]]) {
        data = [NSJSONSerialization JSONObjectWithData:[(NSString *)dataObject dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    }
    
    //大并发教室
    if ([msgName isEqualToString:@"BigRoom"]) {
        self.bigRoom = YES;
        return;
    }
    
    //小白板隐藏
    if (isDel) {
        if ([msgName isEqualToString:sBlackBoard_new]) {
            self.hidden = YES;
            [self clear];
            [_prepareData removeAllObjects];
            return;
        }
    }
    
    NSNumber *currentTapPage = [data objectForKey:sCurrentTapPage];
    
    int pageIndex = 1;
    if (currentTapPage) {
        pageIndex = [currentTapPage intValue];
    }
    
    if ([msgName isEqualToString:sBlackBoard_new]) {
        //小白板状态
        //_prepareing       准备
        //_dispenseed       分发
        //_recycle          收回
        //_againDispenseed  再次分发
        NSString *blackBoardState = [data objectForKey:sBlackBoardState];
        NSString *currentTapKey = [data objectForKey:sCurrentTapKey];
        
        //状态切换以及页签切换
        if ([blackBoardState isEqualToString:s_Prepareing]) {
            //修改小白板状态为TKMiniWhiteBoardStatePrepareing，此状态下老师绘制全部保存，当分发时有学生加进来则将_prepareData绘制到学生上。
            //最终结果就是老师在TKMiniWhiteBoardStatePrepareing状态下的绘制将同步到所有学生。
            [self switchStates:TKMiniWhiteBoardStatePrepareing];
            
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                [_tkDrawView setWorkMode:TKWorkModeViewer];
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = [TKEduSessionHandle shareInstance].localUser.peerID;
                student.nickName = [TKEduSessionHandle shareInstance].localUser.nickName;
                [self chooseStudent:student];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                [self show];
                [_tkDrawView setWorkMode:TKWorkModeControllor];
                [_tkDrawView switchToFileID:sBlackBoardCommon pageID:pageIndex refreshImmediately:YES];
                [self chooseStudent:[TKStudentSegmentObject teacher]];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                [self show];
                [_tkDrawView switchToFileID:sBlackBoardCommon pageID:pageIndex refreshImmediately:YES];
                [self chooseStudent:[TKStudentSegmentObject teacher]];
            }
            
        }
        if ([blackBoardState isEqualToString:s_Dispenseed]) {
            [self show];
            [self switchStates:TKMiniWhiteBoardStateDispenseed];
            //分发，学生端只显示自己画布
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                [_tkDrawView setWorkMode:TKWorkModeControllor];
                [_tkDrawView switchToFileID:[TKEduSessionHandle shareInstance].localUser.peerID pageID:pageIndex refreshImmediately:YES];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                //老师切换切换画布
                [_tkDrawView setWorkMode:TKWorkModeControllor];
                [_tkDrawView switchToFileID:currentTapKey pageID:pageIndex refreshImmediately:YES];
            }
            
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                [_tkDrawView switchToFileID:currentTapKey pageID:pageIndex refreshImmediately:YES];
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = currentTapKey;
                student.currentPage = pageIndex;
                [self chooseStudent:student];
            }
            
        }
        if ([blackBoardState isEqualToString:s_AgainDispenseed]) {
            [self show];
            [self switchStates:TKMiniWhiteBoardStateAgainDispenseed];
            //再次分发，学生端只显示自己画布
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                [_tkDrawView switchToFileID:[TKEduSessionHandle shareInstance].localUser.peerID pageID:pageIndex refreshImmediately:YES];
                [_tkDrawView setWorkMode:TKWorkModeControllor];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = currentTapKey;
                student.currentPage = pageIndex;
                [_tkDrawView setWorkMode:TKWorkModeControllor];
                [self chooseStudent:student];
                [_tkDrawView switchToFileID:currentTapKey pageID:pageIndex refreshImmediately:YES];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = currentTapKey;
                student.currentPage = pageIndex;
                [self chooseStudent:student];
                [_tkDrawView switchToFileID:currentTapKey pageID:pageIndex refreshImmediately:YES];
            }
        }
        
        if ([blackBoardState isEqualToString:s_Recycle]) {
            [self show];
            [self switchStates:TKMiniWhiteBoardStateRecycle];
            //回收，显示所有画布，根据currentTapKey选择显示的画布，blackBoardCommon代表老师
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = currentTapKey;
                student.currentPage = pageIndex;
                [self chooseStudent:student];
                [_tkDrawView switchToFileID:student.ID pageID:student.currentPage refreshImmediately:YES];
                [_tkDrawView setWorkMode:TKWorkModeViewer];
                [_selectorView removeFromSuperview];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = currentTapKey;
                student.currentPage = pageIndex;
                [self chooseStudent:student];
                [_tkDrawView setWorkMode:TKWorkModeControllor];
                [_tkDrawView switchToFileID:currentTapKey pageID:pageIndex refreshImmediately:YES];
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Patrol) {
                TKStudentSegmentObject *student = [[TKStudentSegmentObject alloc] init];
                student.ID = currentTapKey;
                student.currentPage = pageIndex;
                [self chooseStudent:student];
                [_tkDrawView switchToFileID:currentTapKey pageID:pageIndex refreshImmediately:YES];
            }
        }
    }
    
    if ([associatedMsgID isEqualToString:sBlackBoard_new]) {
        //绘制
        if ([msgName isEqualToString:sSharpsChange]) {
            NSString *fileID = [data objectForKey:sWhiteboardID];
            
            NSNumber *isBaseboard = [data objectForKey:@"isBaseboard"];
            if (isBaseboard.boolValue) {
                //主画布数据需要同步到每个添加进来的学生
                [_prepareData addObject:data];
            }
            
            NSString *shapeID = [dictionary objectForKey:@"id"];
            if (shapeID) {
                NSArray *shapeArray = [shapeID componentsSeparatedByString:@"_"];
                if ([shapeArray count] > 3) {
                    NSString *fileid = [shapeArray objectAtIndex:2];
                    NSString *pageid = [shapeArray objectAtIndex:3];
                    if ([pageid isEqualToString:[NSString stringWithFormat:@"%d",pageIndex]]) {
                        bool isSaved = false;
                        if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                            if ([fileid isEqualToString:sBlackBoardCommon]) {
                                isSaved = true;
                            }
                        } else if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                            if ([fileid isEqualToString:[TKEduSessionHandle shareInstance].localUser.peerID]) {
                                isSaved = true;
                            }
                        }
                        
                        if (isSaved) {
                            [_savedData addObject:data];
                        }
                        
                        [_tkDrawView switchToFileID:fileID pageID:pageIndex refreshImmediately:[fileID isEqualToString:_choosedStudent.ID]];
                        [_tkDrawView addDrawData:data refreshImmediately:[fileID isEqualToString:_choosedStudent.ID]];
                        
                    }
                }
            }
            
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                //学生分发状态只显示自己画布
                if (_state == TKMiniWhiteBoardStateDispenseed || _state == TKMiniWhiteBoardStateAgainDispenseed || _state == TKMiniWhiteBoardStatePrepareing) {
                    [_tkDrawView switchToFileID:[TKEduSessionHandle shareInstance].localUser.peerID pageID:pageIndex refreshImmediately:YES];
                }
            }
            if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                [_tkDrawView switchToFileID:self.choosedStudent.ID pageID:pageIndex refreshImmediately:[fileID isEqualToString:self.choosedStudent.ID]];
            }
        }
        
        //新进角色
        if ([msgName isEqualToString:sUserHasNewBlackBoard]) {
            
            TKStudentSegmentObject *obj = [[TKStudentSegmentObject alloc] initWithDictionary:data];
            BOOL addRestult = [self addStudent:obj];
            
            //创建收到的新学生白板
            if (!isDel) {
                if (addRestult) {
                    /*[_prepareData enumerateObjectsUsingBlock:^(NSDictionary *_Nonnull data, NSUInteger idx, BOOL * _Nonnull stop) {
                        [_tkDrawView switchToFileID:obj.ID pageID:obj.currentPage refreshImmediately:NO];
                        [_tkDrawView addDrawData:data refreshImmediately:NO];
                    }];*/
                    
                    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                        if (_state == TKMiniWhiteBoardStateDispenseed || _state == TKMiniWhiteBoardStateAgainDispenseed) {
                            //分发再次分发状态都切换到自己画布
                            [_tkDrawView switchToFileID:[TKEduSessionHandle shareInstance].localUser.peerID pageID:pageIndex refreshImmediately:YES];
                        } else {
                            [_tkDrawView switchToFileID:_choosedStudent.ID pageID:pageIndex refreshImmediately:YES];
                        }
                    }
                    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher || [TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                        [_tkDrawView switchToFileID:sBlackBoardCommon pageID:pageIndex refreshImmediately:YES];
                    }
                }
            } else {
                [self removeStudent:obj];
                //删除正在显示的student
                if ([obj.ID isEqualToString:_choosedStudent.ID]) {
                    if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Teacher) {
                        // 老师重新指定 当前标签
                        [self didSelectStudent:[TKStudentSegmentObject teacher]];
                        
                    } else if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Playback) {
                        
                        [_tkDrawView switchToFileID:sBlackBoardCommon pageID:pageIndex refreshImmediately:YES];
                        [self chooseStudent:[TKStudentSegmentObject teacher]];
                        
                    } else if ([TKEduSessionHandle shareInstance].localUser.role == TKUserType_Student) {
                        
                        if (_state == TKMiniWhiteBoardStateRecycle) {
                            [_tkDrawView switchToFileID:sBlackBoardCommon pageID:pageIndex refreshImmediately:YES];
                            [self chooseStudent:[TKStudentSegmentObject teacher]];
                        }
                    }
                }
            }
        }
    }
    
    if ([msgName isEqualToString:sShowBoardPage]) {
        NSString *currentTapKey = [data objectForKey:sCurrentTapKey];
        if ([currentTapKey isEqualToString:[_tkDrawView fileid]]) {
            NSDictionary *fileData = [data objectForKey:sFileData];
            if (fileData) {
                //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    if ([self.selLoginuserid isEqualToString:self.loginuserid]) {
                        [self saveJsonMaterial];
                    }
                //});
                
                NSNumber *currentPage = [fileData objectForKey:sCurrPage];
                NSNumber *totalNumber = [fileData objectForKey:sPageNum];
                NSString *className = [fileData objectForKey:sCourseWare];
                NSString *swfpath = [fileData objectForKey:sSwfPath];
                
                [_pageIndexs setObject:currentPage forKey:currentTapKey];
                [_classNames setObject:className forKey:currentTapKey];
                [_totalNumbers setObject:totalNumber forKey:currentTapKey];
                
                [_tkDrawView switchToFileID:currentTapKey pageID:[currentPage intValue] refreshImmediately:YES];
                
                NSString *fileName = [NSString stringWithFormat:@"%03d.%@", [currentPage intValue], @"jpg"];
                NSString *urlPath = [self getLocalFilePath:[NSString stringWithFormat:@"%@_%@", _selLoginuserid, fileName]];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                BOOL isLoadedImageFromFile = NO;
                if ([fileManager fileExistsAtPath:urlPath]) {
                    NSData* data = [NSData dataWithContentsOfFile:urlPath];
                    [self loadImageFromData:data];
                    isLoadedImageFromFile = YES;
                } else {
                    [[TKEduSessionHandle shareInstance] configureHUD:@"" aIsShow:YES];
                    NSString *downloadKey = [NSString stringWithFormat:@"%@%@", swfpath, fileName];
                    [self downloadFileFromAWS:downloadKey filePath:urlPath dataType:BACK_IMAGE];
                }
                
                [_savedData removeAllObjects];
                urlPath = [self getLocalFilePath:[NSString stringWithFormat:@"%@_%@", _selLoginuserid, DrawingsJson]];
                if ([fileManager fileExistsAtPath:urlPath]) {
                    if (!isLoadedImageFromFile) {
                        NSData* data = [NSData dataWithContentsOfFile:urlPath];
                        if (data != nil) {
                            [self loadJsonFromData:data pageIndex:[currentPage intValue]];
                        }
                    }
                } else if ([currentPage intValue] == 1) {
                    NSString *downloadKey = [NSString stringWithFormat:@"%@%@", swfpath, DrawingsJson];
                    [self downloadFileFromAWS:downloadKey filePath:urlPath dataType:DATA_JSON];
                }
            }
        }
    }
}

- (void)show
{
    if (self.isBigRoom && [TKEduSessionHandle shareInstance].localUser.publishState == 0) {
        //大并发教室学生未上台，不显示小白板
        self.hidden = YES;
        return;
    }
    
    [self.superview bringSubviewToFront:self];
    self.hidden = NO;
}

@end
