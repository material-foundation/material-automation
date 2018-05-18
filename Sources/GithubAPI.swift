/*
 Copyright 2018 Google LLC

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

public class GithubAPI {
  static let githubBaseURL = "https://api.github.com"
  static let retryCount = 0

  class func addLabelsToIssue(url: String, labels: [String]) {
    let labelsURL = url + "/labels"
    do {
      let request = CURLRequest(labelsURL, .postString(labels.description))
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

  class func setLabelsForAllIssues() {
    do {
      let issuesURL = githubBaseURL + "/repos/yarneo/material-components-ios/issues"
      let params = "?state=all"
      let request = CURLRequest(issuesURL + params)
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
    headers["User-Agent"] = "Material CI App"
    return headers
  }

  class func addAPIHeaders(to request: CURLRequest) {
    let headersDict = githubAPIHTTPHeaders()
    for (k,v) in headersDict {
      request.addHeader(HTTPRequestHeader.Name.fromStandard(name: k), value: v)
    }
  }
}
