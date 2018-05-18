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

import PerfectLib
import PerfectLogger

public class GithubData : JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "githubData"

  var action: String = ""
  var PRData: PullRequestData?
  var issueData: IssueData?
  public var description: String {
    return "GithubData: \(action), \(PRData?.description ?? "No PR Data"), \(issueData?.description ?? "No Issue Data")"
  }

  init(action: String, PRData: [String: Any]?, issueData: [String: Any]?) {
    self.action = action
    if let PRData = PRData {
      self.PRData = PullRequestData.createPRData(from: PRData)
    }
    if let issueData = issueData {
      self.issueData = IssueData.createIssueData(from: issueData)
    }
  }

  public override func setJSONValues(_ values: [String : Any]) {
    self.action = getJSONValue(named: "action", from: values, defaultValue: "")
    self.PRData = getJSONValue(named: "pull_request", from: values, defaultValue: nil)
    self.issueData = getJSONValue(named: "issue", from: values, defaultValue: nil)
  }

  public override func getJSONValues() -> [String : Any] {
    return ["action": action,
            "pull_request": PRData as Any,
            "issue": issueData as Any]
  }

  class func createGithubData(from json: String) -> GithubData? {
    do {
      guard let incoming = try json.jsonDecode() as? [String: Any] else {
        return nil
      }
      return GithubData(action: incoming["action"] as? String ?? "",
                        PRData: incoming["pull_request"] as? [String: Any] ?? nil,
                        issueData: incoming["issue"] as? [String: Any] ?? nil)
    } catch {
      return nil
    }
  }

}

public class PullRequestData: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "pullRequestData"

  var id: Int = -1
  var html_url: String = ""
  var diff_url: String = ""
  var state: String = ""
  var title: String = ""
  var body: String = ""
  var labels: [String] = [String]()
  var url: String = ""
  var issue_url: String = ""
  public var description: String {
    return "PullRequestData: id:\(id), title:\(title), body:\(body), state:\(state), diff_url:\(diff_url)"
  }

  init(id: Int,
       html_url: String,
       diff_url: String,
       state: String,
       title: String,
       body: String,
       labels: [String],
       url: String,
       issue_url: String) {
    self.id = id
    self.html_url = html_url
    self.diff_url = diff_url
    self.state = state
    self.title = title
    self.body = body
    self.labels = labels
    self.url = url
    self.issue_url = issue_url
  }

  public override func setJSONValues(_ values: [String : Any]) {
    self.id = getJSONValue(named: "id", from: values, defaultValue: -1)
    self.html_url = getJSONValue(named: "html_url", from: values, defaultValue: "")
    self.diff_url = getJSONValue(named: "diff_url", from: values, defaultValue: "")
    self.state = getJSONValue(named: "state", from: values, defaultValue: "")
    self.title = getJSONValue(named: "title", from: values, defaultValue: "")
    self.body = getJSONValue(named: "body", from: values, defaultValue: "")
    self.labels = getJSONValue(named: "labels", from: values, defaultValue: [String]())
    self.url = getJSONValue(named: "url", from: values, defaultValue: "")
    self.issue_url = getJSONValue(named: "issue_url", from: values, defaultValue: "")
  }

  public override func getJSONValues() -> [String : Any] {
    return
      ["id": id,
       "html_url": html_url,
       "diff_url": diff_url,
       "state": state,
       "title": title,
       "body": body,
       "labels": labels,
       "url": url,
       "issue_url": issue_url
      ]
  }

  class func createPRData(from dict: [String: Any]) -> PullRequestData? {
    return PullRequestData(id: dict["id"] as? Int ?? -1,
                           html_url: dict["html_url"] as? String ?? "",
                           diff_url: dict["diff_url"] as? String ?? "",
                           state: dict["state"] as? String ?? "",
                           title: dict["title"] as? String ?? "",
                           body: dict["body"] as? String ?? "",
                           labels: dict["labels"] as? [String] ?? [String](),
                           url: dict["url"] as? String ?? "",
                           issue_url: dict["issue_url"] as? String ?? "")
  }

}

public class IssueData: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "issueData"

  var id: Int = -1
  var html_url: String = ""
  var state: String = ""
  var title: String = ""
  var body: String = ""
  var labels: [String] = [String]()
  var url: String = ""
  public var description: String {
    return "IssueData: id:\(id), title:\(title), body:\(body), state:\(state)"
  }

  init(id: Int,
       html_url: String,
       state: String,
       title: String,
       body: String,
       labels: [String],
       url: String) {
    self.id = id
    self.html_url = html_url
    self.state = state
    self.title = title
    self.body = body
    self.labels = labels
    self.url = url
  }

  public override func setJSONValues(_ values: [String : Any]) {
    self.id = getJSONValue(named: "id", from: values, defaultValue: -1)
    self.html_url = getJSONValue(named: "html_url", from: values, defaultValue: "")
    self.state = getJSONValue(named: "state", from: values, defaultValue: "")
    self.title = getJSONValue(named: "title", from: values, defaultValue: "")
    self.body = getJSONValue(named: "body", from: values, defaultValue: "")
    self.labels = getJSONValue(named: "labels", from: values, defaultValue: [String]())
    self.url = getJSONValue(named: "url", from: values, defaultValue: "")
  }

  public override func getJSONValues() -> [String : Any] {
    return
      ["id": id,
       "html_url": html_url,
       "state": state,
       "title": title,
       "body": body,
       "labels": labels,
       "url": url
    ]
  }

  class func createIssueData(from dict: [String: Any]) -> IssueData? {
    return IssueData(id: dict["id"] as? Int ?? -1,
                     html_url: dict["html_url"] as? String ?? "",
                     state: dict["state"] as? String ?? "",
                     title: dict["title"] as? String ?? "",
                     body: dict["body"] as? String ?? "",
                     labels: dict["labels"] as? [String] ?? [String](),
                     url: dict["url"] as? String ?? "")
  }

}
