codeunit 90001 "Data Migration Restore"
{

    trigger OnRun()
    begin
        RestoreDataForCompany();
    end;

    /// <summary>
    /// This procedure is the main procedure for restore data process.
    /// </summary>
    procedure RestoreData()
    var
        company: Record Company;
        session: Record "Active Session";
        progressModeOptions: Option Serial,Parallel;
        selectedProgressMode: Integer;
        backgroundSessionIdFilter: Text;
        currBackgroundSessionId: Integer;
        backgroundSessionStarted: Boolean;
        startingDateTime: DateTime;
    begin
        selectedProgressMode := StrMenu(ProgressModeMsg, 1, ProgressModeInstrMsg);
        startingDateTime := CurrentDateTime();

        Dlg.Open('#1####\' +
                 company.TableCaption() + ' #2####\' +
                 '#3####');

        company.Reset();
        if (company.FindSet(false)) then
            repeat
                backgroundSessionStarted := false;
                currBackgroundSessionId := 0;

                Dlg.Update(1, StartingBackgroundSessionsTxt);
                Dlg.Update(2, company.Name);
                Dlg.Update(3, StrSubstNo(LastHeartBeatMsg, Time()));

                DataMigrationBuffer.Reset();
                DataMigrationBuffer.ChangeCompany(company.Name);
                if (not DataMigrationBuffer.IsEmpty()) then
                    backgroundSessionStarted := StartSession(currBackgroundSessionId, Codeunit::"Data Migration Restore", company.Name);

                Dlg.Update(1, BackgroundSessionStartedTxt);
                Dlg.Update(3, StrSubstNo(LastHeartBeatMsg, Time()));

                if ((selectedProgressMode - 1) = progressModeOptions::Serial) then begin
                    session.Reset();
                    session.SetRange("Session ID", currBackgroundSessionId);
                    session.SetRange("User SID", UserSecurityId());
                    if (session.IsEmpty()) then
                        Error(SessionCouldNotBeIdentifiedErr, currBackgroundSessionId, company.Name);
                    while (not session.IsEmpty()) do begin
                        Dlg.Update(1, WaitingForSessionsTxt);
                        Dlg.Update(3, StrSubstNo(LastHeartBeatMsg, Time()));

                        Sleep(1000); // wait for finish restore of company data
                        SelectLatestVersion();
                    end;
                end else
                    if (backgroundSessionIdFilter = '') then
                        backgroundSessionIdFilter := Format(currBackgroundSessionId)
                    else
                        backgroundSessionIdFilter += '|' + Format(currBackgroundSessionId);
            until company.Next() = 0;

        if ((selectedProgressMode - 1) = progressModeOptions::Parallel) then begin
            Dlg.Update(2, '');

            if (backgroundSessionIdFilter = '') then
                Message(ProcessingFinishedTxt) // should never happen...
            else begin
                session.Reset();
                session.SetFilter("Session ID", backgroundSessionIdFilter);
                session.SetRange("User SID", UserSecurityId());
                while (not session.IsEmpty()) do begin
                    Sleep(1000);
                    SelectLatestVersion();

                    Dlg.Update(1, WaitingForBackgroundSessionsTxt);
                    Dlg.Update(3, StrSubstNo(LastHeartBeatMsg, Time()));
                end;
            end;
        end;
        Dlg.Update(1, FinishedTxt);
        Dlg.Update(3, StrSubstNo(LastHeartBeatMsg, Time()));
        Dlg.Close();

        Message(OverallTimeElapsedMsg, (CurrentDateTime() - startingDateTime));
    end;

    /// <summary>
    /// Restore data for specific company.
    /// </summary>
    procedure RestoreDataForCompany()
    var
        dataMigrationBufferCurrRecord: Record "Data Migration Buffer";
        dataMigrationBufferDelete: Record "Data Migration Buffer";
        allObj: Record AllObj;
        fld: Record Field;
        recRef: RecordRef;
        fldRef: FieldRef;
        fldValue: Variant;
        handled: Boolean;
        insertMode: Boolean;
        recordChanged: Boolean;
    begin
        DataMigrationBuffer.Reset();
        DataMigrationBuffer.SetRange("Company Name", CompanyName());
        if (DataMigrationBuffer.FindFirst()) then
            repeat
                dataMigrationBufferCurrRecord.Reset();
                dataMigrationBufferCurrRecord.SetRange("Record ID", DataMigrationBuffer."Record ID");
                dataMigrationBufferCurrRecord.SetRange("Company Name", DataMigrationBuffer."Company Name");
                OnAfterDataMigrationBufferFilterSet(dataMigrationBufferCurrRecord, DataMigrationBuffer."Table ID", DataMigrationBuffer."Company Name");
                if (allObj.Get(allObj."Object Type"::Table, DataMigrationBuffer."Table ID")) then begin
                    recRef.Open(DataMigrationBuffer."Table ID",
                        false,
                        DataMigrationBuffer."Company Name");
                    if (not recRef.Get(DataMigrationBuffer."Record ID")) then begin
                        recRef.Init();

                        insertMode := true;
                    end else
                        insertMode := false;

                    recordChanged := false;

                    // loop through all fields in current record
                    dataMigrationBufferCurrRecord.Find('-');
                    repeat
                        OnBeforeRestoreDataToFieldNo(dataMigrationBufferCurrRecord, dataMigrationBufferCurrRecord."Field No.");
                        if (fld.Get(dataMigrationBufferCurrRecord."Table ID", dataMigrationBufferCurrRecord."Field No.")) then begin
                            fldRef := recRef.Field(dataMigrationBufferCurrRecord."Field No.");
                            fldValue := fldRef.Value();

                            OnBeforeRestoreDataToTable(dataMigrationBufferCurrRecord, handled);
                            if (not handled) then
                                dataMigrationBufferCurrRecord.GetValue(recRef, fldRef);

                            if (Format(fldValue) <> Format(fldRef.Value())) then
                                recordChanged := true;
                        end;
                    until dataMigrationBufferCurrRecord.Next() = 0;

                    if (recordChanged) then
                        if (insertMode) then
                            recRef.Insert(false)
                        else
                            recRef.Modify(false);
                    recRef.Close();
                end else
                    OnRestoreTableNotExist(dataMigrationBufferCurrRecord);

                dataMigrationBufferDelete.CopyFilters(dataMigrationBufferCurrRecord);
                dataMigrationBufferDelete.DeleteAll(true);

            until (not DataMigrationBuffer.FindFirst())
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterDataMigrationBufferFilterSet(var DataMigrationBuffer: Record "Data Migration Buffer"; TableId: Integer; CompanyName: Text[80])
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnRestoreTableNotExist(var DataMigrationBuffer: Record "Data Migration Buffer")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRestoreDataToFieldNo(DataMigrationBuffer: Record "Data Migration Buffer"; var FieldNo: Integer)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeRestoreDataToTable(var DataMigrationBuffer: Record "Data Migration Buffer"; Handled: Boolean)
    begin
    end;

    var
        DataMigrationBuffer: Record "Data Migration Buffer";
        StartingBackgroundSessionsTxt: Label 'Starting background session. . .';
        BackgroundSessionStartedTxt: Label 'Background session has been started.';
        WaitingForSessionsTxt: Label 'Waiting for finishing session progress . . .';
        WaitingForBackgroundSessionsTxt: Label 'Waiting for finishing background sessions . . .';
        FinishedTxt: Label 'Finished.';
        ProcessingFinishedTxt: Label 'Processing finished. Maybe several background worker are still in progress.';
        ProgressModeInstrMsg: Label 'Please select the progress method:';
        ProgressModeMsg: Label 'Seriel,Parallel';
        SessionCouldNotBeIdentifiedErr: Label 'Requested session with ID %1 could not be found. The process for company %2 failed!';
        OverallTimeElapsedMsg: Label 'Process completed.\Time elapsed: %1.';
        LastHeartBeatMsg: Label 'Heartbeat: %1';
        Dlg: Dialog;
}