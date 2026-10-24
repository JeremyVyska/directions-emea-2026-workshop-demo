namespace AmuseYou.RentalOperations;

using AmuseYou.BookingCore;

codeunit 50220 "Rental Upgrade"
{
    Subtype = Upgrade;

    trigger OnUpgradePerCompany()
    var
        Equipment: Record Equipment;
    begin
        // v1.1: existing equipment gets the default location so the weather check has something to look up.
        Equipment.SetRange(Location, '');
        Equipment.ModifyAll(Location, 'MAIN');
    end;
}
