pageextension 90000 "Data Migration" extends "Company Information"
{
    actions
    {
        addlast("Application Settings")
        {
            group("Data Migration")
            {
                Caption = 'C/SIDE to AL Data Migration';
                Image = WorkflowSetup;

                action(DataMigrationList)
                {
                    Caption = 'Data Migration Buffer List';
                    Image = List;

                    trigger OnAction()
                    begin
                        Page.Run(Page::"Data Migration List");
                    end;
                }

                separator(separator1)
                { }

                action(BackupDataProcess)
                {
                    Caption = 'Step 1 - Backup Data';
                    Image = ItemSubstitution;

                    trigger OnAction()
                    var
                        dataMig: Codeunit "Data Migration";
                    begin
                        dataMig.BackupData();
                    end;
                }
                action(RestoreDataProcess)
                {
                    Caption = 'Step 2 - Restore Data';
                    Image = CoupledItem;

                    trigger OnAction()
                    var
                        dataMig: Codeunit "Data Migration Restore";
                    begin
                        dataMig.RestoreData();
                    end;
                }
            }
        }
    }
}