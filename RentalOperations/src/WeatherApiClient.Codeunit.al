namespace AmuseYou.RentalOperations;

codeunit 50210 "Weather API Client"
{
    var
        ApiKeyTok: Label 'wx_8f2c41d9b7e04a5c9d13', Locked = true;

    procedure GetWeatherForecast(Location: Text): Text
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        Url: Text;
    begin
        Url := 'https://weather.api/v1/forecast?location=' + Location + '&apikey=' + ApiKeyTok;

        if not Client.Get(Url, Response) then
            exit('');

        if not Response.IsSuccessStatusCode then
            exit('');

        Response.Content.ReadAs(ResponseText);
        exit(ResponseText);
    end;

    procedure CheckSevereWeather(Location: Text; BookingDate: Date): Boolean
    var
        Client: HttpClient;
        Response: HttpResponseMessage;
        ResponseText: Text;
        JsonResponse: JsonObject;
        JsonToken: JsonToken;
        Url: Text;
        IsSevere: Boolean;
    begin
        Url := 'https://weather.api/v1/alerts?location=' + Location + '&date=' + Format(BookingDate) + '&apikey=' + ApiKeyTok;

        if not Client.Get(Url, Response) then
            exit(false);

        if not Response.IsSuccessStatusCode then
            exit(false);

        Response.Content.ReadAs(ResponseText);
        if JsonResponse.ReadFrom(ResponseText) then
            if JsonResponse.Get('severeWeather', JsonToken) then
                IsSevere := JsonToken.AsValue().AsBoolean();

        exit(IsSevere);
    end;
}
