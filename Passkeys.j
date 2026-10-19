@import <Foundation/Foundation.j>

/*
    The server speaks WebAuthn options and credentials as JSON, with binary
    fields in base64url. navigator.credentials wants and returns
    ArrayBuffers. These functions convert between the two; PasskeysCreate
    and PasskeysGet run the browser side of the ceremonies.
*/

function PasskeysBase64URLToBuffer(aString)
{
    var base64 = aString.replace(/-/g, "+").replace(/_/g, "/");
    while (base64.length % 4)
        base64 += "=";

    var binary = atob(base64),
        bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++)
        bytes[i] = binary.charCodeAt(i);
    return bytes.buffer;
}

function PasskeysBufferToBase64URL(aBuffer)
{
    var bytes = new Uint8Array(aBuffer),
        binary = "";
    for (var i = 0; i < bytes.length; i++)
        binary += String.fromCharCode(bytes[i]);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function _PasskeysDescriptors(aList)
{
    return (aList || []).map(function(d)
    {
        var copy = Object.assign({}, d);
        copy.id = PasskeysBase64URLToBuffer(d.id);
        return copy;
    });
}

function PasskeysCreationOptions(aJSON)
{
    var options = Object.assign({}, aJSON);
    options.challenge = PasskeysBase64URLToBuffer(aJSON.challenge);
    options.user = Object.assign({}, aJSON.user, { id: PasskeysBase64URLToBuffer(aJSON.user.id) });
    options.excludeCredentials = _PasskeysDescriptors(aJSON.excludeCredentials);
    return options;
}

function PasskeysRequestOptions(aJSON)
{
    var options = Object.assign({}, aJSON);
    options.challenge = PasskeysBase64URLToBuffer(aJSON.challenge);
    options.allowCredentials = _PasskeysDescriptors(aJSON.allowCredentials);
    return options;
}

// A PublicKeyCredential as the JSON the webauthn gem reads.
function PasskeysCredentialToJSON(aCredential)
{
    var response = aCredential.response,
        json = {};

    ["clientDataJSON", "attestationObject", "authenticatorData", "signature", "userHandle"].forEach(function(key)
    {
        if (response[key])
            json[key] = PasskeysBufferToBase64URL(response[key]);
    });
    if (response.getTransports)
        json.transports = response.getTransports();

    return {
        type: aCredential.type,
        id: aCredential.id,
        rawId: PasskeysBufferToBase64URL(aCredential.rawId),
        authenticatorAttachment: aCredential.authenticatorAttachment,
        clientExtensionResults: aCredential.getClientExtensionResults ? aCredential.getClientExtensionResults() : {},
        response: json
    };
}

function PasskeysSupported()
{
    return typeof window !== "undefined" && !!window.PublicKeyCredential && !!navigator.credentials;
}

// aCallback(credentialJSON, errorMessage): exactly one of the two is set.
function PasskeysCreate(anOptionsJSON, aCallback)
{
    _PasskeysRun(function() { return navigator.credentials.create({ publicKey: PasskeysCreationOptions(anOptionsJSON) }); }, aCallback);
}

function PasskeysGet(anOptionsJSON, aCallback)
{
    _PasskeysRun(function() { return navigator.credentials.get({ publicKey: PasskeysRequestOptions(anOptionsJSON) }); }, aCallback);
}

function _PasskeysRun(aStart, aCallback)
{
    if (!PasskeysSupported())
        return aCallback(nil, "This browser does not support passkeys.");

    aStart().then(function(credential)
    {
        aCallback(PasskeysCredentialToJSON(credential), nil);
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
    }, function(error)
    {
        // NotAllowedError covers both "cancelled" and "timed out".
        var message = error && error.name === "NotAllowedError" ? "The passkey request was cancelled." :
                      "The passkey request failed" + (error && error.message ? ": " + error.message : ".");
        aCallback(nil, message);
        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
    });
}
