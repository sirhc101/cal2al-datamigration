# C/SIDE to AL Data Migration Toolkit

## Introduction
Due to a lack of the possibility to transfer data in Microsoft Dynamics standard table extensions (new fields) into corresponding table extensions this toolkit has been created. The goal is provide a toolbox the NAV/Business Central Community can use to transfer data from old C/AL to new AL tables and table extensions.

## Content

### Objects

| Object Type | Object ID | Object Name |
| ----------- | --------- | ----------- |
| Table | 90000 | Data Migration Buffer |
| Page | 90000 | Data Migration List |
| Page Extension | 90000 | Data Migration |
| Codeunit | 90000 | Data Migration |
| Codeunit | 90001 | Data Migration Restore |

### App Structure
```
C/SIDE to AL Data Migration Toolkit
    -app
        #   app.json
        #   
        -res
        #   logo.jpg
        #   
        -.vscode
        #       launch.json
        #       
        -src
        #   -codeunit
        #   #       Cod90000.DataMigration.al
        #   #       Cod90001.DataMigrationRestore.al
        #   #       
        #   -page
        #   #       Pag90000.DataMigrationList.al
        #   #       
        #   -pagext
        #   #       Pag1.Ext90000.DataMigration.al
        #   #       
        #   -table
        #           Tab90000.DataMigrationBuffer.al
        #
```
### How does at work?
The functionality of the `C/SIDE to AL Migration Toolkit` is based on the classic Upgrade Toolkit from Microsoft. As starting point for the migration, all individual tables and/or new fields in standard tables should be available in Microsoft Dynamics NAV 2018 (or newer). 

For example: In general the app tries to move the contact of C/AL table 37, field 50000 into the table extension extending table 37 with field no. 50000. If for some reason you were forced to restructure or remove a field you can use some of the Event Publisher, mentioned below.

#### 1.) Backup
At the beginning the `C/SIDE to AL Data Migration for Dynamics 365 Business Central` app is installed. Afterwards the backup process needs to be started to transfer data from the C/SIDE tables to the table id 90000 `Data Migration Buffer`. You can start the backup process by clicking the `Step 1 - Backup Data` action in the page `Company Information` page.

In the table `Data Migration Buffer` each field represents a separate record in table. So each individual field is resulting in one record.

#### 2.) C/SIDE Clean-Up
In the next step all individual fields and newly created tables can be removed from the Dynamics NAV or Business Central C/AL database. The schema synchronization must be performed with `Force`, which automatically deletes the data in the fields.

This can be done via PowerShell as follows:
```PS
    Sync-NavTenant -ServerInstance [ServerInstance] `
        –Mode ForceSync
```
Optionally you can start the schema synhronization using the C/SIDE development environment (Microsoft Dynamics NAV Development Environment).

#### 3.) Publish and Install Customer App(s)/Extension(s)
Now it's time to deploy the customer app(s)/extension(s) to the database. 

This can be done via PowerShell as follows:
``` PS
    Publish-NAVApp `
        -ServerInstance [ServerInstance] `
        -Path [Your path to the app file] `
        [-SkipVerification]

    Install-NAVApp `
        -ServerInstance [ServerInstance] `
        -Name [Your Solution Name] `
        -Version [Your Version No.]
```
Optionally you can use Visual Studio Code for deployment.

#### 4.) Restore
After all new extensions has been installed the data restore can be started, using the action `Step 2 - Restore Data` in the `Company Information` page.

Now the data from the table id 90000 `Data Migration Buffer` will be restored.
>**IMPORTANT**\
In general the restore process is doing a 1:1 migration of data, based on the previous object id and field no. In case of a changed data model it will be necessary to cover this mapping changes by using the provided event publisher (see below).

After the restore process is finished in general the `Data Migration Buffer` table should be empty. You can verify this by open the `Data Migration Buffer List` in the `Company Information` page. 

### Event Publisher
The following event publisher are in place to provide extensiblity to the backup and restore process:

| Object Type | Object ID | Object Name | Publisher Name | Possible use for |
| ----------- | --------- | ----------- | -------------- | ---------------- |
| Table | 90000 | Data Migration Buffer | OnBeforeAssignValueToBuffer | Manipulate the data which will be stored at the `Data Migration Buffer` table.<br/>Additionally this can be used to support additional data types.<br /><br />_`Handled` Pattern is applied._|
| Table | 90000 | Data Migration Buffer | OnAfterAssignValueToBuffer | Store additional information to the `Data Migration Buffer` table. |
| Table | 90000 | Data Migration Buffer | OnBeforeGetValueFromBuffer | Ignore data, map to other fields or extend/manipulate data.<br /> <br />_`Handled` Pattern is applied._|
| Table | 90000 | Data Migration Buffer | OnAfterGetValueFromBuffer | Manipulate data. |
| Codeunit | 90000 | Data Migration | OnBeforeBackupCustomTables | Can be used to set object range of custom tables to be backed up. |
| Codeunit | 90001 | Data Migration Restore | OnBeforeRestoreDataToTable | Map to other fields. |
| Codeunit | 90001 | Data Migration Restore | OnRestoreTableNotExist | Handling of data were the table does not exist anymore.<br /> <br />_**Notice:** If you just ignore the restore will also do so. The data will remain in the `Data Migration Buffer` table._ |
| Codeunit | 90001 | Data Migration Restore | OnAfterDataMigrationBufferFilterSet | Set additional filters for restore process. Use this for restore partial data. |
| Codeunit | 90001 | Data Migration Restore | OnBeforeRestoreDataToFieldNo | Change target field no. of the table were the data has to be restored to.|

## Known issues
 - The tool has been used in several upgrade project scenarios, but mostly some customer related extensions were necessary. That's not a issue at all, but I just want to point to this, so expect that you also need to do minor extensions please.
 - Runtime is a major factor. Due to the data modell (each field is one record) will customer tables with a lot of records (e.g. G/L Entry) result in a huge buffer table. That need some time. For backup that's usally no issue, but for restore it could be a time issue. Therefor please notice event publisher `OnAfterDataMigrationBufferFilterSet`. This publisher can be used to split the restore process in smaller chunks.
