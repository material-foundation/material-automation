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
import PerfectCURL
import PerfectHTTP
import PerfectLogger
import PerfectCrypto
import PerfectThread

class GithubCURLRequest: CURLRequest {
  static let curlAccessLock = Threading.Lock()

  override init(options: [CURLRequest.Option]) {
    super.init(options: options)

    GithubCURLRequest.curlAccessLock.lock()
    if time(nil) - GithubAPI.lastGithubAccess < 1 {
      Threading.sleep(seconds: 1)
    }
    GithubAPI.lastGithubAccess = time(nil)
    GithubCURLRequest.curlAccessLock.unlock()
  }

}

public class GithubAPI {
  static let githubBaseURL = "https://api.github.com"
  static let retryCount = 0
  static var lastGithubAccess = time(nil)

  class func addLabelsToIssue(url: String, labels: [String]) {
    LogFile.debug(labels.description)
    let labelsURL = url + "/labels"
    do {
      let request = GithubCURLRequest(labelsURL, .postString(labels.description))
      addAPIHeaders(to: request)
      let response = try request.perform()
      if GithubAuth.refreshCredentialsIfUnauthorized(response: response) {
        addLabelsToIssue(url: url, labels: labels)
      }
      LogFile.info("request result for addLabels: \(response.bodyString)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }

  class func createComment(url: String, comment: String) {
    let commentsURL = url + "/comments"
    let bodyDict = ["body": comment]
    do {
      let request = GithubCURLRequest(commentsURL, .postString(try bodyDict.jsonEncodedString()))
      addAPIHeaders(to: request)
      let response = try request.perform()
      if GithubAuth.refreshCredentialsIfUnauthorized(response: response) {
        createComment(url: url, comment: comment)
      }
      LogFile.info("request result for createComment: \(response.bodyString)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }

  class func editIssue(url: String, issueEdit: [String: Any]) {
    do {
      let request = GithubCURLRequest(url, .httpMethod(.patch), .postString(try issueEdit.jsonEncodedString()))
      addAPIHeaders(to: request)
      let response = try request.perform()
      if GithubAuth.refreshCredentialsIfUnauthorized(response: response) {
        editIssue(url: url, issueEdit: issueEdit)
      }
      LogFile.info("request result for editIssue: \(response.bodyString)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }

  class func setLabelsForAllIssues() {
    do {
      guard let repoPath = ProcessInfo.processInfo.environment["GITHUB_REPO_PATH"] else {
        LogFile.error("You have not defined a GITHUB_REPO_PATH pointing to your repo in your app.yaml file")
        return
      }
      let relativePathForRepo = "/repos/" + repoPath
      let issuesURL = githubBaseURL + relativePathForRepo + "/issues"
      let params = "?state=all"
      let request = GithubCURLRequest(issuesURL + params)
      addAPIHeaders(to: request)
      let response = try request.perform()
      if GithubAuth.refreshCredentialsIfUnauthorized(response: response) {
        setLabelsForAllIssues()
      }
      let result = try response.bodyString.jsonDecode() as? [[String: Any]] ?? [[:]]
      for issue in result {
        guard let issueData = IssueData.createIssueData(from: issue) else {
          continue
        }
        var labelsToAdd = [String]()
        if let titleLabel = PRLabelAnalysis.getTitleLabel(title: issueData.title) {
          labelsToAdd.append(titleLabel)
        }
        if let PRDict = issue["pull_request"] as? [String: Any] {
          if let diffURL = PRDict["diff_url"] as? String, diffURL.count > 0 {
            let paths = PRLabelAnalysis.getFilePaths(url: diffURL)
            LogFile.debug(paths.description)
            labelsToAdd.append(contentsOf: PRLabelAnalysis.grabLabelsFromPaths(paths: paths))
          }
        }
        if (labelsToAdd.count > 0) {
          GithubAPI.addLabelsToIssue(url: issueData.url, labels: Array(Set(labelsToAdd)))
        }
      }
      LogFile.info("request result for setLabelsForAllIssues: \(result)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }

}

// API Headers
extension GithubAPI {
  class func githubAPIHTTPHeaders() -> [String: String] {
    var headers = [String: String]()
    headers["Authorization"] = "token \(GithubAuth.accessToken)"
    LogFile.debug("the access token is: \(GithubAuth.accessToken)")
    headers["Accept"] = "application/vnd.github.machine-man-preview+json"
    headers["User-Agent"] = "Material Automation"
    return headers
  }

  class func addAPIHeaders(to request: CURLRequest) {
    let headersDict = githubAPIHTTPHeaders()
    for (k,v) in headersDict {
      request.addHeader(HTTPRequestHeader.Name.fromStandard(name: k), value: v)
    }
  }
}
