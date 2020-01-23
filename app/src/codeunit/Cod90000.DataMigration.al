codeunit 90000 "Data Migration"
{

    trigger OnRun()
    begin
    end;

    /// <summary>
    /// This procedure is the main procedure for backup process.
    /// </summary>
    procedure BackupData()
    var
        startObjectId: Integer;
        endObjectId: Integer;
        startingDateTime: DateTime;
    begin
        startingDateTime := CurrentDateTime();

        Dlg.Open(ProgressDlgTxt);

        // backup additional fields to standard table objects.
        BackupStandardTables();

        // backup new tables in customer area.
        startObjectId := 50000;
        endObjectId := 99999;
        OnBeforeBackupCustomTables(startObjectId, endObjectId);
        BackupCustomTables(startObjectId, endObjectId);

        Dlg.Close();

        Message(OverallTimeElapsedMsg, (CurrentDateTime() - startingDateTime));
    end;

    /// <summary>
    /// Backup individual fields (field no. 50000..99999) from standard tables.
    /// </summary>
    local procedure BackupStandardTables()
    var
        company: Record Company;
        obj: Record AllObj;
        sourceFields: Record Field;
        sourceRecRef: RecordRef;
        sourceFldRef: FieldRef;
        cnt: Integer;
        pos: Integer;
    begin
        obj.Reset();
        obj.SetRange("Object Type", obj."Object Type"::Table);
        obj.SetFilter("Object ID", '<%1|>%2', 50000, 99999);
        if (obj.Find('-')) then
            repeat

                Dlg.Update(1, obj."Object Name");
                Dlg.Update(2, '');
                Dlg.Update(3, '');
                Dlg.Update(4, 0);

                sourceFields.Reset();
                sourceFields.SetRange(TableNo, obj."Object ID");
                sourceFields.SetRange(Enabled, true);
                sourceFields.SetRange(Class, sourceFields.Class::Normal);
                sourceFields.SetRange("No.", 50000, 99999);
                if (not sourceFields.IsEmpty()) then begin
                    company.FindSet(false);
                    repeat

                        Dlg.Update(2, company.Name);

                        sourceRecRef.Open(obj."Object ID", false, company.Name);
                        if (sourceRecRef.Find('-')) then begin
                            cnt := sourceRecRef.Count();
                            pos := 0;
                            repeat
                                pos += 1;
                                Dlg.Update(4, (pos * (9999 / cnt)) DIV 1);

                                if (sourceFields.FindSet(false)) then
                                    repeat
                                        Dlg.Update(3, sourceFields.FieldName);
                                        sourceFldRef := sourceRecRef.Field(sourceFields."No.");

                                        DataMigrationBuffer.ChangeCompany(company.Name);
                                        DataMigrationBuffer.InsertValue(company.Name, sourceFldRef.Number(), sourceRecRef.RecordId(), sourceFldRef.Value());
                                    until sourceFields.Next() = 0;
                            until sourceRecRef.Next() = 0;
                        end;
                        sourceRecRef.Close();
                    until company.Next() = 0;
                end;
            until obj.Next() = 0;
    end;

    /// <summary>
    /// Handling custom table backup in given ID range (standard 50000..99999).
    /// </summary>
    local procedure BackupCustomTables(fromObjectId: Integer; toObjectId: Integer)
    var
        obj: Record AllObj;
    begin
        obj.Reset();
        obj.SetRange("App Package ID", '{00000000-0000-0000-0000-000000000000}');
        obj.SetRange("Object Type", obj."Object Type"::Table);
        obj.SetRange("Object ID", fromObjectId, toObjectId);
        if (obj.FindSet(false)) then
            repeat
                if (obj."Object ID" <> Database::"Data Migration Buffer") then begin
                    Dlg.Update(1, obj."Object Name");
                    BackupCustomTableToBuffer(obj."Object ID", 0, 1); // all companies (0), move content (1)
                end;
            until obj.Next() = 0;
    end;

    /// <summary>
    /// Backup given custom table.
    /// </summary>
    local procedure BackupCustomTableToBuffer(fromTableId: Integer; companySelection: Option "All Companies","Current Company"; method: Option "Copy","Move")
    var
        company: Record Company;
        sourceFields: Record Field;
        sourceRecRef: RecordRef;
        sourceFldRef: FieldRef;
        cnt: Integer;
        pos: Integer;
    begin
        if (companySelection = companySelection::"Current Company") then
            company.SetRange(Name, CompanyName());
        if (not company.FindSet(false)) then
            exit;
        repeat
            sourceRecRef.Open(fromTableId, false, company.Name);

            Dlg.Update(2, company.Name);

            if (sourceRecRef.Find('-')) then begin
                cnt := sourceRecRef.Count();
                pos := 0;
                repeat
                    pos += 1;
                    Dlg.Update(4, (pos * (9999 / cnt)) DIV 1);

                    sourceFields.Reset();
                    sourceFields.SetRange(TableNo, sourceRecRef.Number());
                    sourceFields.SetRange(Enabled, true);
                    sourceFields.SetRange(Class, sourceFields.Class::Normal);
                    if (sourceFields.Find('-')) then
                        repeat
                            Dlg.Update(3, sourceFields.FieldName);
                            sourceFldRef := sourceRecRef.Field(sourceFields."No.");

                            DataMigrationBuffer.ChangeCompany(company.Name);
                            DataMigrationBuffer.InsertValue(company.Name, sourceFldRef.Number(), sourceRecRef.RecordId(), sourceFldRef.Value());
                        until sourceFields.Next() = 0;
                until sourceRecRef.Next() = 0;
            end;

            if (method = method::Move) then
                sourceRecRef.DeleteAll(false);

            sourceRecRef.Close();
        until company.Next() = 0;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeBackupCustomTables(var StartObjectId: Integer; var EndObjectId: Integer)
    begin
    end;

    var
        DataMigrationBuffer: Record "Data Migration Buffer";
        ProgressDlgTxt: Label 'Object #1####\Company #2####\Field #3####\@4@@@@';
        OverallTimeElapsedMsg: Label 'Process completed.\Time elapsed: %1.';
        Dlg: Dialog;
}