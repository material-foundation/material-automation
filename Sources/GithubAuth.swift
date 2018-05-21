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
  static let productionPath = "/root/MaterialAutomation/"
  static let localPath = Dir.workingDir.path
  static var JWTToken = ""
  static var accessToken = ""
  static let credentialsLock = Threading.Lock()
  static let pemFileName = "material-ci-app.2018-05-09.private-key.pem"

  class func signAndEncodeJWT() throws -> String {
    guard let githubAppIDStr = ProcessInfo.processInfo.environment["GITHUB_APP_ID"],
      let githubAppID = Int(githubAppIDStr) else {
      LogFile.error("You have not defined GITHUB_APP_ID in your app.yaml file")
      return ""
    }
    let fileDirectory = productionPath
    LogFile.debug(fileDirectory)
    let PEMPath = fileDirectory + pemFileName
    let key = try PEMKey(pemPath: PEMPath)
    let currTime = time(nil)
    let payload = ["iat": currTime,
                   "exp": currTime + (10 * 60),
                   "iss": githubAppID]
    let jwt1 = try JWTCreator(payload: payload)
    let token = try jwt1.sign(alg: .rs256, key: key)
    JWTToken = token
    return token
  }

  class func getFirstAppInstallationAccessTokenURL() -> String? {
    do {
      let request = CURLRequest("https://api.github.com/app/installations")
      addAuthHeaders(to: request)
      let json = try request.perform().bodyString.jsonDecode() as? [[String: Any]] ?? [[:]]
      if let first = json.first {
        return first["access_tokens_url"] as? String
      }
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
      accessToken = token
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
    headers["User-Agent"] = "Material Automation"
    return headers
  }

  class func refreshCredentialsIfUnauthorized(response: CURLResponse) -> Bool {
    LogFile.debug("trying to refresh Github credentials")
    for n in 0..<4 {
      if response.responseCode == 401 || response.responseCode == 403 {
        if refreshGithubCredentials() {
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

  class func refreshGithubCredentials() -> Bool {
    GithubAuth.credentialsLock.lock()
    defer {
      GithubAuth.credentialsLock.unlock()
    }
    do {
      _ = try GithubAuth.signAndEncodeJWT()
      LogFile.debug("the JWT token is good: \(GithubAuth.JWTToken != "")")
      if let accessTokenURL = GithubAuth.getFirstAppInstallationAccessTokenURL() {
        let accessToken = GithubAuth.createAccessToken(url: accessTokenURL)
        LogFile.debug("the access token is good: \(accessToken != nil && accessToken != "")")
        return accessToken != nil && accessToken != ""
      }
    } catch {
      LogFile.error("Cannot Authenticate with Github: \(error)")
    }

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
