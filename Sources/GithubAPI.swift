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

class GithubManager {
  static let shared = GithubManager()

  let githubInstancesLock = Threading.RWLock()
  private var githubInstances = [String: GithubAPI]()

  func getGithubInstance(for installation: String) -> GithubAPI? {
    var value: GithubAPI?
    githubInstancesLock.doWithReadLock {
      value = githubInstances[installation]
    }
    return value
  }

  func addGithubInstance(for installation: String) -> GithubAPI? {
    if let githubInstanceCached = getGithubInstance(for: installation) {
      return githubInstanceCached
    }

    return githubInstancesLock.doWithWriteLock { () -> GithubAPI? in
      guard let accessToken = GithubAuth.getAccessToken(installationID: installation) else {
        LogFile.error("couldn't get an access token for installation: \(installation)")
        return nil
      }
      let githubInstance = GithubAPI(accessToken: accessToken)
      githubInstances[accessToken] = githubInstance
      return githubInstance
    }
  }
}

class GithubCURLRequest: CURLRequest {
  override init(options: [CURLRequest.Option]) {
    super.init(options: options)
    var action = "unknown action"
    outer: for option in options {
      switch option {
        case .url(let urlString):
        action = urlString
        break outer
      default:
        break
      }
    }
    Analytics.trackEvent(category: "Github API", action: action)
  }
}

public class GithubAPI {

  var accessToken: String
  let curlAccessLock = Threading.Lock()
  var lastGithubAccess = time(nil)

  init(accessToken: String) {
    self.accessToken = accessToken
  }

  /// This method adds labels to a Github issue through the API.
  ///
  /// - Parameters:
  ///   - url: The url of the issue as a String
  ///   - labels: The labels to add to the issue
  func addLabelsToIssue(url: String, labels: [String]) {
    LogFile.debug(labels.description)
    let labelsURL = url + "/labels"
    do {
      APIOneSecondDelay()
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

  func APIOneSecondDelay() {
    self.curlAccessLock.lock()
    if time(nil) - self.lastGithubAccess < 1 {
      Threading.sleep(seconds: 1)
    }
    self.lastGithubAccess = time(nil)
    self.curlAccessLock.unlock()
  }

  /// This method creates and adds a comment to a Github issue through the API.
  ///
  /// - Parameters:
  ///   - url: The url of the issue as a String
  ///   - comment: The comment text
  func createComment(url: String, comment: String) {
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


  /// This method edits an existing Github issue through the API.
  ///
  /// - Parameters:
  ///   - url: The url of the issue as a String
  ///   - issueEdit: A dictionary where the keys are the items to edit in the issue, and the
  ///                values are what they should be edited to.
  func editIssue(url: String, issueEdit: [String: Any]) {
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


  /// This method bulk updates all the existing Github issues to have labels through the API.
  func setLabelsForAllIssues() {
    do {
      guard let repoPath = ConfigManager.shared?.configDict["GITHUB_REPO_PATH"] as? String else {
        LogFile.error("You have not defined a GITHUB_REPO_PATH pointing to your repo in your app.yaml file")
        return
      }
      let relativePathForRepo = "/repos/" + repoPath
      let issuesURL = DefaultConfigParams.githubBaseURL + relativePathForRepo + "/issues"
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
        if let titleLabel = LabelAnalysis.getTitleLabel(title: issueData.title) {
          labelsToAdd.append(titleLabel)
        }
        if let PRDict = issue["pull_request"] as? [String: Any] {
          if let diffURL = PRDict["diff_url"] as? String, diffURL.count > 0 {
            let paths = LabelAnalysis.getFilePaths(url: diffURL)
            LogFile.debug(paths.description)
            labelsToAdd.append(contentsOf: LabelAnalysis.grabLabelsFromPaths(paths: paths))
          }
        }
        if (labelsToAdd.count > 0) {
          addLabelsToIssue(url: issueData.url, labels: Array(Set(labelsToAdd)))
        }
      }
      LogFile.info("request result for setLabelsForAllIssues: \(result)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }


  /// This method receives a relative path inside the repository source code and receives from the Github API
  /// a JSON containing an array of dictionaries showing the files info in that directory. We
  /// then return a list of all the file names that are directories.
  ///
  /// - Parameter relativePath: The relative path inside the repository source code
  /// - Returns: an array of all the file names that are directories in the specific path.
  func getDirectoryContentPathNames(relativePath: String) -> [String] {
    var pathNames = [String]()
    do {
      guard let repoPath = ProcessInfo.processInfo.environment["GITHUB_REPO_PATH"] else {
        LogFile.error("You have not defined a GITHUB_REPO_PATH pointing to your repo in your app.yaml file")
        return pathNames
      }
      let contentsAPIPath = DefaultConfigParams.githubBaseURL + "/repos/" + repoPath + "/contents/" + relativePath
      let request = GithubCURLRequest(contentsAPIPath)
      addAPIHeaders(to: request)
      let response = try request.perform()
      let result = try response.bodyString.jsonDecode() as? [[String: Any]] ?? [[:]]
      for path in result {
        if let type = path["type"] as? String,
          type == "dir",
          let pathName = path["name"] as? String {
          pathNames.append(pathName)
        }
      }
      if GithubAuth.refreshCredentialsIfUnauthorized(response: response) {
        return getDirectoryContentPathNames(relativePath: relativePath)
      }
      LogFile.info("request result for getDirectoryContentPaths: \(response.bodyString)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
    return pathNames
  }

}

// API Headers
extension GithubAPI {
  func githubAPIHTTPHeaders() -> [String: String] {
    let userAgent = ConfigManager.shared?.configDict["USER_AGENT"] as? String ?? DefaultConfigParams.userAgent
    var headers = [String: String]()
    headers["Authorization"] = "token \(self.accessToken)"
    LogFile.debug("the access token is: \(self.accessToken)")
    headers["Accept"] = "application/vnd.github.machine-man-preview+json"
    headers["User-Agent"] = userAgent
    return headers
  }

  func addAPIHeaders(to request: CURLRequest) {
    let headersDict = githubAPIHTTPHeaders()
    for (k,v) in headersDict {
      request.addHeader(HTTPRequestHeader.Name.fromStandard(name: k), value: v)
    }
  }
}
