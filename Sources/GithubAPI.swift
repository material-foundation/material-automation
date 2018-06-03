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

  let githubManagerLock = Threading.RWLock()
  private var githubAPIs = [String: GithubAPI]()

  private func getCachedGithubAPI(for installation: String) -> GithubAPI? {
    var value: GithubAPI?
    githubManagerLock.doWithReadLock {
      value = githubAPIs[installation]
    }
    return value
  }

  func getGithubAPI(for installation: String) -> GithubAPI? {
    if let githubAPICached = getCachedGithubAPI(for: installation) {
      return githubAPICached
    }

    return githubManagerLock.doWithWriteLock { () -> GithubAPI? in
      guard let accessToken = GithubAuth.getAccessToken(installationID: installation) else {
        LogFile.error("couldn't get an access token for installation: \(installation)")
        return nil
      }
      let githubAPI = GithubAPI(accessToken: accessToken, installationID: installation)
      githubAPIs[accessToken] = githubAPI
      return githubAPI
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
  var installationID: String
  let curlAccessLock = Threading.Lock()
  var lastGithubAccess = time(nil)

  init(accessToken: String, installationID: String) {
    self.accessToken = accessToken
    self.installationID = installationID
  }

  /// This method adds labels to a Github issue through the API.
  ///
  /// - Parameters:
  ///   - url: The url of the issue as a String
  ///   - labels: The labels to add to the issue
  func addLabelsToIssue(url: String, labels: [String]) {
    LogFile.debug(labels.description)

    let performRequest = { () -> CURLResponse in
      let labelsURL = url + "/labels"
      let request = GithubCURLRequest(labelsURL, .postString(labels.description))
      self.addAPIHeaders(to: request)
      return try request.perform()
    }
    githubRequestTemplate(requestFlow: performRequest, methodName: #function, resultFlow: nil)
  }

  /// This method creates and adds a comment to a Github issue through the API.
  ///
  /// - Parameters:
  ///   - url: The url of the issue as a String
  ///   - comment: The comment text
  func createComment(url: String, comment: String) {

    let performRequest = { () -> CURLResponse in
      let commentsURL = url + "/comments"
      let bodyDict = ["body": comment]
      let request = GithubCURLRequest(commentsURL, .postString(try bodyDict.jsonEncodedString()))
      self.addAPIHeaders(to: request)
      return try request.perform()
    }
    githubRequestTemplate(requestFlow: performRequest, methodName: #function, resultFlow: nil)
  }

  /// This method edits an existing Github issue through the API.
  ///
  /// - Parameters:
  ///   - url: The url of the issue as a String
  ///   - issueEdit: A dictionary where the keys are the items to edit in the issue, and the
  ///                values are what they should be edited to.
  func editIssue(url: String, issueEdit: [String: Any]) {

    let performRequest = { () -> CURLResponse in
      let request = GithubCURLRequest(url, .httpMethod(.patch),
                                      .postString(try issueEdit.jsonEncodedString()))
      self.addAPIHeaders(to: request)
      return try request.perform()
    }
    githubRequestTemplate(requestFlow: performRequest, methodName: #function, resultFlow: nil)
  }

  /// This method bulk updates all the existing Github issues to have labels through the API.
  func setLabelsForAllIssues(repoURL: String) {

    let performRequest = { () -> CURLResponse in
      let issuesURL = repoURL + "/issues"
      let params = "?state=all"
      let request = GithubCURLRequest(issuesURL + params)
      self.addAPIHeaders(to: request)
      return try request.perform()
    }
    githubRequestTemplate(requestFlow: performRequest, methodName: #function) { response in
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
          self.addLabelsToIssue(url: issueData.url, labels: Array(Set(labelsToAdd)))
        }
      }
    }
  }

  /// This method receives a relative path inside the repository source code and receives from the Github API
  /// a JSON containing an array of dictionaries showing the files info in that directory. We
  /// then return a list of all the file names that are directories.
  ///
  /// - Parameter relativePath: The relative path inside the repository source code
  /// - Returns: an array of all the file names that are directories in the specific path.
  func getDirectoryContentPathNames(relativePath: String, repoURL: String) -> [String] {
    var pathNames = [String]()
    let performRequest = { () -> CURLResponse in
      let contentsAPIPath = repoURL + "/contents/" + relativePath
      let request = GithubCURLRequest(contentsAPIPath)
      self.addAPIHeaders(to: request)
      return try request.perform()
    }
    githubRequestTemplate(requestFlow: performRequest, methodName: #function) { response in
      let result = try response.bodyString.jsonDecode() as? [[String: Any]] ?? [[:]]
      for path in result {
        if let type = path["type"] as? String,
          type == "dir",
          let pathName = path["name"] as? String {
          pathNames.append(pathName)
        }
      }
    }
    return pathNames
  }


  /// Get the project's column name by providing the column ID.
  ///
  /// - Parameter columnID: the column ID number.
  /// - Returns: the name of the column.
  func getProjectColumnName(columnID: Int) -> String? {
    LogFile.debug("Fetching name for column ID: \(columnID)")
    var columnName: String?
    let performRequest = { () -> CURLResponse in
      let columnsAPIPath = DefaultConfigParams.githubBaseURL + "/projects/columns/\(columnID)"
      let request = GithubCURLRequest(columnsAPIPath)
      self.addAPIHeaders(to: request,
                         with: ["Accept": "application/vnd.github.inertia-preview+json"])
      return try request.perform()
    }
    githubRequestTemplate(requestFlow: performRequest, methodName: #function) { response in
      let result = try response.bodyString.jsonDecode() as? [String: Any] ?? [:]
      columnName = result["name"] as? String
    }
    return columnName
  }

}

// API Headers
extension GithubAPI {
  func githubAPIHTTPHeaders(customHeaderParams: [String: String]?) -> [String: String] {
    let userAgent = ConfigManager.shared?.configDict["USER_AGENT"] as? String ?? DefaultConfigParams.userAgent
    var headers = [String: String]()
    headers["Authorization"] = "token \(self.accessToken)"
    LogFile.debug("the access token is: \(self.accessToken)")
    headers["Accept"] = "application/vnd.github.machine-man-preview+json"
    headers["User-Agent"] = userAgent

    if let customHeaderParams = customHeaderParams {
      customHeaderParams.forEach { (k,v) in headers[k] = v }
    }
    return headers
  }

  func addAPIHeaders(to request: CURLRequest, with customHeaderParams: [String: String]? = nil) {
    APIOneSecondDelay()
    let headersDict = githubAPIHTTPHeaders(customHeaderParams: customHeaderParams)
    for (k,v) in headersDict {
      request.addHeader(HTTPRequestHeader.Name.fromStandard(name: k), value: v)
    }
  }

  /// The Github API allows to send a request once a second, so we need to delay the request if
  /// a second hasn't passed yet.
  func APIOneSecondDelay() {
    self.curlAccessLock.lock()
    if time(nil) - self.lastGithubAccess < 1 {
      Threading.sleep(seconds: 1)
    }
    self.lastGithubAccess = time(nil)
    self.curlAccessLock.unlock()
  }

  func githubRequestTemplate(requestFlow: () throws -> CURLResponse,
                             methodName: String,
                             resultFlow: ((_ response: CURLResponse) throws -> ())?) {
    do {
      var response = try requestFlow()
      if GithubAuth.refreshCredentialsIfUnauthorized(response: response, githubAPI: self) {
        response = try requestFlow()
      }
      try resultFlow?(response)
      LogFile.info("request result for \(methodName): \(response.bodyString)")
    } catch {
      LogFile.error("error: \(error) desc: \(error.localizedDescription)")
    }
  }
}
