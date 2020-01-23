page 90000 "Data Migration List"
{
    PageType = Worksheet;
    ApplicationArea = All;
    UsageCategory = Administration;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    SourceTable = "Data Migration Buffer";
    CaptionML = DEU = 'Datenmigration Übersicht',
                ENU = 'Data Migration List';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Company Name"; "Company Name")
                {
                    ApplicationArea = All;
                }
                field("Table ID"; "Table ID")
                {
                    ApplicationArea = All;
                }
                field("Field No."; "Field No.")
                {
                    ApplicationArea = All;
                }
                field("Record ID"; Format("Record ID"))
                {
                    ApplicationArea = All;
                }
                field("Data Type"; "Data Type")
                {
                    ApplicationArea = All;
                }
                field(FieldValueCtrl; FieldValue)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        strmIn: InStream;
    begin
        Clear(FieldValue);
        CalcFields("Field Value");
        if ("Field Value".HasValue()) then begin
            "Field Value".CreateInStream(strmIn);
            strmIn.Read(FieldValue);
        end;
    end;

    var
        FieldValue: Text;
}