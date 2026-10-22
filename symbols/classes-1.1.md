# Project classes (recovered from VMT and RTTI)

Offsets are hex. Field offsets include the VMT pointer at +0.

## TPos = class(TObject)  — unit uTool

- VMT: `0x460a00`, instance size: `0xc` (parent: `0x4`)

## TPosList = class(TList)  — unit uTool

- VMT: `0x460a54`, instance size: `0x14` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TRectPos = class(TPos)  — unit uTool

- VMT: `0x460abc`, instance size: `0x14` (parent: `0xc`)

## TRectPosList = class(TPosList)  — unit uTool

- VMT: `0x460b14`, instance size: `0x14` (parent: `0x14`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TformDebugShow = class(TForm)  — unit fShow

- VMT: `0x4616f4`, instance size: `0x2ec` (parent: `0x2d0`)
- Published fields:
  - `+0x2d0` OKBtn: TBitBtn
  - `+0x2d4` PaintBox1: TPaintBox
  - `+0x2d8` Label1: TLabel
  - `+0x2dc` memText: TMemo
- Published methods:
  - `0x461914` PaintBox1Paint
  - `0x4619f0` OKBtnKeyPress
  - `0x4619fc` FormResize
- Virtual method table (slot offset, address, status):
  - (56 inherited slots omitted)

## TBmpSurface = class(TSurface)  — unit SprBmp

- VMT: `0x461c4c`, instance size: `0x3c` (parent: `0x30`)
- Overrides of TObject virtuals: Destroy=`0x461eac`
- Virtual method table (slot offset, address, status):
  - `+0x08` `0x462a94` override TBmpSurface.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - `+0x20` `0x462530` override TBmpSurface.Virtual20 (slot introduced by TGraphic: @AbstractError)
  - `+0x2c` `0x462524` override TBmpSurface.Virtual2C (slot introduced by TGraphic: @AbstractError)
  - `+0x50` `0x462b20` override TBmpSurface.Virtual50 (slot introduced by TGraphic: @AbstractError)
  - `+0x54` `0x462bd4` override TBmpSurface.Virtual54 (slot introduced by TGraphic: @AbstractError)
  - `+0x60` `0x461dc8` override TBmpSurface.Virtual60 (slot introduced by TSurface: TSurface.Virtual60)
  - `+0x64` `0x461ef8` override TBmpSurface.Virtual64 (slot introduced by TSurface: @AbstractError)
  - `+0x68` `0x461f20` override TBmpSurface.Virtual68 (slot introduced by TSurface: @AbstractError)
  - `+0x6c` `0x461f74` override TBmpSurface.Virtual6C (slot introduced by TSurface: @AbstractError)
  - `+0x70` `0x461f80` override TBmpSurface.Virtual70 (slot introduced by TSurface: @AbstractError)
  - `+0x74` `0x461fc0` override TBmpSurface.Virtual74 (slot introduced by TSurface: @AbstractError)
  - `+0x78` `0x462004` override TBmpSurface.Virtual78 (slot introduced by TSurface: @AbstractError)
  - `+0x7c` `0x462058` override TBmpSurface.Virtual7C (slot introduced by TSurface: @AbstractError)
  - `+0x80` `0x46250c` override TBmpSurface.Virtual80 (slot introduced by TSurface: @AbstractError)
  - `+0x84` `0x462518` override TBmpSurface.Virtual84 (slot introduced by TSurface: TSurface.Virtual84)
  - `+0x88` `0x461ef0` override TBmpSurface.Virtual88 (slot introduced by TSurface: TSurface.Virtual88)
  - `+0x8c` `0x46253c` override TBmpSurface.Virtual8C (slot introduced by TSurface: @AbstractError)
  - `+0x90` `0x462f24` override TBmpSurface.Virtual90 (slot introduced by TSurface: @AbstractError)
  - `+0x94` `0x462588` override TBmpSurface.Virtual94 (slot introduced by TSurface: @AbstractError)
  - `+0x98` `0x462544` override TBmpSurface.Virtual98 (slot introduced by TSurface: @AbstractError)
  - `+0x9c` `0x462548` override TBmpSurface.Virtual9C (slot introduced by TSurface: @AbstractError)
  - `+0xa0` `0x4626c0` override TBmpSurface.VirtualA0 (slot introduced by TSurface: @AbstractError)
  - `+0xa4` `0x462980` override TBmpSurface.VirtualA4 (slot introduced by TSurface: @AbstractError)
  - `+0xa8` `0x462bf0` override TBmpSurface.VirtualA8 (slot introduced by TSurface: TSurface.VirtualA8)
  - `+0xac` `0x462e3c` override TBmpSurface.VirtualAC (slot introduced by TSurface: @AbstractError)
  - `+0xb0` `0x462f70` override TBmpSurface.VirtualB0 (slot introduced by TSurface: @AbstractError)
  - `+0xb4` `0x462fe4` override TBmpSurface.VirtualB4 (slot introduced by TSurface: @AbstractError)
  - `+0xb8` `0x463058` override TBmpSurface.VirtualB8 (slot introduced by TSurface: @AbstractError)
  - (20 inherited slots omitted)

## TSurface = class(TGraphic)  — unit uSurface

- VMT: `0x463280`, instance size: `0x30` (parent: `0x1c`)
- Virtual method table (slot offset, address, status):
  - `+0x0c` `0x463370` override TSurface.Create (slot introduced by TGraphic: TGraphic.Create)
  - `+0x14` `0x4633f0` override TSurface.Virtual14 (slot introduced by TGraphic: @AbstractError)
  - `+0x1c` `0x46358c` override TSurface.Virtual1C (slot introduced by TGraphic: @AbstractError)
  - `+0x34` `0x463560` override TSurface.Virtual34 (slot introduced by TGraphic: @AbstractError)
  - `+0x40` `0x463534` override TSurface.Virtual40 (slot introduced by TGraphic: @AbstractError)
  - `+0x60` `0x4633b0` NEW TSurface.Virtual60
  - `+0x64` `0x4029ec` NEW @AbstractError
  - `+0x68` `0x4029ec` NEW @AbstractError
  - `+0x6c` `0x4029ec` NEW @AbstractError
  - `+0x70` `0x4029ec` NEW @AbstractError
  - `+0x74` `0x4029ec` NEW @AbstractError
  - `+0x78` `0x4029ec` NEW @AbstractError
  - `+0x7c` `0x4029ec` NEW @AbstractError
  - `+0x80` `0x4029ec` NEW @AbstractError
  - `+0x84` `0x4633ec` NEW TSurface.Virtual84
  - `+0x88` `0x4635b0` NEW TSurface.Virtual88
  - `+0x8c` `0x4029ec` NEW @AbstractError
  - `+0x90` `0x4029ec` NEW @AbstractError
  - `+0x94` `0x4029ec` NEW @AbstractError
  - `+0x98` `0x4029ec` NEW @AbstractError
  - `+0x9c` `0x4029ec` NEW @AbstractError
  - `+0xa0` `0x4029ec` NEW @AbstractError
  - `+0xa4` `0x4029ec` NEW @AbstractError
  - `+0xa8` `0x46343c` NEW TSurface.VirtualA8
  - `+0xac` `0x4029ec` NEW @AbstractError
  - `+0xb0` `0x4029ec` NEW @AbstractError
  - `+0xb4` `0x4029ec` NEW @AbstractError
  - `+0xb8` `0x4029ec` NEW @AbstractError
  - `+0xbc` `0x463674` NEW TSurface.VirtualBC
  - (19 inherited slots omitted)

## TPixie = class(TComponent)  — unit uPixie

- VMT: `0x46389c`, instance size: `0x68` (parent: `0x24`)
- Published properties:
  - OnMouseDown: TMouseEvent read field +0x48 write field +0x48
  - OnMouseMove: TMouseMoveEvent read field +0x58 write field +0x58
  - OnMouseUp: TMouseEvent read field +0x50 write field +0x50
  - OnMouseLeave: TNotifyEvent read field +0x60 write field +0x60
- Virtual method table (slot offset, address, status):
  - `+0x30` `0x4639e4` NEW TPixie.Virtual30
  - `+0x34` `0x4639e8` NEW TPixie.Virtual34
  - `+0x38` `0x4639f0` NEW TPixie.Virtual38
  - `+0x3c` `0x463a10` NEW TPixie.Virtual3C
  - `+0x40` `0x4639f8` NEW TPixie.Virtual40
  - `+0x44` `0x463a00` NEW TPixie.Virtual44
  - `+0x48` `0x463a08` NEW TPixie.Virtual48
  - `+0x4c` `0x463a18` NEW TPixie.Virtual4C
  - `+0x50` `0x463a20` NEW TPixie.Virtual50
  - `+0x54` `0x463a28` NEW TPixie.Virtual54
  - `+0x58` `0x463a30` NEW TPixie.Virtual58
  - `+0x5c` `0x4029ec` NEW @AbstractError
  - `+0x60` `0x4029ec` NEW @AbstractError
  - `+0x64` `0x4029ec` NEW @AbstractError
  - `+0x68` `0x4029ec` NEW @AbstractError
  - `+0x6c` `0x463a68` NEW TPixie.Virtual6C
  - `+0x70` `0x463aa4` NEW TPixie.Virtual70
  - `+0x74` `0x463ae4` NEW TPixie.Virtual74
  - `+0x78` `0x463ba8` NEW TPixie.Virtual78
  - `+0x7c` `0x463bb4` NEW TPixie.Virtual7C
  - `+0x80` `0x463b68` NEW TPixie.Virtual80
  - `+0x84` `0x463b94` NEW TPixie.Virtual84
  - (12 inherited slots omitted)

## EFrame = class(Exception)  — unit Sprframe

- VMT: `0x463c60`, instance size: `0xc` (parent: `0xc`)

## TFrame = class(TPersistent)  — unit Sprframe

- VMT: `0x463d10`, instance size: `0x6c` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x4640bc`
- Virtual method table (slot offset, address, status):
  - `+0x08` `0x4640f8` override TFrame.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - `+0x0c` `0x464274` NEW TFrame.Loaded
  - `+0x10` `0x4641dc` NEW TFrame.Notification
  - (2 inherited slots omitted)

## TPersistentList = class(TPersistent)  — unit Sprframe

- VMT: `0x463d9c`, instance size: `0x8` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x46450c`
- Virtual method table (slot offset, address, status):
  - `+0x0c` `0x464540` NEW TPersistentList.Virtual0C
  - (3 inherited slots omitted)

## TFrameList = class(TPersistentList)  — unit Sprframe

- VMT: `0x463e34`, instance size: `0x94` (parent: `0x8`)
- Overrides of TObject virtuals: Destroy=`0x4645d0`
- Virtual method table (slot offset, address, status):
  - `+0x04` `0x464c28` override TFrameList.DefineProperties (slot introduced by TPersistent: TPersistent.DefineProperties)
  - `+0x08` `0x464940` override TFrameList.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - `+0x0c` `0x464854` override TFrameList.Virtual0C (slot introduced by TPersistentList: TPersistentList.Virtual0C)
  - (1 inherited slots omitted)

## TScrnMode = class(TObject)  — unit uResizeScreen

- VMT: `0x464f64`, instance size: `0x14` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x465030`

## TScrnModeList = class(TList)  — unit uResizeScreen

- VMT: `0x464fbc`, instance size: `0x10` (parent: `0x10`)
- Overrides of TObject virtuals: Destroy=`0x4651a0`
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TTextBalloon = class(TPixie)  — unit uTextBalloon

- VMT: `0x465434`, instance size: `0xac` (parent: `0x68`)
- Published properties:
  - SpriteBox: TSpriteBox read field +0x74 write TTextBalloon.SetSpriteBox
  - BalloonText: String read field +0x68 write TTextBalloon.SetBalloonText
  - XOffset: Integer read field +0x80 write TTextBalloon.SetXOffset
  - YOffset: Integer read field +0x84 write TTextBalloon.SetYOffset
  - SideColor: TColor read field +0x78 write TTextBalloon.SetSideColor
  - BackGroundColor: TColor read field +0x7c write TTextBalloon.SetBackGroundColor
  - BalloonLineWidth: Integer read field +0xa0 write TTextBalloon.SetBalloonLineWidth
  - RoundCorner: Boolean read field +0xa8 write TTextBalloon.SetRoundCorner
  - Font: TFont read field +0xa4 write TTextBalloon.SetFont
- Overrides of TObject virtuals: Destroy=`0x4656f0`
- Virtual method table (slot offset, address, status):
  - `+0x2c` `0x465654` override TTextBalloon.Create (slot introduced by TComponent: TComponent.Create)
  - `+0x34` `0x466f1c` override TTextBalloon.Virtual34 (slot introduced by TPixie: TPixie.Virtual34)
  - `+0x38` `0x466f28` override TTextBalloon.Virtual38 (slot introduced by TPixie: TPixie.Virtual38)
  - `+0x3c` `0x466f34` override TTextBalloon.Virtual3C (slot introduced by TPixie: TPixie.Virtual3C)
  - `+0x40` `0x466f60` override TTextBalloon.Virtual40 (slot introduced by TPixie: TPixie.Virtual40)
  - `+0x44` `0x466f68` override TTextBalloon.Virtual44 (slot introduced by TPixie: TPixie.Virtual44)
  - `+0x5c` `0x465750` override TTextBalloon.Virtual5C (slot introduced by TPixie: @AbstractError)
  - `+0x60` `0x465758` override TTextBalloon.Virtual60 (slot introduced by TPixie: @AbstractError)
  - `+0x64` `0x46663c` override TTextBalloon.Virtual64 (slot introduced by TPixie: @AbstractError)
  - `+0x68` `0x466de8` override TTextBalloon.Virtual68 (slot introduced by TPixie: @AbstractError)
  - (24 inherited slots omitted)

## TComment = class(TCustomEdit)  — unit cEditCtr

- VMT: `0x469290`, instance size: `0x208` (parent: `0x208`)
- Published properties:
  - Caption: String read TComment.GetCaption write TComment.SetCaption
- Virtual method table (slot offset, address, status):
  - `+0x2c` `0x469418` override TComment.Create (slot introduced by TComponent: TComponent.Create)
  - (52 inherited slots omitted)

## ESprite = class(Exception)  — unit uSprite

- VMT: `0x4695d8`, instance size: `0xc` (parent: `0xc`)

## TSprite = class(TPixie)  — unit uSprite

- VMT: `0x4697f8`, instance size: `0x13c` (parent: `0x68`)
- Published properties:
  - About: String read TSprite.GetAbout write field +0x68
  - Transparent: TColor read TSprite.GetTransparent write TSprite.SetTransparent
  - HitTest: THitTest read field +0x96 write field +0x96
  - Plotmode: TPlotMode read field +0x80 write field +0x80 default 3
  - FrameList: TFrameList read field +0x70 write TSprite.SetFrameList
  - Priority: Integer read TSprite.GetPriority write TSprite.SetPriority
  - SpriteBox: TSpriteBox read field +0x6c write TSprite.SetSpriteBox
  - SequenceList: TSequenceList read field +0x74 write TSprite.SetSequenceList
  - CurrentFrame: TName read TSprite.GetCurrentFrame write TSprite.SetCurrentFrame
  - FrameIndex: Integer read field +0x84 write TSprite.SetFrameIndex
  - MirrorX: Boolean read field +0x9d write TSprite.SetMirrorX
  - MirrorY: Boolean read field +0x9c write TSprite.SetMirrorY
  - HotSpotX: Integer read virtual slot +0x88 write -
  - HotSpotY: Integer read virtual slot +0x8c write -
  - OnMove: TOnMoveEvent read field +0x108 write field +0x108
  - OnFinishSequence: TOnFinishSequence read field +0x110 write field +0x110
  - OnHit: TOnHitEvent read field +0x118 write field +0x118
  - OnBeforeBlit: TOnBlitEvent read field +0x120 write field +0x120
  - OnAfterBlit: TOnBlitEvent read field +0x128 write field +0x128
  - OnVisible: TOnVisibleEvent read field +0x100 write field +0x100
  - OnFrameSkipped: TOnSkipFrameEvent read field +0x130 write field +0x130
- Overrides of TObject virtuals: Destroy=`0x46a150`
- Virtual method table (slot offset, address, status):
  - `+0x2c` `0x469d70` override TSprite.Create (slot introduced by TComponent: TComponent.Create)
  - `+0x30` `0x46b688` override TSprite.Virtual30 (slot introduced by TPixie: TPixie.Virtual30)
  - `+0x34` `0x46b738` override TSprite.Virtual34 (slot introduced by TPixie: TPixie.Virtual34)
  - `+0x38` `0x46b7ac` override TSprite.Virtual38 (slot introduced by TPixie: TPixie.Virtual38)
  - `+0x3c` `0x46b878` override TSprite.Virtual3C (slot introduced by TPixie: TPixie.Virtual3C)
  - `+0x40` `0x46baf4` override TSprite.Virtual40 (slot introduced by TPixie: TPixie.Virtual40)
  - `+0x44` `0x46bb50` override TSprite.Virtual44 (slot introduced by TPixie: TPixie.Virtual44)
  - `+0x50` `0x46b820` override TSprite.Virtual50 (slot introduced by TPixie: TPixie.Virtual50)
  - `+0x58` `0x46b84c` override TSprite.Virtual58 (slot introduced by TPixie: TPixie.Virtual58)
  - `+0x5c` `0x46bbac` override TSprite.Virtual5C (slot introduced by TPixie: @AbstractError)
  - `+0x60` `0x46bbe0` override TSprite.Virtual60 (slot introduced by TPixie: @AbstractError)
  - `+0x64` `0x46ae50` override TSprite.Virtual64 (slot introduced by TPixie: @AbstractError)
  - `+0x68` `0x46ad00` override TSprite.Virtual68 (slot introduced by TPixie: @AbstractError)
  - `+0x74` `0x46a9d4` override TSprite.Virtual74 (slot introduced by TPixie: TPixie.Virtual74)
  - `+0x78` `0x46abf0` override TSprite.Virtual78 (slot introduced by TPixie: TPixie.Virtual78)
  - `+0x7c` `0x46ac78` override TSprite.Virtual7C (slot introduced by TPixie: TPixie.Virtual7C)
  - `+0x80` `0x46ab14` override TSprite.Virtual80 (slot introduced by TPixie: TPixie.Virtual80)
  - `+0x84` `0x46ab94` override TSprite.Virtual84 (slot introduced by TPixie: TPixie.Virtual84)
  - `+0x88` `0x46bc14` NEW TSprite.Virtual88
  - `+0x8c` `0x46bc50` NEW TSprite.Virtual8C
  - `+0x90` `0x46b2d0` NEW TSprite.Virtual90
  - `+0x94` `0x46a5ec` NEW TSprite.Virtual94
  - `+0x98` `0x46a60c` NEW TSprite.Virtual98
  - `+0x9c` `0x46a69c` NEW TSprite.Virtual9C
  - `+0xa0` `0x46a720` NEW TSprite.VirtualA0
  - `+0xa4` `0x46aae8` NEW TSprite.VirtualA4
  - `+0xa8` `0x46a7ec` NEW TSprite.VirtualA8
  - `+0xac` `0x46a924` NEW TSprite.VirtualAC
  - `+0xb0` `0x46b2ec` NEW TSprite.VirtualB0
  - `+0xb4` `0x469ecc` NEW TSprite.VirtualB4
  - (16 inherited slots omitted)

## TSpriteList = class(TList)  — unit uSprite

- VMT: `0x469c3c`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TBehaviour = class(TObject)  — unit uSprite

- VMT: `0x469ca4`, instance size: `0x1c` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x46c1e4`
- Virtual method table (slot offset, address, status):
  - `+0x00` `0x46c218` NEW TBehaviour.Virtual00
  - `+0x04` `0x46c21c` NEW TBehaviour.Virtual04
  - `+0x08` `0x46c220` NEW TBehaviour.Virtual08
  - `+0x0c` `0x46c228` NEW TBehaviour.Virtual0C
  - `+0x10` `0x46c248` NEW TBehaviour.Virtual10
  - `+0x14` `0x46c284` NEW TBehaviour.Virtual14
  - `+0x18` `0x46c274` NEW TBehaviour.Virtual18
  - `+0x1c` `0x46c27c` NEW TBehaviour.Virtual1C
  - `+0x20` `0x46c268` NEW TBehaviour.Virtual20
  - `+0x24` `0x46c270` NEW TBehaviour.Virtual24
  - `+0x28` `0x46c288` NEW TBehaviour.Virtual28
  - `+0x2c` `0x46c28c` NEW TBehaviour.Virtual2C
  - `+0x30` `0x46c2b0` NEW TBehaviour.Virtual30
  - `+0x34` `0x46c2ac` NEW TBehaviour.Virtual34
  - (0 inherited slots omitted)

## TBehaviourList = class(TList)  — unit uSprite

- VMT: `0x469d50`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TGoblin = class(TPixie)  — unit uGoblin

- VMT: `0x46c4c4`, instance size: `0x84` (parent: `0x68`)
- Published properties:
  - SpriteBox: TSpriteBox read field +0x7c write TGoblin.SetSpriteBox
  - Surface: TSurface read field +0x78 write TGoblin.SetSurface
- Overrides of TObject virtuals: Destroy=`0x46c600`
- Virtual method table (slot offset, address, status):
  - `+0x2c` `0x46c5bc` override TGoblin.Create (slot introduced by TComponent: TComponent.Create)
  - `+0x3c` `0x46c968` override TGoblin.Virtual3C (slot introduced by TPixie: TPixie.Virtual3C)
  - `+0x5c` `0x46c6b8` override TGoblin.Virtual5C (slot introduced by TPixie: @AbstractError)
  - `+0x60` `0x46c6c4` override TGoblin.Virtual60 (slot introduced by TPixie: @AbstractError)
  - `+0x64` `0x46c6d0` override TGoblin.Virtual64 (slot introduced by TPixie: @AbstractError)
  - `+0x68` `0x46c71c` override TGoblin.Virtual68 (slot introduced by TPixie: @AbstractError)
  - `+0x74` `0x46c638` override TGoblin.Virtual74 (slot introduced by TPixie: TPixie.Virtual74)
  - (27 inherited slots omitted)

## TThreeD = class(TPersistent)  — unit uSpritebox

- VMT: `0x46ca60`, instance size: `0x18` (parent: `0x4`)
- Published properties:
  - Enabled: Boolean read field +0x4 write field +0x4
  - XDis: Integer read field +0x8 write field +0x8
  - YDis: Integer read field +0xc write field +0xc
  - ZDis: Integer read field +0x10 write field +0x10
  - DiaF: Integer read field +0x14 write field +0x14
- Virtual method table (slot offset, address, status):
  - `+0x08` `0x46d564` override TThreeD.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - (2 inherited slots omitted)

## TSpriteBox = class(TCustomControl)  — unit uSpritebox

- VMT: `0x46cb84`, instance size: `0x278` (parent: `0x1f4`)
- Published properties:
  - ThreeD: TThreeD read field +0x234 write field +0x234
  - Align: TAlign read field +0x4b write TControl.SetAlign default 0
  - AutoFlip: Boolean read field +0x200 write TSpriteBox.SetAutoFlip
  - AutoSize: Boolean read field +0x203 write TSpriteBox.SetAutoSize default 0
  - Center: Boolean read field +0x202 write field +0x202 default 0
  - DragCursor: TCursor read field +0x6a write field +0x6a default -12
  - DragMode: TDragMode read field +0x4d write virtual slot +0x58 default 0
  - Enabled: Boolean read virtual slot +0x4c write virtual slot +0x5c default 1
  - ParentShowHint: Boolean read field +0x8a write TControl.SetParentShowHint default 1
  - Picture: TSurface read field +0x208 write TSpriteBox.SetPicture
  - PaletteImage: TSurface read field +0x20c write TSpriteBox.SetPaletteImage
  - Reload: String read field +0x238 write field +0x238
  - PopupMenu: TPopupMenu read field +0x6c write TControl.SetPopupMenu
  - ShowHint: Boolean read field +0x89 write TControl.SetShowHint
  - Stretch: Boolean read field +0x204 write field +0x204 default 0
  - Visible: Boolean read field +0x47 write TControl.SetVisible default 1
  - OnClick: TNotifyEvent read field +0x108 write field +0x108
  - OnDblClick: TNotifyEvent read field +0x110 write field +0x110
  - OnDragDrop: TDragDropEvent read field +0xd0 write field +0xd0
  - OnDragOver: TDragOverEvent read field +0xd8 write field +0xd8
  - OnEndDrag: TEndDragEvent read field +0x100 write field +0x100
  - OnMouseDown: TMouseEvent read field +0xb8 write field +0xb8
  - OnMouseMove: TMouseMoveEvent read field +0xc0 write field +0xc0
  - OnMouseUp: TMouseEvent read field +0xc8 write field +0xc8
  - OnKeyDown: TKeyEvent read field +0x1b0 write field +0x1b0
  - OnKeyPress: TKeyPressEvent read field +0x1b8 write field +0x1b8
  - OnKeyUp: TKeyEvent read field +0x1c0 write field +0x1c0
  - OnFlip: TNotifyEvent read field +0x240 write field +0x240
  - OnStarted: TNotifyEvent read field +0x248 write field +0x248
  - OnShow: TNotifyEvent read field +0x250 write field +0x250
  - HandleBackGround: THandleBackGround read field +0x270 write field +0x270
  - BackGroundColor: TColor read field +0x274 write field +0x274
- Overrides of TObject virtuals: Destroy=`0x46d2d4`
- Virtual method table (slot offset, address, status):
  - `+0x2c` `0x46d1a8` override TSpriteBox.Create (slot introduced by TComponent: TComponent.Create)
  - `+0xb4` `0x46d714` override TSpriteBox.Paint (slot introduced by TCustomControl: TCustomControl.Paint)
  - `+0xb8` `0x46dea8` NEW TSpriteBox.VirtualB8
  - `+0xbc` `0x46e1e4` NEW TSpriteBox.VirtualBC
  - `+0xc0` `0x46d914` NEW TSpriteBox.VirtualC0
  - `+0xc4` `0x46db0c` NEW TSpriteBox.VirtualC4
  - `+0xc8` `0x46de00` NEW TSpriteBox.VirtualC8
  - `+0xcc` `0x46df60` NEW TSpriteBox.VirtualCC
  - `+0xd0` `0x46e0f0` NEW TSpriteBox.VirtualD0
  - (44 inherited slots omitted)
- Dynamic/message methods: 0x14→`0x46d44c`, 0x402→`0x46d460`, 0xffda→`0x46d5b8`, 0xffd9→`0x46d620`, 0xffd8→`0x46d6a8`

## TSpriteBoxList = class(TList)  — unit uSpritebox

- VMT: `0x46d188`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TFrameRef = class(TPersistent)  — unit uSequence

- VMT: `0x46ea90`, instance size: `0x70` (parent: `0x4`)
- Virtual method table (slot offset, address, status):
  - `+0x04` `0x46ede0` override TFrameRef.DefineProperties (slot introduced by TPersistent: TPersistent.DefineProperties)
  - `+0x08` `0x46ee1c` override TFrameRef.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - (1 inherited slots omitted)

## TSequence = class(TPersistentList)  — unit uSequence

- VMT: `0x46eb1c`, instance size: `0x6c` (parent: `0x8`)
- Virtual method table (slot offset, address, status):
  - `+0x04` `0x46f128` override TSequence.DefineProperties (slot introduced by TPersistent: TPersistent.DefineProperties)
  - `+0x08` `0x46eef4` override TSequence.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - (2 inherited slots omitted)

## TSequenceList = class(TPersistentList)  — unit uSequence

- VMT: `0x46ebac`, instance size: `0xc` (parent: `0x8`)
- Virtual method table (slot offset, address, status):
  - `+0x04` `0x46f41c` override TSequenceList.DefineProperties (slot introduced by TPersistent: TPersistent.DefineProperties)
  - `+0x08` `0x46f1a0` override TSequenceList.Assign (slot introduced by TPersistent: TPersistent.Assign)
  - (2 inherited slots omitted)

## TCustomFastTimer = class(TComponent)  — unit uTiming

- VMT: `0x46f57c`, instance size: `0x70` (parent: `0x24`)
- Overrides of TObject virtuals: Destroy=`0x46f928`
- Virtual method table (slot offset, address, status):
  - `+0x2c` `0x46f874` override TCustomFastTimer.Create (slot introduced by TComponent: TComponent.Create)
  - `+0x30` `0x46fbd4` NEW TCustomFastTimer.Virtual30
  - (11 inherited slots omitted)
- Dynamic/message methods: 0xfff0→`0x46fbc8`

## TFastTimer = class(TCustomFastTimer)  — unit uTiming

- VMT: `0x46f654`, instance size: `0x70` (parent: `0x70`)
- Published properties:
  - About: String read TFastTimer.GetAbout write field +0x24
  - Enabled: Boolean read field +0x28 write TFastTimer.SetEnabled default 0
  - Interval: Integer read field +0x2c write TFastTimer.SetInterval
  - OnTimer: TNotifyEvent read field +0x40 write TFastTimer.SetOnTimer
  - OnSkipTimer: TNotifyEvent read field +0x48 write field +0x48
  - Priority: Integer read field +0x68 write field +0x68 default 5
- Virtual method table (slot offset, address, status):
  - (13 inherited slots omitted)

## TFastTimerList = class(TList)  — unit uTiming

- VMT: `0x46f7d4`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TBehavCursor = class(TBehaviour)  — unit Sprbehav

- VMT: `0x470014`, instance size: `0x28` (parent: `0x1c`)
- Virtual method table (slot offset, address, status):
  - `+0x20` `0x470c4c` override TBehavCursor.Virtual20 (slot introduced by TBehaviour: TBehaviour.Virtual20)
  - `+0x24` `0x470c9c` override TBehavCursor.Virtual24 (slot introduced by TBehaviour: TBehaviour.Virtual24)
  - (12 inherited slots omitted)

## TBehavControl = class(TBehaviour)  — unit Sprbehav

- VMT: `0x4700a8`, instance size: `0x50` (parent: `0x1c`)
- Virtual method table (slot offset, address, status):
  - `+0x00` `0x4707e0` override TBehavControl.Virtual00 (slot introduced by TBehaviour: TBehaviour.Virtual00)
  - `+0x18` `0x4705fc` override TBehavControl.Virtual18 (slot introduced by TBehaviour: TBehaviour.Virtual18)
  - `+0x1c` `0x470620` override TBehavControl.Virtual1C (slot introduced by TBehaviour: TBehaviour.Virtual1C)
  - `+0x20` `0x47058c` override TBehavControl.Virtual20 (slot introduced by TBehaviour: TBehaviour.Virtual20)
  - `+0x24` `0x4705f4` override TBehavControl.Virtual24 (slot introduced by TBehaviour: TBehaviour.Virtual24)
  - `+0x34` `0x4706b4` override TBehavControl.Virtual34 (slot introduced by TBehaviour: TBehaviour.Virtual34)
  - `+0x38` `0x470850` NEW TBehavControl.Virtual38
  - (8 inherited slots omitted)

## TBehavCheckBox = class(TBehavControl)  — unit Sprbehav

- VMT: `0x470170`, instance size: `0x58` (parent: `0x50`)
- Virtual method table (slot offset, address, status):
  - (15 inherited slots omitted)

## TBehavRadioButton = class(TBehavCheckBox)  — unit Sprbehav

- VMT: `0x470208`, instance size: `0x5c` (parent: `0x58`)
- Virtual method table (slot offset, address, status):
  - `+0x1c` `0x470af8` override TBehavRadioButton.Virtual1C (slot introduced by TBehaviour: TBehaviour.Virtual1C)
  - `+0x38` `0x470b48` override TBehavRadioButton.Virtual38 (slot introduced by TBehavControl: TBehavControl.Virtual38)
  - (13 inherited slots omitted)

## TBehavButton = class(TBehavControl)  — unit Sprbehav

- VMT: `0x4702b4`, instance size: `0x50` (parent: `0x50`)
- Virtual method table (slot offset, address, status):
  - (15 inherited slots omitted)

## TBehavMemo = class(TBehavControl)  — unit Sprbehav

- VMT: `0x47034c`, instance size: `0x68` (parent: `0x50`)
- Overrides of TObject virtuals: Destroy=`0x4713e4`
- Virtual method table (slot offset, address, status):
  - `+0x08` `0x4714d8` override TBehavMemo.Virtual08 (slot introduced by TBehaviour: TBehaviour.Virtual08)
  - `+0x0c` `0x4715e8` override TBehavMemo.Virtual0C (slot introduced by TBehaviour: TBehaviour.Virtual0C)
  - `+0x34` `0x471438` override TBehavMemo.Virtual34 (slot introduced by TBehaviour: TBehaviour.Virtual34)
  - (12 inherited slots omitted)

## TCaption = class(TObject)  — unit Sprbehav

- VMT: `0x4703e0`, instance size: `0x18` (parent: `0x4`)

## TBehavText = class(TBehaviour)  — unit Sprbehav

- VMT: `0x470448`, instance size: `0x28` (parent: `0x1c`)
- Overrides of TObject virtuals: Destroy=`0x4710c4`
- Virtual method table (slot offset, address, status):
  - `+0x0c` `0x4711e0` override TBehavText.Virtual0C (slot introduced by TBehaviour: TBehaviour.Virtual0C)
  - (13 inherited slots omitted)

## TTask = class(TObject)  — unit Usett

- VMT: `0x4721b8`, instance size: `0xc` (parent: `0x4`)

## TSettings = class(TObject)  — unit Usett

- VMT: `0x47223c`, instance size: `0x370` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x4723b8`

## TStatus = class(TObject)  — unit Usett

- VMT: `0x4722d4`, instance size: `0x20` (parent: `0x4`)

## TViewSprite = class(TSprite)  — unit Uview

- VMT: `0x472fc8`, instance size: `0x150` (parent: `0x13c`)
- Virtual method table (slot offset, address, status):
  - (46 inherited slots omitted)

## TViewSpriteList = class(TList)  — unit Uview

- VMT: `0x473110`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TView = class(TPixie)  — unit Uview

- VMT: `0x47317c`, instance size: `0x90` (parent: `0x68`)
- Overrides of TObject virtuals: Destroy=`0x473498`
- Virtual method table (slot offset, address, status):
  - `+0x40` `0x4749cc` override TView.Virtual40 (slot introduced by TPixie: TPixie.Virtual40)
  - `+0x44` `0x4749d4` override TView.Virtual44 (slot introduced by TPixie: TPixie.Virtual44)
  - `+0x4c` `0x474e78` override TView.Virtual4C (slot introduced by TPixie: TPixie.Virtual4C)
  - `+0x54` `0x474e80` override TView.Virtual54 (slot introduced by TPixie: TPixie.Virtual54)
  - `+0x5c` `0x4749c4` override TView.Virtual5C (slot introduced by TPixie: @AbstractError)
  - `+0x60` `0x4749bc` override TView.Virtual60 (slot introduced by TPixie: @AbstractError)
  - `+0x64` `0x474420` override TView.Virtual64 (slot introduced by TPixie: @AbstractError)
  - `+0x68` `0x4740a8` override TView.Virtual68 (slot introduced by TPixie: @AbstractError)
  - (26 inherited slots omitted)

## TAutoSprite = class(TSprite)  — unit uAutos

- VMT: `0x474f3c`, instance size: `0x158` (parent: `0x13c`)
- Virtual method table (slot offset, address, status):
  - `+0x64` `0x475934` override TAutoSprite.Virtual64 (slot introduced by TPixie: @AbstractError)
  - (45 inherited slots omitted)

## TSegment = class(TObject)  — unit uAutos

- VMT: `0x475070`, instance size: `0x18` (parent: `0x4`)

## TSegmentList = class(TList)  — unit uAutos

- VMT: `0x4750c8`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TCtrlForm = class(TForm)  — unit Uctrl

- VMT: `0x477d64`, instance size: `0x2d0` (parent: `0x2d0`)
- Virtual method table (slot offset, address, status):
  - (56 inherited slots omitted)

## TTrein = class(TObject)  — unit uTrein

- VMT: `0x47886c`, instance size: `0x30` (parent: `0x4`)

## TfrmMain = class(TCtrlForm)  — unit Fmain

- VMT: `0x47955c`, instance size: `0x48c` (parent: `0x2d0`)
- Published fields:
  - `+0x2d0` sbStage: TSpriteBox
  - `+0x2d4` memoMessages: TMemo
  - `+0x2d8` butReady: TButton
  - `+0x2dc` memoUitleg: TMemo
  - `+0x2e0` butStart: TButton
  - `+0x2e4` butCancel: TButton
  - `+0x2e8` spriteStart: TSprite
  - `+0x2ec` spriteCancel: TSprite
  - `+0x2f0` spriteUitleg: TSprite
  - `+0x2f4` spriteUitlegBackground: TSprite
  - `+0x2f8` spriteKop: TSprite
  - `+0x2fc` memoKop: TMemo
  - `+0x300` spriteGeld: TSprite
  - `+0x304` spriteHint: TSprite
  - `+0x308` spriteMessages: TSprite
  - `+0x30c` spriteReady: TSprite
  - `+0x310` butStop: TButton
  - `+0x314` spriteStop: TSprite
  - `+0x318` spriteMeeuw: TSprite
  - `+0x31c` timerMeeuw: TFastTimer
  - `+0x320` lblKnopOffset: TLabel
  - `+0x324` butAlgemeen: TButton
  - `+0x328` butWegenEnSpoor: TButton
  - `+0x32c` butStadsvoorzieningen: TButton
  - `+0x330` timerKlachten: TFastTimer
  - `+0x334` spriteStoep: TSprite
  - `+0x338` butSportEnRecreatie: TButton
  - `+0x33c` spriteAuto: TSprite
  - `+0x340` butWijkvoorzieningen: TButton
  - `+0x344` lblCoo: TLabel
  - `+0x348` lblVakje: TLabel
  - `+0x34c` lblVakjeCoo: TLabel
  - `+0x350` Comment2: TComment
  - `+0x354` lblGroen: TLabel
  - `+0x358` lblVeiligheid: TLabel
  - `+0x35c` lblVrijetijd: TLabel
  - `+0x360` lblCultuur: TLabel
  - `+0x364` lblMobiliteit: TLabel
  - `+0x368` lblWerk: TLabel
  - `+0x36c` lblOverlast: TLabel
  - `+0x370` Label1: TLabel
  - `+0x374` spriteJa: TSprite
  - `+0x378` spriteNee: TSprite
  - `+0x37c` butJa: TButton
  - `+0x380` butNee: TButton
  - `+0x384` butLoad: TButton
  - `+0x388` butSave: TButton
  - `+0x38c` spriteLoad: TSprite
  - `+0x390` spriteSave: TSprite
  - `+0x394` SaveDialog: TSaveDialog
  - `+0x398` OpenDialog: TOpenDialog
  - `+0x39c` lblContents: TLabel
  - `+0x3a0` lblSubtype: TLabel
  - `+0x3a4` lblWijk: TLabel
  - `+0x3a8` spriteWijk: TSprite
  - `+0x3ac` timerMain: TFastTimer
  - `+0x3b0` spriteWijkvoorzieningen: TSprite
  - `+0x3b4` spriteAlgemeen: TSprite
  - `+0x3b8` spriteWegenEnSpoor: TSprite
  - `+0x3bc` spriteSportEnRecreatie: TSprite
  - `+0x3c0` spriteStadsvoorzieningen: TSprite
  - `+0x3c4` timerRecalc: TFastTimer
  - `+0x3c8` Label2: TLabel
  - `+0x3cc` lblRecalc: TLabel
  - `+0x3d0` lblTimers: TLabel
  - `+0x3d4` spriteZoomuit: TSprite
  - `+0x3d8` spriteScrollup: TSprite
  - `+0x3dc` spriteZoomin: TSprite
  - `+0x3e0` spriteScrollleft: TSprite
  - `+0x3e4` spriteScrolldown: TSprite
  - `+0x3e8` spriteScrollright: TSprite
  - `+0x3ec` butZoomuit: TButton
  - `+0x3f0` butScrollup: TButton
  - `+0x3f4` butScrollleft: TButton
  - `+0x3f8` butZoomin: TButton
  - `+0x3fc` butScrolldown: TButton
  - `+0x400` butScrollright: TButton
  - `+0x404` spriteLevel: TSprite
  - `+0x408` lblLevel: TLabel
  - `+0x40c` Memo1: TMemo
  - `+0x410` Button1: TButton
- Published methods:
  - `0x47a904` sbStageStarted
  - `0x47baac` butPlaceSomethingClick
  - `0x47bb08` sbStageMouseDown
  - `0x47bcf4` sbStageMouseMove
  - `0x479f54` FormCreate
  - `0x47b84c` FormDestroy
  - `0x47e9cc` FormCloseQuery
  - `0x47d20c` butReadyClick
  - `0x47c77c` butStartClick
  - `0x47c89c` butCancelClick
  - `0x47d244` spriteHintAfterBlit
  - `0x47dc88` sbStageKeyPress
  - `0x47e7e0` butSaveClick
  - `0x47dd1c` FormClose
  - `0x47deac` butStopClick
  - `0x47dee4` timerMeeuwTimer
  - `0x47df70` spriteMeeuwFinishSequence
  - `0x47dc4c` sbStageKeyDown
  - `0x47e25c` tabClick
  - `0x47e2e8` timerKlachtenTimer
  - `0x47e370` Label1Click
  - `0x47e378` butJaClick
  - `0x47e38c` butNeeClick
  - `0x47e394` butLoadClick
  - `0x47ea08` timerMainTimer
  - `0x47f8c8` timerRecalcTimer
  - `0x47f974` butZoomuitClick
  - `0x47f9d4` butZoominClick
  - `0x47fa34` butScrollupClick
  - `0x47fa98` butScrollleftClick
  - `0x47fafc` butScrolldownClick
  - `0x47fb60` butScrollrightClick
  - `0x47fc18` Button1Click
- Virtual method table (slot offset, address, status):
  - (56 inherited slots omitted)
- Dynamic/message methods: 0x14→`0x479f50`

## TfrmReport = class(TForm)  — unit fReport

- VMT: `0x47fdb4`, instance size: `0x308` (parent: `0x2d0`)
- Published fields:
  - `+0x2d0` butOK: TButton
  - `+0x2d4` tcTabs: TTabControl
  - `+0x2d8` memoTab: TMemo
- Published methods:
  - `0x47ff5c` FormCreate
  - `0x47ffc4` FormDestroy
  - `0x480144` butOKClick
  - `0x480150` tcTabsChange
  - `0x48016c` tcTabsDrawTab
- Virtual method table (slot offset, address, status):
  - (56 inherited slots omitted)

## TCell = class(TObject)  — unit Uworld

- VMT: `0x4802a4`, instance size: `0x58` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x48043c`

## TCellList = class(TList)  — unit Uworld

- VMT: `0x480310`, instance size: `0x10` (parent: `0x10`)
- Virtual method table (slot offset, address, status):
  - (4 inherited slots omitted)

## TWijk = class(TObject)  — unit Uworld

- VMT: `0x480378`, instance size: `0x18` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x482dbc`

## TWorld = class(TObject)  — unit Uworld

- VMT: `0x4803dc`, instance size: `0x2000` (parent: `0x4`)
- Overrides of TObject virtuals: Destroy=`0x4835b4`

## TfrmBlack = class(TForm)  — unit fBack

- VMT: `0x486cb8`, instance size: `0x2e0` (parent: `0x2d0`)
- Published fields:
  - `+0x2d0` imgLoading: TImage
  - `+0x2d4` lblLoading: TLabel
  - `+0x2d8` lblLoading0: TLabel
  - `+0x2dc` lblVersion: TLabel
- Published methods:
  - `0x486e68` FormKeyDown
  - `0x486e80` FormKeyPress
  - `0x486e90` FormMouseDown
  - `0x486ea4` FormCreate
- Virtual method table (slot offset, address, status):
  - (56 inherited slots omitted)

