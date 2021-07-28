unit Megapacker;

interface

uses Windows, Classes, SysUtils, Math, DateUtils, Dialogs;

type
  TPixels = set of 0..15; //множество пикселей
  TBytes = array[0..15] of Byte; //массив под множество

  TTile4bit = Array[0..31] of Byte;
  TTile8bit = Array[0..7, 0..7] of Byte;

  TPackedTile = record
    hhi, hlo: Byte; //hbits (horizontal bits) Биты повторения строк пикселей
    vhi, vlo: Byte; //vbits (vertical bits) Биты повторения пикселей - общие для всех строк
    vbits: array[0..7] of Byte; //персональные vbits для каждой строки
    Pixels: Word; //множество пикселей тайла
    PackedData: String; //Сжатые данные тайла в битовом представлении
    PackedSize: Word; //Размер сжатого тайла
  end;

  TListOfSet = class(TList) //класс для хранения списка множеств пикселей для декодирования тайлов
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
    SimilarTiles: array[0..1023] of TPackedTile; //массив под тайлы сжатые алгоритмом схожести тайлов
    LineRepeatsTiles: array[0..1023] of TPackedTile; //массив под тайлы сжатые алгоритмом схожести строк
    Tiles: array[0..1023] of TTile8bit; //массив под тайлы в 8 битном представлении
    ListOfSet: TListOfSet;  //Клосс для хранения списка множеств
    //Truncated binary encoding
    //Generate the truncated binary encoding for a value x, 0 <= x < n, where n > 0 is the size of the alphabet containing x. n need not be a power of two.
    function TruncatedBinary(x, n: Integer): string; //функция преобразования числа с конечным алфавитом в усечённую кодировку
    function TruncatedToFull(Range: Integer): Integer; //функция преобразования из усечённой кодировки в полную
    //The routine Binary is expository; usually just the rightmost len bits of the variable x are desired. Here we simply output the binary code for x using len bits, padding with high-order 0's if necessary.
    function Binary(x, len: integer): string; //Преобразует число в двоичное представлении
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
    function CompressSimilarTiles(): Integer; //сжимает тайлы по методу схожести тайлов
    function CompressSimilarTile(I, J: Integer): Integer; //сжимает тайл по методу схожести тайлов
    function CompressLineRepeatsTiles(): Integer; //сжимает тайлы по методу схожести строк
    function FindSimilarTile(Index: Integer): Integer; //ищет схожий тайл с кодируемым
  end;
    function _4bppto8bpp(Tile: TTile4bit): TTile8bit;
    function _8bppTo4bpp(Tile: TTile8bit): TTile4bit;
    function SetToArray(const SetOfPixels): TBytes; //преобразует множество в массив
    function GetElementIndex(const SetOfPixels; Element: Byte): ShortInt; //возвращает индекс элемента во множестве
    function CountingBitSet(Value: Word): Byte; //считает количество выставленных бит в числе

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
  Функция: BitOnIndex
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: Value: Word
  Результат:    Byte
  возвращает индекс выставленного бита
-------------------------------------------------------------------------------}
function BitOnIndex(Value: Word): Byte;
begin
  for Result := 0 to 15 do
    if Value = (1 shl Result) then
      break;
end;

{-------------------------------------------------------------------------------
  Функция: CountingBitSet
  Автор:    __
  Дата:  2021.07.11
  Входные параметры: Value: Word
  Результат:    Byte
  Возвращает количество выставленных бит в Value
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

  for I := 0 to TilesNum - 1 do //Инициализируем наборы пикселей для каждого тайла
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

  CompressSimilarTiles(); //Сожмём все тайлы каждым из алгоритмов в отдельный массив
  CompressLineRepeatsTiles();

  //****************************************************************
  //**Создадим общий список наборов с учётом изменений после сжатия
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

  //Записываем в выходной поток наборы пикселей для всего архива
  CompressedStreamWriteBits(ListOfSet[0], 16); //Первый набор отправляем без кодирования
  for J := 1 to ListOfSet.Count - 1 do
  begin
    for K := 0 to J - 1 do //Цикл в котором ищем набор, который отличается от кодируемого на один бит
    begin
      if CountingBitSet(ListOfSet[K] xor ListOfSet[J]) = 1 then //Если наборы отличаются на 1 бит/пиксель
      begin
        Index := J - K - 1; //Вычислим индекс набора
        CompressedStreamWriteBit(false);
        CompressedStreamWriteBits(TruncatedBinary(Index, J)); //закодируем индекс усечённым бинарным кодом
        Index := BitOnIndex(ListOfSet[K] xor ListOfSet[J]); //вычисли индекс бита, на который отличаются наборы
        CompressedStreamWriteBits(Index, 4); //отправим в сжатый поток без кодирования
        Break;
      end;
    end;
    if K = J then //Если таковых наборов нет, то отправим набор в сжатый поток без кодирования
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
  vpref: Boolean; //Предпочтительный пиксель, если true, предпочтительно левый пиксель, если false, предпочтительно верхний пиксель
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
  ListOfSet.Add(CompressedStreamReadBits(16)); //Добавим первый набор в список
  while I > 0 do
  begin
    If CompressedStreamReadBits(1) = 1 then
    begin
      ListOfSet.Add(CompressedStreamReadBits(16));// Получим набор из сжатого потока
    end
    else   //иначе вычислим набор через дельту.
    begin
      Delta := GetBigStream(ListOfSet.Count);
      Index := ListOfSet.Count - Delta  - 1; //Вычислим индекс набора, из которого путём исключения/включения, получим новый набор
      ColSet := ListOfSet.Items[Index];
      ColSet := ColSet xor (1 shl CompressedStreamReadBits(4));
      ListOfSet.Add(ColSet);
    end;
    Dec(I);
  end;
  UsedSetsCount := 0; //Количество используемых наборов

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
      //Распаковка тайла частично похожего на предыдущие
      Offset := $FFFFFFFF xor GetBigStream(I); //Получаем офсет похожего тайла из уже распакованных
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


      //hmap  карта строк, если бит выставлен, то копируем предыдущую строку пикселей, иначе декодируем её из потока
      hmap := 0;
      if CompressedStreamReadBits(1) = 1 then //В строках 0..3 есть похожие строки
      begin
        hmap := GetStream(15); //получаем карту строк 0..3
        hmap := hmap xor 15;   //инверсия битов
        hmap := hmap shl 4;   //сдвигаем влево, освобождая место для оставшихся строк 5..7
      end;
      if CompressedStreamReadBits(1) = 1 then //в строках 4..7 есть похожие строки
      begin
        hmap := hmap or 15;
        hmap := hmap xor GetStream(15);
      end;

      //Декодируем 8 строк пикселей, по 8  пикселей
      for Y := 7 downto 0 do
      begin
        if (hmap and (1 shl Y)) <> 0 then
        begin
          Move(Tiles[Offset][7 - Y, 0], Tiles[I][7 - Y, 0], 8);
        end
        else
        begin
          vmaptemp := vmap;
          if ((hmap or (1 shl Y)) <> $FF) then //Если это не единственная строка с персональным vbits
          begin
            //make personal vbits
            for X := 7 downto 0 do  //считаем vbits из потока
            begin
              if vmaptemp in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F] then //Если 7 пикселей идентичны у двух строк, то 8 пиксель, в любом случае отличается и нет
                                     //необходимости хранить об этом информацию.
                Break;
              if (vmap and (1 shl X)) = 0 then
              begin
                vmaptemp := vmaptemp or (CompressedStreamReadBits(1) shl X);
              end;
            end;
          end;

          for X := 7 downto 0 do //декодируем 8 пикселей одной строки
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
      //hmap  карта строк, если бит выставлен, то копируем предыдущую строку пикселей, иначе декодируем её из потока
      //строка под индексом 0, в любом случае декодируется из потока
      hmap := 0;
      if CompressedStreamReadBits(1) = 1 then //В строках 0..4 есть похожие строки
      begin
        hmap := GetStream(15); //получаем карту строк 1..4
        hmap := hmap xor 15;   //инверсия битов
        hmap := hmap shl 3;   //сдвигаем влево, освобождая место для оставшихся строк 5..7
      end;
      if CompressedStreamReadBits(1) = 1 then //в строках 5..7 есть похожие строки
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
      //ДЕКОДИРУЕМ СТРОКУ ПОД ИНДЕКСОМ 0
      Tiles[I][0, 0] := pixStream(Pixels); //Первый пиксель декодируем из потока
      for X := 6 downto 0 do  //Декодируем оставшиеся 7 пикселей
      begin
        //в vmap хранятся общие биты для всех строк.
        if (vmap and (1 shl X)) <> 0 then    //Если vbit = 1, то повторить левый пиксель
        begin //   vbit = 1
          Tiles[I][0, 7 - X] := Tiles[I][0, 7 - X - 1];
        end
        else //Если vbit = 0, то надо декодировать персональный vbit для строки и смотреть по нему.
        begin                //vbit = 0
          if CompressedStreamReadBits(1) = 1 then //personal vbit = 1
          begin
            Tiles[I][0, 7 - X] := mPixStream(Tiles[I][0, 7 - X - 1], Pixels); //декодируем из потока, при этом исключим из множества левый пиксель
          end
          else  // personal vbit = 0 Использовать левый пиксель
          begin
            Tiles[I][0, 7 - X]:= Tiles[I][0, 7 - X - 1];
          end;
        end;
      end;
      //******************
      //Декодируем строки 1..7
      //******************
      vpref := True; //Предпочтительно левый пиксель
      for Y := 6 downto 0 do
      begin
        if (hmap and (1 shl Y)) <> 0  then //Повторим предыдущую строку
        begin
          Move(Tiles[I][7 - Y - 1, 0], Tiles[I][7 - Y, 0], 8); //Копируем предыдущую строку
        end
        else  //Декодируем пиксели из сжатого потока
        begin
          //Декодируем первый пиксель строки
          Pixels := TPixels(ListOfSet[Index]);
          if CompressedStreamReadBits(1) = 1 then  //vbit = 1 Декодируем из потока, исключив верхний пиксель из набора
          begin
            Tiles[I][7 - Y, 0] := mPixStream(Tiles[I][7 - Y - 1, 0], Pixels);
          end
          else //vbit = 0 иначе повторим верхний пиксель
          begin
            Tiles[I][7 - Y, 0] := Tiles[I][7 - Y - 1, 0];
          end;

          for X := 6 downto 0 do //Декодируем оставшиеся 7 пикселей строки
          begin
            if (vmap and (1 shl X)) <> 0 then  //повторим левый пиксель  vbit = 1
            begin
              Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y, 7 - X - 1];
            end
            else //vbit = 0 декодируем персональный vbit
            begin
              if vpref then //предпочтительно левый пиксель
              begin
                if CompressedStreamReadBits(1) = 1 then  //персональный vbit = 1
                begin
                  Pixels := TPixels(ListOfSet[Index]);
                             //левый пиксель              //верхний пиксель
                  if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then   //исключим левый пиксель
                  begin
                    Tiles[I][7 - Y, 7 - X] := mPixStream(Tiles[I][7 - Y, 7 - X - 1], Pixels); //декодируем из потока исключив левый пиксель
                  end
                  else
                  begin
                    if CompressedStreamReadBits(1) = 1 then //исключим левый и верхний пиксель
                    begin
                      System.Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]);//исключим верхний пиксель
                      System.Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);//исключим левый пиксель
                      Tiles[I][7 - Y, 7 - X] := PixStream(Pixels); //декодируем пиксель из потока
                    end
                    else
                    begin
                      vpref := false; //предпочтительно верхний пиксель
                      Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y - 1, 7 - X];
                    end;
                  end;
                end
                else   //Используем левый пиксель
                begin
                  Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y, 7 - X - 1];
                end;
              end
              else  //предпочтительно верхний пиксель
              begin
                if CompressedStreamReadBits(1) = 1 then  //персональный vbit = 1
                begin
                  Pixels := TPixels(ListOfSet[Index]);
                            //левый пиксель               верхний пиксель
                  if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then   //Если левый и верхний пиксель равны
                  begin
                    Tiles[I][7 - Y, 7 - X] := mPixStream(Tiles[I][7 - Y, 7 - X - 1], Pixels); //декодируем пиксель из потока, исключив левый пиксель
                  end
                  else
                  begin
                    if CompressedStreamReadBits(1) = 1 then
                    begin
                      System.Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]);//исключим верхний пиксель
                      System.Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);//исключим левый пиксель
                      Tiles[I][7 - Y, 7 - X] := PixStream(Pixels); //декодируем пиксель из потока
                    end
                    else
                    begin
                      vpref := true; //Предпочтительно левый пиксель
                      Tiles[I][7 - Y, 7 - X] := Tiles[I][7 - Y, 7 - X - 1];
                    end;
                  end;
                end
                else  //vbit = 0, используем верхний пиксель
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
  Функция: SetToArray
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: const SetOfPixels
  Результат:    TBytes
  Преобразует множество в массив
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
  Функция: GetElementIndex
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: const SetOfPixels; Element: Byte
  Результат:    ShortInt
  Получает индекс элемента во множестве
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
  Функция: TCODEC.GetBigStream
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: Range: Integer
  Результат:    Integer
  Декодирует число из потока, закодированное методом усечённой кодировки,
  при этом число больше 256 кодируется модифицированным кодом
-------------------------------------------------------------------------------}
function TCODEC.GetBigStream(Range: Integer): Integer;
begin
  Result := TruncatedToFull(Range);
end;

{-------------------------------------------------------------------------------
  Функция: TCODEC.GetStream
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: Range: Integer
  Результат:    Integer
  Декодирует число из потока, закодированное методом усечённой кодировки
-------------------------------------------------------------------------------}
function TCODEC.GetStream(Range: Integer): Integer;
begin
  Result := TruncatedToFull(Range);
end;

{-------------------------------------------------------------------------------
  Функция: TCODEC.mPixStream
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: Pixel: Byte; Pixels: TPixels
  Результат:    Byte
  Декодирует пиксель из потока, исключая из множества известный пиксель
-------------------------------------------------------------------------------}
function TCODEC.mPixStream(Pixel: Byte; Pixels: TPixels): Byte;
begin
  Exclude(Pixels, Pixel);
  Result := PixStream(Pixels)
end;

{-------------------------------------------------------------------------------
  Функция: TCODEC.PixStream
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: Pixels: TPixels
  Результат:    Byte
  Декодирует пиксель из потока
-------------------------------------------------------------------------------}
function TCODEC.PixStream(Pixels: TPixels): Byte;
var
  ColNums: Byte;
  Index: Word;
begin
  ColNums := CountingBitSet(Word(Pixels));
  Index := GetBigStream(ColNums); //Получаем индекс пикселя во множестве из потока
  Result := SetToArray(Pixels)[Index];
end;

{-------------------------------------------------------------------------------
  Функция: TCODEC.CompressLineRepeatsTiles
  Автор:    Марат
  Дата:  2021.07.10
  Входные параметры: 
  Результат:    Integer
  Сжимает все тайлы алгоритмом, который повторяет предыдущую строку пикселей,
  либо полность копирую её, либо частично модифицируя пиксели
-------------------------------------------------------------------------------}
function TCODEC.CompressLineRepeatsTiles(): Integer;
var
  X, Y, I: Integer;
  Pixels: TPixels; //Набор пикселей для кодирования тайла
  vpref: Boolean; // переменная предпочтения, если True, то предопчтительно копируется левый пиксель,
                  //если False, то верхний. Предпочтительный пиксель имеет более короткий код
  vmap, hmap: Byte; //карты для столбцов(пикселей) и строк пикселей
begin
  DataStreamPos := 0;
  for I := 0 to TilesNum - 1 do
  begin
    vmap := $7F; //Выставляем все биты, кроме левого
    hmap := 0;
    //ROW 0 ENCODE
    //Encode first pixel directly
    //LineRepeatsTiles[I].PackedData := TruncatedBinary(Tiles[I][0, 0], CountingBitSet(Word(Pixels));
    for X := 1 to 7 do
    begin
      LineRepeatsTiles[I].vbits[0] := LineRepeatsTiles[I].vbits[0] shl 1;
      if Tiles[I][0, X - 1] = Tiles[I][0, X] then
      begin
        Inc(LineRepeatsTiles[I].vbits[0]); //Выставляем бит
      end
    end;
    vmap := vmap and LineRepeatsTiles[I].vbits[0]; //vmap общая карта для всех строк. В ней выставленными останутся только те биты,
                                                   //которые выставлены у всех строк с одноименным индексом
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


    with LineRepeatsTiles[I] do  //Непосредственно кодирование тайла
    begin
      hhi := hmap shr 3;        //извлекаем старшую и младшую часть карты
      hlo := hmap and 7;
      if hhi <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(hhi xor 15, 15)
      else
        PackedData := PackedData + '0';

      if (hmap and 8) <> 0 then  //не совсем понятно для чего так делается, но так в оригинале
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

      //запись vmap и hmap
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
      if (vmap and (1 shl X)) = 0 then //Если бит равен 0, то необходимо проверить индивидуальный бит строки
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
    vpref := True;  //предпочтительно левый пиксель
    for Y := 6 downto 0 do  //закодируем оставшиеся 7 строк пикселей
    begin

      if (hmap and (1 shl Y)) = 0 then   //Если 0, то строки отличаются
      begin
        //Закодируем первый пиксель кодируемой строки
        if Tiles[I][7 - Y, 0] <> Tiles[I][7 - Y - 1, 0] then  //Если пиксели строк отличаются/верхний пиксель отличается от кодируемого
        begin
          Pixels := TPixels(LineRepeatsTiles[I].Pixels);     //Возьмём набор пикселей для этого тайла
          Exclude(Pixels, Tiles[I][7 - Y - 1, 0]);           //Исключим верхний пиксель из набора, тем самым уменьшив количество пикселей в наборе и количество бит для кодирования
          LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1' + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 0]), CountingBitSet(Word(Pixels)));
        end
        else  //Пиксели строк совпадают, выдадим бит 0 в сжатый поток
          LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0';

        //Закодируем оставшиеся пиксели
        for X := 6 downto 0 do
        begin
          if (vmap and (1 shl X)) = 0 then //Тестируем биты в общей карте
          begin
            if vpref then //если предпочтительно левый пиксель
            begin
                  //кодируемый пиксель           //левый пиксель
              if Tiles[I][7 - Y, 7 - X] <> Tiles[I][7 - Y, 7 - X - 1] then //Если кодируемый пиксель отличается от левого пикселя
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1'; //выдадим в поток 1
                    //левый пиксель                     //верхний пиксель
                if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then //если левый и верхний пиксель равны/похожи
                begin
                  Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                  Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);   //исключим из набора левый пиксель
                  //закодируем пиксель, используя алгоритм усечённого бинарного кодирования
                  LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                end
                else //иначе левый и верхний пиксель неравны
                begin
                  //кодируемый пиксель                //верхний пиксель
                  if Tiles[I][7 - Y, 7 - X] = Tiles[I][7 - Y - 1, 7 - X]  then //если кодируемый и верхний пиксель равны
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0'; //выдадим в поток 0
                    vpref := false; //предпочтение отдадим верхнему пикселю
                  end
                  else  //иначе левый и верхний пиксель неравны
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1'; //выдадим в поток 1
                    Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                    Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]); //исключаем левый пиксель
                    Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]); //исключаем верхний пиксель
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                  end;
                end;
              end
              else  //кодируемый и левый пиксель равны
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0';
              end;
            end
            else //иначе предпочтительно верхний пиксель
            begin
                   //кодируемый пиксель           //верхний пиксель
              if Tiles[I][7 - Y, 7 - X] <> Tiles[I][7 - Y - 1, 7 - X]  then  //если кодируемый и верхний пиксель неравны
              begin
                LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1'; //выдадим в потко код 1
                            //левый пиксель             //верхний пиксель
                if Tiles[I][7 - Y, 7 - X - 1] = Tiles[I][7 - Y - 1, 7 - X] then
                begin
                  Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                  Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]);  //исключим левый пиксель из набора
                  LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                end
                else
                begin
                  //кодируемый пиксель                 //левый пиксель
                  if Tiles[I][7 - Y, 7 - X] = Tiles[I][7 - Y, 7 - X - 1]  then //если кодируемый и левый пиксель равны
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '0'; //выдадим в поток код 0
                    vpref := true;  //Предпочтение отдадим левому пикселю
                  end
                  else  //иначе пиксели неравны
                  begin
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + '1';
                    Pixels := TPixels(LineRepeatsTiles[I].Pixels);
                    Exclude(Pixels, Tiles[I][7 - Y, 7 - X - 1]); //исключаем левый пиксель
                    Exclude(Pixels, Tiles[I][7 - Y - 1, 7 - X]); //исключаем верхний пиксель
                    LineRepeatsTiles[I].PackedData := LineRepeatsTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
                  end;
                end;
              end
              else  //кодируемый и верхний пиксель равны
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
  Функция: TCODEC.CompressSimilarTiles
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: 
  Результат:    Integer
  Сжимает тайлы алгоритмом основанным на схожести тайлов
-------------------------------------------------------------------------------}
function TCODEC.CompressSimilarTiles(): Integer;
var
  I, X, Y, Index: Integer;
  Pixels: TPixels;
  hmap, vmap, vmaptemp: Byte;
begin
  with SimilarTiles[0] do
  begin
    PackedSize := 65535; //Первому тайлу назначим максимально большой размер, так как первый тайл нельзя закодировать
                         //данным алгоритмом
  end;


  for I := 1 to TilesNum - 1 do
  begin
    Pixels := [];// Инициализируем пустым набором
    Index := FindSimilarTile(I); //Найдём самый похожий тайл
    vmap := $FF;
    hmap := 0;
    //Сгенерируем карты строк(hmap) и пикселей(vmap)
    FillChar(SimilarTiles[I].vbits[0], 8, 0);
    for Y := 0 to 7 do
    begin
      hmap := hmap shl 1;
      if CompareMem(@Tiles[I][Y, 0], @Tiles[Index][Y, 0], 8) then //Если строки равны
      begin
        Inc(hmap);  //выставим бит в 1
      end
      else  //строки неравны
      begin
        for X := 0 to 7 do //закодируем пиксели
        begin
          SimilarTiles[I].vbits[Y] := SimilarTiles[I].vbits[Y] shl 1;
          if Tiles[I][Y, X] = Tiles[Index][Y, X] then  //если пиксели равны
          begin
            Inc(SimilarTiles[I].vbits[Y]);   //выставим персональный бит в 1
          end
          else  //пиксели неравны
          begin
            Include(Pixels, Tiles[I][Y, X]); //включим кодируемый пиксель в набор
          end;
        end;
        vmap := vmap and SimilarTiles[I].vbits[Y]; //Замаскируем биты, оставив только выставленные биты
      end;
    end;
    SimilarTiles[I].Pixels := Word(Pixels); //

    with SimilarTiles[I] do
    begin
      PackedData := TruncatedBinary(I - Index - 1, I); //Закодируем индекс похожего тайла в виде смещения от кодируемого тайла
      //запись vmap и hmap
      //закодируем vmap
      vhi := vmap shr 4;
      vlo := vmap and $F;
      if vhi <> 0 then                                   //xor'им, чтобы число было в диапазоне 0..14
        PackedData := PackedData + '1' + TruncatedBinary(vhi xor 15, 15)
      else
        PackedData := PackedData + '0';
      if vlo <> 0 then
        PackedData := PackedData + '1' + TruncatedBinary(vlo xor 15, 15)
      else
        PackedData := PackedData + '0';
      //закодируем hmap
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

    //закодируем непосредственно тайл
    for Y := 7 downto 0 do
    begin
      vmaptemp := vmap; //берём карту пикселей общую для всех строк
      if (hmap and (1 shl Y)) = 0 then //если строки неравны
      begin
        //Выдадим в поток персональные биты
        if ((hmap or (1 shl Y)) <> $FF) then //Если это не единственная строка с персональным vbits, выдадим в поток персональные vbits
        begin
          for X := 7 downto 0 do //запись персональных vbits
          begin
            if (not (vmap in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F])) and ((vmap and (1 shl X)) = 0)  then
            begin
              SimilarTiles[I].PackedData := SimilarTiles[I].PackedData + IntToBin(SimilarTiles[I].vbits[7 - Y] shr X, 1);
              vmaptemp := vmaptemp or (SimilarTiles[I].vbits[7 - Y] and (1 shl X));
              if vmaptemp in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F] then //Если 7 пикселей идентичны у двух строк, то 8 пиксель, в любом случае отличается и нет
                                       //необходимости хранить об этом информацию.
                  Break;
            end;
          end;
        end;
        //Закодируем пиксели строк
        for X := 7 downto 0 do
        begin
          if (SimilarTiles[I].vbits[7 - Y] and (1 shl X)) = 0 then //Если пиксели неравны
          begin
            Pixels := TPixels(SimilarTiles[I].Pixels);
            Exclude(Pixels, Tiles[Index][7 - Y, 7 - X]);  //исключим пиксель похожего тайла
            SimilarTiles[I].PackedData := SimilarTiles[I].PackedData + TruncatedBinary(GetElementIndex(Pixels, Tiles[I][7 - Y, 7 - X]), CountingBitSet(Word(Pixels)));
          end;
        end;
      end;
    end;
    SimilarTiles[I].PackedSize := Length(SimilarTiles[I].PackedData);
  end;
end;

{-------------------------------------------------------------------------------
  Функция: TCODEC.FindSimilarTile
  Автор:    Марат
  Дата:  2021.07.10
  Входные параметры: Index: Integer
  Результат:    Integer
  Функция ищет похожий тайл из уже закодированных тайлов
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
  Функция: TCODEC.Binary
  Автор:    ___
  Дата:  2021.07.10
  Входные параметры: x, len: integer
  Результат:    string
  Переводит число в бинарный код в виде строки
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
  Функция: TCODEC.TruncatedBinary
  Автор:    __
  Дата:  2021.07.10
  Входные параметры: x, n: Integer
  Результат:    string
  Кодирует число усечённым бинарным кодом

  x - кодируемое число; n - размер конечного алфавита
-------------------------------------------------------------------------------}
function TCODEC.TruncatedBinary(x, n: Integer): string;
var
  k, t, u, hi, low, xhi, xlow: integer;
begin
  //модифицированная часть кода
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
  Функция: TCODEC.CompressSimilarTile
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: I, J: Integer
  Результат:    Integer
  Сжимает тайл алгоритмом, который основан на схожести тайлов
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
  Pixels := []; //Инициализируем пустым набором
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
    //запись vmap и hmap
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
      if ((hmap or (1 shl Y)) <> $FF) then //Если это не единственная строка с персональным vbits
      begin
        for X := 7 downto 0 do //запись персональных vbits
        begin
          if (not (vmap in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F])) and ((vmap and (1 shl X)) = 0)  then
          begin
            Inc(SimilarTiles[I].PackedSize);
            vmaptemp := vmaptemp or (SimilarTiles[I].vbits[7 - Y] and (1 shl X));
            if vmaptemp in [$FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F] then //Если 7 пикселей идентичны у двух строк, то 8 пиксель, в любом случае отличается и нет
                                     //необходимости хранить об этом информацию.
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
  Функция: TCODEC.TruncatedToFull
  Автор:    Марат
  Дата:  2021.07.11
  Входные параметры: Range: Integer
  Результат:    Integer
  Обратное преобразование усечённой двоичной кодировки в полную двоичную кодировку
-------------------------------------------------------------------------------}
function TCODEC.TruncatedToFull(Range: Integer): Integer;
var
  bitCount, x, temp, unused, low, hi, xhi: Integer;
begin
  //модифицированная часть кода
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
