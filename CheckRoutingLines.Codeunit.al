codeunit 99000752 "Check Routing Lines"
{

    trigger OnRun()
    begin
    end;

    var
        Text000: Label 'Circular reference in routing %1 when calculating %2. Counted sequences %3. Max. lines %4.';
        Text001: Label 'back';
        Text002: Label 'Actual number of termination processes in route %1 is %2. They should be 1. Check %3.';
        Text003: Label 'Actual number of start processes in route %1 is %2. They should be 1. Check %3.';
        Text004: Label 'Not all routing lines are sequenced backwards on routing %1. Check %2.';
        Text005: Label 'Not all routing lines are sequenced forward on routing %1. Check %2.';
        Text006: Label 'Previous operations for %1 cannot be found.';
        Text007: Label 'Next operations for %1 cannot be found.';
        UOMMgt: Codeunit "Unit of Measure Management";
        ErrList: Text[50];
        Text008: Label 'Operation %1 does not have a work center or a machine center defined.';

    local procedure ErrorInRouting(RoutingCode: Code[20]; Direction: Text[20]; ActualSequence: Integer; MaxSequences: Integer)
    begin
        Error(
          Text000,
          RoutingCode,
          Direction,
          ActualSequence,
          MaxSequences);
    end;

    local procedure InsertInErrList(RtngLine: Record "Routing Line")
    begin
        if (StrLen(ErrList) + StrLen(RtngLine."Operation No.") + 1) > MaxStrLen(ErrList) then
            exit;

        if StrLen(ErrList) > 0 then
            ErrList := ErrList + ',' + RtngLine."Operation No."
        else
            ErrList := RtngLine."Operation No.";
    end;

    procedure SetNextOperations(RtngHeader: Record "Routing Header"; VersionCode: Code[20])
    var
        RtngLine: Record "Routing Line";
        RtngLine2: Record "Routing Line";
    begin
        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        RtngLine.ModifyAll("Next Operation No.", '');

        if RtngLine.Find('-') then
            repeat
                RtngLine2 := RtngLine;
                RtngLine2.SetRange("Routing No.", RtngHeader."No.");
                RtngLine2.SetRange("Version Code", VersionCode);
                if RtngLine2.Find('>') then begin
                    RtngLine."Next Operation No." := RtngLine2."Operation No.";
                    RtngLine.Modify;
                end;
            until RtngLine.Next = 0;
    end;

    local procedure CalcPreviousOperations(RtngHeader: Record "Routing Header"; VersionCode: Code[20])
    var
        RtngLine: Record "Routing Line";
        RtngLine2: Record "Routing Line";
    begin
        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        RtngLine.ModifyAll("Previous Operation No.", '');

        if RtngLine.Find('-') then
            repeat
                if RtngLine."Next Operation No." <> '' then begin
                    RtngLine2.SetRange("Routing No.", RtngHeader."No.");
                    RtngLine2.SetRange("Version Code", VersionCode);
                    RtngLine2.SetFilter("Operation No.", RtngLine."Next Operation No.");
                    if RtngLine2.Find('-') then
                        repeat
                            if RtngLine2."Previous Operation No." <> '' then
                                RtngLine2."Previous Operation No." :=
                                  RtngLine2."Previous Operation No." + '|';
                            RtngLine2."Previous Operation No." :=
                              RtngLine2."Previous Operation No." +
                              RtngLine."Operation No.";
                            RtngLine2.Modify;
                        until RtngLine2.Next = 0;
                end;
            until RtngLine.Next = 0;
    end;

    local procedure CheckCircularReference(ActSequences: Integer; MaxSequences: Integer; RoutingNo: Code[20])
    begin
        if ActSequences > MaxSequences then
            ErrorInRouting(
              RoutingNo,
              Text001,
              ActSequences,
              MaxSequences);
    end;

    local procedure SetRtngLineSequenceBack(RoutingType: Option Serial,Parallel; RoutingNo: Code[20]; VersionCode: Code[20]; Maxsequences: Integer)
    var
        RoutingLine: Record "Routing Line";
        SequenceNo: Integer;
        LinesFound: Boolean;
    begin
        SequenceNo := 1;
        if RoutingType = RoutingType::Parallel then begin
            SetTerminalOperationSequenceNo(RoutingNo, VersionCode);
            RoutingLine.SetRange("Routing No.", RoutingNo);
            RoutingLine.SetRange("Version Code", VersionCode);
            repeat
                RoutingLine.SetRange("Sequence No. (Backward)", SequenceNo);
                LinesFound := RoutingLine.FindSet;
                if LinesFound then begin
                    CheckCircularReference(SequenceNo, Maxsequences, RoutingNo);
                    SequenceNo += 1;
                    repeat
                        if RoutingLine."Previous Operation No." <> '' then
                            SetSequenceNoOnPreviousOperations(RoutingNo, VersionCode, RoutingLine."Previous Operation No.", SequenceNo);
                    until (RoutingLine.Next = 0) or (RoutingLine."Previous Operation No." = '');
                end;
            until not LinesFound or (RoutingLine."Previous Operation No." = '');
        end else begin
            RoutingLine.SetRange("Routing No.", RoutingNo);
            RoutingLine.SetRange("Version Code", VersionCode);
            if RoutingLine.Find('+') then
                repeat
                    RoutingLine."Sequence No. (Backward)" := SequenceNo;
                    RoutingLine.Modify;
                    SequenceNo += 1;
                until RoutingLine.Next(-1) = 0;
        end;
    end;

    procedure SetRtngLineSequenceForward(RoutingType: Option Serial,Parallel; RoutingNo: Code[20]; VersionCode: Code[20]; MaxSequences: Integer)
    var
        RoutingLine: Record "Routing Line";
        SequenceNo: Integer;
        LinesFound: Boolean;
    begin
        SequenceNo := 1;
        if RoutingType = RoutingType::Parallel then begin
            SetStartingOperationSequenceNo(RoutingNo, VersionCode);
            RoutingLine.SetRange("Routing No.", RoutingNo);
            RoutingLine.SetRange("Version Code", VersionCode);
            repeat
                RoutingLine.SetRange("Sequence No. (Forward)", SequenceNo);
                LinesFound := RoutingLine.FindSet;
                if LinesFound then begin
                    CheckCircularReference(SequenceNo, MaxSequences, RoutingNo);
                    SequenceNo += 1;
                    repeat
                        if RoutingLine."Next Operation No." <> '' then
                            SetSequenceNoOnNextOperations(RoutingNo, VersionCode, RoutingLine."Next Operation No.", SequenceNo);
                    until (RoutingLine.Next = 0) or (RoutingLine."Next Operation No." = '');
                end;
            until not LinesFound or (RoutingLine."Next Operation No." = '');
        end else begin
            RoutingLine.SetRange("Routing No.", RoutingNo);
            RoutingLine.SetRange("Version Code", VersionCode);
            if RoutingLine.Find('-') then
                repeat
                    RoutingLine."Sequence No. (Forward)" := SequenceNo;
                    RoutingLine.Modify;
                    SequenceNo += 1;
                until RoutingLine.Next = 0;
        end;
    end;

    local procedure SetStartingOperationSequenceNo(RoutingNo: Code[20]; VersionCode: Code[20])
    var
        RoutingLine: Record "Routing Line";
    begin
        RoutingLine.SetRange("Routing No.", RoutingNo);
        RoutingLine.SetRange("Version Code", VersionCode);
        RoutingLine.SetFilter("Previous Operation No.", '%1', '');
        RoutingLine.FindFirst;
        RoutingLine."Sequence No. (Forward)" := 1;
        RoutingLine.Modify;
    end;

    local procedure SetTerminalOperationSequenceNo(RoutingNo: Code[20]; VersionCode: Code[20])
    var
        RoutingLine: Record "Routing Line";
    begin
        RoutingLine.SetRange("Routing No.", RoutingNo);
        RoutingLine.SetRange("Version Code", VersionCode);
        RoutingLine.SetFilter("Next Operation No.", '%1', '');
        RoutingLine.FindFirst;
        RoutingLine."Sequence No. (Backward)" := 1;
        RoutingLine.Modify;
    end;

    local procedure SetSequenceNoOnNextOperations(RoutingNo: Code[20]; VersionCode: Code[20]; NextOperationFilter: Text; SequenceNo: Integer)
    var
        RoutingLine: Record "Routing Line";
    begin
        RoutingLine.SetRange("Routing No.", RoutingNo);
        RoutingLine.SetRange("Version Code", VersionCode);
        RoutingLine.SetFilter("Operation No.", NextOperationFilter);
        RoutingLine.ModifyAll("Sequence No. (Forward)", SequenceNo);
    end;

    local procedure SetSequenceNoOnPreviousOperations(RoutingNo: Code[20]; VersionCode: Code[20]; PreviousOperationFilter: Text; SequenceNo: Integer)
    var
        RoutingLine: Record "Routing Line";
    begin
        RoutingLine.SetRange("Routing No.", RoutingNo);
        RoutingLine.SetRange("Version Code", VersionCode);
        RoutingLine.SetFilter("Operation No.", PreviousOperationFilter);
        RoutingLine.ModifyAll("Sequence No. (Backward)", SequenceNo);
    end;

    local procedure CalcSequenceBack(RtngHeader: Record "Routing Header"; VersionCode: Code[20])
    var
        RtngLine: Record "Routing Line";
        MaxSeq: Integer;
    begin
        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        if RtngLine.Find('-') then
            repeat
                RtngLine."Sequence No. (Backward)" := 0;
                RtngLine."Fixed Scrap Qty. (Accum.)" := 0;
                RtngLine."Scrap Factor % (Accumulated)" := 0;
                RtngLine.Modify;
            until RtngLine.Next = 0;

        MaxSeq := RtngLine.Count;

        SetRtngLineSequenceBack(RtngHeader.Type, RtngHeader."No.", VersionCode, MaxSeq);
    end;

    local procedure CalcSequenceForward(RtngHeader: Record "Routing Header"; VersionCode: Code[20])
    var
        RtngLine: Record "Routing Line";
        MaxSeq: Integer;
    begin
        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        RtngLine.ModifyAll("Sequence No. (Forward)", 0);

        MaxSeq := RtngLine.Count;

        SetRtngLineSequenceForward(RtngHeader.Type, RtngHeader."No.", VersionCode, MaxSeq);
    end;

    procedure NeedsCalculation(RtngHeader: Record "Routing Header"; VersionCode: Code[20]): Boolean
    var
        RtngLine: Record "Routing Line";
    begin
        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        RtngLine.SetRange(Recalculate, true);
        exit(RtngLine.FindFirst);
    end;

    procedure Calculate(RtngHeader: Record "Routing Header"; VersionCode: Code[20])
    var
        RtngVersion: Record "Routing Version";
        RtngLine: Record "Routing Line";
        RtngLine2: Record "Routing Line";
        CalcScrapFactor: Decimal;
        CalcScrapQty: Decimal;
        ScrapFactorThis: Decimal;
        ScrapQtyThis: Decimal;
    begin
        RtngLine.SetCurrentKey("Routing No.", "Version Code", "Sequence No. (Backward)");
        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        if RtngLine.IsEmpty then
            exit;

        if VersionCode <> '' then begin
            RtngVersion.Get(RtngHeader."No.", VersionCode);
            RtngHeader.Type := RtngVersion.Type;
        end;

        if RtngHeader.Type = RtngHeader.Type::Serial then
            SetNextOperations(RtngHeader, VersionCode);

        CalcPreviousOperations(RtngHeader, VersionCode);
        CalcSequenceBack(RtngHeader, VersionCode);
        CalcSequenceForward(RtngHeader, VersionCode);

        OnBeforeFindRoutingLines(RtngHeader, VersionCode);

        if RtngLine.Find('-') then
            repeat
                if RtngLine."Next Operation No." <> '' then begin
                    RtngLine2.SetRange("Routing No.", RtngLine."Routing No.");
                    RtngLine2.SetRange("Version Code", VersionCode);
                    RtngLine2.SetFilter("Operation No.", RtngLine."Next Operation No.");
                    CalcScrapFactor := 0;
                    CalcScrapQty := 0;
                    if RtngLine2.Find('-') then
                        repeat
                            ScrapFactorThis :=
                              RtngLine2."Scrap Factor % (Accumulated)";
                            ScrapQtyThis := Round(RtngLine2."Fixed Scrap Qty. (Accum.)", UOMMgt.QtyRndPrecision);
                            if CalcScrapFactor < ScrapFactorThis then
                                CalcScrapFactor := ScrapFactorThis;
                            if CalcScrapQty < ScrapQtyThis then
                                CalcScrapQty := ScrapQtyThis;
                        until RtngLine2.Next = 0;
                end;
                if CalcScrapFactor <> 0 then begin
                    if RtngLine."Scrap Factor %" <> 0 then
                        CalcScrapFactor :=
                          Round(
                            (1 + CalcScrapFactor) *
                            (1 + RtngLine."Scrap Factor %" / 100), 0.00001) - 1;
                end else
                    CalcScrapFactor :=
                      Round(1 + RtngLine."Scrap Factor %" / 100, 0.00001) - 1;
                CalcScrapQty := CalcScrapQty * (1 + RtngLine."Scrap Factor %" / 100) + RtngLine."Fixed Scrap Quantity";
                OnCalculateOnAfterCalcScrapQtyAndFactor(RtngLine, CalcScrapQty, CalcScrapFactor);
                RtngLine."Fixed Scrap Qty. (Accum.)" := CalcScrapQty;
                RtngLine."Scrap Factor % (Accumulated)" := CalcScrapFactor;
                RtngLine.Modify;
            until RtngLine.Next = 0;

        RtngLine.ModifyAll(Recalculate, false);
        Check(RtngHeader, VersionCode);
    end;

    local procedure Check(RtngHeader: Record "Routing Header"; VersionCode: Code[20])
    var
        RtngLine: Record "Routing Line";
        RtngLine2: Record "Routing Line";
        NoOfProcesses: Integer;
    begin
        ErrList := '';

        RtngLine.SetRange("Routing No.", RtngHeader."No.");
        RtngLine.SetRange("Version Code", VersionCode);
        RtngLine.SetRange("No.", '');
        if RtngLine.FindFirst then
            Error(Text008, RtngLine."Operation No.");
        RtngLine.SetRange("No.");

        RtngLine.SetFilter("Next Operation No.", '%1', '');

        NoOfProcesses := RtngLine.Count;
        if NoOfProcesses <> 1 then begin
            repeat
                InsertInErrList(RtngLine);
            until RtngLine.Next = 0;
            Error(
              Text002,
              RtngHeader."No.",
              NoOfProcesses,
              ErrList);
        end;

        RtngLine.SetFilter("Previous Operation No.", '%1', '');
        RtngLine.SetRange("Next Operation No.");
        NoOfProcesses := RtngLine.Count;
        if NoOfProcesses <> 1 then begin
            repeat
                InsertInErrList(RtngLine);
            until RtngLine.Next = 0;
            Error(
              Text003,
              RtngHeader."No.",
              NoOfProcesses,
              ErrList);
        end;
        RtngLine.SetRange("Previous Operation No.");

        RtngLine.SetRange("Sequence No. (Backward)", 0);
        if RtngLine.Find('-') then begin
            repeat
                InsertInErrList(RtngLine);
            until RtngLine.Next = 0;
            Error(
              Text004,
              RtngLine."Routing No.",
              ErrList);
        end;
        RtngLine.SetRange("Sequence No. (Backward)");

        RtngLine.SetRange("Sequence No. (Forward)", 0);
        if RtngLine.Find('-') then begin
            repeat
                InsertInErrList(RtngLine);
            until RtngLine.Next = 0;
            Error(
              Text005,
              RtngLine."Routing No.",
              ErrList);
        end;
        RtngLine.SetRange("Sequence No. (Forward)");

        RtngLine.SetCurrentKey("Routing No.", "Version Code", "Sequence No. (Backward)");
        RtngLine.SetFilter("Previous Operation No.", '<>%1', '');

        if RtngLine.Find('-') then
            repeat
                RtngLine2.SetRange("Routing No.", RtngLine."Routing No.");
                RtngLine2.SetRange("Version Code", VersionCode);
                RtngLine2.SetFilter("Operation No.", RtngLine."Previous Operation No.");
                if RtngLine2.IsEmpty then
                    Error(
                      Text006,
                      RtngLine."Routing No.");
            until RtngLine.Next = 0;

        RtngLine.SetCurrentKey("Routing No.", "Version Code", "Sequence No. (Forward)");
        RtngLine.SetFilter("Next Operation No.", '<>%1', '');
        RtngLine.SetRange("Operation No.");

        if RtngLine.Find('-') then
            repeat
                RtngLine2.SetRange("Routing No.", RtngLine."Routing No.");
                RtngLine2.SetRange("Version Code", VersionCode);
                RtngLine2.SetFilter("Operation No.", RtngLine."Next Operation No.");
                if RtngLine2.IsEmpty then
                    Error(
                      Text007,
                      RtngLine."Routing No.");
            until RtngLine.Next = 0;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeFindRoutingLines(var RoutingHeader: Record "Routing Header"; VersionCode: Code[20])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCalculateOnAfterCalcScrapQtyAndFactor(var RoutingLine: Record "Routing Line"; var ScrapQty: Decimal; var ScrapFactor: Decimal)
    begin
    end;
}

