unit Megapacker;

interface

uses Windows, Classes, SysUtils, Math, DateUtils, Dialogs;

type
  TPixels = set of 0..15; //��������� ��������
  TBytes = array[0..15] of Byte; //������ ��� ���������

  TTile4bit = Array[0..31] of Byte;
  TTile8bit = Array[0..7, 0..7] of Byte;

  TPackedTile = record
    hhi, hlo: Byte; //hbits (horizontal bits) ���� ���������� ����� ��������
    vhi, vlo: Byte; //vbits (vertical bits) ���� ���������� �������� - ����� ��� ���� �����
    vbits: array[0..7] of Byte; //������������ vbits ��� ������ ������
    Pixels: Word; //��������� �������� �����
    PackedData: String; //������ ������ ����� � ������� �������������
    PackedSize: Word; //������ ������� �����
  end;

  TListOfSet = class(TList) //����� ��� �������� ������ �������� �������� ��� ������������� ������
  private
    function Get(Index: Integer): Word; overload;
  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  public
    destructor Destroy; override;
    function Add(Value: Word): Integer; overload;
    function Contains(SetOfPixels: Word): Boolean;
    function IndexOf(Item: Word): Integer;
    procedure Insert(Index: Integer; Value: Word);
    property Items[Index: Integer]: Word read Get; default;
  end;

  TSize = record
    CompressedSize: LongWord;
    DecompressedSize: LongWord;
  end;

  TCODEC = Class
  public
    function Compress(const Source; var Dest; Size: ULONG): ULONG;
    function Decompress(const Source; var Dest): TSize;
  private
    DataStreamPos: ULONG;
    CompressedStreamPos: ULONG;
    Data:array of UCHAR;
    CompressedData:array of UCHAR;
    DataSize: ULONG;
    CompressedSize: ULONG;
    CompressedLong: ULONG;
    CompressedBitsUsed: UCHAR;
    TilesNum: Word;
    SimilarTiles: array[0..1023] of TPackedTile; //������ ��� ����� ������ ���������� �������� ������
    LineRepeatsTiles: array[0..1023] of TPackedTile; //������ ��� ����� ������ ���������� �������� �����
    Tiles: array[0..1023] of TTile8bit; //������ ��� ����� � 8 ������ �������������
    ListOfSet: TListOfSet;  //����� ��� �������� ������ ��������
    //Truncated binary encoding
    //Generate the truncated binary encoding for a value x, 0 <= x < n, where n > 0 is the size of the alphabet containing x. n need not be a power of two.
    function TruncatedBinary(x, n: Integer): string; //������� �������������� ����� � �������� ��������� � ��������� ���������
    function TruncatedToFull(Range: Integer): Integer; //������� �������������� �� ��������� ��������� � ������
    //The routine Binary is expository; usually just the rightmost len bits of the variable x are desired. Here we simply output the binary code for x using len bits, padding with high-order 0's if necessary.
    function Binary(x, len: integer): string; //����������� ����� � �������� �������������
    //Functions
    function  CompressedStreamReadBits(NumBits: UCHAR): Word;
    procedure CompressedStreamWriteBits(Value : ULONG; NumBits: UCHAR);  overload;
    procedure CompressedStreamWriteBitsFlush();
    procedure CompressedStreamWriteBits(Value : string);  overload;
    procedure CompressedStreamWriteBit(Value: Boolean);
    function GetBigStream(Range: Integer): Integer;
    function GetStream(Range: Integer): Integer;
    function PixStream(Pixels: TPixels): Byte;
    function mPixStream(Pixel: Byte; Pixels: TPixels): Byte;
    function CompressSimilarTiles(): Integer; //������� ����� �� ������ �������� ������
    function CompressSimilarTile(I, J: Integer): Integer; //������� ���� �� ������ �������� ������
    function CompressLineRepeatsTiles(): Integer; //������� ����� �� ������ �������� �����
    function FindSimilarTile(Index: Integer): Integer; //���� ������ ���� � ����������
  end;
    function _4bppto8bpp(Tile: TTile4bit): TTile8bit;
    function _8bppTo4bpp(Tile: TTile8bit): TTile4bit;
    function SetToArray(const SetOfPixels): TBytes; //����������� ��������� � ������
    function GetElementIndex(const SetOfPixels; Element: Byte): ShortInt; //���������� ������ �������� �� ���������
    function CountingBitSet(Value: Word): Byte; //������� ���������� ������������ ��� � �����

const
  MaxSetNums = 512;

implementation

  // Integer to Binary 

function IntToBin(Value: Longint; Digits: Integer): string;
 var
   i: Integer;
 begin
   Result := '';
   Dec(Digits);
   for i := Digits downto 0 do
     if Value and (1 shl i) <> 0 then
       Result := Result + '1'
   else
     Result := Result + '0';
 end;

{-------------------------------------------------------------------------------
  �������: BitOnIndex
  �����:    �����
  ����:  2021.07.11
  ������� ���������: Value: Word
  ���������:    Byte
  ���������� ������ ������������� ����
-------------------------------------------------------------------------------}
function BitOnIndex(Value: Word): Byte;
begin
  for Result := 0 to 15 do
    if Value = (1 shl Result) then
      break;
end;

{-------------------------------------------------------------------------------
  �������: CountingBitSet
  �����:    __
  ����:  2021.07.11
  ������� ���������: Value: Word
  ���������:    Byte
  ���������� ���������� ������������ ��� � Value
-------------------------------------------------------------------------------}
function CountingBitSet(Value: Word): Byte;
begin
  Result := 0;
  while Value > 0 do
  begin
    Result := Result + Byte(Value and 1);
    Value := Value shr 1;
  end;
end;

function TCODEC.CompressedStreamReadBits(NumBits: UCHAR): Word;
var
  Temp: ULONG;
begin
  CompressedLong:= CompressedLong and $FFFF;
  while NumBits > 0 do
  begin
    dec(NumBits);
    if CompressedBitsUsed = 0 then
    begin
      Temp:= CompressedData[CompressedStreamPos];
      inc(CompressedStreamPos);
      CompressedLong:= CompressedLong or (Temp shl 8);
      Temp:= CompressedData[CompressedStreamPos];
      inc(CompressedStreamPos);
      CompressedLong:= CompressedLong or Temp;
      CompressedBitsUsed:= 16;
    end;
    CompressedLong:= CompressedLong shl 1;
    dec(CompressedBitsUsed);
  end;
  Result:= CompressedLong shr 16;
end;

procedure TCODEC.CompressedStreamWriteBits(Value: ULONG; NumBits: UCHAR);
begin
  while NumBits > 0 do
  begin
    dec(NumBits);
    CompressedLong := CompressedLong shl 1;
    CompressedLong:= CompressedLong or ((Value shr NumBits) and 1);
    inc(CompressedBitsUsed);

    if(CompressedBitsUsed = 8) then
    begin
      CompressedData[CompressedStreamPos]:= CompressedLong and $FF;
      inc(CompressedStreamPos);
      inc(CompressedSize);
      CompressedBitsUsed := 0;
    end;
  end;  //end while
end;

procedure TCODEC.CompressedStreamWriteBit(Value: Boolean);
begin
  CompressedLong := CompressedLong shl 1;
  if Value then
  begin
    Inc(CompressedLong);
  end;

  Inc(CompressedBitsUsed);
  if(CompressedBitsUsed = 8) then
  begin
    CompressedData[CompressedStreamPos]:= CompressedLong and $FF;
    Inc(CompressedStreamPos);
    Inc(CompressedSize);
    CompressedBitsUsed:= 0;
  end;
end;

procedure TCODEC.CompressedStreamWriteBits(Value: string);
var
  I: Byte;
begin
  for I := 1 to Length(Value) do
  begin
    if Value[I] = '0' then
      CompressedStreamWriteBit(False)
    else
      CompressedStreamWriteBit(True);
  end;
end;

procedure TCODEC.CompressedStreamWriteBitsFlush;
begin
  if CompressedBitsUsed > 0 then
  begin
    CompressedData[CompressedStreamPos]:= (CompressedLong shl (8 - CompressedBitsUsed)) and $FF;
    inc(CompressedStreamPos);
    inc(CompressedSize);
    CompressedBitsUsed := 0;
  end;
  CompressedLong:= 0;
end;

function _4bppto8bpp(Tile: TTile4bit): TTile8bit;
var
  X, Y: Integer;
begin
  FillChar(Result, SizeOf(TTile8bit), 0);
  for Y:= 0 to 7 do
    for X:= 0 to 3 do
    begin
      Result[Y, X * 2] := Tile[Y * 4 + X] shr 4;
      Result[Y, X * 2 + 1] := Tile[Y * 4 + X] and $F;
    end;
end;

function _8bppTo4bpp(Tile: TTile8bit): TTile4bit;
var
  X, Y: Integer;
begin
  FillChar(Result, SizeOf(TTile4bit), 0);
  for Y := 0 to 7 do
  begin
    for X := 0 to  3 do
    begin
      Result[Y * 4 + X] := (Tile[Y, X * 2] shl 4) or (Tile[Y, X * 2 + 1] and $F);
    end;
  end;
end;

function TCODEC.Compress(const Source; var Dest; Size: ULONG): ULONG;
var
  Index, X, Y, I, J, K: Integer;
  Tile: TTile4bit;
  Pixels: TPixels;
begin
  Data := @Source;
  CompressedData := @Dest;
  CompressedStreamPos := 0;
  DataStreamPos := 0;
  ListOfSet := TListOfSet.Create;
  TilesNum := Size div 32;
  for I := 0 to TilesNum - 1 do
  begin
    Move(Data[DataStreamPos], Tile[0], SizeOf(TTile4bit));
    Tiles[I]:= _4bppto8bpp(Tile);
    Inc(DataStreamPos, SizeOf(TTile4bit));
  end;

  CompressedStreamWriteBits(TilesNum, 8);
  CompressedStreamWriteBits(TilesNum shr 8, 2);

  for I := 0 to TilesNum - 1 do //�������������� ������ �������� ��� ������� �����
  begin
    Pixels := [];
    for Y := 0 to 7 do
    begin
      for X := 0 to 7 do
      begin
        if not (Tiles[I][Y, X] in Pixels) then
        begin
          Include(Pixels, Tiles[I][Y, X]);
        end;
      end;
    end;
    SimilarTiles[I].Pixels := Word(Pixels);
    LineRepeatsTiles[I].Pixels := SimilarTiles[I].Pixels;
  end;

  CompressSimilarTiles(); //����� ��� ����� ������ �� ���������� � ��������� ������
  CompressLineRepeatsTiles();

  //****************************************************************
  //**�������� ����� ������ ������� � ������ ��������� ����� ������
  //****************************************************************
  for I := 0 to TilesNum - 1 do
  begin
    if SimilarTiles[I].PackedSize < LineRepeatsTiles[I].PackedSize then
    begin
      if not ListOfSet.Contains(SimilarTiles[I].Pixels) then
        ListOfSet.Add(SimilarTiles[I].Pixels);
    end
    else
    begin
      if not ListOfSet.Contains(LineRepeatsTiles[I].Pixels) then
        ListOfSet.Add(LineRepeatsTiles[I].Pixels);
    end;
  end;
  //***************************************************************
  if TilesNum > MaxSetNums then
    CompressedStreamWriteBits(TruncatedBinary(ListOfSet.Count - 1, MaxSetNums))
  else
    CompressedStreamWriteBits(TruncatedBinary(ListOfSet.Count - 1, TilesNum));

  //���������� � �������� ����� ������ �������� ��� ����� ������
  CompressedStreamWriteBits(ListOfSet[0], 16); //������ ����� ���������� ��� �����������
  for J := 1 to ListOfSet.Count - 1 do
  begin
    for K := 0 to J - 1 do //���� � ������� ���� �����, ������� ���������� �� ����������� �� ���� ���
    begin
      if CountingBitSet(ListOfSet[K] xor ListOfSet[J]) = 1 then //���� ������ ���������� �� 1 ���/�������
      begin
        Index := J - K - 1; //�������� ������ ������
        CompressedStreamWriteBit(false);
        CompressedStreamWriteBits(TruncatedBinary(Index, J)); //���������� ������ ��������� �������� �����
        Index := BitOnIndex(ListOfSet[K] xor ListOfSet[J]); //������� ������ ����, �� ������� ���������� ������
        CompressedStreamWriteBits(Index, 4); //�������� � ������ ����� ��� �����������
        Break;
      end;
    end;
    if K = J then //���� ������� ������� ���, �� �������� ����� � ������ ����� ��� �����������
    begin
      CompressedStreamWriteBit(true);
      CompressedStreamWriteBits(ListOfSet[J], 16); 
    end;
  end;

  ListOfSet.Clear;
  CompressedStreamWriteBits(1, 1);
  CompressedStreamWriteBits(LineRepeatsTiles[0].PackedData);
  ListOfSet.Add(LineRepeatsTiles[0].Pixels);
  for I := 1 to TilesNum - 1 do
  begin
    if SimilarTiles[I].PackedSize < LineRepeatsTiles[I].PackedSize then
    begin
      If not ListOfSet.Contains(SimilarTiles[I].Pixels) then
      begin
        ListOfSet.Add(SimilarTiles[I].Pixels);
        CompressedStreamWriteBits(TruncatedBinary(0, ListOfSet.Count));
      end
      else
      begin
        Index := ListOfSet.Count - ListOfSet.IndexOf(SimilarTiles[I].Pixels);
        CompressedStreamWriteBits(TruncatedBinary(Index, ListOfSet.Count + 1));
      end;
      CompressedStreamWriteBits('0' + SimilarTiles[I].PackedData);
    end
    else
    begin
      If not ListOfSet.Contains(LineRepeatsTiles[I].Pixels) then
      begin
        ListOfSet.Add(LineRepeatsTiles[I].Pixels);
        CompressedStreamWriteBits(TruncatedBinary(0, ListOfSet.Count));
      end
      else
      begin
        Index := ListOfSet.Count - ListOfSet.IndexOf(LineRepeatsTiles[I].Pixels);
        CompressedStreamWriteBits(TruncatedBinary(Index, ListOfSet.Count + 1));
      end;
      CompressedStreamWriteBits('1' + LineRepeatsTiles[I].PackedData);
    end;
  end;
  ListOfSet.Free;
  CompressedStreamWriteBitsFlush;
  Result := CompressedStreamPos;
end;

function TCODEC.Decompress(const Source; var Dest): TSize;
var
  X, Y, I, Offset: Integer;
  Tile: TTile4bit;
  Index, Delta, SetNums, ColSet, UsedSetsCount: Word;
  hmap, vmap, vmaptemp: Byte;
  vpref: Boolean; //���������������� �������, ���� true, ��������������� ����� �������, ���� false, ��������������� ������� �������
  Pixels: TPixels;
  RepeatRow, UseLeft: boolean;
begin
  Data := @Dest;
  CompressedData := @Source;
  CompressedStreamPos := 0;
  TilesNum := CompressedStreamReadBits(8) + (CompressedStreamReadBits(2) shl 8);
  DataSize := TilesNum * SizeOf(TTile4bit);
  if TilesNum > MaxSetNums then
  begin
    SetNums := GetBigStream(MaxSetNums);
  end
  else
    SetNums := GetBigStream(TilesNum);
  I := SetNums;
  ListOfSet := TListOfSet.Create;
  ListOfSet.Add(CompressedStreamReadBits(16)); //������� ������ ����� � ������
  while I > 0 do
  begin
    If CompressedStreamReadBits(1) = 1 then
    begin
      ListOfSet.Add(CompressedStreamReadBits(16));// ������� ����� �� ������� ������
    end
    else   //����� �������� ����� ����� ������.
    begin
      Delta := GetBigStream(ListOfSet.Count);
      Index := ListOfSet.Count - Delta  - 1; //�������� ������ ������, �� �������� ���� ����������/���������, ������� ����� �����
      ColSet := ListOfSet.Items[Index];
      ColSet := ColSet xor (1 shl CompressedStreamReadBits(4));
      ListOfSet.Add(ColSet);
    end;
    Dec(I);
  end;
  UsedSetsCount := 0; //���������� ������������ �������

  for I := 0 to TilesNum - 1 do
  begin
    Index := GetBigStream(UsedSetsCount + 1);
    if Index = 0 then
    begin
      Index := UsedSetsCount;
      Inc(UsedSetsCount);
    end
    else
    begin
      Index := UsedSetsCount - Index;
    end;

    Pixels := TPixels(ListOfSet.Items[Index]);
    if CompressedStreamReadBits(1) = 0 then //Similar Tiles
    begin
      //unpack similar characters
      //���������� ����� �������� �������� �� ����������
      Offset := $FFFFFFFF xor GetBigStream(I); //�������� ����� �������� ����� �� ��� �������������
      Offset := I + Offset;

      //vmap
      vmap := 0;
      if CompressedStreamReadBits(1) = 1 then
      begin
        vmap := GetStream(15);
        vmap := vmap xor 15;
        vmap := vmap shl 4;
      end;
      if CompressedStreamReadBits(1) = 1 then
      begin
        vmap := vmap or 15;
        vmap := vmap xor GetStream(15);
      end;


      //hmap  ����� �����, ���� ��� ���������, �� �������� ���������� ������ ��������, ����� ���������� � �� ������
      hmap := 0;
      if CompressedStreamReadBits(1) = 1 then //� ������� 0..3 ���� ������� ������
      begin
        hmap := GetStream(15); //�������� ����� ����� 0..3
        hmap := hmap xor 15;   //�������� �����
        hmap := hmap shl 4;   //�������� �����, ���������� ����� ��� ���������� ����� 5..7
      end;
      if CompressedStreamReadBits(1) = 1 then //� ������� 4..7 ���� ������� ������
      begin
        hmap := hmap or 15;
        hmap := hmap xor GetStream(15);
      end;

      //���������� 8 ����� ��������, �� 8  ��������
      for Y := 7 downto 0 do
      begin
        if (hmap and (1 shl Y)) <> 0 then
        begin
          Move(Tiles[Offset][7 - Y, 0], Tiles[I][7 - Y, 0], 8);
        end
        else
        begin
          vmaptemp := vmap;
          if ((hmap or (1 shl Y)) <> $FF) then //���� ��� �� ������������ ������ � ������������ vbits
          begin
            //make personal vbits
            for X := 7 downto 0 do  //������� vbits �� ������
            begin
              if vmaptemp in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F] then //���� 7 �������� ��������� � ���� �����, �� 8 �������, � ����� ������ ���������� � ���
                                     //������������� ������� �� ���� ����������.
                Break;
              if (vmap and (1 shl X)) = 0 then
              begin
                vmaptemp := vmaptemp or (CompressedStreamReadBits(1) shl X);
              end;
            end;
          end;

          for X := 7 downto 0 do //���������� 8 �������� ����� ������
          begin
            if (vmaptemp and (1 shl X)) = 0 then
              Tiles[I][7 - Y, 7 - X] := mPixStream(Tiles[Offset][7 - Y, 7 - X], Pixels)
            else
              Tiles[I][7 - Y, 7 - X] := Tiles[Offset][7 - Y, 7 - X];
          end;
        end;
      end;
    end
    else
    begin
      //****************************************************************//
      //****************************************************************//
      //*********************unpack line repeats************************//
      //****************************************************************//
      //****************************************************************//
      //hmap  ����� �����, ���� ��� ���������, �� �������� ���������� ������ ��������, ����� ���������� � �� ������
      //������ ��� �������� 0, � ����� ������ ������������ �� ������
      hmap := 0;
      if CompressedStreamReadBits(1) = 1 then //� ������� 0..4 ���� ������� ������
      begin
        hmap := GetStream(15); //�������� ����� ����� 1..4
        hmap := hmap xor 15;   //�������� �����
        hmap := hmap shl 3;   //�������� �����, ���������� ����� ��� ���������� ����� 5..7
      end;
      if CompressedStreamReadBits(1) = 1 then //� ������� 5..7 ���� ������� ������
      begin
        hmap := hmap or 7;
        hmap := hmap xor GetStream(7);
      end;
      if (hmap and 8) <> 0 then
      begin
        hmap := hmap xor 7;
      end;

      vmap := 0;
      //vmap
      if CompressedStreamReadBits(1) = 1 then
      begin
        vmap := GetStream(15);
        vmap := vmap xor 15;
        vmap := vmap shl 3;
      end;
      if CompressedStreamReadBits(1) = 1 then
      begin
        vmap := vmap or 7;
        vmap := vmap xor GetStream(7);
      end;
      if (vmap and 8) <> 0 then
      begin
        vmap := vmap xor 7;
      end;
      //**************************************************************************
      //���������� ������ ��� �������� 0
      Tiles[I][0, 0] := pixStream(Pixels); //������ ������� ���������� �� ������
      for X := 6 downto 0 do  //���������� ���������� 7 ��������
      begin
        //� vmap �������� ����� ���� ��� ���� �����.
        if (vmap and (1 shl X)) <> 0 then    //���� vbit = 1, �� ��������� ����� �������
        begin //   vbit = 1
          Tiles[I][0, 7 - X] := Tiles[I][0, 7 - X - 1];
        end
        else //���� vbit = 0, �� ���� ������������ ������������ vbit ��� ������ � �������� �� ����.
        begin                //vbit = 0
          if CompressedStreamReadBits(1) = 1 then //personal vbit = 1
          begin
            Tiles[I][0, 7 - X] := mPixStream(Tiles[I][0, 7 - X - 1], Pixels); //���������� �� ������, ��� ���� �������� �� ��������� ����� �������
          end
          else  // personal vbit = 0 ������������ ����� �������
          begin
            Tiles[I][0, 7 - X]:= Tiles[I][0, 7 - X - 1];
          end;
        end;
      end;
      //******************
      //���������� ������ 1..7
      //******************
      vpref := True; //��������������� ����� �������
      for Y := 6 downto 0 do
      begin
        if (hmap and (1 shl Y)) <> 0  then //�������� ���������� ������
        begin
          Move(Tiles[I][7 - Y - 1, 0], Tiles[I][7 - Y, 0], 8); //�������� ���������� ������
        end
        else  //���������� ������� �� ������� ������
        begin
          //���������� ������ ������� ������
          Pixels := TPixels(ListOfSet[Index]);
          if CompressedStreamReadBits(1) = 1 then  //vbit = 1 ���������� �� ������, �������� ������� ������� �� ������
          begin
            Tiles[I][7 - Y, 0] := mPixStream(Tiles[I][7 - Y - 1, 0], Pixels);
          end
          else //vbit = 0 ����� �������� ������� �������
          begin
            Tiles[I][7 - Y, 0] := Tiles[I][7 - Y - 1, 0];
          end;

          for X := 6 downto 0 do //���������� ���������� 7 �������� ������
          begin
            if (vmap and (1 shl X)) <> 0 then  //�������� ����� �������  vbit = 1
            begin
              Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y, 7 - X - 1];
            end
            else //vbit = 0 ���������� ������������ vbit
            begin
              if vpref then //��������������� ����� �������
              begin
                if CompressedStreamReadBits(1) = 1 then  //������������ vbit = 1
                begin
                  Pixels := TPixels(ListOfSet[Index]);
                             //����� �������              //������� �������
                  if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then   //�������� ����� �������
                  begin
                    Tiles[I][7 - Y, 7 - X] := mPixStream(Tiles[I][7 - Y, 7 - X - 1], Pixels); //���������� �� ������ �������� ����� �������
                  end
                  else
                  begin
                    if CompressedStreamReadBits(1) = 1 then //�������� ����� � ������� �������
                    begin
                      System.Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]);//�������� ������� �������
                      System.Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);//�������� ����� �������
                      Tiles[I][7 - Y, 7 - X] := PixStream(Pixels); //���������� ������� �� ������
                    end
                    else
                    begin
                      vpref := false; //��������������� ������� �������
                      Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y - 1, 7 - X];
                    end;
                  end;
                end
                else   //���������� ����� �������
                begin
                  Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y, 7 - X - 1];
                end;
              end
              else  //��������������� ������� �������
              begin
                if CompressedStreamReadBits(1) = 1 then  //������������ vbit = 1
                begin
                  Pixels := TPixels(ListOfSet[Index]);
                            //����� �������               ������� �������
                  if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then   //���� ����� � ������� ������� �����
                  begin
                    Tiles[I][7 - Y, 7 - X] := mPixStream(Tiles[I][7 - Y, 7 - X - 1], Pixels); //���������� ������� �� ������, �������� ����� �������
                  end
                  else
                  begin
                    if CompressedStreamReadBits(1) = 1 then
                    begin
                      System.Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]);//�������� ������� �������
                      System.Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);//�������� ����� �������
                      Tiles[I][7 - Y, 7 - X] := PixStream(Pixels); //���������� ������� �� ������
                    end
                    else
                    begin
                      vpref := true; //��������������� ����� �������
                      Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y, 7 - X - 1];
                    end;
                  end;
                end
                else  //vbit = 0, ���������� ������� �������
                begin
                  Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y - 1, 7 - X];
                end;
              end;
            end;
            ///
          end;
        end;
      end;
    end;
    Tile := _8bppTo4bpp(Tiles[I]);
    Move(Tile, Data[DataStreamPos], SizeOf(TTile4bit));
    Inc(DataStreamPos, SizeOf(TTile4bit));
  end;
  ListOfSet.Free;
  Result.CompressedSize := CompressedStreamPos;
  Result.DecompressedSize := DataSize;
end;

{-------------------------------------------------------------------------------
  �������: SetToArray
  �����:    �����
  ����:  2021.07.11
  ������� ���������: const SetOfPixels
  ���������:    TBytes
  ����������� ��������� � ������
-------------------------------------------------------------------------------}
function SetToArray(const SetOfPixels): TBytes;
var
  I, J: Integer;
  Pixels: TPixels absolute SetOfPixels;
begin
  J := 0;
  for I := 0 to 15 do
  begin
    if I in Pixels then
    begin
      Result[J] := I;
      Inc(J);
    end;
  end;
end;

{-------------------------------------------------------------------------------
  �������: GetElementIndex
  �����:    �����
  ����:  2021.07.11
  ������� ���������: const SetOfPixels; Element: Byte
  ���������:    ShortInt
  �������� ������ �������� �� ���������
-------------------------------------------------------------------------------}
function GetElementIndex(const SetOfPixels; Element: Byte): ShortInt;
var
  I: Integer;
  Pixels: TPixels absolute SetOfPixels;
  P: TBytes;
begin
  Result := -1;
  if Element in Pixels then
  begin
    P := SetToArray(SetOfPixels);
    for I := 0 to 15 do
    begin
      if P[I] = Element then
      begin
        Result := I;
        Break;
      end;
    end;
  end;
end;


{-------------------------------------------------------------------------------
  �������: TCODEC.GetBigStream
  �����:    �����
  ����:  2021.07.11
  ������� ���������: Range: Integer
  ���������:    Integer
  ���������� ����� �� ������, �������������� ������� ��������� ���������,
  ��� ���� ����� ������ 256 ���������� ���������������� �����
-------------------------------------------------------------------------------}
function TCODEC.GetBigStream(Range: Integer): Integer;
begin
  Result := TruncatedToFull(Range);
end;

{-------------------------------------------------------------------------------
  �������: TCODEC.GetStream
  �����:    �����
  ����:  2021.07.11
  ������� ���������: Range: Integer
  ���������:    Integer
  ���������� ����� �� ������, �������������� ������� ��������� ���������
-------------------------------------------------------------------------------}
function TCODEC.GetStream(Range: Integer): Integer;
begin
  Result := TruncatedToFull(Range);
end;

{-------------------------------------------------------------------------------
  �������: TCODEC.mPixStream
  �����:    �����
  ����:  2021.07.11
  ������� ���������: Pixel: Byte; Pixels: TPixels
  ���������:    Byte
  ���������� ������� �� ������, �������� �� ��������� ��������� �������
-------------------------------------------------------------------------------}
function TCODEC.mPixStream(Pixel: Byte; Pixels: TPixels): Byte;
begin
  Exclude(Pixels, Pixel);
  Result := PixStream(Pixels)
end;

{-------------------------------------------------------------------------------
  �������: TCODEC.PixStream
  �����:    �����
  ����:  2021.07.11
  ������� ���������: Pixels: TPixels
  ���������:    Byte
  ���������� ������� �� ������
-------------------------------------------------------------------------------}
function TCODEC.PixStream(Pixels: TPixels): Byte;
var
  ColNums: Byte;
  Index: Word;
begin
  ColNums := CountingBitSet(Word(Pixels));
  Index := GetBigStream(ColNums); //�������� ������ ������� �� ��������� �� ������
  Result := SetToArray(Pixels)[Index];
end;

{-------------------------------------------------------------------------------
  �������: TCODEC.CompressLineRepeatsTiles
  �����:    �����
  ����:  2021.07.10
  ������� ���������: 
  ���������:    Integer
  ������� ��� ����� ����������, ������� ��������� ���������� ������ ��������,
  ���� �������� ������� �, ���� �������� ����������� �������
-------------------------------------------------------------------------------}
function TCODEC.CompressLineRepeatsTiles(): Integer;
var
  X, Y, I: Integer;
  Pixels: TPixels; //����� �������� ��� ����������� �����
  vpref: Boolean; // ���������� ������������, ���� True, �� ��������������� ���������� ����� �������,
                  //���� False, �� �������. ���������������� ������� ����� ����� �������� ���
  vmap, hmap: Byte; //����� ��� ��������(��������) � ����� ��������
begin
  DataStreamPos := 0;
  for I := 0 to TilesNum - 1 do
  begin
    vmap := $7F; //���������� ��� ����, ����� ������
    hmap := 0;
    //ROW 0 ENCODE
    //Encode first pixel directly
    //LineRepeatsTiles[I].PackedData := TruncatedBinary(Tiles[I][0, 0], CountingBitSet(Word(Pixels));
    for X := 1 to 7 do
    begin
      LineRepeatsTiles[I].vbits[0] := LineRepeatsTiles[I].vbits[0] shl 1;
      if Tiles[I][0, X - 1] = Tiles[I][0, X] then
      begin
        Inc(LineRepeatsTiles[I].vbits[0]); //���������� ���
      end
    end;
    vmap := vmap and LineRepeatsTiles[I].vbits[0]; //vmap ����� ����� ��� ���� �����. � ��� ������������� ��������� ������ �� ����,
                                                   //������� ���������� � ���� ����� � ����������� ��������
    //ROW 1..7 ENCODE
    for Y := 1 to 7 do
    begin
      hmap := hmap shl 1;
      if CompareMem(@Tiles[I][Y - 1, 0], @Tiles[I][Y, 0], 8) then
      begin
        Inc(hmap);
      end
      else
      begin
        for X := 1 to 7 do
        begin
          LineRepeatsTiles[I].vbits[Y] := LineRepeatsTiles[I].vbits[Y] shl 1;
          if Tiles[I][Y, X - 1] = Tiles[I][Y, X] then
          begin
            Inc(LineRepeatsTiles[I].vbits[Y]);
          end
        end;
        vmap := vmap and LineRepeatsTiles[I].vbits[Y];
      end;
    end;


    with LineRepeatsTiles[I] do  //��������������� ����������� �����
    begin
      hhi := hmap shr 3;        //��������� ������� � ������� ����� �����
      hlo := hmap and 7;
      if hhi <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(hhi xor 15, 15)
      else
        PackedData := PackedData + '0';

      if (hmap and 8) <> 0 then  //�� ������ ������� ��� ���� ��� ��������, �� ��� � ���������
      begin
        if hlo = 7 then
          PackedData := PackedData + '0'
        else
          PackedData := PackedData + '1' + TruncatedBinary(hlo, 7);
      end
      else
      begin
        if hlo <> 0 then
          PackedData := PackedData + '1' + TruncatedBinary(hlo xor 7, 7)
        else
          PackedData := PackedData + '0';
      end;

      //������ vmap � hmap
      vhi := vmap shr 3;
      vlo := vmap and 7;
      if vhi <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(vhi xor 15, 15)
      else
        PackedData := PackedData + '0';

      if (vmap and 8) <> 0 then
      begin
        if vlo = 7 then
          PackedData := PackedData + '0'
        else
          PackedData := PackedData + '1' + TruncatedBinary(vlo, 7);
      end
      else
      begin
        if vlo <> 0 then
          PackedData := PackedData + '1' + TruncatedBinary(vlo xor 7, 7)
        else
          PackedData := PackedData + '0';
      end;
    end;

    Pixels := TPixels(LineRepeatsTiles[I].Pixels);
    //ROW0 ENCODE
    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][0, 0]), CountingBitSet(Word(Pixels)));
    for X := 6 downto 0 do
    begin
      if (vmap and (1 shl X)) = 0 then //���� ��� ����� 0, �� ���������� ��������� �������������� ��� ������
      begin
        if (LineRepeatsTiles[I].vbits[0] and (1 shl X)) = 0 then 
        begin
          Pixels := TPixels(LineRepeatsTiles[I].Pixels);
          Exclude(Pixels, Tiles[I][0, 7 - X - 1]);
          LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1' + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][0, 7 - X]), CountingBitSet(Word(Pixels)));
        end
        else
          LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0'
      end;
    end;
    //ROW 1..7 ENCODE
    vpref := True;  //��������������� ����� �������
    for Y := 6 downto 0 do  //���������� ���������� 7 ����� ��������
    begin

      if (hmap and (1 shl Y)) = 0 then   //���� 0, �� ������ ����������
      begin
        //���������� ������ ������� ���������� ������
        if Tiles[I][7 - Y, 0] <> Tiles[I][7 - Y - 1, 0] then  //���� ������� ����� ����������/������� ������� ���������� �� �����������
        begin
          Pixels := TPixels(LineRepeatsTiles[I].Pixels);     //������ ����� �������� ��� ����� �����
          Exclude(Pixels, Tiles[I][7 - Y - 1, 0]);           //�������� ������� ������� �� ������, ��� ����� �������� ���������� �������� � ������ � ���������� ��� ��� �����������
          LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1' + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 0]), CountingBitSet(Word(Pixels)));
        end
        else  //������� ����� ���������, ������� ��� 0 � ������ �����
          LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0';

        //���������� ���������� �������
        for X := 6 downto 0 do
        begin
          if (vmap and (1 shl X)) = 0 then //��������� ���� � ����� �����
          begin
            if vpref then //���� ��������������� ����� �������
            begin
                  //���������� �������           //����� �������
              if Tiles[I][7 - Y, 7 - X] <> Tiles[I][7 - Y, 7 - X - 1] then //���� ���������� ������� ���������� �� ������ �������
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1'; //������� � ����� 1
                    //����� �������                     //������� �������
                if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then //���� ����� � ������� ������� �����/������
                begin
                  Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                  Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);   //�������� �� ������ ����� �������
                  //���������� �������, ��������� �������� ���������� ��������� �����������
                  LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                end
                else //����� ����� � ������� ������� �������
                begin
                  //���������� �������                //������� �������
                  if Tiles[I][7 - Y, 7 - X] = Tiles[I][7 - Y - 1, 7 - X]  then //���� ���������� � ������� ������� �����
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0'; //������� � ����� 0
                    vpref := false; //������������ ������� �������� �������
                  end
                  else  //����� ����� � ������� ������� �������
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1'; //������� � ����� 1
                    Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                    Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]); //��������� ����� �������
                    Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]); //��������� ������� �������
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                  end;
                end;
              end
              else  //���������� � ����� ������� �����
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0';
              end;
            end
            else //����� ��������������� ������� �������
            begin
                   //���������� �������           //������� �������
              if Tiles[I][7 - Y, 7 - X] <> Tiles[I][7 - Y - 1, 7 - X]  then  //���� ���������� � ������� ������� �������
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1'; //������� � ����� ��� 1
                            //����� �������             //������� �������
                if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then
                begin
                  Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                  Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);  //�������� ����� ������� �� ������
                  LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                end
                else
                begin
                  //���������� �������                 //����� �������
                  if Tiles[I][7 - Y, 7 - X] = Tiles[I][7 - Y, 7 - X - 1]  then //���� ���������� � ����� ������� �����
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0'; //������� � ����� ��� 0
                    vpref := true;  //������������ ������� ������ �������
                  end
                  else  //����� ������� �������
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1';
                    Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                    Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]); //��������� ����� �������
                    Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]); //��������� ������� �������
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                  end;
                end;
              end
              else  //���������� � ������� ������� �����
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0';
              end;
            end;
          end;
        end;
      end;
    end;
    LineRepeatsTiles[I].PackedSize := Length(LineRepeatsTiles[I].PackedData);
  end;
end;


{-------------------------------------------------------------------------------
  �������: TCODEC.CompressSimilarTiles
  �����:    �����
  ����:  2021.07.11
  ������� ���������: 
  ���������:    Integer
  ������� ����� ���������� ���������� �� �������� ������
-------------------------------------------------------------------------------}
function TCODEC.CompressSimilarTiles(): Integer;
var
  I, X, Y, Index: Integer;
  Pixels: TPixels;
  hmap, vmap, vmaptemp: Byte;
begin
  with SimilarTiles[0] do
  begin
    PackedSize := 65535; //������� ����� �������� ����������� ������� ������, ��� ��� ������ ���� ������ ������������
                         //������ ����������
  end;


  for I := 1 to TilesNum - 1 do
  begin
    Pixels := [];// �������������� ������ �������
    Index := FindSimilarTile(I); //����� ����� ������� ����
    vmap := $FF;
    hmap := 0;
    //����������� ����� �����(hmap) � ��������(vmap)
    FillChar(SimilarTiles[I].vbits[0], 8, 0);
    for Y := 0 to 7 do
    begin
      hmap := hmap shl 1;
      if CompareMem(@Tiles[I][Y, 0], @Tiles[Index][Y, 0], 8) then //���� ������ �����
      begin
        Inc(hmap);  //�������� ��� � 1
      end
      else  //������ �������
      begin
        for X := 0 to 7 do //���������� �������
        begin
          SimilarTiles[I].vbits[Y] := SimilarTiles[I].vbits[Y] shl 1;
          if Tiles[I][Y, X] = Tiles[Index][Y, X] then  //���� ������� �����
          begin
            Inc(SimilarTiles[I].vbits[Y]);   //�������� ������������ ��� � 1
          end
          else  //������� �������
          begin
            Include(Pixels, Tiles[I][Y, X]); //������� ���������� ������� � �����
          end;
        end;
        vmap := vmap and SimilarTiles[I].vbits[Y]; //����������� ����, ������� ������ ������������ ����
      end;
    end;
    SimilarTiles[I].Pixels := Word(Pixels); //

    with SimilarTiles[I] do
    begin
      PackedData := TruncatedBinary(I - Index - 1, I); //���������� ������ �������� ����� � ���� �������� �� ����������� �����
      //������ vmap � hmap
      //���������� vmap
      vhi := vmap shr 4;
      vlo := vmap and $F;
      if vhi <> 0 then                                   //xor'��, ����� ����� ���� � ��������� 0..14
        PackedData := PackedData + '1' + TruncatedBinary(vhi xor 15, 15)
      else
        PackedData := PackedData + '0';
      if vlo <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(vlo xor 15, 15)
      else
        PackedData := PackedData + '0';
      //���������� hmap
      hhi := hmap shr 4;
      hlo := hmap and $F;
      if hhi <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(hhi xor 15, 15)
      else
        PackedData := PackedData + '0';
      if hlo <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(hlo xor 15, 15)
      else
        PackedData := PackedData + '0';
    end;

    //���������� ��������������� ����
    for Y := 7 downto 0 do
    begin
      vmaptemp := vmap; //���� ����� �������� ����� ��� ���� �����
      if (hmap and (1 shl Y)) = 0 then //���� ������ �������
      begin
        //������� � ����� ������������ ����
        if ((hmap or (1 shl Y)) <> $FF) then //���� ��� �� ������������ ������ � ������������ vbits, ������� � ����� ������������ vbits
        begin
          for X := 7 downto 0 do //������ ������������ vbits
          begin
            if (not (vmap in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F])) and ((vmap and (1 shl X)) = 0)  then
            begin
              SimilarTiles[I].PackedData := SimilarTiles[I].PackedData + IntToBin(SimilarTiles[I].vbits[7 - Y] shr X, 1);
              vmaptemp := vmaptemp or (SimilarTiles[I].vbits[7 - Y] and (1 shl X));
              if vmaptemp in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F] then //���� 7 �������� ��������� � ���� �����, �� 8 �������, � ����� ������ ���������� � ���
                                       //������������� ������� �� ���� ����������.
                  Break;
            end;
          end;
        end;
        //���������� ������� �����
        for X := 7 downto 0 do
        begin
          if (SimilarTiles[I].vbits[7 - Y] and (1 shl X)) = 0 then //���� ������� �������
          begin
            Pixels := TPixels(SimilarTiles[I].Pixels);
            Exclude(Pixels, Tiles[Index][7 - Y, 7 - X]);  //�������� ������� �������� �����
            SimilarTiles[I].PackedData := SimilarTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
          end;
        end;
      end;
    end;
    SimilarTiles[I].PackedSize := Length(SimilarTiles[I].PackedData);
  end;
end;

{-------------------------------------------------------------------------------
  �������: TCODEC.FindSimilarTile
  �����:    �����
  ����:  2021.07.10
  ������� ���������: Index: Integer
  ���������:    Integer
  ������� ���� ������� ���� �� ��� �������������� ������
-------------------------------------------------------------------------------}
function TCODEC.FindSimilarTile(Index: Integer): Integer;
var
  I, J, MinDiff, Diff: Integer;
begin
  MinDiff := 65535;
  Result := 0;
  J := Index;
  for I := Index - 1 downto 0 do
  begin
    Diff := CompressSimilarTile(J, I);
    if Diff < MinDiff then
    begin
      MinDiff := Diff;
      Result := I;
    end;
  end;
end;


//The routine Binary is expository; usually just the rightmost len bits of the variable x are desired. Here we simply output the binary code for x using len bits, padding with high-order 0's if necessary.
{-------------------------------------------------------------------------------
  �������: TCODEC.Binary
  �����:    ___
  ����:  2021.07.10
  ������� ���������: x, len: integer
  ���������:    string
  ��������� ����� � �������� ��� � ���� ������
-------------------------------------------------------------------------------}
function TCODEC.Binary(x, len: integer): string;
begin
  result := '';
  while x <> 0 do
  begin
    if (x and 1) = 0 then
      result := '0' + result
    else
      result := '1' + result;
    x := x shr 1;
  end;
  while Length(result) < len do
    result := '0' + result;
end;

//Generate the truncated binary encoding for a value x, 0 <= x < n, where n > 0 is the size of the alphabet containing x. n need not be a power of two.
{-------------------------------------------------------------------------------
  �������: TCODEC.TruncatedBinary
  �����:    __
  ����:  2021.07.10
  ������� ���������: x, n: Integer
  ���������:    string
  �������� ����� ��������� �������� �����

  x - ���������� �����; n - ������ ��������� ��������
-------------------------------------------------------------------------------}
function TCODEC.TruncatedBinary(x, n: Integer): string;
var
  k, t, u, hi, low, xhi, xlow: integer;
begin
  //���������������� ����� ����
  if n > $100 then
  begin
    Dec(n);
    low := n and $FF;
    Inc(low);
    hi := (n shr 8) + 1;
    if x >= low then
    begin
      xhi := ((x - low) shr 8) + 1;
      xlow := (x - low) and $FF;
      Result := TruncatedBinary(xhi, hi) + IntToBin(xlow, 8);
      exit;
    end
    else
    begin
      result := TruncatedBinary(0, hi) + TruncatedBinary(x, low);
      exit;
    end;
  end;

  // Set k = floor(log2(n)), i.e., k such that 2^k <= n < 2^(k+1).
  k := 0; t := n;
  while t > 1 do
  begin
    inc(k);
    t := t shr 1;
  end;
  // Set u to the number of unused codewords = 2^(k+1) - n.
  u := (1 shl (k + 1)) - n;

  if x < u then
    result := Binary(x, k)
  else
    result := Binary(x + u, k + 1);
end;

{ TListOfSet }

function TListOfSet.Add(Value: Word): Integer;
var
  P: PWord;
begin
  New(P);
  P^ := Value;
  Result := inherited Add(P);
end;

function TListOfSet.Contains(SetOfPixels: Word): Boolean;
var
  I: Integer;
begin
  Result := false;
  for I := 0 to Count - 1 do
  begin
    if Items[I] = SetOfPixels then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

destructor TListOfSet.Destroy;
begin
  inherited;
end;

function TListOfSet.Get(Index: Integer): Word;
begin
  Result := Word(inherited Get(Index)^);
end;


function TListOfSet.IndexOf(Item: Word): Integer;
begin
  Result := 0;
  while (Result < Count) and (Items[Result] <> Item) do
    Inc(Result);
  if Result = Count then
    Result := -1;
end;

procedure TListOfSet.Insert(Index: Integer; Value: Word);
var
  P: PWord;
begin
  New(P);
  P^ := Value;
  inherited Insert(Index, P);
end;

procedure TListOfSet.Notify(Ptr: Pointer; Action: TListNotification);
begin
  inherited;
  if (Action = lnDeleted) then
    Dispose(Ptr);
end;


{-------------------------------------------------------------------------------
  �������: TCODEC.CompressSimilarTile
  �����:    �����
  ����:  2021.07.11
  ������� ���������: I, J: Integer
  ���������:    Integer
  ������� ���� ����������, ������� ������� �� �������� ������
-------------------------------------------------------------------------------}
function TCODEC.CompressSimilarTile(I, J: Integer): Integer;
var
  X, Y, Index: Integer;
  Pixels: TPixels;
  hmap, vmap, vmaptemp: Byte;
begin
  Index := J;
  vmap := $FF;
  hmap := 0;
  Pixels := []; //�������������� ������ �������
  FillChar(SimilarTiles[I].vbits[0], 8, 0);
  for Y := 0 to 7 do
  begin
    hmap := hmap shl 1;
    if CompareMem(@Tiles[I][Y, 0], @Tiles[Index][Y, 0], 8) then
    begin
      Inc(hmap);
    end
    else
    begin
      for X := 0 to 7 do
      begin
        SimilarTiles[I].vbits[Y] := SimilarTiles[I].vbits[Y] shl 1;
        if Tiles[I][Y, X] = Tiles[Index][Y, X] then
        begin
          Inc(SimilarTiles[I].vbits[Y]);
        end
        else
        begin
          Include(Pixels, Tiles[I][Y, X]);
        end;
      end;
      vmap := vmap and SimilarTiles[I].vbits[Y];
    end;
  end;
  SimilarTiles[I].Pixels := Word(Pixels);

  with SimilarTiles[I] do
  begin
    PackedSize := Length(TruncatedBinary(I - Index - 1, I));
    //������ vmap � hmap
    vhi := vmap shr 4;
    vlo := vmap and $F;
    Inc(PackedSize, 2);
    if vhi <> 0 then
      PackedSize := PackedSize + Length(TruncatedBinary(vhi xor 15, 15));
    if vlo <> 0 then
      PackedSize := PackedSize + Length(TruncatedBinary(vlo xor 15, 15));

    hhi := hmap shr 4;
    hlo := hmap and $F;

    Inc(PackedSize, 2);
    if hhi <> 0 then
      PackedSize := PackedSize + Length(TruncatedBinary(hhi xor 15, 15));
    if hlo <> 0 then
      PackedSize := PackedSize + Length(TruncatedBinary(hlo xor 15, 15));
  end;

  for Y := 7 downto 0 do
  begin
    vmaptemp := vmap;
    if (hmap and (1 shl Y)) = 0 then
    begin
      if ((hmap or (1 shl Y)) <> $FF) then //���� ��� �� ������������ ������ � ������������ vbits
      begin
        for X := 7 downto 0 do //������ ������������ vbits
        begin
          if (not (vmap in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F])) and ((vmap and (1 shl X)) = 0)  then
          begin
            Inc(SimilarTiles[I].PackedSize);
            vmaptemp := vmaptemp or (SimilarTiles[I].vbits[7 - Y] and (1 shl X));
            if vmaptemp in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F] then //���� 7 �������� ��������� � ���� �����, �� 8 �������, � ����� ������ ���������� � ���
                                     //������������� ������� �� ���� ����������.
                Break;
          end;
        end;
      end;
      for X := 7 downto 0 do
      begin
        if (SimilarTiles[I].vbits[7 - Y] and (1 shl X)) = 0 then
        begin
          Pixels := TPixels(SimilarTiles[I].Pixels);
          Exclude(Pixels, Tiles[Index][7 - Y, 7 - X]);
          SimilarTiles[I].PackedSize := SimilarTiles[I].PackedSize + Length(TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels))));
        end;
      end;
    end;
  end;
  Result := SimilarTiles[I].PackedSize;
end;

{-------------------------------------------------------------------------------
  �������: TCODEC.TruncatedToFull
  �����:    �����
  ����:  2021.07.11
  ������� ���������: Range: Integer
  ���������:    Integer
  �������� �������������� ��������� �������� ��������� � ������ �������� ���������
-------------------------------------------------------------------------------}
function TCODEC.TruncatedToFull(Range: Integer): Integer;
var
  bitCount, x, temp, unused, low, hi, xhi: Integer;
begin
  //���������������� ����� ����
  if Range > $100 then
  begin
    Dec(Range);
    low := Range  and $FF;
    Inc(low);
    hi := (Range shr 8) + 1;
    xhi := TruncatedToFull(hi) - 1;
    if xhi >= 0 then
    begin
      Result := CompressedStreamReadBits(8) + xhi * 256 + low;
      exit;
    end
    else
    begin
      Result := TruncatedToFull(low);
      exit;
    end;
  end;

  // Set k (bitCount) = floor(log2(n)), i.e., k such that 2^k <= n < 2^(k+1).
  temp := Range;
  bitCount := 0;
  while temp > 1 do
  begin
    inc(bitCount);
    temp := temp shr 1;
  end;
  // Set u (unused) to the number of unused codewords = 2^(k+1) - n.
  unused := (1 shl (bitCount + 1)) - Range;
  x := CompressedStreamReadBits(bitCount);
  if x < unused then
    Result := x
  else
    Result := ((x shl 1) or CompressedStreamReadBits(1)) - unused;
end;

//procedure TCODEC.Exclude(var Pixels: Word; I: Byte); assembler;
//asm
//  mov ax,[edx];
//  btr ax,cx
//  mov [edx],ax
//end;
//
//procedure TCODEC.Include(var Pixels: Word; I: Byte); assembler;
//asm
//  mov ax,[edx];
//  bsr ax,cx
//  mov [edx],ax
//end;

end.
