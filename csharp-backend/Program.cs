using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using Jose;
using dotenv.net;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

DotEnv.Load();



var builder = WebApplication.CreateBuilder(args);

// var config = builder.Configuration;

// ADD CORS POLICY
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

//APPLY CORS POLICY
app.UseCors("AllowAll");

app.MapPost("/api/pay/jwt", async ([FromBody] JsonElement requestBody) =>
{
    Console.WriteLine("hitting the endpoint");
    string merchantUniqueId = "user_" + DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(); // >= 15 chars
    HttpResponseMessage? response = null;
    string responseContent = string.Empty;

    try
    {
        if (!requestBody.TryGetProperty("merchantTxnId", out var merchantTxnIdElem) ||
            !requestBody.TryGetProperty("merchantUniqueId", out var merchantUniqueIdElem) ||
            !requestBody.TryGetProperty("paymentData", out var paymentDataElem) ||
            !requestBody.TryGetProperty("merchantCallbackURL", out var merchantCallbackURLElem))
        {
            return Results.BadRequest(new { error = "Missing required fields: merchantTxnId, merchantUniqueId, paymentData, or merchantCallbackURL" });
        }

        var paymentData = paymentDataElem;

        if (!paymentData.TryGetProperty("totalAmount", out _) ||
            !paymentData.TryGetProperty("txnCurrency", out _) ||
            !paymentData.TryGetProperty("billingData", out var billingDataElem) ||
            !billingDataElem.TryGetProperty("emailId", out _))
        {
            return Results.BadRequest(new { error = "Missing required fields in paymentData or billingData.emailId" });
        }

        var payloadObj = new
        {
            merchantTxnId = merchantTxnIdElem.GetString(),
            merchantUniqueId = merchantUniqueId,
            paymentData = JsonSerializer.Deserialize<object>(paymentData.GetRawText()),
            merchantCallbackURL = merchantCallbackURLElem.GetString()
        };

        var payloadJson = JsonSerializer.Serialize(payloadObj, new JsonSerializerOptions { WriteIndented = true });
        Console.WriteLine("Payload:");
        Console.WriteLine(payloadJson);

Console.WriteLine("Environment Variables:");

Console.WriteLine(new
{
    MerchantId = builder.Configuration["PayGlocal:MerchantId"],
    PublicKeyId = builder.Configuration["PayGlocal:PublicKeyId"],
    PrivateKeyId = builder.Configuration["PayGlocal:PrivateKeyId"],
    ApiKeyStatus = !string.IsNullOrEmpty(builder.Configuration["PayGlocal:ApiKey"]) ? "Set" : "Not Set"
});


        long iat = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        long exp = iat + 300000;

var publicKeyPem = builder.Configuration["PayGlocal:PayGlocalPublicKey"];
if (string.IsNullOrEmpty(publicKeyPem))
    return Results.Problem("PayGlocalPublicKey config is missing");

using RSA rsaPublic = RSA.Create();
rsaPublic.ImportFromPem(publicKeyPem.ToCharArray());


        var jweHeaders = new Dictionary<string, object>
        {
            // { "alg", "RSA-OAEP-256" },
            // { "enc", "A128CBC-HS256" },
            { "iat", iat.ToString() },
            { "exp", iat + 300000 },
            { "kid", builder.Configuration["PayGlocal:PublicKeyId"] ?? "" },
           { "issued-by", builder.Configuration["PayGlocal:MerchantId"] ?? "" }

        };

        var jwe = JWT.Encode(payloadJson, rsaPublic, JweAlgorithm.RSA_OAEP_256, JweEncryption.A128CBC_HS256, extraHeaders: jweHeaders);

        Console.WriteLine("JWE:");
        Console.WriteLine(jwe);

        var jweHeader = JsonDocument.Parse(Base64UrlDecode(jwe.Split('.')[0]));
        Console.WriteLine("JWE Header:");
        Console.WriteLine(JsonSerializer.Serialize(jweHeader.RootElement, new JsonSerializerOptions { WriteIndented = true }));

var privateKeyPem = builder.Configuration["PayGlocal:PayGlocalPrivateKey"];
if (string.IsNullOrEmpty(privateKeyPem))
    return Results.Problem("PayGlocalPrivateKey config is missing");

using RSA rsaPrivate = RSA.Create();
rsaPrivate.ImportFromPem(privateKeyPem.ToCharArray());

using var sha256 = SHA256.Create();
var digestBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(jwe));
var digestBase64 = Convert.ToBase64String(digestBytes);

var digestObject = new
{
    digest = digestBase64,
    digestAlgorithm = "SHA-256",
    exp = 300000, // Align with JavaScript for consistency
    iat = iat.ToString()
};

var digestJson = JsonSerializer.Serialize(digestObject);

var jwsHeaders = new Dictionary<string, object>
{
    { "alg", "RS256" }, // Explicitly include alg
    { "issued-by", builder.Configuration["PayGlocal:MerchantId"] ?? "" },
     { "kid", builder.Configuration["PayGlocal:PrivateKeyId"] ?? "" },
    { "x-gl-merchantId", builder.Configuration["PayGlocal:MerchantId"] ?? "" },
    { "x-gl-enc", "true" },
    { "is-digested", "true" }
};

var jws = JWT.Encode(digestJson, rsaPrivate, JwsAlgorithm.RS256, extraHeaders: jwsHeaders);

Console.WriteLine("JWS:");
Console.WriteLine(jws);

var jwsHeader = JsonDocument.Parse(Base64UrlDecode(jws.Split('.')[0]));
Console.WriteLine("JWS Header:");
Console.WriteLine(JsonSerializer.Serialize(jwsHeader.RootElement, new JsonSerializerOptions { WriteIndented = true }));

        using var httpClient = new HttpClient();

        var httpContent = new StringContent(jwe, Encoding.UTF8, "text/plain");
        httpContent.Headers.ContentType = new MediaTypeHeaderValue("text/plain");

        var request = new HttpRequestMessage(HttpMethod.Post, "https://api.uat.payglocal.in/gl/v1/payments/initiate/paycollect");
        request.Content = httpContent;
        request.Headers.Add("x-gl-token-external", jws);

        response = await httpClient.SendAsync(request);
        responseContent = await response.Content.ReadAsStringAsync();

        Console.WriteLine("PayGlocal Response:");
        Console.WriteLine(responseContent);

        if (!response.IsSuccessStatusCode)
        {
            return Results.Json(new { error = "Payment initiation failed", details = responseContent }, statusCode: (int)response.StatusCode);
        }

        var jsonDoc = JsonDocument.Parse(responseContent);

        string? redirectUrl = jsonDoc.RootElement.GetProperty("data").TryGetProperty("redirectUrl", out var redirectElem)
            ? redirectElem.GetString()
            : (jsonDoc.RootElement.TryGetProperty("redirect_url", out var r2) ? r2.GetString() : null);

        if (string.IsNullOrEmpty(redirectUrl))
        {
            Console.Error.WriteLine("No redirect_url found in response");
            return Results.Json(new { error = "Payment initiation failed", details = responseContent }, statusCode: (int)response.StatusCode);
        }

        string? statusUrl = jsonDoc.RootElement.GetProperty("data").TryGetProperty("statusUrl", out var statusElem)
            ? statusElem.GetString()
            : (jsonDoc.RootElement.TryGetProperty("status_url", out var s2) ? s2.GetString() : null);

        string? gid = null;
        if (!string.IsNullOrEmpty(statusUrl))
        {
            var match = System.Text.RegularExpressions.Regex.Match(statusUrl, @"/payments/([^/]+)/status");
            if (match.Success)
                gid = match.Groups[1].Value;
        }

        return Results.Ok(new
        {
            payment_link = redirectUrl,
            gid = gid
        });
    }
    catch (HttpRequestException httpEx)
    {
        Console.Error.WriteLine($"HTTP request failed: {httpEx.Message}");
        return Results.Json(new
        {
            error = "Payment initiation failed",
            details = responseContent != string.Empty ? responseContent : httpEx.Message
        }, statusCode: response != null ? (int)response.StatusCode : 502);
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Error in /api/pay/jwt: {ex.Message}");
        return Results.Json(new
        {
            error = "Payment initiation failed",
            details = responseContent != string.Empty ? responseContent : ex.Message
        }, statusCode: response != null ? (int)response.StatusCode : 500);
    }
});

app.Run();

static byte[] Base64UrlDecode(string input)
{
    string base64 = input.Replace('-', '+').Replace('_', '/');
    switch (base64.Length % 4)
    {
        case 2: base64 += "=="; break;
        case 3: base64 += "="; break;
    }
    return Convert.FromBase64String(base64);
}







