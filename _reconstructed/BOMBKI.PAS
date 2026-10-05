program BOMBKI;
{ Turbo Pascal 7.0 real-mode main program of BOMBKI.EXE.
  MZ: CS:IP = 0000:B0CF, header paragraphs 0x52E, image length 0x1D4F0;
  img = file[0x52E*16:]. At img 0xB0CF sits lcall 1C71:0000 (System
  bootstrap); program prologue at img 0xB0D9; wrapped near-call at img 0xB0E8
  enters WybierzRase at img 0x16EF, which far-calls MONSTRA.WSTEP (the intro)
  at img 0x16F9. Main loop bleed tick at img 0xB193; ordered room dispatch
  at img 0xB1E5. Backedge img 0xF5BF returns to img 0xB0F0. }
uses
  crt, swiat, przedm, monstra;

{ program-level DGROUP workspace:
    ds:0x007E  plik / save-file TextRec (img 0x2BEA..0x2BF4)
    ds:0x0564  PRZEDM.wpisz / command buffer (PRZEDM.KOMENDY at img 0x1BB07)
  Other unit-owned globals live in the SWIAT/PRZEDM/MONSTRA interface vars. }

label
  L1012_ZachetaPodswiadomosc, L1025_Wyjscie,
  L1027_Ucieczka16, L1028_PoUcieczce16;
const
  MIECHO_Podswiadomosc = 1000; { subconscious (MODE) context }
  MIECHO_Smierc = 10000; { smierc context at img 0xEA22 }
var
  Unused0052: Integer; { effectively unused: only saved/loaded, no business code }
  JakaBron: Integer; { invented label for DGROUP word 0x054 }
  ZapisanoGre: Integer; { invented label for DGROUP word 0x056 }
  StanCieniasa: Integer;  { invented label for DGROUP word 0x058 }
  StanZrecznego: Integer;  { invented label for DGROUP word 0x05A }
  StanOdpornego: Integer;  { invented label for DGROUP word 0x05C }
  StanOgromnego: Integer;  { invented label for DGROUP word 0x05E }
  JakaTarcza: Integer;  { invented label for DGROUP word 0x060 }
  LimitPrzedmiotow: Integer;     { invented label for DGROUP word 0x062 }
  Unused0064: Integer; { completely unused: no references }
  WartoscMiecza: Integer; { invented label for DGROUP word 0x066 }
  WartoscTarczy: Integer; { invented label for DGROUP word 0x068 }
  WartoscSerca: Integer; { invented label for DGROUP word 0x06A }
  PunktKontrolny: Integer; { invented label for DGROUP word 0x06C }
  SilaZbroi: Integer; { S.Z. = PRO + 10 * PRZEDM.ILOSC }
  GodzinySnu: Integer;         { invented label for SPIJ counter at DGROUP word 0x070 }
  Unused0072: Integer; { completely unused: no references }
  PotrawkiNiepotrzebnaZmiennaBug: Integer; { saved word at DGROUP 0x074 }
  Unused0076: Integer; { completely unused: no references }
  Powracanie: Integer;     { invented label for DGROUP word 0x078 }
  PrzedmScrollPowrot: Integer; { invented label for DGROUP word 0x07A }
  PrzedmPiwo: Integer; { invented label for DGROUP word 0x07C }
  plik: Text;              { main-program file record at DGROUP 0x007E }

procedure WalkaKoncert; forward;
procedure WybierzRase; forward;
procedure PunktyKontrolne; forward;
procedure SprawdzCzyZdobylesLevel; forward;
procedure Trening; forward;
procedure Pokoj2; forward;
procedure Pokoj3; forward;
procedure Pokoj9; forward;
procedure Pokoj12; forward;
procedure WalkaMiasto; forward;
procedure ZakupyPiekarnia; forward;
procedure ZakupyZbrojownia; forward;
procedure ZakupySklepWielobranzowy; forward;
procedure ZakupySklepMagiczny; forward;
procedure PokojeKoncertowe; forward;
procedure ZapiszPostac; forward;
procedure Smierc; forward;
procedure WczytajPostac; forward;
procedure PokazPostac; forward;

procedure PokazPostac;
{ Invented source name for the inventory/status portion of the JA helper at
  img 0x073C..0x1405 (called through the near-call at img 0xEC98). }
begin
  { img 0x073C..0x07D4: carrying-capacity calculation in the JA handler. }
  if ZRE < 11 then LimitPrzedmiotow := 10;
  if (ZRE > 10) and (ZRE < 13) then LimitPrzedmiotow := 11;
  if (ZRE > 12) and (ZRE < 16) then LimitPrzedmiotow := 12;
  if (ZRE > 15) and (ZRE < 19) then LimitPrzedmiotow := 13;
  if (ZRE > 18) and (ZRE < 21) then LimitPrzedmiotow := 14;
  if (ZRE > 20) and (ZRE < 25) then LimitPrzedmiotow := 15;
  if ZRE > 24 then LimitPrzedmiotow := 16;
  if PRZEDM.PLECAK < 0 then LimitPrzedmiotow := LimitPrzedmiotow + 4;
  WriteLn('NOSISZ ZE SOBA:'); { inventory header at img 0x07D4..0x07EB }
  if MMIECZ <= -10 then WriteLn('STARY ZARDZEWIALY MIECZ');
  if MTARCZA <= -10 then WriteLn('OKRAGLA MALA TARCZA');
  if SERCE <= -10 then WriteLn('ZAKRWAWIONE SERCE');
  if DYPLOM <= -10 then WriteLn('DYPLOM MUD SZKOLY');
  if PACZEK <= -10 then WriteLn('SMACZNY POLANY LIKIEREM PACZEK', PACZEK:10);
  if CIASTKO <= -10 then WriteLn('SMACZNE CIASTKO ', CIASTKO:10);
  if SUCHA <= -10 then WriteLn('TWARDA SUCHA RACJE', SUCHA:10);
  if BULKA <= -10 then WriteLn('OKRAGLA PACHNACA BULKA', BULKA:10);
  if CHLEB <= -10 then WriteLn('DUZY CIEPLY CHLEB', CHLEB:10);
  if WEKA <= -10 then WriteLn('DLUGA I SMACZNA WEKE', WEKA:10);
  if BIGOS <= -10 then WriteLn('PYSZNY BIGOS Z KAPUSTA Z WROGA', BIGOS:10);
  if PrzedmPiwo <= -10 then
    WriteLn('OZEWIAJACE PIWSKO Z KONKRETNYM KLIMATEM', PrzedmPiwo div 10);
  if FAJKA <= -10 then WriteLn('CIEZKA FAJKA OD DZIADA MROZA', FAJKA);
  if KOMPLET <= -10 then WriteLn('KOMPLET UBRAN FIRMY "SYF"', KOMPLET);
  if GARNITUR <= -10 then WriteLn('GARNITUR Z KOLCAMI', GARNITUR);
  if MBUTELKA <= -10 then WriteLn('MALA BUTELKE MANY', MBUTELKA);
  if LISTEK <= -10 then WriteLn('DELIKATNY CHOC SZORSTKI LISTEK', LISTEK);
  if kaseta <= -10 then WriteLn('KASETA LIROYA : L - JAK LIROY ', kaseta);
  if PIGULKA <= -10 then WriteLn('PIGULKA TRANSPORTUJACA (M:G) ', PIGULKA);
  if PRZEPUSTKA <= -10 then
    WriteLn('PRZEPUSTKA WLASNORECZNIE PODPISANA PRZEZ QUEST-MASTERA ', PRZEPUSTKA);
  if SCROLLPOR <= -10 then WriteLn('SCROLL Z CZAREM : POROWNYWANIE ', SCROLLPOR);
  if PrzedmScrollPowrot <= -10 then WriteLn('SCROLL Z CZAREM : POWROT ', PrzedmScrollPowrot);
  WriteLn('W SUMIE MASZ ', PRZED, '/', LimitPrzedmiotow, ' PRZEDMIOTOW');
  if JakaBron = 0 then WriteLn('BIJESZ SIE NA PIESCI');
  if JakaTarcza = 0 then WriteLn('NIE MASZ ZADNEJ OCHRONY');
  if PRZEDM.JAKIEUB = '' then WriteLn('JESTES NAGI !!!!!!!!');
  if PRZEDM.JAKIEUB = 'SYF' then WriteLn('MASZ NA SOBIE KOMPLET UBRAN FIRMY "SYF"');
  if PRZEDM.JAKIEUB = 'GARNITUR' then WriteLn('MASZ NA SOBIE GRANITUR Z KOLCAMI ');
  if (JakaTarcza = 1) and (MTARCZA = -100) then
    WriteLn('TWOJA OCHRONA JEST MALA TARCZA');
  if (JakaBron = 1) and (MMIECZ = -100) then
    WriteLn('JAKO BRONI UZYWASZ STAREGO MIECZA');
  WriteLn('MASZ ', FORSA, ' MONET I ', PRA, ' PRAKTYK');
  if POZIOM = 1 then begin
    WriteLn('JESTES NA PIERWSZYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', 700 - KUNSZT, ' KUNSZTU');
  end;
  if POZIOM = 2 then begin
    WriteLn('JESTES NA DRUGIM LEVELU A DO NASTEPNEGO BRAKUJE CI ', 725 - KUNSZT, ' KUNSZTU');
  end;
  if POZIOM = 3 then begin
    WriteLn('JESTES NA TRZECIM LEVELU A DO NASTEPNEGO BRAKUJE CI ', 730 - KUNSZT, 'KUNSZTU');
  end;
  if POZIOM = 4 then begin
    WriteLn('JESTES NA CZWARTYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 5 then begin
    WriteLn('JESTES NA PIATYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 6 then begin
    WriteLn('JESTES NA SZ'#224'STYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 7 then begin
    WriteLn('JESTES NA SIODMYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 8 then begin
    WriteLn('JESTES NA OSMYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 9 then begin
    WriteLn('JESTES NA DZIEWIATYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + 2 * POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 10 then begin
    WriteLn('JESTES NA DZIESIATYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + 2 * POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 11 then begin
    WriteLn('JESTES NA JEDENASTYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + 2 * POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 12 then begin
    WriteLn('JESTES NA DWUNASTYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + 2 * POZIOM, ' KUNSZTU');
  end;
  if POZIOM = 13 then begin
    WriteLn('JESTES NA TRZYNASTYM LEVELU A DO NASTEPNEGO BRAKUJE CI ', (735 - KUNSZT) + 2 * POZIOM, ' KUNSZTU');
  end;
  if POZIOM > 13 then begin
    WriteLn('JESTES NA BARDZO WYSOKIM LEVELU A DO NASTEPNEGO BRAKUJE CI TYLKO', (735 - KUNSZT) + 2 * POZIOM, ' KUNSZTU');
  end;
  { img 0x11C4..0x12BD: current/max attributes, S.Z, and FUKSROLL. }
  WriteLn('TWOJE PARAMETRY : SILA - ', SIL, '/', MAXSIL,
         ' ZRECZNOSC - ', ZRE, '/', MAXZRE,
         ' MADROSC - ', MAD, '/', MAXMAD);
  SilaZbroi := 10 * PRZEDM.ILOSC + PRZEDM.PRO;
  WriteLn('S.Z-', SilaZbroi,
         '                    FUKSROLL-', PRZEDM.FUKSROLL);
  WriteLn('MASZ ', MANA, '/', MAXMANA, ' MANY');
  WriteLn('MASZ ', ENERGIA, '/', MAXE, ' ENERGII');
  if QUEST = 1 then WriteLn('TWOJ AKTUALNY QUEST - ZABIC MUSISZ JESZCZE ', QUESTWYK, ' POTWOROW');
  if QUEST > 1 then WriteLn('TWOJ AKTUALNY QUEST - ZABIC MUSISZ JESZCZE ', QUESTWYK - 150, ' POTWOROW');
  if PRZEDM.DUNQ <> 0 then WriteLn('NIE ZAPOMNIALES O POKRZYWIE W SADACH DUNCANA???');
end;

procedure WybierzRase;
{ img 0x16EF..0x1ABD: intro call, then race selection at game start }
begin
  MONSTRA.WSTEP; { img 0x16F9 -> far entry 1BC4:022B }
  repeat
    WriteLn('NAPISZ SWA RASE : OLBRZYM , NIMFA , UFOK , CZAROMIL , CZLOWIEK , POL-ELF');
    ReadLn(wpisz);
    if wpisz = 'CZLOWIEK' then begin
      SIL := 10; ZRE := 10; MAD := 10;
      MAXSIL := 15; MAXZRE := 15; MAXMAD := 15;
    end;
    if wpisz = 'OLBRZYM' then begin
      SIL := 13; ZRE := 13; MAD := 5;
      MAXSIL := 20; MAXZRE := 20; MAXMAD := 7;
      MAXMANA := MAXMANA - 30;
    end;
    if wpisz = 'NIMFA' then begin
      SIL := 10; ZRE := 13; MAD := 7;
      MAXSIL := 15; MAXZRE := 20; MAXMAD := 11;
    end;
    if wpisz = 'POL-ELF' then begin
      SIL := 6; ZRE := 16; MAD := 8;
      MAXSIL := 10; MAXZRE := 24; MAXMAD := 12;
      MAXMANA := MAXMANA - 20;
      FORSA := FORSA + 30;
      MAXE := MAXE - 5;
      ENERGIA := ENERGIA - 5;
    end;
    if wpisz = 'UFOK' then begin
      SIL := 9; ZRE := 9; MAD := 13;
      MAXSIL := 13; MAXZRE := 14; MAXMAD := 20;
      MAXMANA := MAXMANA + 50;
    end;
    if wpisz = 'CZAROMIL' then begin
      SIL := 6; ZRE := 7; MAD := 16;
      MAXMANA := MAXMANA + 150;
      MAXSIL := 9; MAXZRE := 11; MAXMAD := 25;
    end;
  until (wpisz = 'CZLOWIEK') or (wpisz = 'OLBRZYM') or (wpisz = 'NIMFA') or
        (wpisz = 'UFOK') or (wpisz = 'CZAROMIL') or (wpisz = 'POL-ELF');
  WriteLn('PODAJE SWE IMIE (I TAK MNIE TO NIE OBCHODZI)');
  ReadLn(wpisz);
  ENERGIA := 50;
  PRA := 10;
  StanCieniasa := 12; { img 0x196D, DGROUP 0x058 }
  { PunktKontrolny starts at zero in the cleared DGROUP (img 0x51D5). }
  MONSTRA.SILNY := 13; { img 0x1973 DGROUP $68C }
  StanZrecznego := 14; { img 0x1979, DGROUP 0x05A }
  StanOdpornego := 15; { img 0x197F, DGROUP 0x05C }
  StanOgromnego := 16; { img 0x1985, DGROUP 0x05E }
  { Room-state initializers are in Room at img 0x12ACA. }
  POZIOM := 1;
  MAXMANA := MAXMANA + 100;
  MANA := MAXMANA;
  PRZEDM.POTWORY; { PRZEDM.POTWORY entry 0008:0000 -> original 129D:00FA }
  WriteLn('WITAJ W MUD-ZIE INTERAKTYWNIEJ FORMIE ROZRYWKI');
  WriteLn('MUD JEST TO BARDZO SKOMPLIKOWANA GRA INTERNETOWA');
  WriteLn('TEN PROGRAM NIE JEST IDENTYCZNY JAK MUD TYLE ZE NIE GRA W TO 1000 OSOB');
  WriteLn('DZIEKI TEMU PROGRAMOWI NAUCZYSZ SIE GRAC W PRAWDZIWEGO MUDA');
  WriteLn('ALE MAM NADZIEJE ZE ROZRYWKA TA BEDZIE DLA CIEBIE NOWYM WYZWANIEM');
  WriteLn('W CZASIE GRY BEDZIESZ POZNAWAL CORAZ TO NOWE KOMENDY');
  WriteLn('ALE JAK NARAZIE TYLKO KILKA Z NIECH');
  WriteLn('KOMENDA EXIT PODAJE WSZYSTKIE AKTUALNIE DOSTEPNE WYJSCIA');
  WriteLn('PORUSZASZ SIE ZA POMOCA KOMEND POLNOC POLODNIE WSCHOD ZACHOD GORA DOL');
  WriteLn('ABY SIE PATRZEC UZYJ KOMENDY PATRZ RAZEM Z RZECZA KTORA CHCESZ OBEJRZECZ');
end;

procedure WalkaMiasto;
{ img 0x1C2A..0x1E97: room-gated dog/city-NPC kill router }
begin
  if (wpisz = 'ZABIJ OWCZAREK') and (MONSTRA.OWCZAREK = MIECHO) then begin
    PRZEDM.WALKAPIES;
    MONSTRA.OWCZAREK := 0;
  end;
  if (wpisz = 'ZABIJ PIESEK') and (MONSTRA.PIESEK = MIECHO) then begin
    PRZEDM.WALKAPIES;
    MONSTRA.PIESEK := 0;
  end;
  if (wpisz = 'ZABIJ JAMNIK') and (MONSTRA.JAMNIK = MIECHO) then begin
    PRZEDM.WALKAPIES;
    MONSTRA.JAMNIK := 0;
  end;
  if (wpisz = 'ZABIJ SPANIEL') and (MONSTRA.SPANIEL = MIECHO) then begin
    PRZEDM.WALKAPIES;
    MONSTRA.SPANIEL := 0;
    WriteLn('GDY NAGLE!!!! NIEBIOSA SIE OTWIERAJA');
    WriteLn('A SPANIEL PRZEMAWIA DO CIEBIE LUDZKIM GLOSEM !!!!!');
    WriteLn('HAU HAU CHAMIE PO CO MNIE ZABILES ??? ');
  end;
  if (wpisz = 'ZABIJ PUDEL') and (MONSTRA.PUDEL = MIECHO) then begin
    PRZEDM.WALKAPIES;
    MONSTRA.PUDEL := 0;
  end;
  if (wpisz = 'ZABIJ TAKSOWKARZ') and (MONSTRA.TAKSOWKARZ = MIECHO) then begin
    PRZEDM.VEASY;
    MONSTRA.TAKSOWKARZ := 0;
    PRZEDM.GARNITURZYSK;
  end;
  if (wpisz = 'ZABIJ SPRZEDAWCA') and (MONSTRA.SPRZEDAWCA = MIECHO) then begin
    PRZEDM.VEASY;
    MONSTRA.SPRZEDAWCA := 0;
    PRZEDM.GARNITURZYSK;
  end;
  if (wpisz = 'ZABIJ ZAMIATACZ') and (MONSTRA.ZAMIATACZ = MIECHO) then begin
    PRZEDM.VEASY;
    MONSTRA.ZAMIATACZ := 0;
    PRZEDM.FUKS := Random(100);
    if (PRZEDM.FUKS < 35) and (PRZEDM.KOMPLET = 0) then begin
      WriteLn('ZYSKALES KOMPLET OBRABIAJAC ZAMIATACZA');
      PRZEDM.KOMPLET := PRZEDM.KOMPLET - 10;
    end;
  end;
  if (wpisz = 'ZABIJ PIJAK') and (MONSTRA.PIJAK = MIECHO) then begin
    PRZEDM.VEASY;
    MONSTRA.PIJAK := 0;
  end;
  if (wpisz = 'ZABIJ ZEBRAK') and (MONSTRA.ZEBRAK = MIECHO) then begin
    PRZEDM.VEASY;
    if ENERGIA > 0 then begin
      PRZEDM.FUKS := Random(10);
      WriteLn('Z GRUBEGO PORTFELA ZEBRAKA WYCIAGASZ BONUS !!! ',
              PRZEDM.FUKS, ' MONET!');
      PRZEDM.FORSA := PRZEDM.FORSA + PRZEDM.FUKS;
      MONSTRA.ZEBRAK := 0;
    end;
  end;
end;

procedure Trening;
{ Invented source name for the program-local routine at img 0x2396..0x2B74. }
begin
  if wpisz = 'PATRZ PLAKAT' then begin
    WriteLn('NA PLAKACIE PISZE:');
    WriteLn('MOZESZ CWICZYC UZYWAJAC KOMENDY CWICZ RAZEM Z ');
    if MAD < 11 then WriteLn('Z NICZYM BO MASZ ZA MALA MADROSC');
    if (MAD > 10) and (SIL > 11) then WriteLn('KOPAC - KOMENDA:KOP ');
    if (MAD > 10) and (ZRE > 10) then WriteLn('UCIEKAC - KOMENDA : ZWIEJ ');
    if (MAD > 15) and (ZRE > 11) then WriteLn('PAROWANIE - SAMOCZYNNIE ');
    if MAD > 11 then WriteLn('POROWNANIE-KOMEDA POROWNAJ');
    if MAD > 18 then WriteLn('POTRAWKI-SAMOCZYNNIE , PO WALCE');
    if MAD > 17 then WriteLn('POWROT-KOMEDA POWROT');
    if ZRE > 20 then WriteLn('ZRECZNE RECE - KOMENDA : RECE');
    if (SIL > 20) and (ZRE > 10) then WriteLn('KRZEPA : SAMOCZYNNIE');
    if (MAD > 19) and (ZRE > 10) and (SIL > 10) then
      WriteLn('TARGOWANIE SIE : SAMOCZYNNIE');
    if (SIL > 25) and (MAD > 12) then WriteLn('WIROWANIE - SAMOCZYNNIE ');
    if (SIL > 29) and (MAD > 14) then WriteLn('FATALITY - SAMOCZYNNIE ');
    if ZRE > 22 then WriteLn('COMBO - SAMOCZYNNIE ');
    if ZRE > 28 then WriteLn('SUPER COMBO - SAMOCZYNNIE ');
    if MAD > 22 then WriteLn('TRUCIZNA - SAMOCZYNNIE');
    if MAD > 23 then WriteLn('UZDRAWIANIE - KOMENDA UZDROW');
    if (ZRE > 24) and (MAD > 14) and (SIL > 14) then
      WriteLn('MOCNY SEN - SAMOCZYNNIE ');
    if MAD > 24 then WriteLn('OSLEPIANIE  - KOMEDA OSLEP ');
    if MAD > 26 then WriteLn('NEKROMANCJA - SAMOCZYNNIE ');
    if (SIL > 12) and (MAD > 19) and (ZRE > 12) then
      WriteLn('SZAL - KOMEDNA SZAL');
    if (ZRE > 22) and (MAD > 16) then WriteLn('SIATKA - KOMENDA SIATKA');
    if ZRE > 30 then WriteLn('CIOS W PLECY - KOMENDA CIOS W (COS)');
    if MAD > 29 then WriteLn('ROZPALANIE OGNISKA - KOMENDA ROZPAL');
    if MAD > 19 then WriteLn('HIPER SPEED - KOMENDA SPEED');
    if (MAD > 23) and (ZRE > 12) then WriteLn('PIECZENIE - KOMENDA PIECZ');
    WriteLn('W STANIE PODSWIADOMOSCI KOMEDA ZDOLNOSCI SPRAWDZI TWE ZDOLNOSCI');
  end;

  if wpisz = 'CWICZ KOPAC' then
    if (MAD > 10) and (SIL > 11) and (PRA > 0) then begin
      KOP := KOP + MAD;
      PRA := PRA - 1;
      WriteLn('CWICZYSZ KOPANIE - PRAWDOPODOBIENSTWO JEST TERAZ ', KOP,
              '% MASZ ', PRA, ' PRAKTYK');
    end;

  if wpisz = 'CWICZ UCIEKAC' then begin
    if MAD > 10 then
      if ZRE > 10 then
        if (PRA > 0) and (ZWIEJ < 85) then begin
          ZWIEJ := ZWIEJ + MAD + ZRE - 5;
          PRA := PRA - 1;
          WriteLn('CWICZYSZ UCIEKANIE - PRAWDOPODOBIENSTWO JEST TERAZ ', ZWIEJ,
                  '% MASZ ', PRA, ' PRAKTYK');
        end else
          WriteLn('ALBO MASZ ZA DOBRZE WYTRENOWANE ALBO ZA MALO PRAKTYK');
  end;

  if wpisz = 'CWICZ POWROT' then
    if (MAD > 17) and (Powracanie < 90) and (PRA > 0) then begin
      Powracanie := Powracanie + 2 * MAD - 3;
      PRA := PRA - 1;
      WriteLn('CWICZYSZ POWRACANIE - PRAWDOPODOBIENSTWO JEST TERAZ ', Powracanie,
              '% MASZ ', PRA, ' PRAKTYK');
    end;

  if wpisz = 'CWICZ PAROWANIE' then
    if (MAD > 15) and (ZRE > 11) and (PAR < 90) and (PRA > 0) then begin
      PAR := PAR + MAD + ZRE - 14;
      PRA := PRA - 1;
      WriteLn('CWICZYSZ PAROWANIE - PRAWDOPODOBIENSTWO JEST TERAZ ', PAR,
              '% MASZ ', PRA, ' PRAKTYK');
    end;

  if wpisz = 'CWICZ POROWNANIE' then
    if (MAD > 11) and (POR < 90) and (PRA > 0) then begin
      POR := POR + 3 * MAD - 9;
      PRA := PRA - 1;
      WriteLn('CWICZYSZ POROWNYWANIE - PRAWDOPODOBIENSTWO JEST TERAZ ', POR,
              '% MASZ ', PRA, ' PRAKTYK');
    end;

  if wpisz = 'CWICZ POTRAWKI' then
    if (MAD > 18) and (POTRAWKI < 90) and (PRA > 0) then begin
      POTRAWKI := POTRAWKI + MAD + 1;
      PRA := PRA - 1;
      WriteLn('CWICZYSZ POTRAWKI - PRAWDOPODOBIENSTWO JEST TERAZ ', POTRAWKI,
              '% MASZ ', PRA, ' PRAKTYK');
    end;
end;

procedure ZapiszPostac;
begin
  wpisz := 'JA';
  ZapisanoGre := 1;
  WriteLn('ALL RIGHT !!! GRA ZAPISANA! ;)');
  PRZEDM.save; { img 0x2BE0 -> PRZEDM:0x9263 stack-check wrapper }
  ClrScr;
  Assign(plik, 'pliki.tpu');
  Rewrite(plik);
  WriteLn(plik, MANA * 4);
  WriteLn(plik, POZIOM + $17);
  WriteLn(plik, MMIECZ);
  WriteLn(plik, FAJKA);
  WriteLn(plik, DYPLOM);
  WriteLn(plik, MTARCZA);
  WriteLn(plik, GARNITUR);
  WriteLn(plik, KUNSZT);
  WriteLn(plik, (ENERGIA + $28) * 4);
  WriteLn(plik, MIECHO2);
  WriteLn(plik, ZRE + 12);
  WriteLn(plik, SIL - 24);
  WriteLn(plik, MAD);
  WriteLn(plik, PRA);
  WriteLn(plik, PunktKontrolny);
  WriteLn(plik, Unused0052);
  WriteLn(plik, PRZEDM.TEST1);
  WriteLn(plik, FORSA * MAD);
  WriteLn(plik, PRZEDM.CZY);
  WriteLn(plik, MAXE);
  WriteLn(plik, LimitPrzedmiotow);
  WriteLn(plik, PRZEDM.POR);
  WriteLn(plik, MAXMANA);
  WriteLn(plik, MAXSIL);
  WriteLn(plik, MAXZRE);
  WriteLn(plik, MAXMAD);
  WriteLn(plik, PRZED);
  WriteLn(plik, PRO);
  WriteLn(plik, FUKSROLL);
  WriteLn(plik, JakaBron);
  WriteLn(plik, PRZEDM.CIALO);
  WriteLn(plik, MONSTRA.OGOL);
  WriteLn(plik, ZapisanoGre);
  WriteLn(plik, StanCieniasa);
  WriteLn(plik, MONSTRA.SILNY);
  WriteLn(plik, StanZrecznego);
  WriteLn(plik, StanOdpornego);
  WriteLn(plik, StanOgromnego);
  WriteLn(plik, JakaTarcza);
  WriteLn(plik, SilaZbroi);
  WriteLn(plik, POTRAWKI);
  WriteLn(plik, PotrawkiNiepotrzebnaZmiennaBug);
  WriteLn(plik, Unused0076);
  WriteLn(plik, SERCE);
  WriteLn(plik, MBUTELKA);
  WriteLn(plik, CIASTKO);
  WriteLn(plik, SUCHA);
  WriteLn(plik, CHLEB);
  WriteLn(plik, BULKA);
  WriteLn(plik, WEKA);
  WriteLn(plik, CHLEB);
  WriteLn(plik, BULKA);
  WriteLn(plik, PRZEDM.ILOSC);
  WriteLn(plik, PAR);
  WriteLn(plik, KOP);
  WriteLn(plik, KOPM);
  WriteLn(plik, KOPHP);
  WriteLn(plik, ZWIEJ);
  WriteLn(plik, WIMP);
  WriteLn(plik, PASZOL);
  WriteLn(plik, PRZEDM.ARENA);
  WriteLn(plik, KOMPLET);
  WriteLn(plik, kaseta);
  WriteLn(plik, PIGULKA);
  WriteLn(plik, KORNIK);
  WriteLn(plik, MUCHA);
  WriteLn(plik, BAKTERIA);
  WriteLn(plik, QUEST);
  WriteLn(plik, QUESTWYK);
  WriteLn(plik, SLIMAK);
  WriteLn(plik, LISTEK);
  WriteLn(plik, Powracanie);
  WriteLn(plik, BIGOS);
  WriteLn(plik, PrzedmPiwo);
  WriteLn(plik, SCROLLPOR);
  WriteLn(plik, PrzedmScrollPowrot);
  WriteLn(plik, MONSTRA.STARUCH);
  WriteLn(plik, PRZEDM.DUNQ);
  WriteLn(plik, PRZEDM.PLECAK);
  WriteLn(plik, PRZEDM.DUNCAN);
  WriteLn(plik, PRZEDM.JAKIEUB);
  Close(plik);
end;

procedure Smierc;
{ Recovered death handler at img 0x36F4..0x3845; called for context 10000
  by the main loop at img 0xEA22. }
begin
  WriteLn('AJAJAJAJ TWOJA GLOWA NAWALA JAK TESCIOWA!!!');
  WriteLn('NIC NA TO NIE PORADZE , TRZEBA BYLO SIE STARAC');
  WriteLn('NAGLE REFLEKSJA - DO JASNEJ CENZURY JAK SIE WALCZYLO TYM MIECZEM?');
  WriteLn('NIESTETY WRAZ ZE SMIERCIA TRACISZ KUNSZT ADEKWATNIE DO TWOJEGO LEVELKA');
  WriteLn('POJAWISZ SIE W CENTRUM MIASTA ..... POWODZENIA');
  WriteLn('P.S : AHA POTWORY SIE ODREGENEROWALY');
  WriteLn('P.S.2 : Z OSTATNIEJ CHWILI : HE HE HE SPROBOJ ODLOADOWAC POSTAC >:)');
  if QUEST = 1 then QUESTWYK := 50;
  if QUEST > 1 then QUESTWYK := 200;
  ENERGIA := MAXE;
  KUNSZT := KUNSZT - 250 + Random(50) - (5 * POZIOM);
  MIECHO := 20;
  PRZEDM.POTWORY; { PRZEDM.POTWORY far call at img 0x381A }
  wpisz := 'PAMIETAJ';
  ReadLn; { lcall 0x1C71:0x59D and CheckIO at img 0x3832..0x383C }
  ZapiszPostac; { save routine at img 0x2BA1, called from img 0x3841 }
end;

procedure ZakupyPiekarnia;
{ img 0x39BE..0x3CEA: LISTA and KUP food commands }
begin
  if wpisz = 'LISTA' then begin
    WriteLn('NAZWA         CENA');
    WriteLn('PACZEK     :   8  ');
    WriteLn('CIASTKO    :   12 ');
    WriteLn('SUCHA RACJA:   15 ');
    WriteLn('BULKA      :   19 ');
    WriteLn('CHLEB      :   24 ');
    WriteLn('WEKA       :   29 ');
  end;
  WalkaMiasto; { img 0x3AA0 -> helper at 0x1C2A }
  if (wpisz = 'KUP PACZEK') and (PRZEDM.FORSA >= 8) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.PACZEK := PRZEDM.PACZEK - 10;
    PRZEDM.FORSA := PRZEDM.FORSA - 8;
    WriteLn('KUPUJESZ PACZEK ZA 8 MONET');
  end;
  if (wpisz = 'KUP CIASTKO') and (PRZEDM.FORSA >= 12) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.CIASTKO := PRZEDM.CIASTKO - 10;
    PRZEDM.FORSA := PRZEDM.FORSA - 12;
    WriteLn('KUPUJESZ CIASTKO ZA 12 MONET');
  end;
  if (wpisz = 'KUP SUCHA RACJA') and (PRZEDM.FORSA >= 15) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.SUCHA := PRZEDM.SUCHA - 10;
    PRZEDM.FORSA := PRZEDM.FORSA - 15;
    WriteLn('KUPUJESZ SUCHA RACJE ZA 15 MONET');
  end;
  if (wpisz = 'KUP BULKA') and (PRZEDM.FORSA >= 19) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.BULKA := PRZEDM.BULKA - 10;
    PRZEDM.FORSA := PRZEDM.FORSA - 19;
    WriteLn('KUPUJESZ BULKE ZA 19 MONET');
  end;
  if (wpisz = 'KUP CHLEB') and (PRZEDM.FORSA >= 24) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.CHLEB := PRZEDM.CHLEB - 10;
    PRZEDM.FORSA := PRZEDM.FORSA - 24;
    WriteLn('KUPUJESZ CHLEB ZA 24 MONET');
  end;
  if (wpisz = 'KUP WEKA') and (PRZEDM.FORSA >= 29) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.WEKA := PRZEDM.WEKA - 10;
    PRZEDM.FORSA := PRZEDM.FORSA - 29;
    WriteLn('KUPUJESZ WEKE ZA 29 MONET');
  end;
end;

procedure ZakupyZbrojownia;
{ img 0x3E8E..0x40BB: weapon/armor store transaction body }
begin
  if wpisz = 'LISTA' then begin
    WriteLn('NAZWA         CENA');
    if PRZEDM.MMIECZ = 0 then
      WriteLn('!STARY! MIECZ           :   70  10%-50%');
    if PRZEDM.MTARCZA = 0 then
      WriteLn('!MALA! TARCZA           :   15  10%-50%');
    WriteLn('DLUGI MIECZ GLADIATORA  : 3200  2%');
  end;
  WalkaMiasto; { img 0x3F2A -> helper at 0x1C2A }
  if (wpisz = 'KUP STARY') and (PRZEDM.MMIECZ = 0) and
     (PRZEDM.FORSA >= 70) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.MMIECZ := -10;
    PRZEDM.FORSA := PRZEDM.FORSA - 70;
    WriteLn('KUPUJESZ ZWYKLY MALY !STARY! MIECZYK ZA 70 MONET');
    WartoscMiecza := 500;
  end;
  if wpisz = 'SPRZEDAJ STARY' then begin
    if PRZEDM.MMIECZ = -10 then begin
      WriteLn('SPRZEDAWCA MOWI CI : WYPCHAJ SIE Z TYM MIECZEM');
      WriteLn('ALBO DOBRA KUPIE GO OD CIEBIE ZA 30 MONET');
      PRZEDM.FORSA := PRZEDM.FORSA + 30;
      PRZEDM.MMIECZ := 0;
      PRZEDM.PRZED := PRZEDM.PRZED - 1;
    end;
  end;
  if (wpisz = 'KUP MALA') and (PRZEDM.MTARCZA = 0) and
     (PRZEDM.FORSA >= 15) then begin
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.MTARCZA := -10;
    PRZEDM.FORSA := PRZEDM.FORSA - 15;
    WriteLn('KUPUJESZ !MALA! TARCZA ZA 15 MONET');
  end;
  if wpisz = 'SPRZEDAJ MALA' then begin
    WriteLn('TA TARCZA JEST BAJER,FRAJER KUPIE JA OD CIEBIE ZA 8 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA + 8;
    PRZEDM.MTARCZA := 0;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
  end;
end;

procedure ZakupySklepWielobranzowy;
{ img 0x43A5..0x47DB: general-store transaction body }
begin
  if wpisz = 'LISTA' then begin
    WriteLn('NAZWA                        CENA');
    if PRZEDM.FAJKA = 0 then WriteLn('FAJKA                      :  480');
    if PRZEDM.KOMPLET = 0 then
      WriteLn('!KOMPLET! UBRAN FIRMY "SYF":   35 ');
    WriteLn('!KASETA! LIROYA            : 1999 4%');
    WriteLn('GARNITUR Z KOLCAMI(3)      : 1000 2,5%');
  end;
  if wpisz = 'PATRZ POSTER' then
    WriteLn('OKAZJA !!! PRZY ZAKUPIE GARNITURU KOMPLET UBRAN GRATIS !!!(ZART)');
  if (wpisz = 'KUP FAJKA') and (PRZEDM.FAJKA = 0) and
     (PRZEDM.FORSA >= 480) then begin
    WriteLn('KUPUJESZ FAJKE ZA 480 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA - 480;
    PRZEDM.FAJKA := PRZEDM.FAJKA - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.MAD := PRZEDM.MAD + 1;
  end;
  if (wpisz = 'KUP KOMPLET') and (PRZEDM.KOMPLET = 0) and
     (PRZEDM.FORSA >= 35) then begin
    WriteLn('KUPUJESZ !KOMPLET! UBRAN FIRMY "SYF" ZA 35 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA - 35;
    PRZEDM.KOMPLET := PRZEDM.KOMPLET - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
  end;
  if (wpisz = 'SPRZEDAJ KOMPLET') and (PRZEDM.KOMPLET <= -10) and
     (PRZEDM.JAKIEUB <> 'SYF') then begin
    WriteLn('SPRZEDAJESZ !KOMPLET! UBRAN FIRMY "SYF" ZA 15 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA + 15;
    PRZEDM.KOMPLET := PRZEDM.KOMPLET + 10;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
  end;
  if (wpisz = 'SPRZEDAJ FAJKA') and (PRZEDM.FAJKA = -10) then begin
    WriteLn('SPRZEDAJESZ FAJKE ZA 120 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA + 120;
    PRZEDM.FAJKA := PRZEDM.FAJKA + 10;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
    PRZEDM.MAD := PRZEDM.MAD - 1;
  end;
  if (wpisz = 'KUP KASETA') and (PRZEDM.FORSA >= 1999) then begin
    WriteLn('KUPUJESZ KASETE LIROYA - L JAK LIROY ZA 1999 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA - 1999;
    PRZEDM.kaseta := PRZEDM.kaseta - 10;
    PRZEDM.PRO := PRZEDM.PRO - 8;
    MONSTRA.MAXE := MONSTRA.MAXE + 5;
    PRZEDM.ZRE := PRZEDM.ZRE + 1;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
  end;
  if (wpisz = 'KUP GARNITUR') and (PRZEDM.FORSA >= 1000) then begin
    WriteLn('KUPUJESZ GARNITUR Z KOLCAMI ZA JEDYNE 1000 $');
    PRZEDM.FORSA := PRZEDM.FORSA - 1000;
    PRZEDM.GARNITUR := PRZEDM.GARNITUR - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
  end;
  if (wpisz = 'SPRZEDAJ GARNITUR') and
     (PRZEDM.JAKIEUB <> 'GARNITUR') then begin
    WriteLn('SPRZEDAJESZ GARNITUR Z KOLCAMI ZA JEDYNE 500 $');
    PRZEDM.FORSA := PRZEDM.FORSA + 500;
    PRZEDM.GARNITUR := PRZEDM.GARNITUR + 10;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
  end;
  if (wpisz = 'SPRZEDAJ KASETA') and (PRZEDM.kaseta < 0) then begin
    WriteLn('SPRZEDAJESZ KASETE LIROYA - L JAK LIROY ZA 1000 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA + 1000;
    PRZEDM.kaseta := PRZEDM.kaseta + 10;
    PRZEDM.PRO := PRZEDM.PRO + 8;
    MONSTRA.MAXE := MONSTRA.MAXE - 5;
    PRZEDM.ZRE := PRZEDM.ZRE - 1;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
  end;
end;

procedure ZakupySklepMagiczny;
{ img 0x4ADD..0x4E8A: potion, lucky-leaf, pill, and scroll transactions }
begin
  if wpisz = 'LISTA' then begin
    WriteLn('NAZWA                  CENA');
    WriteLn('MALA BUTELKA MANY       :   20');
    WriteLn('SREDNIA BUTELKA MANY    :   40');
    WriteLn('SPORA BUTELKA MANY      :   80');
    WriteLn('LISTEK SZCZESCIA        :  820 3%');
    WriteLn('PIERSCIONEK ZARECZYNOWY : 1800 N/A');
    WriteLn('PIGULKA TRANSPORTUJACA  :  235 ');
    WriteLn('SCROLL POROWNYWANIE     :   40 ');
  end;
  if (wpisz = 'KUP MALA BUTELKA MANY') and (PRZEDM.FORSA >= 15) then begin
    WriteLn('KUPUJESZ MALA BUTELKA MANY ZA 20 MONET ( AHHHH TA INFLACJA ) ');
    PRZEDM.FORSA := PRZEDM.FORSA - 20;
    PRZEDM.MBUTELKA := PRZEDM.MBUTELKA - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
  end;
  if (wpisz = 'KUP LISTEK') and (PRZEDM.FORSA >= 820) then begin
    WriteLn('KUPUJESZ LISTEK KTORY PRZYNOSCI SZCZESCIE ZA 820 KESZU');
    PRZEDM.FORSA := PRZEDM.FORSA - 830;
    PRZEDM.LISTEK := PRZEDM.LISTEK - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
    PRZEDM.MAXMANA := PRZEDM.MAXMANA + 40;
  end;
  if (wpisz = 'SPRZEDAJ LISTEK') and (PRZEDM.FORSA >= 820) then begin
    WriteLn('SPRZEDAJESZ LISTEK ZA 400 !!! CIESZ SIE');
    PRZEDM.FORSA := PRZEDM.FORSA + 400;
    PRZEDM.LISTEK := PRZEDM.LISTEK + 10;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
    PRZEDM.MAXMANA := PRZEDM.MAXMANA - 40;
  end;
  if (wpisz = 'KUP PIGULKA TRANSPORTUJACA') and
     (PRZEDM.FORSA >= 235) then begin
    WriteLn('KUPUJESZ PIGULKE TRANSPORTUJACA ZA 235 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA - 235;
    PRZEDM.PIGULKA := PRZEDM.PIGULKA - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
  end;
  if (wpisz = 'SPRZEDAJ PIGULKA TRANSPORTUJACA') and
     (PRZEDM.PIGULKA <= 10) then begin
    WriteLn('SPRZEDAWCA KUPUJE OD CIEBIE PIGULKE ZA 170 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA + 170;
    PRZEDM.PIGULKA := PRZEDM.PIGULKA + 10;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
  end;
  if (wpisz = 'KUP SCROLL POROWNYWANIE') and
     (PRZEDM.FORSA > 39) then begin
    WriteLn('SPRZEDAWCA SPRZEDAJE CI SCROLL ZA 40 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA - 40;
    PRZEDM.SCROLLPOR := PRZEDM.SCROLLPOR - 10;
    PRZEDM.PRZED := PRZEDM.PRZED + 1;
  end;
  if (wpisz = 'SPRZEDAJ SCROLL POROWNYWANIE') and
     (PRZEDM.SCROLLPOR < 0) then begin
    WriteLn('SPRZEDAWCA KUPUJE OD CIEBIE SCROLL ZA NEDZNE 18 MONET');
    PRZEDM.FORSA := PRZEDM.FORSA + 18;
    PRZEDM.SCROLLPOR := PRZEDM.SCROLLPOR + 10;
    PRZEDM.PRZED := PRZEDM.PRZED - 1;
  end;
end;

procedure WalkaKoncert;
{ img 0x4F53: shared room-NPC kill router; called only at the recovered
  room call sites. Keep its independent command comparisons in EXE order. }
begin
  if (wpisz = 'ZABIJ DZIECKO') and (PRZEDM.DZIECKO = PRZEDM.MIECHO) then begin
    PRZEDM.MNIEJSLABO;
    if PRZEDM.WROGEN < 1 then PRZEDM.DZIECKO := 0;
  end;
  if (wpisz = 'ZABIJ DZIADEK') and (PRZEDM.DZIADEK = PRZEDM.MIECHO) then begin
    PRZEDM.MNIEJSLABO;
    if PRZEDM.WROGEN < 1 then begin
      PRZEDM.DZIADEK := 0;
      PRZEDM.FUKS := Random(100);
      if (PRZEDM.FUKS < 5) and (PRZEDM.FAJKA = 0) then begin
        WriteLn('WYCIAGASZ FAJKE Z UST DZIADKA ');
        WriteLn('TEN PRZEDMIOT JEST UNIQE 5%');
        PRZEDM.FAJKA := PRZEDM.FAJKA - 10;
        PRZEDM.MAD := PRZEDM.MAD + 1;
      end;
    end;
  end;
  if (wpisz = 'ZABIJ WARIAT') and (PRZEDM.WARIAT = PRZEDM.MIECHO) then begin
    PRZEDM.SREDNIO;
    if PRZEDM.WROGEN < 1 then PRZEDM.WARIAT := 0;
  end;
  if (wpisz = 'ZABIJ SLUCHACZ') and (PRZEDM.SLUCHACZ = PRZEDM.MIECHO) then begin
    PRZEDM.SREDNIO;
    if PRZEDM.WROGEN < 1 then PRZEDM.SLUCHACZ := 0;
  end;
  if (wpisz = 'ZABIJ CZLOWIEK') and (PRZEDM.CZLOWIEK = PRZEDM.MIECHO) then begin
    PRZEDM.SREDNIO;
    if PRZEDM.WROGEN < 1 then PRZEDM.CZLOWIEK := 0;
  end;
  if (wpisz = 'ZABIJ FAN') and (PRZEDM.FAN = PRZEDM.MIECHO) then begin
    PRZEDM.SREDNIO;
    if PRZEDM.WROGEN < 1 then PRZEDM.FAN := 0;
  end;
  if (wpisz = 'ZABIJ REPORTER') and (PRZEDM.REPORTER = PRZEDM.MIECHO) then begin
    PRZEDM.SREDNIO;
    if PRZEDM.WROGEN < 1 then PRZEDM.REPORTER := 0;
  end;
  if (wpisz = 'ZABIJ POLICJANT') and (PRZEDM.POLICJANT = PRZEDM.MIECHO) then begin
    PRZEDM.TRUDNO;
    if PRZEDM.WROGEN < 1 then PRZEDM.POLICJANT := 0;
  end;
  if (wpisz = 'ZABIJ GORYL') and (PRZEDM.GORYL = PRZEDM.MIECHO) then begin
    PRZEDM.TRUDNO;
    if PRZEDM.WROGEN < 1 then PRZEDM.GORYL := 0;
    PRZEDM.GARNITURZYSK;
  end;
  if (wpisz = 'ZABIJ OCHRONIARZ') and
     (PRZEDM.OCHRONIARZ = PRZEDM.MIECHO) then begin
    PRZEDM.TRUDNO;
    if PRZEDM.WROGEN < 1 then PRZEDM.OCHRONIARZ := 0;
    PRZEDM.GARNITURZYSK;
  end;
end;

procedure PunktyKontrolne;
{ img 0x51C3..0x534A: sequential checkpoint tests can cascade }
begin
  if (KUNSZT >= 400) and (PunktKontrolny = 0) and (SIL < 20) then begin
    WriteLn('###################!!!CHECKPOINT!!!#########################');
    PunktKontrolny := 1;
    PRZEDM.POTWORY;
  end;
  if (KUNSZT >= 180) and (PunktKontrolny = 0) and (SIL < 8) then begin
    WriteLn('###################!!!CHECKPOINT!!!#########################');
    PunktKontrolny := 1;
    PRZEDM.POTWORY;
  end;
  if (KUNSZT >= 360) and (PunktKontrolny = 1) and (SIL < 8) then begin
    WriteLn('###################!!!CHECKPOINT!!!#########################');
    PunktKontrolny := 2;
    PRZEDM.POTWORY;
  end;
  if (KUNSZT >= 540) and (PunktKontrolny = 2) and (SIL < 8) then begin
    WriteLn('###################!!!CHECKPOINT!!!#########################');
    PunktKontrolny := 3;
    PRZEDM.POTWORY;
  end;
  if (KUNSZT >= 300) and (PunktKontrolny = 0) and (SIL > 7) and (SIL < 13) then begin
    WriteLn('###################!!!CHECKPOINT!!!#########################');
    PunktKontrolny := 1;
    PRZEDM.POTWORY;
  end;
  if (KUNSZT >= 500) and (PunktKontrolny = 1) and (SIL > 7) and (SIL < 13) then begin
    WriteLn('###################!!!CHECKPOINT!!!#########################');
    PunktKontrolny := 2;
    PRZEDM.POTWORY;
  end;
end;

procedure Pokoj2;
{ img 0x548A: inline room 2 (context 2) - POKOJ TRENINGOWY 1 }
begin
  if MIECHO <> 2 then Exit;
  WriteLn('JESTES W POKOJU GDZIE RAMBO TRENUJE SWYCH UCZNOW ');
  WriteLn('WSZ'#168'DZIE S'#164' PRZEDMIOTY DO R'#224#189'NYCH RODZAJI '#143'WICZE'#227);
  WriteLn('NO A POZA TYM NA SCIANIE JEST!!! PLAKAT!!!!');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then PRZEDM.MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('ZACHOD-POK'#224'J CENTRALNY');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'ZACHOD' then MIECHO := 1;
    if wpisz = 'PATRZ PLAKAT' then begin
      WriteLn(#169' NA PLAKACIE PISZE:');
      WriteLn('ABY TRENOWA'#143' U'#189'YJ KOM'#168'DY TRENUJ RAZEM Z ');
      WriteLn('SILA , ZRECZNOSC  LUB MADROSC ');
    end;
    PRZEDM.TRAIN;
  until MIECHO <> 2;
end;

procedure Pokoj3;
{ img 0x571E: inline room 3 (context 3) - PODDZIEMNY POKOJ TRENINGOWY(2) }
begin
  if MIECHO <> 3 then Exit;
  WriteLn('ZSZEDLES NA DOL GDZIE TRENUJE SIE MEDYTUJAC');
  WriteLn('NA SRODKU NA WIELKI MATERAC PRZEZNACZONY DO MEDYTACJI');
  WriteLn('NA SCIANCE JEST PIEKNIUTKI PLAKAT');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then PRZEDM.MODE;
    if wpisz = 'EXIT' then
      WriteLn('DOSTEPNE WYJSCIE-GORA-HALA GLOWNA MUD SZKOLE ');
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'GORA' then MIECHO := 1;
    Trening; { img 0x5853 -> program-local routine img 0x2396 }
  until MIECHO <> 3;
end;

procedure Pokoj9;
{ img 0x5923: inline room 9 (context 9) }
begin
  WriteLn('JESTES W MALUTKIM POKOJU ALE WIDZISZ WYJSCIA W DWIE STRONY ');
  WriteLn('SKADS SLYSZYSZ DZIWNE NIEPOKOJACE WRZASKI');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then PRZEDM.MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('DOL-MUD SZKOLA (2)');
      WriteLn('GORA-KLATKI PELNE GAJDY');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'DOL' then MIECHO := 5;
    if wpisz = 'GORA' then MIECHO := 11;
  until MIECHO <> 9;
end;

procedure Pokoj12;
{ img 0x5C36: inline room 12 (context 12) - KLATKA CIENIASA }
begin
  if MIECHO <> 12 then Exit;
  WriteLn('TEN POKOJ JEST CALY OBRYZGANY KRWIA NA SCIANACH FLAKI I MOZGI LODZKIE ');
  if StanCieniasa = 12 then
    WriteLn('POTWOR - CIENIAS STOI NA 1 NODZE POD SCIANA');
  if StanCieniasa = 0 then
    WriteLn('PAROJACE WNETRZNOSCI POTWORA SA ROZWLECZONE DOOKOLA');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('ZACHOD-KLATKI PELNE GAJDY');
    end;
    if wpisz = 'MODE' then PRZEDM.MODE;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'ZACHOD' then MIECHO := 11;
    if (wpisz = 'ZABIJ POTWOR') and (StanCieniasa = 12) then begin
      WROGEN := 20; WROGZRE := 3; WROGSIL := 3;
      WALKA;
      if PASZOL = 0 then begin
        StanCieniasa := 0;
        CZY := Random(10);
        WriteLn('WYCIAGASZ ', CZY, ' MONET Z CIALA POTWORA');
        FORSA := FORSA + CZY;
        if PRZEDM.MMIECZ = 0 then begin
          PRZEDM.FUKS := Random(20);
          if PRZEDM.FUKS < 4 then begin
            PRZEDM.MMIECZ := MIECHO;
            WriteLn('WYCIAGASZ STARY ZARDZEWIALY MIECZ Z CIALA POTWORA');
            WartoscMiecza := 500;
          end;
        end;
        if PRZEDM.MTARCZA = 0 then begin
          PRZEDM.FUKS := Random(20);
          if PRZEDM.FUKS < 4 then begin
            PRZEDM.MTARCZA := MIECHO;
            WriteLn('WYCIAGASZ ZWYKLA MALA TARCZA Z CIALA POTWORA');
            WartoscTarczy := 300;
          end;
        end;
        if PRZEDM.SERCE = 0 then begin
          PRZEDM.FUKS := Random(20);
          if PRZEDM.FUKS < 6 then begin
            PRZEDM.SERCE := MIECHO;
            WriteLn('WYCIAGASZ ZAKRWAWIONE SERCE Z CIALA POTWORA');
            WartoscSerca := 50;
          end;
        end;
      end
      else
        PASZOL := 0;
    end;
  until MIECHO <> 12;
end;

procedure PokojeKoncertowe; { invented name for img 0x68BC..0x7D6A }
{ One ordered context dispatcher, matching the single EXE procedure. }
begin
  if MIECHO = 61 then begin
    { img 0x68D0..0x6AE6: inline context 61 }
    WriteLn('KIEDY PODSZEDLES BLIZEJ ZBARANIALES - TO SALA KONCERTOWA !!!');
    WriteLn('WOKOLO TLUMY SLUCHAJA MUZYKI , DZIWNA TO MUZYKA - WLASCIWIE SAME SLOWA');
    WriteLn('!!!!!!!!!NA SCIANIE JEST PLAKAT !!!!!!!!!!!!!!!');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('ZACHOD-DOLINA ROZRYWEK');
        WriteLn('POLNOC-TLUM');
        WriteLn('POLODNIE-TLUM');
      end;
      WalkaKoncert; { img 0x6A20 }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'ZACHOD' then MIECHO := 60;
      if wpisz = 'POLNOC' then MIECHO := 63;
      if wpisz = 'POLODNIE' then MIECHO := 62;
      if wpisz = 'WSCHOD' then MIECHO := 64;
      if wpisz = 'PATRZ PLAKAT' then begin
        WriteLn(' NA PLAKACIE PISZE :');
        WriteLn('20 X 98 r KONCERT LIROYA - ZAPRASZAMY WSZYSTKICH  ');
      end;
    until MIECHO <> 61;
  end;
  if MIECHO = 62 then begin
    { img 0x6AF0..0x6C40: inline context 62 }
    WriteLn('NA BRZEGACH TLUM JEST MNIEJSZY , MIMO TO UCZUCIE SCISKU IRYTUJE CIE');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x6B71 }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLNOC-TLUM');
        WriteLn('WSCHOD-TLUM');
      end;
      WalkaKoncert; { img 0x6BF1 }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 61;
      if wpisz = 'WSCHOD' then MIECHO := 65;
    until MIECHO <> 62;
  end;
  if MIECHO = 63 then begin
    { img 0x6C4A..0x6DCD: inline context 63 }
    WriteLn('NA BRZEGACH TLUM JEST RZADSZY , BOISZ SIE POMYSLEC CO SIE DZIEJE W SRODKU');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x6CCB }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLODNIE-TLUM');
        WriteLn('WSCHOD-TLUM');
        WriteLn('POLNOC-PIWIARNIA');
      end;
      WalkaKoncert; { img 0x6D67 }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLODNIE' then MIECHO := 61;
      if wpisz = 'WSCHOD' then MIECHO := 66;
      if wpisz = 'POLNOC' then MIECHO := 67;
    until MIECHO <> 63;
  end;
  if MIECHO = 64 then begin
    { img 0x6DD2..0x6F76: inline context 64 }
    WriteLn('JESTES W SRODKU TLUMU A DO TEGO PRZY BALUSTRADKACH-CO ZA TLOK');
    WriteLn('NIE MOZNA ODDYCHAC W TAKIM TLUMIE - LEPIEJ SZYBKO Z TAD IDZ');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x6E74 }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('ZACHOD-TLUM');
        WriteLn('POLNOC-TLUM');
        WriteLn('POLODNIE-TLUM');
      end;
      WalkaKoncert; { img 0x6F10 }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 66;
      if wpisz = 'ZACHOD' then MIECHO := 61;
      if wpisz = 'POLODNIE' then MIECHO := 65;
    until MIECHO <> 64;
  end;
  if MIECHO = 65 then begin
    { img 0x6F76..0x70EC: inline context 65 }
    WriteLn('JESTES Z BOKU ALE PRZY BALUSTRADKACH LUDZIE WPYCHAJA CIE NA TE BALUSTRADKI');
    WriteLn('NIE MOZNA ODDYCHAC W TAKIM TLUMIE - LEPIEJ SZYBKO Z TAD IDZ');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x701D }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('ZACHOD-TLUM');
        WriteLn('POLNOC-TLUM');
      end;
      WalkaKoncert; { img 0x709D }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 64;
      if wpisz = 'ZACHOD' then MIECHO := 62;
    until MIECHO <> 65;
  end;
  if MIECHO = 66 then begin
    { img 0x70EC..0x723C: inline context 66 }
    WriteLn('JESTES PRZY BALUSTRADKACH-NIE BEDE SIE ROZWODZIL JAK CI JEST CIASNO');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x7177 }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('ZACHOD-TLUM');
        WriteLn('POLODNIE-TLUM');
      end;
      WalkaKoncert; { img 0x71F7 }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLODNIE' then MIECHO := 64;
      if wpisz = 'ZACHOD' then MIECHO := 63;
    until MIECHO <> 66;
  end;
  if MIECHO = 67 then begin
    { img 0x7250..0x74FA: inline context 67 }
    WriteLn('JESTES W PIWIARNI - WOKOLO CIEBIE UNOSI SIE ZAPACH PIWA , TY NIE PIJASZ PIWA');
    WriteLn('TY PIJASZ JABOLA !!! , NIE REZYGNUJAC ZE SWYCH PRZYZWYCZAJEN ROZGLADASZ SIE:');
    if MONSTRA.MINIBARMAN = 67 then
      WriteLn('I WIDZISZ MINI-BARMANA SPIESZACEGO SIE ABY PODAC WSZYSTKIM NAWARZONE PIWO');
    if MONSTRA.GRUBAS = 67 then
      WriteLn('I WIDZISZ GRUBASA KTORY PO WYPICIU 18 PIW WYRAZNIE MA PEWNE OBJAWY SPICIA');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x7333 }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('WSCHOD-WEJSCIE NA ESTRADE');
        WriteLn('POLODNIE-TLUM');
      end;
      WalkaKoncert; { img 0x73B3 }
      if (wpisz = 'ZABIJ MINI-BARMAN') and (MONSTRA.MINIBARMAN = 67) then begin
        WriteLn('---------------  ROUND ONE --------------------');
        WriteLn('----------------  FIGHT -----------------------');
        PRZEDM.BTRUDNO;
        if ENERGIA > 0 then begin
          MONSTRA.MINIBARMAN := 0;
          PRZEDM.FUKS := Random(100);
          if PRZEDM.FUKS < 15 then begin
            WriteLn('Z CIALA MINI-BARMANA WYCIAGASZ NAPOJ BOGOW : PIWO !!!');
            PrzedmPiwo := PrzedmPiwo - 10;
            PRZEDM.PRZED := PRZEDM.PRZED + 1;
          end;
        end;
      end;
      if (wpisz = 'ZABIJ GRUBAS') and (MONSTRA.GRUBAS = 67) then begin
        PRZEDM.BTRUDNO;
        if ENERGIA > 0 then begin
          MONSTRA.GRUBAS := 0;
          if PRZEDM.FUKS < 15 then begin
            WriteLn('Z CIALA GRUBASA WYCIAGASZ NAPOJ BOGOW : PIWO !!!');
            PrzedmPiwo := PrzedmPiwo - 10;
            PRZEDM.PRZED := PRZEDM.PRZED + 1;
          end;
        end;
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLODNIE' then MIECHO := 63;
      if wpisz = 'WSCHOD' then MIECHO := 68;
    until MIECHO <> 67;
  end;
  if MIECHO = 68 then begin
    { img 0x750E..0x76C3: inline context 68 }
    WriteLn('TO JEST WEJSCIE NA SCENE NA KTOREJ TANCZY LIROY - UWAZAJ');
    WriteLn('NA SCIANIE WISI !!!TABLICZKA!!!');
    PRZEDM.TLUM;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      PRZEDM.KOMENDY; { img 0x75AB }
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('ZACHOD-PIWIARNIA');
        WriteLn('WSCHOD-SCENA');
        WriteLn('P.S-HEJ DZIECI JESLI CHCECIE ZOBACZYC TAMTEN SWIAT PODLACZCIE SIE DO 1000 WAT');
      end;
      WalkaKoncert; { img 0x7647 }
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'ZACHOD' then MIECHO := 67;
      if wpisz = 'WSCHOD' then MIECHO := 69;
      if wpisz = 'PATRZ TABLICZKA' then
        WriteLn('*** NIE UPOWAZNIONYM WSTEP WZBRONIONY *** ');
    until MIECHO <> 68;
  end;
  if MIECHO = 69 then begin
    { img 0x76CD..0x7928: inline context 69 }
    WriteLn('JESTES NA SCENIE , WLASCIWIE TO DOPIERO POCZATEK SCENY');
    WriteLn('WLASCIWIE JESTES JESZCZE ZA KULISAMI BO WIDZOWIE CIE NIE WIDZA');
    if MONSTRA.DJ = 69 then
      WriteLn('D.J PILNUJE ABY WSZYSTKO PRZEBIEGALO ZGODNIE Z PLAYBACKIEM');
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('ZACHOD-WEJSCIE NA SCENE');
        WriteLn('POLODNIE-SCENA');
      end;
      if wpisz = 'ZABIJ D.J' then begin
        if MONSTRA.DJ = 69 then begin
          PRZEDM.BTRUDNO;
          if PRZEDM.WROGEN < 0 then begin
            MONSTRA.DJ := 0;
            PRZEDM.FUKS := Random(100);
            if PRZEDM.FUKS < 25 then begin
              WriteLn('WYCIAGASZ SUCHA RACJA Z CIALA D.J-a');
              PRZEDM.SUCHA := PRZEDM.SUCHA - 10;
              PRZEDM.PRZED := PRZEDM.PRZED + 1;
            end;
            if PRZEDM.FUKS < 3 then begin
              WriteLn('WYCIAGASZ KASETE LIROYA Z CIALA D.J-a');
              WriteLn('!!! PRZEDMIOT UNIQE 3% !!!');
              PRZEDM.kaseta := PRZEDM.kaseta - 10;
              MAXE := MAXE + 5;
              PRO := PRO - 8;
              PRZEDM.PRZED := PRZEDM.PRZED + 1;
              ZRE := ZRE + 1;
            end;
          end;
        end;
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'ZACHOD' then MIECHO := 68;
      if wpisz = 'POLODNIE' then MIECHO := 70;
    until MIECHO <> 69;
  end;
  if MIECHO = 70 then begin
    { img 0x7932..0x7AB7: inline context 70 }
    WriteLn('ALL RIGHT JESTES NA SCENIE !!! NA TWOJ WIDOK OCHRONIAZE COS MAMROCZA');
    WriteLn('TLUMY CIE PRAKTYCZNIE NIE ZAUWAZAJA BO ICH OCZY SKIEROWANE SA NA LIROYA');
    WriteLn('GDY NAGLE WSROD TLUMU ZAUWAZASZ NIEZLA LALE,JEDNAK ONA KOCHA LIROYA :(');
    PRZEDM.SCENA;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLNOC-SCENA');
        WriteLn('POLODNIE-SRODEK SCENY');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 69;
      if wpisz = 'POLODNIE' then MIECHO := 71;
      PRZEDM.FIGHTSCENA; { img 0x7AA8 -> PRZEDM:0x85C7 }
    until MIECHO <> 70;
  end;
  if MIECHO = 71 then begin
    { img 0x7AC1..0x7C2A: inline context 71 }
    WriteLn('LUDZIE SIE NA CIEBIE GAPIA , JESTES NA SRODKU SCENY !!! KTOS CI MOWI:');
    WriteLn('HEY MAN IT,S COOL YEAH! . A TY NA TO: JE JE KUP KUL....');
    PRZEDM.SCENA;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLNOC-SCENA');
        WriteLn('POLODNIE-SCENA');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 70;
      if wpisz = 'POLODNIE' then MIECHO := 72;
      PRZEDM.FIGHTSCENA; { img 0x7C1B -> PRZEDM:0x85C7 }
    until MIECHO <> 71;
  end;
  if MIECHO = 72 then begin
    { img 0x7C34..0x7D69: inline context 72 }
    WriteLn('UFFF PRZEBIEGLES PRZEZ SRODEK SCENY WIEC TREMA CIE JUZ NIE DRECZY');
    WriteLn('DALEJ PISAC NIE MA O CZYM WIEC MOZESZ MI NASKOCZYC ');
    PRZEDM.SCENA;
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then PRZEDM.MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLNOC-SRODEK SCENY');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 71;
      PRZEDM.FIGHTSCENA; { img 0x7D5A -> PRZEDM:0x85C7 }
    until MIECHO <> 72;
  end;
end;

procedure WczytajPostac;
begin
  ReadLn(wpisz);
  Assign(plik, 'pliki.tpu');
  Reset(plik);
  Read(plik, MANA);
  MANA := MANA div 4;
  Read(plik, POZIOM);
  POZIOM := POZIOM - $17;
  Read(plik, MMIECZ);
  Read(plik, FAJKA);
  Read(plik, DYPLOM);
  Read(plik, MTARCZA);
  Read(plik, GARNITUR);
  Read(plik, KUNSZT);
  Read(plik, ENERGIA);
  ENERGIA := ENERGIA div 4;
  ENERGIA := ENERGIA - $28;
  Read(plik, MIECHO2);
  Read(plik, ZRE);
  ZRE := ZRE - 12;
  Read(plik, SIL);
  SIL := SIL + 24;
  Read(plik, MAD);
  Read(plik, PRA);
  Read(plik, PunktKontrolny);
  Read(plik, Unused0052);
  Read(plik, PRZEDM.TEST1);
  Read(plik, FORSA);
  FORSA := FORSA div MAD;
  Read(plik, PRZEDM.CZY);
  Read(plik, MAXE);
  Read(plik, LimitPrzedmiotow);
  Read(plik, PRZEDM.POR);
  Read(plik, MAXMANA);
  Read(plik, MAXSIL);
  Read(plik, MAXZRE);
  Read(plik, MAXMAD);
  Read(plik, PRZED);
  Read(plik, PRO);
  Read(plik, FUKSROLL);
  Read(plik, JakaBron);
  Read(plik, PRZEDM.CIALO);
  Read(plik, MONSTRA.OGOL);
  Read(plik, ZapisanoGre);
  Read(plik, StanCieniasa);
  Read(plik, MONSTRA.SILNY);
  Read(plik, StanZrecznego);
  Read(plik, StanOdpornego);
  Read(plik, StanOgromnego);
  Read(plik, JakaTarcza);
  Read(plik, SilaZbroi);
  Read(plik, POTRAWKI);
  Read(plik, PotrawkiNiepotrzebnaZmiennaBug);
  Read(plik, Unused0076);
  Read(plik, SERCE);
  Read(plik, MBUTELKA);
  Read(plik, CIASTKO);
  Read(plik, SUCHA);
  Read(plik, CHLEB);
  Read(plik, BULKA);
  Read(plik, WEKA);
  Read(plik, CHLEB);
  Read(plik, BULKA);
  Read(plik, PRZEDM.ILOSC);
  Read(plik, PAR);
  Read(plik, KOP);
  Read(plik, KOPM);
  Read(plik, KOPHP);
  Read(plik, ZWIEJ);
  Read(plik, WIMP);
  Read(plik, PASZOL);
  Read(plik, PRZEDM.ARENA);
  Read(plik, KOMPLET);
  Read(plik, kaseta);
  Read(plik, PIGULKA);
  Read(plik, KORNIK);
  Read(plik, MUCHA);
  Read(plik, BAKTERIA);
  Read(plik, QUEST);
  Read(plik, QUESTWYK);
  Read(plik, SLIMAK);
  Read(plik, LISTEK);
  Read(plik, Powracanie);
  Read(plik, BIGOS);
  Read(plik, PrzedmPiwo);
  Read(plik, SCROLLPOR);
  Read(plik, PrzedmScrollPowrot);
  Read(plik, MONSTRA.STARUCH);
  Read(plik, PRZEDM.DUNQ);
  Read(plik, PRZEDM.PLECAK);
  ReadLn(plik, PRZEDM.DUNCAN);
  Read(plik, PRZEDM.JAKIEUB);
  Close(plik);
  WriteLn('suckemall:', PRZEDM.JAKIEUB);
end;

procedure SprawdzCzyZdobylesLevel;
{ img 0x872E..0x8BA2: level thresholds and stat gains }
begin
  if (KUNSZT < 700) or (POZIOM <> 1) then
    if (KUNSZT < 725) or (POZIOM <> 2) then
      if (KUNSZT < 730) or (POZIOM <> 3) then
        if ((735 + POZIOM) > KUNSZT) or (POZIOM <= 3) or (POZIOM >= 9) then begin
          if POZIOM <= 8 then Exit;
          if (735 + POZIOM + POZIOM) > KUNSZT then Exit;
        end;
  { Level up body at img 0x87A2 }
  WriteLn('<<<<<<<<<=+=+=+!!!#####ZDOBYLES LEVEL#####!!!+=+=+=<<<<<<<<<<<<<');
  WriteLn('<<<<<<<<<=+=+=+!!!#####ZDOBYLES LEVEL#####!!!+=+=+=<<<<<<<<<<<<<');
  WriteLn('<<<<<<<<<=+=+=+!!!#####ZDOBYLES LEVEL#####!!!+=+=+=<<<<<<<<<<<<<');
  WriteLn('<<<<<<<<<=+=+=+!!!#####ZDOBYLES LEVEL#####!!!+=+=+=<<<<<<<<<<<<<');
  if POZIOM = 1 then KUNSZT := KUNSZT - 725;
  if POZIOM = 2 then KUNSZT := KUNSZT - 730;
  if POZIOM = 3 then KUNSZT := KUNSZT - 735;
  if (POZIOM > 3) and (POZIOM < 9) then
    KUNSZT := (KUNSZT - 735) - POZIOM;
  if (POZIOM > 8) then
    KUNSZT := (KUNSZT - (POZIOM * 2)) - 735;
  if MAD < 11 then PRA := PRA + 3;
  if (MAD > 10) and (MAD < 16) then PRA := PRA + 4;
  if (MAD > 15) and (MAD < 23) then PRA := PRA + 5;
  if MAD > 22 then PRA := PRA + 6;
  WriteLn('<<<<<<<<<<<<ZYSKALES ', PRA, ' PRAKTYK >>>>>>>>>>>>>>>');
  if ZRE > 12 then MAXE := MAXE + 11
  else MAXE := MAXE + 10;
  if ZRE > 16 then MAXE := MAXE + 1;
  if ZRE > 21 then MAXE := MAXE + 1;
  if (ZRE > 26) and (SIL > 20) then MAXE := MAXE + 1;
  WriteLn('<<<<<<<<<<<<ZYSKALES ', MAXE, ' MAXIMUM ENERGI >>>>>>>>>>>>>');
  MAXMANA := MAXMANA + MAD + 2;
   WriteLn('<<<<<<<<<<<<<<ZYSKALES ', MAD + 2, 'MANY >>>>>>>>>>>>>>>>>');
  POZIOM := POZIOM + 1;
  PunktKontrolny := 0;
  if POZIOM = 12 then begin
    WriteLn('HURRRA TO JUZ DWUNASTY POZIOM , CZAS PODWYZSZYC MAXYMALNE PARAMETRY');
    if SIL >= MAXSIL then MAXSIL := MAXSIL + 3;
    if ZRE >= MAXZRE then MAXZRE := MAXZRE + 3;
    if MAD >= MAXMAD then MAXMAD := MAXMAD + 3;
    if SIL < MAXSIL then MAXSIL := MAXSIL + 2;
    if ZRE < MAXZRE then MAXZRE := MAXZRE + 2;
    if MAD < MAXMAD then MAXMAD := MAXMAD + 2;
    if (MAXMAD > MAXSIL) and (MAXMAD > MAXZRE) then
      MAXMAD := MAXMAD + 3;
    if (MAXSIL > MAXMAD) and (MAXSIL > MAXZRE) then
      MAXSIL := MAXSIL + 3;
    if (MAXZRE > MAXSIL) and (MAXZRE > MAXMAD) then
      MAXZRE := MAXZRE + 3;
    if (MAXZRE = MAXSIL) and (MAXSIL = MAXMAD) then begin
      MAXZRE := MAXZRE + 1;
      MAXMAD := MAXMAD + 1;
      MAXSIL := MAXSIL + 1;
    end;
    if (MAXZRE > MAXMAD) and (MAXZRE = MAXSIL) then begin
      MAXSIL := MAXSIL + 2;
      MAXZRE := MAXZRE + 1;
    end;
    WriteLn(#2#2#2#2#2#2#2#2#2#2#2#2#2#2' MASZ TERAZ ', MAXSIL,
          ' MAXYMALNIE SILY '#2#2#2#2#2#2#2#2#2#2#2#2#2#2);
    WriteLn(#2#2#2#2#2#2#2#2#2#2#2#2#2#2' MASZ TERAZ ', MAXZRE,
          ' MAXYMALNIE ZRECZNOSCI '#2#2#2#2#2#2#2#2#2#2#2#2#2#2);
    WriteLn(#2#2#2#2#2#2#2#2#2#2#2#2#2#2' MASZ TERAZ ', MAXMAD,
          ' MAXYMALNIE MADROSCI '#2#2#2#2#2#2#2#2#2#2#2#2#2#2);
  end;
end;


begin
  { --- TP7 runtime, implicit (file 0x52E0..): img 0xB0CF..0xB0D8 ---
    lcall 1C71:0000 System bootstrap: DS := DGROUP (para 0x1D49), BSS
    zeroed 0x52..0x8EE, CPU probe, heap init; std TextRec init 1C0F:000D. }
  { --- main prologue img 0xB0D9: push bp; mov bp,sp; xor ax,ax --- }
  { heap check: lcall 1C71:02CD }
  Randomize; { GetTime-seeded, lcall 1C71:0C79 }
  WybierzRase; { near-call displacement lands at IP 0x16EF after 16-bit wrap }
  ReadKey; { ignored result; CRT lcall 1C0F:031A at img 0xB0EB }
  repeat
    PunktyKontrolne; { call 0x51C3 at img 0xB0F0 }
    SprawdzCzyZdobylesLevel; { call 0x872E at img 0xB0F3 }
  { Overload gate: PRZED [0x182] > LimitPrzedmiotow [0x62] -> overload-print block }
    if PRZED > LimitPrzedmiotow then begin
      WriteLn('JESTES OBLADOWANY !!! MASZ O ', PRZED - LimitPrzedmiotow, ' ZA DUZO');
      WriteLn('TRACISZ ', (PRZED - LimitPrzedmiotow) * 10, '% ENERGI');
      ENERGIA := ENERGIA - ((PRZED - LimitPrzedmiotow) * 10);
    end;
  { --- img 0xB193 bleed tick; img 0xB1E5 ordered room dispatch --- }
    { bleed tick at img 0xB193..0xB1E4 }
    if ILEPOI > 0 then begin
      PRZEDM.FUKS := Random(5);
      WriteLn('JESTES ZATRUTY TRACISZ ', PRZEDM.FUKS, ' % ENERGI');
      ILEPOI := ILEPOI - 1;
    end;
    { Ordered independent tests, not a case: a room transition can reach a
      later handler in this same pass (img 0xB1E5..0xCC13). }
    if MIECHO = 0 then POKOJ0;
    if MIECHO = 1 then POKOJ1;
    if MIECHO = 2 then Pokoj2; { img 0x548A }
    if MIECHO = 3 then Pokoj3; { img 0x571E }
    if MIECHO = 4 then POKOJ4;
    if MIECHO = 5 then POKOJ5;
    POKOJE; { unconditional dispatcher for contexts 6, 8, 7, and 10 }
    if MIECHO = 9 then Pokoj9; { img 0x5923 }
    if MIECHO = 11 then POKOJ11;
    if MIECHO = 12 then Pokoj12; { img 0x5C36 }
    if MIECHO = 13 then POKOJ13;
{ img 0xB264..0xB520: inline room 14 (context 14) - zreczny potwor }
    if MIECHO = 14 then begin

      WriteLn('TEN POKOJ JEST CALY OBRYZGANY KRWIA NA SCIANACH FLAKI I MOZGI LODZKIE ');
      if StanZrecznego = 14 then
        WriteLn('ZRECZNY POTWOR SMIGA MIEDZY SCIANAMI');
      if StanZrecznego = 0 then
        WriteLn('PAROJACE WNETRZNOSCI POTWORA SMIERDZA DOSYC MOCNO');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-KLATKI PELNE GAJDY');
        end;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 11;
        if (wpisz = 'ZABIJ POTWOR') and (StanZrecznego = 14) then begin
          WROGEN := 20; WROGZRE := 30; WROGSIL := 3;
          WALKA;
          if PASZOL = 0 then begin
            StanZrecznego := 0;
            CZY := Random(15);
            WriteLn('WYCIAGASZ ', CZY, ' MONET Z CIALA POTWORA');
            FORSA := FORSA + CZY;
            if PRZEDM.MMIECZ = 0 then begin
              PRZEDM.FUKS := Random(20);
              if PRZEDM.FUKS < 7 then begin
                PRZEDM.MMIECZ := MIECHO;
                WriteLn('WYCIAGASZ STARY ZARDZEWIALY MIECZ Z CIALA POTWORA');
                WartoscMiecza := 500;
              end;
            end;
            if PRZEDM.MTARCZA = 0 then begin
              PRZEDM.FUKS := Random(20);
              if PRZEDM.FUKS < 7 then begin
                PRZEDM.MTARCZA := MIECHO;
                WriteLn('WYCIAGASZ ZWYKLA MALA TARCZA Z CIALA POTWORA');
                WartoscTarczy := 300;
              end;
            end;
            if PRZEDM.SERCE = 0 then begin
              PRZEDM.FUKS := Random(20);
              if PRZEDM.FUKS < 6 then begin
                PRZEDM.SERCE := MIECHO;
                WriteLn('WYCIAGASZ ZAKRWAWIONE SERCE Z CIALA POTWORA');
                WartoscSerca := 50;
              end;
            end;
          end else
            PASZOL := 0;
        end;
      until MIECHO <> 14;

    end;
{ img 0xB52B..0xB7F1: inline room 15 (context 15) - odporny potwor }
    if MIECHO = 15 then begin

      WriteLn('TEN POKOJ JEST CALY OBRYZGANY KRWIA NA SCIANACH FLAKI I MOZGI LODZKIE ');
      if StanOdpornego = 15 then
        WriteLn('POWOLNY ACZ ODPORNY NA BOL POTWOR SPOKOJNIE LEZY POD SCIANA');
      if StanOdpornego = 0 then
        WriteLn('PAROJACE WNETRZNOSCI POTWORA SA ROZWLECZONE DOOKOLA');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLNOC-KLATKI PELNE GAJDY');
        end;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLNOC' then MIECHO := 11;
        if (wpisz = 'ZABIJ POTWOR') and (StanOdpornego = 15) then begin
          WROGEN := 40; WROGZRE := 3; WROGSIL := 3;
          WALKA;
          if PASZOL = 0 then begin
            StanOdpornego := 0;
            CZY := Random(15);
            WriteLn('WYCIAGASZ ', CZY, ' MONET Z CIALA POTWORA');
            FORSA := FORSA + CZY;
            if PRZEDM.MMIECZ = 0 then begin
              PRZEDM.FUKS := Random(20);
              if PRZEDM.FUKS < 7 then begin
                PRZEDM.MMIECZ := MIECHO;
                WriteLn('WYCIAGASZ STARY ZARDZEWIALY MIECZ Z CIALA POTWORA');
                WartoscMiecza := 500;
              end;
            end;
            if PRZEDM.MTARCZA = 0 then begin
              PRZEDM.FUKS := Random(20);
              if PRZEDM.FUKS < 7 then begin
                PRZEDM.MTARCZA := MIECHO;
                WriteLn('WYCIAGASZ ZWYKLA MALA TARCZA Z CIALA POTWORA');
                WartoscTarczy := 300;
              end;
            end;
            if PRZEDM.SERCE = 0 then begin
              PRZEDM.FUKS := Random(20);
              if PRZEDM.FUKS < 6 then begin
                PRZEDM.SERCE := MIECHO;
                WriteLn('WYCIAGASZ ZAKRWAWIONE SERCE Z CIALA POTWORA');
                WartoscSerca := 50;
              end;
            end;
          end else
            PASZOL := 0;
        end;
      until MIECHO <> 15;

    end;
{ img 0xB7F2..0xBAAB: inline room 16 (context 16) - silny potwor }
    if MIECHO = 16 then begin

      WriteLn('TEN POKOJ JEST CALY OBRYZGANY KRWIA NA SCIANACH FLAKI I MOZGI LODZKIE ');
      if StanOgromnego = 16 then
        WriteLn('OGROMNY POTWOR WIDZAC MIESO RZUCA SIE NA CIEBIE');
      if StanOgromnego = 0 then
        WriteLn('PAROJACE WNETRZNOSCI POTWORA SA ROZWLECZONE DOOKOLA');
      repeat
        if StanOgromnego = 16 then begin
          WROGEN := 40; WROGZRE := 11; WROGSIL := 10;
          WALKA;
          if PASZOL <> 0 then goto L1027_Ucieczka16;
          StanOgromnego := 0;
          CZY := Random(30);
          WriteLn('WYCIAGASZ ', CZY, ' MONET Z CIALA POTWORA');
          FORSA := FORSA + CZY;
          if PRZEDM.MMIECZ = 0 then begin
            PRZEDM.FUKS := Random(20);
            if PRZEDM.FUKS < 10 then begin
              PRZEDM.MMIECZ := MIECHO;
              WriteLn('WYCIAGASZ STARY ZARDZEWIALY MIECZ Z CIALA POTWORA');
              WartoscMiecza := 500;
            end;
          end;
          if PRZEDM.MTARCZA = 0 then begin
            PRZEDM.FUKS := Random(20);
            if PRZEDM.FUKS < 10 then begin
              PRZEDM.MTARCZA := MIECHO;
              WriteLn('WYCIAGASZ ZWYKLA MALA TARCZA Z CIALA POTWORA');
              WartoscTarczy := 300;
            end;
          end;
          if PRZEDM.SERCE = 0 then begin
            PRZEDM.FUKS := Random(20);
            if PRZEDM.FUKS < 6 then begin
              PRZEDM.SERCE := MIECHO;
              WriteLn('WYCIAGASZ ZAKRWAWIONE SERCE Z CIALA POTWORA');
              WartoscSerca := 50;
            end;
          end;
          goto L1028_PoUcieczce16;
          L1027_Ucieczka16:
          PASZOL := 0;
          MIECHO := 11;
          L1028_PoUcieczce16:
        end;
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('DOL-KLATKI PELNE GAJDY');
        end;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'DOL' then MIECHO := 11;
      until MIECHO <> 16;

    end;
{ img 0xBAAB..0xBD1E: inline room 17, the poster room }
    if MIECHO = 17 then begin

      WriteLn('JESTES W POKOJU W KTORYM !JEST! !PLAKAT (SMIERDZI TU) ');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('GORA-KLATKI PELNE GAJDY');
          WriteLn('DOL-TELEPORT!!!');
        end;
        if wpisz = 'PATRZ PLAKAT' then begin
          WriteLn('NA PLAKACIE PISZE:');
          WriteLn('SORRY ZE NIE UMYLEM POKOJU ALE NIE MAM NA TO CZASU');
          WriteLn('JEZELI BYLES AKTYWNY TO POWINIENES LICZYC NA NAGRODE');
          WriteLn('SPRAWDZ CZY LEZY TU COS , POTEM MOZESZ ZEJZD DO TELEPORTU ');
          if (StanCieniasa = 0) and (StanZrecznego = 0) and
          (MONSTRA.SILNY = 0) and (StanOdpornego = 0) and
          (StanOgromnego = 0) and (DYPLOM = 0) then
            DYPLOM := 17;
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'GORA' then MIECHO := 11;
        if wpisz = 'DOL' then MIECHO := 18;
      until MIECHO <> 17;

    end;
{ img 0xBCA2..0xBD1E: one-shot teleport room, context 18 -> room 1 }
    if MIECHO = 18 then begin

      WriteLn('BBBBBBBBZBZBZBZBZZZZZZZzzzzzzzzzbbzbBbzbzbzBZZZ');
      WriteLn('===-------......_________.....----------....._______....-------======');
      WriteLn('T***E***L***E***P***O***R***T***O***W***A***L***E***S***** *****S***I***E!');
      WriteLn('==========================================================================');
      MIECHO := 1;

    end;
{ img 0xBD29..0xBF0A: context 20, city center }
    if MIECHO = 20 then begin

      WriteLn('JESTES W CENTRUM MIASTA : NA SCIANIE JEST PLAKAT (DUZY RUCH) ');
      PRZEDM.ULSKLEPIKOWA; { img 0xBD45 -> PRZEDM entry at 0x155F2 }
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'PATRZ PLAKAT' then
          WriteLn('TO JEST MIASTO : RADZ SOBIE SAM!');
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-POKOJ CENTRALNY');
          WriteLn('POLNOC-UL.SKLEPIKOWA');
          WriteLn('WSCHOD-UL.CIEMNA');
          WriteLn('ZACHOD-UL.DLUGA');
        end;
        if wpisz = 'WYJSC0IE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 1;
        if wpisz = 'POLNOC' then MIECHO := 21;
        if wpisz = 'ZACHOD' then MIECHO := 30;
        if wpisz = 'WSCHOD' then MIECHO := 75;
        WalkaMiasto; { img 0x11C2A }
      until MIECHO <> 20;

    end;
    if MIECHO = 75 then POKOJ75;
    if MIECHO = 30 then POKOJ30;
{ img 0xC005..0xC202: context 0x4C (76) - BAR POD DWOMA PEDALAMI }
    if MIECHO = 76 then begin

      WriteLn('JESTES W BARZE POD DWOMA PEDALAMI CHCAC ROZWIKLAC TA DZIWNA NAZWE');
      WriteLn('PYTASZ SIE BARMANA : PRZEPRASZAM DLACZEGO TEN BAR NAZYWA SIE  ');
      WriteLn('"POD DWOMA PEDALAMI"? A ON NA TO -WLASCIWIE TO NIE WIEM');
      WriteLn(' ALE SPYTAM SIE ZONY:MAREEEK!!.......(teraz ju'#190' wiesz) ');
      if MONSTRA.MACIEK = 76 then
        WriteLn('MACIEK , TUTEJSZY BARMAN SERWUJE TUTAJ DRINKI (MOZLIWA LISTA!');
      if MONSTRA.PEDAL = 76 then
        WriteLn(' PEDAL CZEKA TU NA TEGO JEDYNEGO');
      if MONSTRA.PARA = 76 then
        WriteLn('PARA-JACEK I JUREK OBMYSLAJA MIESIAC MIODOWY');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-ULICA CIEMNA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 75;
        if wpisz = 'LISTA' then begin
          WriteLn('DRINK        CENA');
          WriteLn('ORAL DRINK     130');
          WriteLn('ONANISOFT      180');
          WriteLn('PEDAL&SPRZEGLO 220');
        end;
        if wpisz = 'ZABIJ PEDAL' then begin
          PRZEDM.EASY;
          MONSTRA.PEDAL := 0;
          PRZEDM.PIGULKAZYSK;
        end;
        if wpisz = 'ZABIJ PARA' then begin
          PRZEDM.BTRUDNO;
          MONSTRA.PARA := 0;
          PRZEDM.BTRUDNO;
        end;
        if wpisz = 'ZABIJ MACIEK' then begin
          PRZEDM.EASY;
          MONSTRA.MACIEK := 0;
        end;
        if wpisz = 'MAM 18 LAT' then begin
          WriteLn('I CO Z TEGO ??? A JA MAM 100 LAT I ZYJE !!!');
        end;
      until MIECHO <> 76;

    end;
{ img 0xC20C..0xC3D9: inline context 77 }
    if MIECHO = 77 then begin

      WriteLn('ZNALAZLES SIE WSROD BLUSZCZU , WOKOLO CIEBIE TAJEMNICZE ROSLINY ');
      WriteLn('MUSISZ BARDZO UWAZAC,TU NAWET STOKROTKA MOZE BYC ZABOJCZA');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLNOC-UL.CIEMNA');
          WriteLn('WSCHOD-BLUSZCZ');
          WriteLn('ZACHOD-BLUSZCZ');
          WriteLn('POLODNIE-BLUSZCZ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLNOC' then MIECHO := 75;
        if wpisz = 'WSCHOD' then MIECHO := 78;
        if wpisz = 'ZACHOD' then MIECHO := 79;
        if wpisz = 'POLODNIE' then MIECHO := 80;
      until MIECHO <> 77;

    end;
{ img 0xC3ED..0xC51E: inline context 78 }
    if MIECHO = 78 then begin

      WriteLn('WSZEDLES W GASZCZ ROSLIN I KWIATOW');
      WriteLn('NIE MA CO OPISYWAC WYSTARCZY POWIEDZIEC ZE JEST TU BYDLO CHWASTOW');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('ZACHOD-BLUSZCZ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'ZACHOD' then MIECHO := 77;
      until MIECHO <> 78;

    end;
{ img 0xC532..0xC663: inline context 79 }
    if MIECHO = 79 then begin

      WriteLn('SLYSZYSZ POKRZYWE KTORA POZERA BEZBRONNY SZCZAW .... OHYDA');
      WriteLn('WOKOLO TAK CIEMNO,ZE GDYBY NIE JA JUZ DAWNO BYS ZGINA');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-BLUSZCZ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 77;
      until MIECHO <> 79;

    end;
{ img 0xC677..0xC982: inline context 80 }
    if MIECHO = 80 then begin

      WriteLn('CHOC TO MALO PRAWDOPODOBNE TUTAJ JEST JESZCZE CIEMNIEJ');
      WriteLn('PONADTO W NIEKTORYCH MIEJSCACH ZNAJDUJE SIE BLOTO I INNE BZDURY');
      WriteLn('NA SRODKU ZNAJDUJE SIE STUDNIA I MALO CZYTELNY NAPIS');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLNOC-BLUSZCZ');
          WriteLn('WSCHOD-BLUSZCZ');
          WriteLn('ZACHOD-BLUSZCZ');
          WriteLn('POLODNIE-BLUSZCZ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLNOC' then MIECHO := 77;
        if wpisz = 'ZACHOD' then MIECHO := 81;
        if wpisz = 'WSCHOD' then MIECHO := 82;
        if wpisz = 'POLODNIE' then MIECHO := 83;
        if wpisz = 'PATRZ NAPIS' then
          WriteLn('PISZE TUTAJ : '#2'A'#2'RZY'#2' D'#2' S'#2'UDN'#2' (MOWILEM ZE MALO CZYTELNY)');
        if wpisz = 'PATRZ STUDNIA' then begin
          PRZEDM.FUKS := Random(3) + 1;
          WriteLn('ZAGLADASZ DO SRODKA STUDNI,COS TAM JEST,WYCI'#164'GASZ ', PRZEDM.FUKS,
              ' MONET!');
          FORSA := FORSA + PRZEDM.FUKS;
          PRZEDM.FUKS := Random(100);
          if PRZEDM.FUKS < 10 then begin
            WriteLn('JAK SMIESZ PODBIERAC MOJE SWIETOSCI , GIN CHAMIE , GIN');
            ENERGIA := ENERGIA - 40;
            WriteLn('ODDAWAJ MOJE PIENIADZE !!!');
            FORSA := FORSA - 100;
            if FORSA < 0 then FORSA := 0;
          end;
        end;
      until MIECHO <> 80;

    end;
{ img 0xC98C..0xCAC7: inline context 81 }
    if MIECHO = 81 then begin

      WriteLn('PRZEDZIERASZ SIE PRZEZ CALY TEN SYF I NAJCHETNIEJ BYS');
      WriteLn('TERAZ PORZYCZY'#157' KOSIARKI OD SWEGO KOLEGI TOMKA');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-BLUSZCZ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 80;
      until MIECHO <> 81;

    end;
{ img 0xCAD1..0xCC0C: inline context 82 }
    if MIECHO = 82 then begin

      WriteLn('W TEJ KOMNACIE JEST ZNACZNIE JASNIEJ A TO DLATEGO ZE NAPROMIENIOWANE');
      WriteLn('I ZMUTOWANE ROSLINY ID'#164' W TWYM KIERUNKU');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('ZACHOD-BLUSZCZ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'ZACHOD' then MIECHO := 80;
      until MIECHO <> 82;

    end;
    if MIECHO = 83 then POKOJ83;
{ img 0xCC22..0xCDFB: context 84, entrance toward the cave }
    if MIECHO = 84 then begin

      WriteLn('TO CIEKAWE ZE WCZESNIEJ NIE ZAUWAZYLES TYCH KRARZAKOW PRZEDZIERASZ');
      WriteLn('SIE PRZEZ ICH GASZCZ WYGLADA TO NA NIEZBYT MILA KRAINE');
      WriteLn('DALES NA ZACHOD WIDZISZ JAKIES PODEJRZANE BUDOWLE , A NA POLODNIE BRRRR.');
      WriteLn('NA POLODNIE JAK GDYBY KTOS SIE OBZERAL , ALE BARDZO GLOSNO I NIEBEZPIECZNIE');
      PRZEDM.BLUSZCZ;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        PRZEDM.FIGHTBLUSZCZ;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-BLUSZCZ');
          WriteLn('ZACHOD-BUDYNEK');
          WriteLn('POLODNIE-WEJSCIE DO GROTY ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 83;
        if wpisz = 'ZACHOD' then MIECHO := 85;
        if wpisz = 'POLODNIE' then MIECHO := 87;
      until MIECHO <> 84;

    end;
{ img 0xCDFB..0xCFC2: context 87, poisonous passage }
    if MIECHO = 87 then begin

      WriteLn('MLASK , MLASK KTOS RZECZYWISCIE SIE OBZERA CZY JESTES 100% PEWNY IZ');
      WriteLn('CHCESZ SIE ZAGLEBIC W TE NIEBADANE CZELUSCIE PIEKIELNE?, MOZE LEPIEJ WROC');
      PRZEDM.FUKS := Random(100);
      if PRZEDM.FUKS < 40 then begin
        WriteLn('NO PIEKNIE WLAZLES W JAKIES TOKSYCZNE SUBSTANCJE ,AAA, TO PARZY TRACISZ ',
           25 - ZRE, '%');
        ENERGIA := ENERGIA - 25 + ZRE;
      end;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-GROTA');
          WriteLn('POLNOC-PODEJRZANE KRZAKI');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLNOC' then MIECHO := 84;
        if wpisz = 'POLODNIE' then MIECHO := 88;
      until MIECHO <> 87;

    end;
{ img 0xCFCC..0xD1FB: context 88, giant man-eating plant encounter }
    if MIECHO = 88 then begin

      WriteLn('MOJ BOZE , COZ TO JEST , NA TRONIE SIEDZI 20 RAZY WIEKSZA OD CIEBIE POKRZYWA');
      WriteLn('WOKOL NIEJ UWIJAJA SIE PRACOWITE MLECZE DOSTARCZAJAC JEJ SWIEZEGO ');
      WriteLn('MIESA LUDZKIEGO !!! , UWIELBIA ONA MOZGI KTORE WYSSYSA JAK PYSZNY PUDDING ');
      WriteLn('W PEWNYM MOMECIE ZAUWAZA CIEBIE - WITAJ WEDROWCZE PODOBAM CI SIE? - (TAK,NIE)');
      Write('TAK lub NIE >');
      ReadLn(wpisz);
      WriteLn('NO TO GIN!!!');
      repeat
        WROGEN := 200; WROGZRE := 15; WROGSIL := 18;
        PRZEDM.FIREBALL := 5; PRZEDM.POISON := 1;
        WALKA;
        if WROGEN < 0 then begin
          PRZEDM.LISTEKZYSK;
          PRZEDM.PIGULKAZYSK;
          PRZEDM.SCROLLPORZYSK;
          if PRZEDM.DUNQ <> 0 then PRZEDM.DUNQ := PRZEDM.DUNQ - 50;
        end;
        if ENERGIA > 0 then begin
          WriteLn('UFFF,TO BYLA PRZYGODA,WOKOL GROMADZILY SIE SETKI MLECZOW - NIE MIALBYS SZANS');
          MIECHO := 87;
        end;
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-WEJSCIE DO GROTY');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 87;
      until MIECHO <> 88;

    end;
{ img 0xD1FB..0xD41D: context 85, living door }
    if MIECHO = 85 then begin

      WriteLn('DO DOBRA WYGLADA TO NA JAKIS DOM , WEJDZMY DO SRODKA ');
      WriteLn('GOD DAMN , A NIECH MNIE MA MATEUSZ W SWOJEJ OPIECE , TE DRZWI ZYJA !!!');
      if MONSTRA.DRZWI <> 0 then
        WriteLn('DRZWI WYCIAGAJA SWE DREWNIANE RECE W TWYM KIERUNKU MOWIAC : NIE WPUSZCZE');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        if wpisz = 'ZABIJ DRZWI' then begin
          if MONSTRA.DRZWI <> 0 then begin
            PRZEDM.NEASY;
            if ENERGIA > 0 then MONSTRA.DRZWI := 0;
          end;
        end;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-PODEJRZANE KRZAKI');
          if MONSTRA.DRZWI <> 0 then
            WriteLn('ZACHOD-GDYBY NIE TE CHOLERNE DRZWI ... ');
          if MONSTRA.DRZWI = 0 then
            WriteLn('ZACHOD-WEJSCIE DO DOMKU');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 84;
        if (wpisz = 'ZACHOD') and (MONSTRA.DRZWI = 0) then MIECHO := 86;
        if (wpisz = 'ZACHOD') and (MONSTRA.DRZWI <> 0) then
          WriteLn('SPROBOJ OMINAC TE MEGA-PRZYPAKOWANE DRZWI KTORYCH BY SIE HE-MAN NIE POWSTYDZIL');
      until MIECHO <> 85;

    end;
{ img 0xD427..0xD7F0: context 86, the old man's room }
    if MIECHO = 86 then begin

      WriteLn('DOBRA JESTES W SRODKU BRAK OSWIETLENIA CIE NIE WZRUSZA , DOOKOLA ROZNE GARNKI');
      if MONSTRA.STARUCH <> 0 then
        WriteLn('W ROGU ZAUWAZASZ MALEGO WYGLODZONEGO ELFIEGO STARUCHA');
      if MONSTRA.STARUCH = 0 then
        WriteLn('WIDZISZ TU TYLKO PLASZCZ PO STARUCHU KTORY ZNIKNA W PRZESTRZEN');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        PRZEDM.KOMENDY;
        if wpisz = 'DAWAJ KUNSZT' then KUNSZT := KUNSZT + 500;
        if wpisz = 'PATRZ GARNKI' then
          WriteLn('Z JEZOREM NA WIERZCHU PATRZYSZ DO GARNKOW LECZ NIC W NICH NIE MA');
        if wpisz = 'ROZMAWIAJ STARUCH' then begin
          if (WEKA > -30) and (FORSA < 200) and (PrzedmScrollPowrot = 0) then begin
            WriteLn('STARUCH MOWI CI : HEJ KTO TY JESTES CZY ZE MAGICZNE DRZWI NIE POWSTRZYMALY CIE?');
            WriteLn('MUSISZ BYC NIEZLYM WOJOWNIKIEM ,SPOXOLANDIA, GLODNY JESTEM PRZYNIES MI 4 WEKI ');
            WriteLn('ORAZ OKOLO 200 KASY , A DAM CI TAKIE NUMERY O JAKICH CI SIE NIE SNILO....');
          end;
        end;
        if wpisz = 'ROZMAWIAJ STARUCH' then begin
          if (WEKA < -30) and (FORSA > 199) then begin
            WriteLn('STARUCH MOWI CI : OOO JAKA PIEKNA WEKA ... MNIAM I DRUGA TRZECIA I CZWARTA');
            WriteLn('TO BYLO DOBRE ZARCIE !!! , DAWAJ KASE , PIENIADZE !!! , CO SIE TAK GAPISZ?');
            WriteLn('WYNOCHA STAD !!! MRAMMMARAMMARAMAAMMARAM BUM !! -T-E-L-E-P-O-R-T-Y');
            WriteLn('WYGLADA ZE ZROBIL CIE W BUCA , A MOZE JEDNAK NIE , CO TO ? , SCROLL POWROTU');
            WriteLn('I PIWSKO NA OSLODZENIE ZYCIA , NO TRUDNO PRZYNAJMNIEJ CZEGOS SIE NAUCZYLES');
            MIECHO := 20;
            PrzedmPiwo := PrzedmPiwo - 10;
            WEKA := WEKA + 40;
            FORSA := FORSA - 200;
            PrzedmScrollPowrot := PrzedmScrollPowrot - 10;
            KUNSZT := KUNSZT + 50;
            PRZED := PRZED - 2;
          end;
        end;
        if wpisz = 'ROZMAWIAJ STARUCH' then begin
          if PrzedmScrollPowrot < 0 then begin
            WriteLn('AAAA SPADAJ STAD BO CI KOSCI POLAMIE');
            MIECHO := 16;
          end;
        end;
        if wpisz = 'ZABIJ STARUCH' then begin
          if MONSTRA.STARUCH <> 0 then begin
            PRZEDM.SLABO;
            MONSTRA.STARUCH := 0;
            WriteLn('HMMM UBRANIE JEST , ALE CIALO GDZIES ZNIKNELO , WTEM SLYSZYSZ GLOS :');
            WriteLn('--- TO BYL TWOJ BLAD --- , DOSTAJESZ OCMIENIA LECZ NIE WIESZ CO TO BYLO');
            POZIOM := POZIOM - 1;
          end;
        end;
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-BUDYNEK');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 85;
      until MIECHO <> 86;

    end;
{ img 0xD7F0..0xD9CA: context 21 }
    if MIECHO = 21 then begin

      WriteLn('JESTES NA ULICY NA ULICY SKLEPIKOWEJ - JAK SAMA NAZWA WZKAZUJE  ');
      WriteLn('JEST TU PARE SKLEPIKOW KTORE BYC MOZE CI SIE PRZYDADZA');
      PRZEDM.ULSKLEPIKOWA;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-CENTRUM MIASTA');
          WriteLn('POLNOC-UL.SKLEPIKOWA');
          WriteLn('WSCHOD-PIEKARNIA');
          WriteLn('ZACHOD-ZBROJOWNIA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 20;
        if wpisz = 'POLNOC' then MIECHO := 22;
        if wpisz = 'WSCHOD' then MIECHO := 23;
        if wpisz = 'ZACHOD' then MIECHO := 24;
        WalkaMiasto; { img 0x11C2A }
      until MIECHO <> 21;

    end;
{ img 0xD9CA..0xDBA4: context 22 }
    if MIECHO = 22 then begin

      WriteLn('CIAGNIE SIE TEDY ULICA SKLEPIKOWA JEST TU JESZCZE PARE  ');
      WriteLn('INTERESUJACYCH SKLEPOW. DALEJ CIAGNIE SIE KILKA ULIC....');
      PRZEDM.ULSKLEPIKOWA;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-UL.SKLEPIKOWA');
          WriteLn('POLNOC-ROZJAZD!');
          WriteLn('WSCHOD-SKLEP WIELOBRANZOWY');
          WriteLn('ZACHOD-SKLEP MAGICZNY  ');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 21;
        if wpisz = 'WSCHOD' then MIECHO := 25;
        if wpisz = 'ZACHOD' then MIECHO := 26;
        if wpisz = 'POLNOC' then MIECHO := 100;
        WalkaMiasto; { img 0x11C2A }
      until MIECHO <> 22;

    end;
{ img 0xDBA4..0xDDA8: context 101 }
    if MIECHO = 101 then begin

      WriteLn('IDZIESZ DROGA , MIASTA PO DRODZE MIJASZ DROGOWSKAZ . JEST TU O WIELE ');
      WriteLn('NIEBEZPIECZNIEJ NIZ W MIESCIE PELNO TU ZEZIMIERZKOW ROZNEGO RODZAJU');
      WriteLn('JESLI NIE CHCESZ MIEC KLOPOTOW LEPIEJ DOBRZE TRYMAJ SIE DROGI....');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-ROZJAZD!');
          WriteLn('ZACHOD-DROGA');
          WriteLn('POLNOC-LAS');
          WriteLn('POLODNIE-LAS');
        end;
        if wpisz = 'PATRZ DROGOWSKAZ' then
          WriteLn('WSCHOD - MIASTO , ZACHOD - SHIGGHLERATHR');
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 100;
        if wpisz = 'ZACHOD' then MIECHO := 102;
        if wpisz = 'POLNOC' then MIECHO := 104;
      until MIECHO <> 101;

    end;
{ img 0xDDA8..0xDF4C: context 102 }
    if MIECHO = 102 then begin

      WriteLn('IDZIESZ DALEJ KAMIENISTA DROGA , BRZYDALA BI CI SIE JAKA BRYCZKA NALEPIEJ ');
      WriteLn('MODEL SZKAPA 2000 , ALE COZ KONIE SA TYLKO DLA NAJBOGATSZYCH');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-DROGA');
          WriteLn('ZACHOD-DROGA');
          WriteLn('POLNOC-LAS');
          WriteLn('POLODNIE-LAS');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 101;
        if wpisz = 'ZACHOD' then MIECHO := 103;
      until MIECHO <> 102;

    end;
{ img 0xDF4C..0xE0F2: context 103 }
    if MIECHO = 103 then begin

      WriteLn('CO TO ZA GLUPOTA ? DROGA SKRECA TROCHE W LEWO , TROCHE W PRAWO ALE ');
      WriteLn('PRZECIEZ ROWNIE DOBRZE MOGLA BY ISC SRODKIEM , ZYSKALI BY NA TYM WSZYSCY');
      WriteLn('A SZCZEGOLNIE TY ,  BO BOLA CIE NOGI OD TEGO CHODZENIA NIEMOZEBNIE');
      WriteLn('UPS DROGA SIE KONCZY NA TEJ NIEPRZEPASTNEJ RZECE O DALSZEJ PODROZY NIE MA MOWY');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-DROGA');
          WriteLn('POLNOC-LAS');
          WriteLn('POLODNIE-LAS');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 102;
      until MIECHO <> 103;

    end;
    if MIECHO = 100 then POKOJ100;
{ img 0xE0FE..0xE2A1: inline context 23 }
    if MIECHO = 23 then begin

      WriteLn('JESTES W PIEKARNI , SKLEP PRZESIAKNIETY JEST PRZYJEMNYM ZAPACHEM CHLEBA ');
      WriteLn('PIEKARZ MILO SIE NA CIEBIE PATRZY WYCIERAJAC MAKE Z TWARZY');
      WriteLn('NA SCIANIE  JEST PLAKAT CALY W MACE');
      PRZEDM.ULSKLEPIKOWA;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'PATRZ PLAKAT' then begin
          WriteLn('LISTA-LISTA DOSTEPNYCH RZECZY,KUP (PRZEDMIOT)-KUPUJESZ GO ');
          WriteLn('PO ODEJSCIU OD LADY REKLAMACJI NIE UWZGLEDNIA SIE');
        end;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('ZACHOD-ULICA SKLEPIKOWA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'ZACHOD' then MIECHO := 21;
        ZakupyPiekarnia;
      until MIECHO <> 23;

    end;
{ img 0xE2AB..0xE42B: inline context 24 }
    if MIECHO = 24 then begin

      WriteLn('JESTES W ZBROJOWNI - SKLEP NIEDAWNO ZOSTAL OTWARTY');
      WriteLn('SPRZEDAWCA(BRZYDKA AURA) STARA SIE WCISNAC CI JAKIS TOWAR ');
      WriteLn('NA SCIANIE WISI PLAKAT');
      PRZEDM.ULSKLEPIKOWA;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        ZakupyZbrojownia; { img 0x13E8E }
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-ULICA SKLEPIKOWA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 21;
        if wpisz = 'PATRZ PLAKAT' then
          WriteLn('LISTA,KUP XXX I SPRZEDAJ XXX TO JEST DOSTEPNE W TYM SKLEPIE ');
        WalkaMiasto; { img 0x11C2A }
      until MIECHO <> 24;

    end;
{ img 0xE435..0xE599: inline context 25 }
    if MIECHO = 25 then begin

      WriteLn('WSZEDLES DO SKLEPU WIELOBRANZOWEGO,STWIERDZASZ OBECNOSC SPRZEDAWCY');
      WriteLn('NA DRZWIACH ZOSTALA WYWIESZONA WYWIESZKA');
      PRZEDM.ULSKLEPIKOWA;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('ZACHOD-ULICA SKLEPIKOWA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'ZACHOD' then MIECHO := 22;
        if wpisz = 'PATRZ WYWIESZKA' then
          WriteLn('* SKLEP OTWARTY DO ODWOLANIA *');
        WalkaMiasto; { img 0x11C2A }
        ZakupySklepWielobranzowy; { img 0x143A5 }
      until MIECHO <> 25;

    end;
{ img 0xE5A3..0xE6EB: inline context 26; transaction at img 0x14ADD }
    if MIECHO = 26 then begin

      WriteLn('WCHODZISZ DO SKLEPU ALE NICZEGO TU NIE MA POZA SPRZEDAWCA I JEGO TOWAREM');
      PRZEDM.ULSKLEPIKOWA;
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-ULICA SKLEPIKOWA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 22;
        if wpisz = 'PATRZ PLAKAT' then
          WriteLn('* OTWARTE Z POWODU CHOROBY *');
        ZakupySklepMagiczny;
        WalkaMiasto; { img 0x11C2A }
      until MIECHO <> 26;

    end;
{ img 0xE6F5..0xE854: inline context 31 }
    if MIECHO = 31 then begin

      WriteLn('IDAC ULICA DLUGA NA POLNOC SPOSTRZEGASZ DOLINE ROZRYWEK');
      WriteLn('A NA POLODNIE BASNIOWY GAJ...........');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('WSCHOD-ULICA DLUGA');
          WriteLn('POLNOC-DOLINA ROZRYWEK');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'WSCHOD' then MIECHO := 30;
        if wpisz = 'POLNOC' then MIECHO := 60;
      until MIECHO <> 31;

    end;
    if MIECHO = 60 then POKOJ60;
    PokojeKoncertowe; { near call at img 0xE860 -> 0x68BC }
{ img 0xE86D..0xEA0B: inline context 32; MINIARENA owns cells 33..57 }
    if MIECHO = 32 then begin

      WriteLn('CZESC TO ARENA PRZYCHODZA TU TACY JAK TY PO TO ABY MORDOWAC');
      WriteLn('!!!!!O NIE!!!!!!!! TO STRASZNE!!! ( SIE DAL NABRAC ) (NAPISZ PATRZ PLAKAT');
      repeat
        Write(ENERGIA, '%.', KUNSZT, '>');
        ReadLn(wpisz);
        if wpisz = 'MODE' then PRZEDM.MODE;
        if wpisz = 'PATRZ PLAKAT' then begin
          WriteLn('NA PLAKACIE PISZE');
          WriteLn('NIE ATAKUJ LUDZI I ZWIERZAT Z ZOO CHYBA ZE MASZ 3 LEVEL( LUB WYZEJ :P)');
        end;
        if wpisz = 'EXIT' then begin
          WriteLn('DOSTEPNE WYJSCIA:');
          WriteLn('POLODNIE-ULICA DLUGA');
          WriteLn('POLNOC-ARENA');
        end;
        if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;
        if wpisz = 'POLODNIE' then MIECHO := 30;
        if wpisz = 'POLNOC' then MIECHO := 33;
      until MIECHO <> 32;

    end;
    { Called unconditionally at img 0xEA15; MINIARENA guards contexts 33..57. }
    PRZEDM.MINIARENA;
    if MIECHO = MIECHO_Smierc then Smierc; { near call at img 0xEA22 -> 0x36F4 }
    if ENERGIA > MAXE then ENERGIA := MAXE; { img 0xEA25..0xEA34 }
    if MIECHO = MIECHO_Podswiadomosc then begin
      if MMIECZ = PRZEDM.MIECHO2 then
        WriteLn('W TWYM POKOJU LEZY !STARY! ZARDZEWIALY MIECZ');
      if MTARCZA = PRZEDM.MIECHO2 then
        WriteLn('W TYM POKOJU ZNAJDUJE SIE !MALA! TARCZA');
      if SERCE = PRZEDM.MIECHO2 then
        WriteLn('W TYM POKOJU ZNAJDUJE SIE ZAKRWAWIONE !SERCE!');
      if DYPLOM = PRZEDM.MIECHO2 then
        WriteLn('W TYM POKOJU ZNAJDUJE SIE !DYPLOM! MUD SZKOLY');
      if FAJKA = PRZEDM.MIECHO2 then
        WriteLn('TU LEZY !FAJKA!');
      L1012_ZachetaPodswiadomosc: Write(ENERGIA, '%.', KUNSZT, '>'); { img 0xEAF8..0xEB31 }
      ReadLn(wpisz);

      if wpisz = 'PAMIETAJ' then ZapiszPostac; { save routine starts img 0x2BA1 }
      if wpisz = 'SCAN' then
        WriteLn('FUNKCJA BEDZIE DOSTEPNA ZA DWA LATA , I TAK ZGINIESZ , I TAK :) ');
      if wpisz = 'CZYSC EKRAN' then ClrScr; { img 0xEB99..0xEBAF }
      if wpisz = 'DAWAJ EN' then ENERGIA := ENERGIA + 200;
      if wpisz = 'ZABIERAJ KASE' then FORSA := FORSA - 100;

      if wpisz = 'USTAW SZ' then begin
        PRZEDM.ILOSC := 0;
        PRO := 0;
        FUKSROLL := 0;
      end;
      if wpisz = 'ZDEJMUJ' then begin
        PRZEDM.CIALO := 0;
        JakaBron := 0;
        JakaTarcza := 0; { DGROUP word 0x60, shield-equipped flag in this branch }
        PRZEDM.JAKIEUB := '';
        MMIECZ := -10;
        MTARCZA := -10;
        SIL := SIL - 1;
      end;

      if wpisz = 'EXIT' then WriteLn('NAPISZ UNMODE ');
      if wpisz = 'WYJSCIE' then goto L1025_Wyjscie;

      if wpisz = 'JA' then PokazPostac;
      PRZEDM.BRANIE; { img 0xEC9B -> PRZEDM:0x5A36 item pickup/drop dispatch }
      if ZapisanoGre = 1 then begin
        wpisz := 'ZDOLNOSCI'; { img 0xECA7: short-string assign via System:0x900 }
        ZapisanoGre := 0;
        WriteLn(PRZEDM.MIECHO2, ' MIECHO!');
      end;
      if wpisz = 'UZYJ PIWO' then begin
        if PrzedmPiwo <= -10 then begin
          PrzedmPiwo := PrzedmPiwo + 10;
          WriteLn('GDY POCZULES AMBROZJE W USTACH ODZYSKALES 10 MANY ZAS GDY GO WYPILES 10% E.');
          PRZEDM.PRZED := PRZEDM.PRZED - 1;
          ENERGIA := ENERGIA + 10;
          MANA := MANA + 10;
        end;
      end;
      if wpisz = 'UZYJ STARY' then begin
        if (MMIECZ = -10) and (JakaBron = 0) then begin
          MMIECZ := -100;
          JakaBron := 1;
          WriteLn('UZYWASZ STAREGO ZARDZEWIALEGO MIECZA JAKO BRONI');
          SIL := SIL + 1;
          FUKSROLL := FUKSROLL + 3;
        end;
      end;
      if wpisz = 'ODLOZ STARY' then begin
        if (MMIECZ = -100) and (JakaBron = 1) then begin
          MMIECZ := -10;
          JakaBron := 0;
          WriteLn('CHOWASZ STARY ZARDZEWIALY MIECZ I NIE UZYWASZ GO JAKO BRONI');
          SIL := SIL - 1;
          FUKSROLL := FUKSROLL - 3;
        end;
      end;
      if wpisz = 'UZYJ MALA' then begin
        if (JakaTarcza = 0) and (MTARCZA = -10) then begin
          JakaTarcza := 1;
          PRO := PRO + 15;
          PRZEDM.ILOSC := PRZEDM.ILOSC + 1;
          MTARCZA := -100;
          WriteLn('UZYWASZ MALEJ TARCZY JAKO TARCZY');
        end;
      end;
      if wpisz = 'ODLOZ MALA' then begin
        if (JakaTarcza = 1) and (MTARCZA = -100) then begin
          JakaTarcza := 0;
          PRO := PRO - 15;
          PRZEDM.ILOSC := PRZEDM.ILOSC - 1;
          MTARCZA := -10;
          WriteLn('JUZ NIE UZYWASZ MALEJ TARCZY JAKO TARCZY');
        end;
      end;

    { Unit procedures supply the remaining recovered item effects. }
      PRZEDM.UZYWANIE;

      if wpisz = 'ZWIEJ' then begin
        if ZWIEJ > 0 then begin
          WriteLn('PONIZEJ ILU ENERGII CHCESZ UCIEKAC?');
          ReadLn(PRZEDM.WIMP);
        end;
      end;
      if wpisz = 'SPIJ' then begin
        GodzinySnu := 0;
        repeat
          GodzinySnu := GodzinySnu + 1;
          Delay(5000);
          WriteLn('SPISZ JUZ ', GodzinySnu, ' GODZIN');
          KUNSZT := KUNSZT - 20;
          ENERGIA := ENERGIA + 10;
        until KeyPressed;
        WriteLn('PO OBUDZENIU STWIERDZILES ZE ZYSKALES ', GodzinySnu * 10,
            ' ENERGI I STRACILES ', (20 * GodzinySnu) - Random(2 * GodzinySnu), ' KUNSZTU');
        KUNSZT := KUNSZT + Random(2 * GodzinySnu);
        if GodzinySnu > 4 then begin
          WriteLn('DLUGI SEN DODATKOWO POZWOLIL CI ODPOCZAC : ZYSKALES ', MAD, 'ENERGI');
          ENERGIA := ENERGIA + MAD;
        end;
        if GodzinySnu > 8 then begin
          WriteLn('PELNOWARTOSCIOWY SEN SPOWODOWAL SUPER ZYSK : ', MAD * 2, 'ENERGI');
          ENERGIA := ENERGIA + (MAD * 2);
        end;
        if ENERGIA > MAXE then ENERGIA := MAXE;
      end;
      if wpisz = 'POROWNAJ' then begin
        if PRZEDM.POR > 0 then begin
          PRZEDM.FUKS := Random(100);
          if PRZEDM.POR > PRZEDM.FUKS then begin
            PRZEDM.POROWNANIE;
            MANA := MANA - 10;
          end
        else begin
            WriteLn('POPELNILES PEWNE BLEDY I NIE UDALO SIE WYKONAC CZARU');
            MANA := MANA - 5;
          end;
        end;
      end;
      if wpisz = 'DAWAJ KASE' then FORSA := FORSA + 5000;
      if (wpisz = 'ODRZUC PACZEK') or (wpisz = 'ODRZUC CIASTKO') or
       (wpisz = 'ODRZUC SUCHA RACJA') or (wpisz = 'ODRZUC BULKA') or
       (wpisz = 'ODRZUC CHLEB') or (wpisz = 'ODRZUC WEKA') or
       (wpisz = 'ODRZUC SERCE') or (wpisz = 'ODRZUC BIGOS') then
        WriteLn('JAK SMIESZ WYRZUCAC JEDZENIE!!! WSTYD MI ZA CIEBIE !!! NIE POZWOLE !!!');
      if ((wpisz = 'POWROT') and (Powracanie > 0)) or
       ((wpisz = 'UZYJ SCROLL POWROT') and (PrzedmScrollPowrot < 0)) then begin
        PRZEDM.FUKS := Random(100);
        if wpisz = 'UZYJ SCROLL POWROT' then begin
          PRZEDM.FUKS := Random(1);
          PrzedmScrollPowrot := PrzedmScrollPowrot + 10;
          PRZEDM.PRZED := PRZEDM.PRZED - 1;
        end;
        if PRZEDM.FUKS <= Powracanie then begin
          WriteLn('OTWIERASZ MAGICZNY PORTAL KTORY PRZENOSI CIE DO MIASTA');
          MANA := MANA - 15;
          PRZEDM.MIECHO2 := 20;
        end;
        if (PRZEDM.FUKS > Powracanie) and (Powracanie + 30 > PRZEDM.FUKS) then begin
          WriteLn('NIE UDAJE CI SIE OTWORZYC MAGICZNEGO PORTALU');
          MANA := MANA - 5;
        end;
        if Powracanie + 29 < PRZEDM.FUKS then begin
          WriteLn('OTWIERASZ MAGICZNY PORTAL KTORY JEDNAK PRZENOSI CIE DO INNEGO MIEJSCA');
          MANA := MANA - 10;
          PRZEDM.MIECHO2 := Random(100) + 1;
        end;
      end;
      if wpisz = 'UZYJ SCROLL POROWNYWANIE' then begin
        if PRZEDM.SCROLLPOR < 0 then begin
          PRZEDM.POROWNANIE;
          MANA := MANA - 10;
          PRZEDM.SCROLLPOR := PRZEDM.SCROLLPOR + 10;
          PRZEDM.PRZED := PRZEDM.PRZED - 1;
        end;
      end;
      if wpisz = 'KOP' then begin
        if KOP > 0 then begin
          WriteLn('ZADAM CI PARE PYTAN:');
          WriteLn('1)PONIZEJ JAKIEJ ENERGI CHCESZ ZACZAC KOPAC');
          ReadLn(PRZEDM.KOPHP);
          WriteLn('2)DO JAKIECH ILOSCI MANA CHCESZ KOPAC');
          ReadLn(PRZEDM.KOPM);
        end;
      end;
      if wpisz = 'JESTEM SPEEDE' then PRZEPUSTKA := PRZEPUSTKA - 10;

      if wpisz = 'ZDOLNOSCI' then begin
        if (MAD > 10) and (SIL > 11) then WriteLn('KOPANIE       - ', KOP, '%');
        if (MAD > 10) and (ZRE > 10) then WriteLn('UCIEKANIE     - ', ZWIEJ, '%');
        if (MAD > 15) and (ZRE > 11) then WriteLn('PAROWANIE     - ', PAR, '%');
        if MAD > 11 then WriteLn('POROWNYWANIE  - ', PRZEDM.POR, '%');
        if MAD > 18 then WriteLn('POTRAWKI      - ', PotrawkiNiepotrzebnaZmiennaBug, '%');
        if MAD > 19 then WriteLn('POWROT        - ', Powracanie, '%');
      end;
      PRZEDM.PIERDOLY; { img 0xF566: color/background command dispatch }
      if wpisz = 'WLACZ POSTAC' then WczytajPostac;
    { At img 0xF5A1, UNMODE and UM both restore the saved room context. }
      if ((wpisz = 'UNMODE') or (wpisz = 'UM')) then
        MIECHO := PRZEDM.MIECHO2;
      if MIECHO = MIECHO_Podswiadomosc then goto L1012_ZachetaPodswiadomosc;
    end;
    { Reached after leaving MODE: img 0xF5B2 clears the combat flee flag. }
    PRZEDM.PASZOL := 0;
    { Context 193 terminates at img 0xF5C2; otherwise the loop restarts at
      img 0xB0F0, including the save/load checkpoint and level-up gates. }
  until MIECHO = 193;
  { Garden WYJSCIE branches jump directly to img 0xF5C2, bypassing cleanup. }
  L1025_Wyjscie: ;
  { Exit path: System termination at img 0xF5C5 }
end.
