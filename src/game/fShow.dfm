object formDebugShow: TformDebugShow
  Left = 483
  Top = 187
  Width = 417
  Height = 332
  ActiveControl = OKBtn
  BorderIcons = [biMaximize]
  Caption = 'Show'
  Font.Color = clBlack
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = [fsBold]
  Position = poScreenCenter
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object PaintBox1: TPaintBox
    Left = 8
    Top = 56
    Width = 393
    Height = 241
    Visible = False
    OnPaint = PaintBox1Paint
  end
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 83
    Height = 13
    Caption = 'Width and Height'
    Font.Color = clBlack
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
  end
  object OKBtn: TBitBtn
    Left = 8
    Top = 24
    Width = 73
    Height = 25
    TabOrder = 0
    OnKeyPress = OKBtnKeyPress
    Kind = bkOK
    Spacing = -1
    IsControl = True
  end
  object memText: TMemo
    Left = 8
    Top = 56
    Width = 393
    Height = 241
    TabOrder = 1
    Visible = False
  end
end
