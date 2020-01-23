table 90000 "Data Migration Buffer"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Table ID"; Integer)
        {
            DataClassification = SystemMetadata;
            Caption = 'Table ID';
        }
        field(2; "Field No."; Integer)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field No.';
        }
        field(3; "Record ID"; RecordId)
        {
            DataClassification = SystemMetadata;
            Caption = 'Record ID';
        }
        field(4; "Company Name"; Text[80])
        {
            DataClassification = SystemMetadata;
            Caption = 'Company Name';
        }
        field(5; "Data Type"; Text[30])
        {
            DataClassification = SystemMetadata;
            Caption = 'Data Type';
        }
        field(10; "Field Value"; Blob)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(20; "Field Value as Text"; Text[250])
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(21; "Field Value as Integer"; Integer)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(22; "Field Value as Decimal"; Decimal)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(23; "Field Value as Date"; Date)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(24; "Field Value as Time"; Time)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(25; "Field Value as DateTime"; DateTime)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(26; "Field Value as DateFormula"; DateFormula)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(27; "Field Value as Guid"; Guid)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
        field(28; "Field Value as Boolean"; Boolean)
        {
            DataClassification = SystemMetadata;
            Caption = 'Field Value';
        }
    }

    keys
    {
        key(PK; "Table ID", "Field No.", "Record ID", "Company Name")
        {
            Clustered = true;
        }
    }

    procedure InsertValue(companyName: Text[80]; fieldNo: Integer; recId: RecordId; fieldValue: Variant)
    var
        sourceFld: Record Field;
        handled: Boolean;
    begin
        Init();
        "Table ID" := recId.TableNo();
        "Field No." := fieldNo;
        "Record ID" := recId;
        "Company Name" := companyName;

        if (not sourceFld.Get("Table ID", "Field No.")) then
            Error(UnknownFieldNoGivvenErr, "Field No.", "Table ID");
        "Data Type" := sourceFld."Type Name";

        OnBeforeAssignValueToBuffer(Rec, fieldValue, handled);
        if (not handled) then
            case Format(sourceFld."Type") of
                'Boolean':
                    "Field Value as Boolean" := fieldValue;
                'Code',
                'Text':
                    "Field Value as Text" := fieldValue;
                'Option':
                    "Field Value as Text" := Format(fieldValue);
                'Date':
                    "Field Value as Date" := fieldValue;
                'Time':
                    "Field Value as Time" := fieldValue;
                'DateTime':
                    "Field Value as DateTime" := fieldValue;
                'Decimal':
                    "Field Value as Decimal" := fieldValue;
                'Integer':
                    "Field Value as Integer" := fieldValue;
                'GUID':
                    "Field Value as Guid" := fieldValue;
                'DateFormula':
                    "Field Value as DateFormula" := fieldValue;
                else
                    if not WriteToStream(fieldValue) then
                        Error(OutsidePermittedRangeErr, Format(recId), Format(fieldNo));
            end;
        OnAfterAssignValueToBuffer(Rec);

        if (FieldHasValue(Format(sourceFld."Type"))) then
            Insert(true);
    end;

    local procedure FieldHasValue(fldType: Text): Boolean
    begin
        case Format(fldType) of
            'Boolean':
                exit("Field Value as Boolean");
            'Code',
            'Text',
            'Option':
                exit("Field Value as Text" <> '');
            'Date':
                exit("Field Value as Date" <> 0D);
            'Time':
                exit("Field Value as Time" <> 0T);
            'DateTime':
                exit("Field Value as DateTime" <> 0DT);
            'Decimal':
                exit("Field Value as Decimal" <> 0);
            'Integer':
                exit("Field Value as Integer" <> 0);
            'GUID':
                exit(true);
            'DateFormula':
                exit(Format("Field Value as DateFormula") <> '');
            else
                exit("Field Value".HasValue());
        end;
    end;

    local procedure WriteToStream(var fieldValue: Variant): Boolean
    var
        strmOut: OutStream;
    begin
        "Field Value".CreateOutStream(strmOut);
        strmOut.Write(Format(fieldValue));

        exit(true);
    end;

    procedure GetValue(var recRef: RecordRef; var fldRef: FieldRef)
    var
        targetFld: Record Field;
        handled: Boolean;
    begin
        OnBeforeGetValueFromBuffer(Rec, recRef, fldRef, handled);
        if (handled) then
            exit;

        if (not targetFld.Get(recRef.Number(), fldRef.Number())) then
            exit;

        case Format(targetFld."Type") of
            'Boolean':
                fldRef.Value("Field Value as Boolean");
            'Code',
            'Text':
                fldRef.Value("Field Value as Text");
            'Option':
                AssignOptionValue(fldRef, "Field Value as Text");
            'Date':
                fldRef.Value("Field Value as Date");
            'Time':
                fldRef.Value("Field Value as Time");
            'DateTime':
                fldRef.Value("Field Value as DateTime");
            'Decimal':
                fldRef.Value("Field Value as Decimal");
            'Integer':
                fldRef.Value("Field Value as Integer");
            'GUID':
                fldRef.Value("Field Value as Guid");
            'DateFormula':
                fldRef.Value("Field Value as DateFormula");
        end;
        OnAfterGetValueFromBuffer(Rec, fldRef);
    end;

    local procedure AssignOptionValue(var fldRef: FieldRef; optionValueAsText: Text)
    var
        optionValueAsInt: Integer;
        noOfOptions: Integer;
        optionString: Text;
    begin
        if (optionValueAsText = '') then
            fldRef.VALUE := 0
        else begin
            optionString := fldRef.OptionCaption();
            noOfOptions := 1;
            while (STRPOS(optionString, ',') <> 0) do begin
                noOfOptions += 1;
                optionString := DELSTR(optionString, 1, STRPOS(optionString, ','));
            end;
            optionString := fldRef.OptionCaption();

            optionValueAsInt := 1;
            while ((optionValueAsInt <= noOfOptions) AND (SELECTSTR(optionValueAsInt, optionString) <> optionValueAsText)) do
                optionValueAsInt += 1;
            optionValueAsInt -= 1; // optionstring starts with 1, option values starts with 0

            fldRef.VALUE := optionValueAsInt;
        END;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeAssignValueToBuffer(var DataMigrationBuffer: Record "Data Migration Buffer"; var FieldValue: Variant; var Handled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterAssignValueToBuffer(var DataMigrationBuffer: Record "Data Migration Buffer")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeGetValueFromBuffer(var DataMigrationBuffer: Record "Data Migration Buffer"; var recRef: RecordRef; var fldRef: FieldRef; var Handled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterGetValueFromBuffer(var DataMigrationBuffer: Record "Data Migration Buffer"; var fldRef: FieldRef)
    begin
    end;

    var
        UnsupportedDataTypeForBufferErr: Label 'Data type for value "%1" could not be detected.\Table ID: %2, Field No.: %3';
        UnknownFieldNoGivvenErr: Label 'The givven field no. %1 is not found in table id %2.';

        OutsidePermittedRangeErr: Label 'A value is outside the permitted range.\Table ID: %1, FieldNo.: %2';

}