table 1456 "Headline RC Whse. WMS"
{
    Caption = 'Headline RC Whse. WMS';
    ObsoleteState = Removed;
    ObsoleteReason = 'Replaced with "RC Headlines User Data" table';

    fields
    {
        field(1; "Key"; Code[10])
        {
            Caption = 'Key';
            DataClassification = SystemMetadata;
        }
        field(2; "Workdate for computations"; Date)
        {
            Caption = 'Workdate for computations';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(Key1; "Key")
        {
            Clustered = true;
        }
    }

}

