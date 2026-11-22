import XCTest
@testable import PassbyCore

final class SteamLoginTests: XCTestCase {
    private let id = "76561198000000042"

    private func query(_ url: URL) -> [String: String] {
        var out: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] { out[item.name] = item.value }
        return out
    }

    /// What Steam sends the person back with after a sign-in.
    private func handBack(
        mode: String = "id_res", claimed: String? = nil, returnTo: String? = nil,
        endpoint: String = "https://steamcommunity.com/openid/login"
    ) -> URL {
        var parts = URLComponents(url: SteamLogin.returnTo, resolvingAgainstBaseURL: false)!
        parts.queryItems = [
            URLQueryItem(name: "openid.ns", value: "http://specs.openid.net/auth/2.0"),
            URLQueryItem(name: "openid.mode", value: mode),
            URLQueryItem(name: "openid.op_endpoint", value: endpoint),
            URLQueryItem(name: "openid.claimed_id", value: claimed ?? "https://steamcommunity.com/openid/id/\(id)"),
            URLQueryItem(name: "openid.identity", value: claimed ?? "https://steamcommunity.com/openid/id/\(id)"),
            URLQueryItem(name: "openid.return_to", value: returnTo ?? SteamLogin.returnTo.absoluteString),
            URLQueryItem(name: "openid.response_nonce", value: "2026-11-22T16:00:00Zabc"),
            URLQueryItem(name: "openid.assoc_handle", value: "1234567890"),
            URLQueryItem(name: "openid.signed", value: "signed,op_endpoint,claimed_id,identity,return_to,response_nonce,assoc_handle"),
            URLQueryItem(name: "openid.sig", value: "c2lnbmF0dXJl+/="),
        ]
        return parts.url!
    }

    // MARK: Asking

    func testTheSignInPageIsSteamsWithThisAppAsWhereToComeBackTo() {
        let page = SteamLogin.page
        XCTAssertEqual(page.scheme, "https")
        XCTAssertEqual(page.host, "steamcommunity.com")
        XCTAssertEqual(page.path, "/openid/login")
        let q = query(page)
        XCTAssertEqual(q["openid.ns"], "http://specs.openid.net/auth/2.0")
        XCTAssertEqual(q["openid.mode"], "checkid_setup")
        XCTAssertEqual(q["openid.return_to"], SteamLogin.returnTo.absoluteString)
        XCTAssertEqual(q["openid.realm"], SteamLogin.realm)
        XCTAssertEqual(q["openid.identity"], "http://specs.openid.net/auth/2.0/identifier_select")
        XCTAssertEqual(q["openid.claimed_id"], "http://specs.openid.net/auth/2.0/identifier_select")
        // Steam only hands back to an address inside the realm it was given.
        XCTAssertTrue(SteamLogin.returnTo.absoluteString.hasPrefix(SteamLogin.realm))
    }

    // MARK: Being handed back

    func testOnlyTheAddressGivenToSteamCountsAsBeingHandedBack() {
        XCTAssertTrue(SteamLogin.isReturn(handBack()))
        XCTAssertTrue(SteamLogin.isReturn(SteamLogin.returnTo))
        XCTAssertFalse(SteamLogin.isReturn(URL(string: "https://steamcommunity.com/openid/login?x=1")!))
        XCTAssertFalse(SteamLogin.isReturn(URL(string: "https://passby.example/steam")!))
        XCTAssertFalse(SteamLogin.isReturn(URL(string: "https://passby/other")!))
    }

    func testASignInNamesThePersonAndCarriesWhatSteamNeedsToConfirmIt() throws {
        let claim = try XCTUnwrap(SteamLogin.claim(from: handBack()))
        XCTAssertEqual(claim.steamID, id)
        // Everything Steam sent goes back to it unchanged, except that the question is now "is this real?".
        XCTAssertEqual(claim.check["openid.mode"], "check_authentication")
        XCTAssertEqual(claim.check["openid.sig"], "c2lnbmF0dXJl+/=")
        XCTAssertEqual(claim.check["openid.assoc_handle"], "1234567890")
        XCTAssertEqual(claim.check["openid.claimed_id"], "https://steamcommunity.com/openid/id/\(id)")
        XCTAssertEqual(claim.check["openid.return_to"], SteamLogin.returnTo.absoluteString)
        XCTAssertEqual(claim.check.count, 10)
    }

    func testBackingOutOfTheSignInNamesNobody() {
        XCTAssertNil(SteamLogin.claim(from: handBack(mode: "cancel")))
        XCTAssertNil(SteamLogin.claim(from: SteamLogin.returnTo))
    }

    func testAnAnswerThatIsNotAboutASteamAccountOrNotForThisAppNamesNobody() {
        XCTAssertNil(SteamLogin.claim(from: handBack(claimed: "https://example.com/openid/id/\(id)")))
        XCTAssertNil(SteamLogin.claim(from: handBack(claimed: "https://steamcommunity.com/openid/id/1234")))
        XCTAssertNil(SteamLogin.claim(from: handBack(claimed: "https://steamcommunity.com/openid/id/\(id)/extra")))
        XCTAssertNil(SteamLogin.claim(from: handBack(returnTo: "https://someone-else/steam")))
        XCTAssertNil(SteamLogin.claim(from: handBack(endpoint: "https://example.com/openid/login")))
    }

    // MARK: Checking with Steam

    func testTheFormSentToConfirmASignInIsPercentEncoded() throws {
        let claim = try XCTUnwrap(SteamLogin.claim(from: handBack()))
        let form = String(decoding: SteamLogin.form(claim.check), as: UTF8.self)
        XCTAssertTrue(form.contains("openid.mode=check_authentication"))
        XCTAssertTrue(form.contains("openid.sig=c2lnbmF0dXJl%2B%2F%3D"))
        XCTAssertTrue(form.contains("openid.claimed_id=https%3A%2F%2Fsteamcommunity.com%2Fopenid%2Fid%2F\(id)"))
        XCTAssertFalse(form.contains(" "))
    }

    func testOnlySteamSayingItIsValidConfirmsIt() {
        XCTAssertTrue(SteamLogin.isConfirmed(status: 200, body: Data("ns:http://specs.openid.net/auth/2.0\nis_valid:true\n".utf8)))
        XCTAssertFalse(SteamLogin.isConfirmed(status: 200, body: Data("ns:http://specs.openid.net/auth/2.0\nis_valid:false\n".utf8)))
        XCTAssertFalse(SteamLogin.isConfirmed(status: 500, body: Data("is_valid:true\n".utf8)))
        XCTAssertFalse(SteamLogin.isConfirmed(status: 200, body: Data()))
        XCTAssertFalse(SteamLogin.isConfirmed(status: 200, body: Data("not_is_valid:true".utf8)))
    }
}
