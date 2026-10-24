namespace AmuseYou.BookingCore;

table 50000 Equipment
{
    Caption = 'Equipment';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "No."; Code[20])
        {
            Caption = 'No.';
            DataClassification = CustomerContent;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; "Equipment Type"; Enum EquipmentType)
        {
            Caption = 'Equipment Type';
            DataClassification = CustomerContent;
        }
        field(4; "Daily Rental Rate"; Decimal)
        {
            Caption = 'Daily Rental Rate';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
        field(5; Blocked; Boolean)
        {
            Caption = 'Blocked';
            DataClassification = CustomerContent;
        }
        field(6; "Last Maintenance Date"; Date)
        {
            Caption = 'Last Maintenance Date';
            DataClassification = CustomerContent;
        }
        field(7; "Next Maintenance Date"; Date)
        {
            Caption = 'Next Maintenance Date';
            DataClassification = CustomerContent;
        }
        field(8; Location; Text[50])
        {
            Caption = 'Location';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "No.")
        {
            Clustered = true;
        }
        key(TypeKey; "Equipment Type")
        {
        }
    }
}
