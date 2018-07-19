/*
 Copyright 2018 the Material Automation authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import PerfectCrypto
import PerfectLib
import PerfectCURL
import PerfectHTTP
import PerfectLogger
import PerfectThread

public class GithubAuth {
  static var JWTToken = ""
  static let credentialsLock = Threading.Lock()

  class func signAndEncodeJWT() throws -> String {
    let key = try PEMKey(pemPath: config.pemFilePath)
    let currTime = time(nil)
    let payload = ["iat": currTime,
                   "exp": currTime + (10 * 60),
                   "iss": config.githubAppId]
    let jwt1 = try JWTCreator(payload: payload)
    let token = try jwt1.sign(alg: .rs256, key: key)
    JWTToken = token
    return token
  }

  class func getAccessToken(installationID: String) -> String? {
    do {
      _ = try GithubAuth.signAndEncodeJWT()
      LogFile.debug("the JWT token is good: \(GithubAuth.JWTToken != "")")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }

    guard let accessTokenURL = getInstallationAccessTokenURL(installationID: installationID) else {
      LogFile.error("Could not retrieve the access token URL for the installation ID: \(installationID)")
      return nil
    }

    let accessToken = GithubAuth.createAccessToken(url: accessTokenURL)
    LogFile.debug("the access token is good: \(accessToken != nil && accessToken != "")")
    return accessToken
  }

  class func getInstallationAccessTokenURL(installationID: String) -> String? {
    do {
      let request = CURLRequest(config.githubAPIBaseURL + "/app/installations/" + installationID)
      addAuthHeaders(to: request)
      let json = try request.perform().bodyString.jsonDecode() as? [String: Any] ?? [:]
      return json["access_tokens_url"] as? String
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
    return nil
  }

  class func createAccessToken(url: String) -> String? {
    do {
      let request = CURLRequest(url, .postString(""))
      addAuthHeaders(to: request)
      let json = try request.perform().bodyJSON
      let token = json["token"] as? String ?? ""
      return token
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
    return nil
  }

  class func addAuthHeaders(to request: CURLRequest) {
    let headersDict = githubAuthHTTPHeaders()
    for (k,v) in headersDict {
      request.addHeader(HTTPRequestHeader.Name.fromStandard(name: k), value: v)
    }
  }

  class func githubAuthHTTPHeaders() -> [String: String] {
    var headers = [String: String]()
    headers["Authorization"] = "Bearer \(JWTToken)"
    headers["Accept"] = "application/vnd.github.machine-man-preview+json"
    headers["User-Agent"] = config.userAgent
    return headers
  }

  class func refreshCredentialsIfUnauthorized(response: CURLResponse, githubAPI: GithubAPI) -> Bool {
    LogFile.debug("trying to refresh Github credentials")
    for n in 0..<4 {
      if response.responseCode == 401 || response.responseCode == 403 {
        if refreshGithubCredentials(githubAPI: githubAPI) {
          LogFile.debug("Refreshed Github credentials!")
          return true
        } else {
          #if os(Linux)
          let rand = Double(random() % 1000)
          #else
          let rand = Double(arc4random_uniform(1000))
          #endif
          Thread.sleep(forTimeInterval: round(pow(Double(2), Double(n)) * 1000) + rand)
        }
      }
    }
    return false
  }

  class func refreshGithubCredentials(githubAPI: GithubAPI) -> Bool {
    GithubAuth.credentialsLock.lock()
    defer {
      GithubAuth.credentialsLock.unlock()
    }
    if let accessToken = GithubAuth.getAccessToken(installationID: githubAPI.installationID) {
      LogFile.debug("the access token is good: \(accessToken)")
      githubAPI.accessToken = accessToken
      return true
    }
    LogFile.error("Cannot Authenticate with Github for this installation: \(githubAPI.installationID)")
    return false
  }

  class func verifyGooglerPassword(googlerPassword: String) -> Bool {
    guard var password = ProcessInfo.processInfo.environment["SECRET_TOKEN"] else {
      return false
    }
    password = "Basic " + password
    return googlerPassword == password
  }

  class func verifyGithubSignature(payload: String, requestSig: String) -> Bool {
    guard let password = ProcessInfo.processInfo.environment["SECRET_TOKEN"] else {
      return false
    }
    if let signed = payload.sign(.sha1, key: HMACKey(password))?.encode(.hex),
      let hexStr = String(bytes: signed, encoding: .utf8){
      let sig = "sha1=" + hexStr
      return sig == requestSig
    }
    return false
  }
}
