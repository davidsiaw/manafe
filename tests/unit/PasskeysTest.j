@import <Foundation/Foundation.j>
@import <OJUnit/OJTestCase.j>
@import <OJUnit/OJAssert.j>

@import "../../Passkeys.j"

function bytes(aBuffer) { return Array.prototype.slice.call(new Uint8Array(aBuffer)); }
function buffer(anArray) { return new Uint8Array(anArray).buffer; }

@implementation PasskeysTest : OJTestCase

- (void)testBase64URLRoundTripsBytesThatNeedTheURLAlphabet
{
    // 0xfb 0xff encodes as "-_8" in base64url ("+/8=" in plain base64).
    [OJAssert assert:"-_8" equals:PasskeysBufferToBase64URL(buffer([0xfb, 0xff]))];
    [OJAssert assert:[0xfb, 0xff] equals:bytes(PasskeysBase64URLToBuffer("-_8"))];
}

- (void)testBase64URLHandlesEveryPaddingLength
{
    [OJAssert assert:[1] equals:bytes(PasskeysBase64URLToBuffer(PasskeysBufferToBase64URL(buffer([1]))))];
    [OJAssert assert:[1, 2] equals:bytes(PasskeysBase64URLToBuffer(PasskeysBufferToBase64URL(buffer([1, 2]))))];
    [OJAssert assert:[1, 2, 3] equals:bytes(PasskeysBase64URLToBuffer(PasskeysBufferToBase64URL(buffer([1, 2, 3]))))];
}

- (void)testCreationOptionsDecodeChallengeAndUserId
{
    var options = PasskeysCreationOptions({ challenge: "AQI", user: { id: "AwQ", name: "a@example.com" },
                                            rp: { id: "example.com" } });
    [OJAssert assert:[1, 2] equals:bytes(options.challenge)];
    [OJAssert assert:[3, 4] equals:bytes(options.user.id)];
    [OJAssert assert:"a@example.com" equals:options.user.name];
    [OJAssert assert:"example.com" equals:options.rp.id];
}

- (void)testRequestOptionsDecodeAllowedCredentials
{
    var options = PasskeysRequestOptions({ challenge: "AQI", allowCredentials: [{ type: "public-key", id: "BQY" }] });
    [OJAssert assert:[5, 6] equals:bytes(options.allowCredentials[0].id)];
    [OJAssert assert:"public-key" equals:options.allowCredentials[0].type];
}

- (void)testAssertionBecomesJSONWithBase64URLFields
{
    var json = PasskeysCredentialToJSON({
        type: "public-key", id: "Bwg", rawId: buffer([7, 8]), authenticatorAttachment: "platform",
        getClientExtensionResults: function() { return {}; },
        response: { clientDataJSON: buffer([1]), authenticatorData: buffer([2]), signature: buffer([3]),
                    userHandle: buffer([4]) }
    });
    [OJAssert assert:"Bwg" equals:json.rawId];
    [OJAssert assert:["AQ", "Ag", "Aw", "BA"] equals:[json.response.clientDataJSON, json.response.authenticatorData,
                                                       json.response.signature, json.response.userHandle]];
    [OJAssert assertFalse:("attestationObject" in json.response)];
}

@end
