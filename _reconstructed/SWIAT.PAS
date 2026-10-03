unit SWIAT; { checksum = $3B76 }
interface
uses  crt, monstra, przedm;
  procedure POKOJ0; { Proc $0008 Entry 8:005A }
  procedure POKOJ1; { Proc $0010 Entry 16:0397 }
  procedure POKOJ4; { Proc $0018 Entry 24:01E2 }
  procedure POKOJ13; { Proc $0020 Entry 32:01A7 }
  procedure POKOJE; { Proc $0028 Entry 40:00C9 }
  procedure POKOJ5; { Proc $0030 Entry 0:0196 }
  procedure POKOJ11; { Proc $0038 Entry 48:0261 }
  procedure POKOJ30; { Proc $0040 Entry 56:00F1 }
  procedure POKOJ60; { Proc $0048 Entry 64:011F }
  procedure POKOJ75; { Proc $0050 Entry 72:014E }
  procedure POKOJ100; { Proc $0058 Entry 88:03AB }
  procedure POKOJ83; { Proc $0060 Entry 80:012B }
implementation
procedure POKOJ5; { img 0xF766..0xFA04 }
begin
  WriteLn('SZOK!! AAA UPSI  O NIE FUJ ACH AJ OCH NEIN EEE UGH   ');
  WriteLn('STWIERDZASZ ZE W TYM POKOJU JEST X POKOI O NIE !! JAK SIE WYDOSTAC?');
  WriteLn('AHA (NA SCIANIE JEST PLAKAT)');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('WSCHOD-MUD SZKOLA');
      WriteLn('ZACHOD-POKOJ');
      WriteLn('POLNOC-POKOJ');
      WriteLn('POLODNIE-POKOJ');
      WriteLn('GORA-POKOJ');
      WriteLn('DOL-POKOJ');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'WSCHOD' then MIECHO := 4;
    if wpisz = 'ZACHOD' then MIECHO := 6;
    if wpisz = 'POLNOC' then MIECHO := 7;
    if wpisz = 'POLODNIE' then MIECHO := 8;
    if wpisz = 'GORA' then MIECHO := 9;
    if wpisz = 'DOL' then MIECHO := 10;
    if wpisz = 'PATRZ PLAKAT' then begin
      WriteLn('NA PLAKACIE BYNAJMNIEJ PISZE');
      WriteLn('TO JEST POKOJ DO ORIETACJI W TERENIE ORAZ W KIERUNKACH');
    end;
  until MIECHO <> 5;
end;

procedure POKOJ0; { img 0xFA5F..0xFB47 }
begin
  WriteLn('TU ZACZYNA SIE GRE');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'EXIT' then WriteLn('DOSTEPNE WYJSCIE-POLNOC-HALA GLOWNA MUD SZKOLE ');
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'POLNOC' then MIECHO := 1;
  until MIECHO <> 0;
end;
procedure POKOJ1; { img 0xFEDF..0x10261 }
begin
  WriteLn('JESTES W OKROGLYM SALONIE WYPELNIONYM WITRAZAMI ');
  WriteLn('W POWIETRZU UNOSZA SIE ZAPACHY I SO TO ZAPACHY OK');
  WriteLn('NO A POZA TYM NA SCIANIE JEST!!! PLAKAT!!!!');
  WriteLn('NAPISZ PATRZ PLAKAT ABY GO ODCZYTA'#143' ');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('POLODNIE-TAM GDZIE ZACZYNASZ GRE');
      WriteLn('POLNOC-MIASTO');
      WriteLn('WSCHOD-POKOJ TRENINGOWY 1');
      WriteLn('ZACHOD-MUD SZKOLA');
      WriteLn('DOL-PODDZIEMNY POKOJ TRENINGOWY(2)');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'POLODNIE' then MIECHO := 0;
    if wpisz = 'WSCHOD' then MIECHO := 2;
    if wpisz = 'DOL' then MIECHO := 3;
    if wpisz = 'ZACHOD' then MIECHO := 4;
    if wpisz = 'POLNOC' then MIECHO := 20;
    if wpisz = 'PATRZ PLAKAT' then begin
      WriteLn(#169' NA PLAKACIE PISZE:');
      WriteLn('JE'#189'ELI CHCESZ TRENOWAC UDAJ SIE DO POKOJU TRENINGOWEGO');
      WriteLn('JE'#189'ELI CHCESZ NAUCZYC SIE NOWYCH KOMEND IDZ DO MUD SZKOLY');
      WriteLn('DOPIERO POTEM IDZ DO MIASTA ');
      WriteLn('A OTO TAJNE KOMENDY :');
      WriteLn(' MODE - WPROWADZENIE W STAN PODSWIADOMOSCI');
      WriteLn(' UNMODE - POWROT DO POPRZEDNIEGO STANU');
      WriteLn('W CZASIE POBYTU W STANIE PODSWIADOMOSCI DZIALA WIELE KOMEND MIN:');
      WriteLn(' JA - WSZYSTKO O TOBIE , BIERZ , UZYJ , ZDEJMIJ , ODRZUC I INNE ');
      WriteLn(' PONADTO WIELE KOMEND TRZEBA ODKRYC NP:ZMIEN KOLOR , ZMIEN TLO ');
      WriteLn(' UWAGA Z OSTATNIEJ CHWILI : KOMENDA SPIJ W STANIE PODSWIADOMOSCI!');
    end;
  until MIECHO <> 1;
end;
procedure POKOJ4; { img 0x10447..0x1065A }
begin
  if MIECHO <> 4 then Exit;
  WriteLn('JESTES W HALLU MUD SZKOLY- OGARNIA CIE CYKORIA  ');
  WriteLn('NO A POZA TYM NA SCIANIE JEST!!! AFISZ!!!');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('WSCHOD-POKOJ CENTRALNY');
      WriteLn('ZACHOD-MUD SZKOLA (2)');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'WSCHOD' then MIECHO := 1;
    if wpisz = 'ZACHOD' then MIECHO := 5;
    if wpisz = 'PATRZ AFISZ' then begin
      WriteLn(#169' NA AFISZU BYNAJMNIEJ PISZE');
      WriteLn('TO JEST MUD SZKOLA KUJ KOMEDY ALBO ZGINIESZ!!!!!!!!');
      WriteLn('JESLI CHODZI O EKWIPUNEK TO BIERZ (PRZEDMIOT)=BIERZESZ PRZEDMIOT');
      WriteLn('UZYJ (PRZEDMIOT) = UZYWASZ PRZEDMIOTU ODRZUC (PRZEDMIOT) = ODRZUCASZ');
      WriteLn('BRONIE I TARCZE I UBRONIA MOZNA ZDJAC KOMENDA ODLORZ (PRZEDMIOT) ');
    end;
  until MIECHO <> 4;

end;
procedure POKOJ13; { img 0x10803..0x10AC3; room-13 tracker at DGROUP $68C }
begin
  if MIECHO <> 13 then Exit;
  WriteLn('TEN POKOJ JEST CALY OBRYZGANY KRWIA NA SCIANACH FLAKI I MOZGI LODZKIE ');
  if MONSTRA.SILNY = 13 then WriteLn('SILNY , NAPAKOWANY POTWOR STOI POD SCIANA');
  if MONSTRA.SILNY = 0 then WriteLn('PAROJACE WNETRZNOSCI POTWORA SA ROZWLECZONE DOOKOLA');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('WSCHOD-KLATKI PELNE GAJDY');
    end;
    if wpisz = 'MODE' then MODE;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'WSCHOD' then MIECHO := 11;
    if (wpisz = 'ZABIJ POTWOR') and (MONSTRA.SILNY = 13) then begin
      WROGEN := 20;
      WROGZRE := 3;
      WROGSIL := 10;
      WALKA;
      if PASZOL = 0 then begin
        MONSTRA.SILNY := 0;
        CZY := Random(15);
        WriteLn('WYCIAGASZ ', CZY, ' MONET Z CIALA POTWORA');
        FORSA := FORSA + CZY;
        if MMIECZ = 0 then begin
          FUKS := Random(20);
          if FUKS < 7 then begin MMIECZ := MIECHO; WriteLn('WYCIAGASZ STARY ZARDZEWIALY MIECZ Z CIALA POTWORA'); end;
        end;
        if MTARCZA = 0 then begin
          FUKS := Random(20);
          if FUKS < 7 then begin MTARCZA := MIECHO; WriteLn('WYCIAGASZ ZWYKLA MALA TARCZA Z CIALA POTWORA'); end;
        end;
        if SERCE = 0 then begin
          FUKS := Random(20);
          if FUKS < 6 then begin SERCE := MIECHO; WriteLn('WYCIAGASZ ZAKRWAWIONE SERCE Z CIALA POTWORA'); end;
        end;
      end else PASZOL := 0;
    end;
  until MIECHO <> 13;

end;
procedure POKOJE; { img 0x10B8D..0x10FFF; four separate guarded rooms }
begin
  if MIECHO = 6 then begin
    WriteLn('JESTES W DOSYC CIASNYM POKOJU I NICZEGO TU NIEMA ');
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('WSCHOD-MUD SZKOLA(2)');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'WSCHOD' then MIECHO := 5;
    until MIECHO <> 6;
  end;
  if MIECHO = 8 then begin
    WriteLn('JESTES W DOSYC CIASNYM POKOJU I NICZEGO TU NIEMA ');
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLNOC-MUD SZKOLA(2)');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLNOC' then MIECHO := 5;
    until MIECHO <> 8;
  end;
  if MIECHO = 7 then begin
    WriteLn('JESTES W DOSYC CIASNYM POKOJU I NICZEGO TU NIEMA ');
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('POLODNIE-MUD SZKOLA(2)');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'POLODNIE' then MIECHO := 5;
    until MIECHO <> 7;
  end;
  if MIECHO = 10 then begin
    WriteLn('JESTES W DOSYC CIASNYM POKOJU I NICZEGO TU NIEMA ');
    repeat
      Write(ENERGIA, '%.', KUNSZT, '>');
      ReadLn(wpisz);
      if wpisz = 'MODE' then MODE;
      if wpisz = 'EXIT' then begin
        WriteLn('DOSTEPNE WYJSCIA:');
        WriteLn('GORA-MUD SZKOLA(2)');
      end;
      if wpisz = 'WYJSCIE' then Exit;
      if wpisz = 'GORA' then MIECHO := 5;
    until MIECHO <> 10;
  end;
end;
procedure POKOJ11; { img 0x11261..0x11546 }
begin
  if MIECHO <> 11 then Exit;
  WriteLn('JESTES W POKOJU PROWADZACYM DO KLATEK');
  WriteLn('DRZWI POD TOBA SIE ZATRZASNELY I NIE MASZ ODWROTU');
  WriteLn('WE WSZYSTKICH KIERUNKACH SA KLATKI I UJADAJACE SIE W NICH POTWORY');
  WriteLn('NO A POZA TYM NA SCIANIE JEST!!! PLAKAT!!!!');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    KOMENDY; { img 0x11345 -> 0x1BB07 }
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('WSCHOD-KLATKA CIENIASA');
      WriteLn('ZACHOD-KLATKA SILNEGO');
      WriteLn('POLNOC-KLATKA ZRECZNEGO');
      WriteLn('POLODNIE-KLATKA ODPORNEGO');
      WriteLn('GORA-KLATKA SILNEGO,ODPORNEGO I ZRECZNEGO ');
      WriteLn('DOL-JEDYNA DROGA NIE PROWADZACA DO KLATEK');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'WSCHOD' then MIECHO := 12;
    if wpisz = 'ZACHOD' then MIECHO := 13;
    if wpisz = 'POLNOC' then MIECHO := 14;
    if wpisz = 'POLODNIE' then MIECHO := 15;
    if wpisz = 'GORA' then MIECHO := 16;
    if wpisz = 'DOL' then MIECHO := 17;
    if wpisz = 'PATRZ PLAKAT' then begin
      WriteLn('NA PLAKACIE PISZE:');
      WriteLn('W KLATKACH SA POTWORKI - ZABIJ JE! KOMEDA : ZABIJ [COS] - ZABIJA ');
      WriteLn('CZASAMI COS WYPADNIE Z POTWORKA MOZE CI SIE TO PRZYDAC');
    end;
  until MIECHO <> 11;

end;
procedure POKOJ30; { img 0x11638..0x117DE }
begin
  if MIECHO <> 30 then Exit;
  WriteLn('ULICA DLUGA CIAGNIE SIE W NIESKONCZONOSC,SORKI');
  WriteLn('NA POLNOCY ZNAJDUJESZ OGROMNA BUDOWLE=TO ARENA PRZEZNACZONA DO WALKI');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('WSCHOD-CENTRUM MIASTA');
      WriteLn('ZACHOD-ULICA DLUGA');
      WriteLn('POLNOC-WEJSCIE NA ARENE');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'WSCHOD' then MIECHO := 20;
    if wpisz = 'ZACHOD' then MIECHO := 31;
    if wpisz = 'POLNOC' then MIECHO := 32;
  until MIECHO <> 30;

end;
procedure POKOJ60; { img 0x118FE..0x11A8C }
begin
  if MIECHO <> 60 then Exit;
  WriteLn('JESTES W DOLINIE ROZRYWEK DOLINA CIAGNIE SIE NA POLNOC, NA WSCHODZIE');
  WriteLn('JEST SLYSZALNY JAKIS DZIWNY  HALAS , NA ZACHODZIE ZAS "LA LA LA LA" ');
  WriteLn('ZAWSZE MOZESZ WROCIC SIE IDAC NA POLODNIE ;)');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('POLODNIE-ULICA DLUGA');
      WriteLn('WSCHOD-BUDOWLA PELNA HALASU');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'POLODNIE' then MIECHO := 31;
    if wpisz = 'WSCHOD' then MIECHO := 61;
  until MIECHO <> 60;

end;
procedure POKOJ75; { img 0x11BDC..0x11D9E }
begin
  if MIECHO <> 75 then Exit;
  WriteLn('JESTES NA ULICY CIEMNEJ , WLASCIWIE NARAZIE NIE JEST TU JESZCZE TAK CIEMNO ');
  WriteLn('TA ULICA WYGLADA NA REMONTOWAN'#164' , NA POLNOC WIDZISZ JAKIS BAR ');
  WriteLn('NA POLODNIE PRZEBIEGAJA CIE DRESZCZE , JEST TAM NAPRAWDE CIEMNO');
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('ZACHOD-CENTRUM MIASTA');
      WriteLn('POLNOC-BAR POD DWOMA PEDALAMI');
      WriteLn('POLODNIE-BLUSZCZ');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'ZACHOD' then MIECHO := 20;
    if wpisz = 'POLNOC' then MIECHO := 76;
    if wpisz = 'POLODNIE' then MIECHO := 77;
  until MIECHO <> 75;

end;
procedure POKOJ83; { img 0x11ECA..0x12068 }
begin
  if MIECHO <> 83 then Exit;
  WriteLn('............................. PIERDUT...........PIERDUT......PIERDUT');
  WriteLn('DOPIERO TERAZ SIE ZORIENTOWALES ZE NA SRODKU STOI WIELKIE DRZEWO');
  WriteLn('HMMM ALE ZARAZ ... TE KRZAKI NA ZACHOD WYGLADAJA BARDZO PODEJRZANIE....');
  BLUSZCZ; { img 0x11F32 -> 0x13629 }
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    KOMENDY; { img 0x11F97 -> 0x1BB07 }
    FIGHTBLUSZCZ; { img 0x11F9C -> 0x1B5B7 }
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('POLNOC-BLUSZCZ');
      WriteLn('ZACHOD-PODEJRZANE KRZAKI');
    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'POLNOC' then MIECHO := 80;
    if wpisz = 'ZACHOD' then MIECHO := 84;
  until MIECHO <> 83;

end;
procedure POKOJ100; { img 0x12414..0x129C6; quest-master road }
begin
  if MIECHO <> 100 then Exit;
  WriteLn('ZNALAZLES SIE NA ROZJEZDZIE DROG , DROGI PILNUJE QUEST-MASTER ');
  WriteLn('QUEST-MASTER NIE POSCI CIE DALEJ DOPOKI NIE KUPISZ I ROZWIAZESZ QUESTA');
  ULSKLEPIKOWA; { img 0x12460 -> 0x155F2 }
  repeat
    Write(ENERGIA, '%.', KUNSZT, '>');
    ReadLn(wpisz);
    if wpisz = 'MODE' then MODE;
    if wpisz = 'EXIT' then begin
      WriteLn('DOSTEPNE WYJSCIA:');
      WriteLn('POLODNIE-UL.SKLEPIKOWA');
      WriteLn('WSCHOD-DROGA O KTOREJ MOZESZ POMAZYC ( BO JEST W PRODUKCJI !!! )');
      if PRZEPUSTKA = 0 then WriteLn('ZACHOD-DROGA ( ZABLOKOWANA PRZEZ QUEST-MASTERA)');
      if PRZEPUSTKA < 0 then WriteLn('ZACHOD-DROGA');
    end;
    if wpisz = 'LISTA' then begin
      WriteLn('LATWY QUEST      - 200');
      WriteLn('PRZECIETNY QUEST - 100');
      WriteLn('TRUDNY QUEST     - 50');
      WriteLn('KOMEDA - SPRZEDAJ QUEST - OZNACZA IZ QUEST ZOSTAL WYKONANY');
    end;
    if (wpisz = 'KUP LATWY QUEST') and (FORSA > 199) then begin
      WriteLn('ZABIJ 75 POTWOROW');
      QUEST := 1;
      QUESTWYK := 75;
      FORSA := FORSA - 200;
    end;
    if (wpisz = 'KUP PRZECIETNY QUEST') and (FORSA > 99) then begin
      WriteLn('ZABIJ 50 POTWOROW W TYM LIROYA I DAJ MI DYPLOM MUD SZKOLY');
      QUEST := 2;
      QUESTWYK := 200;
      FORSA := FORSA - 100;
    end;
    if (wpisz = 'KUP TRUDNY QUEST') and (FORSA > 49) then begin
      WriteLn('ZABIJ 50 POTWOROW W TYM LIROYA I DAJ MI FAJKE I POSWIEC 1 PRAKTYKE');
      QUEST := 3;
      QUESTWYK := 200;
      FORSA := FORSA - 50;
    end;
    if (wpisz = 'SPRZEDAJ QUEST') and (QUEST > 0) then begin
      if (QUEST = 1) and (QUESTWYK < 1) then begin
        WriteLn('AAAAA BARDZO MI MILO ZE UDALO CI SIE WYKONAC TEN QUEST');
        WriteLn(' ------ OTRZYMUJESZ 100 KUNSZTU -----');
        KUNSZT := KUNSZT + 100;
        QUEST := 0;
        QUESTWYK := 0;
        PRZEPUSTKA := PRZEPUSTKA - 10;
        PRZED := PRZED + 1;
      end;
      if (QUEST = 2) and (QUESTWYK < 1) and (DYPLOM <= -10) then begin
        WriteLn('AAAAA BARDZO MI MILO ZE UDALO CI SIE WYKONAC TEN QUEST');
        WriteLn(' ------ OTRZYMUJESZ 250 KUNSZTU -----');
        KUNSZT := KUNSZT + 250;
        QUEST := 0;
        QUESTWYK := 0;
        DYPLOM := 0;
        MONSTRA.MAXE := MONSTRA.MAXE - 5;
        PRZEPUSTKA := PRZEPUSTKA - 10;
      end;
      if (QUEST = 3) and (QUESTWYK < 1) and (FAJKA <= -10) and (PRA > 0) then begin
        WriteLn('AAAAA BARDZO MI MILO ZE UDALO CI SIE WYKONAC TEN QUEST');
        WriteLn(' ------ OTRZYMUJESZ 425 KUNSZTU -----');
        KUNSZT := KUNSZT + 425;
        PRZED := PRZED - 1;
        MAD := MAD - 1;
        QUEST := 0;
        QUESTWYK := 0;
        FAJKA := FAJKA + 10;
        PRA := PRA - 1;
        PRZEPUSTKA := PRZEPUSTKA - 10;
      end;

    end;
    if wpisz = 'WYJSCIE' then Exit;
    if wpisz = 'POLODNIE' then MIECHO := 22;
    if (wpisz = 'ZACHOD') and (PRZEPUSTKA <= -10) then MIECHO := 101;
if (wpisz = 'ZACHOD') and (PRZEPUSTKA = 0) then WriteLn('QUEST-MASTER MOWI CI : BARDZO MI PRZYKRO ALE MUSISZ MIEC PRZEPUSTKE');
    if wpisz = 'ZABIJ QUEST-MASTER' then begin
      POISON := 10; { DGROUP $25F, img 0x1297F }
      FIREBALL := 20; { DGROUP $25E, img 0x12984 }
      WROGSIL := 10;
      WROGZRE := 26;
      WROGEN := 188;
      WALKA;
      if WROGEN < 1 then PRZEPUSTKA := PRZEPUSTKA - 10;
    end;
  until MIECHO <> 100;

end;
end.
