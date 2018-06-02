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
  
  var installationID: String?
  var action: String = ""
  var PRData: PullRequestData?
  var issueData: IssueData?
  var changes: Changes?
  var projectCard: ProjectCard?
  var sender: String?

  static func registerModels() {
    JSONDecoding.registerJSONDecodable(name: GithubData.registerName,
                                       creator: { return GithubData() })
    JSONDecoding.registerJSONDecodable(name: PullRequestData.registerName,
                                       creator: { return PullRequestData() })
    JSONDecoding.registerJSONDecodable(name: IssueData.registerName,
                                       creator: { return IssueData() })
    JSONDecoding.registerJSONDecodable(name: Changes.registerName,
                                       creator: { return Changes() })
    JSONDecoding.registerJSONDecodable(name: ProjectCard.registerName,
                                       creator: { return ProjectCard() })
  }

  public var description: String {
    return "GithubData: \(action), Installation ID: \(installationID ?? "No Installation ID")," +
      "\(PRData?.description ?? "No PR Data"), \(issueData?.description ?? "No Issue Data")"
  }

  public override func setJSONValues(_ values: [String : Any]) {
    let installationDict: [String: Any]? =
      getJSONValue(named: "installation", from: values, defaultValue: nil)
    self.installationID = installationDict?["id"] as? String
    self.action = getJSONValue(named: "action", from: values, defaultValue: "")
    self.PRData = getJSONValue(named: "pull_request", from: values, defaultValue: nil)
    self.issueData = getJSONValue(named: "issue", from: values, defaultValue: nil)
    self.changes = getJSONValue(named: "changes", from: values, defaultValue: nil)
    self.projectCard = getJSONValue(named: "project_card", from: values, defaultValue: nil)
    let senderDict: [String: Any]? =
      getJSONValue(named: "sender", from: values, defaultValue: nil)
    self.sender = senderDict?["login"] as? String
  }

  public override func getJSONValues() -> [String : Any] {
    return [JSONDecoding.objectIdentifierKey:GithubData.registerName,
            "installationID": installationID as Any,
            "action": action,
            "pull_request": PRData as Any,
            "issue": issueData as Any,
            "changes": changes as Any,
            "project_card": projectCard as Any]
  }

  class func createGithubData(from json: String) -> GithubData? {
    do {
      guard let githubData = try json.jsonDecode() as? GithubData else {
        return nil
      }
      return githubData
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
      [JSONDecoding.objectIdentifierKey:PullRequestData.registerName,
       "id": id,
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
  var repository_url: String = ""

  public var description: String {
    return "IssueData: id:\(id), title:\(title), body:\(body), state:\(state)"
  }

  public override func setJSONValues(_ values: [String : Any]) {
    self.id = getJSONValue(named: "id", from: values, defaultValue: -1)
    self.html_url = getJSONValue(named: "html_url", from: values, defaultValue: "")
    self.state = getJSONValue(named: "state", from: values, defaultValue: "")
    self.title = getJSONValue(named: "title", from: values, defaultValue: "")
    self.body = getJSONValue(named: "body", from: values, defaultValue: "")
    self.labels = getJSONValue(named: "labels", from: values, defaultValue: [String]())
    self.url = getJSONValue(named: "url", from: values, defaultValue: "")
    self.repository_url = getJSONValue(named: "repository_url", from: values, defaultValue: "")
  }

  public override func getJSONValues() -> [String : Any] {
    return
      [JSONDecoding.objectIdentifierKey:IssueData.registerName,
       "id": id,
       "html_url": html_url,
       "state": state,
       "title": title,
       "body": body,
       "labels": labels,
       "url": url,
       "repository_url": repository_url
    ]
  }

}

public class Changes: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "changes"

  var column_from: Int?

  public var description: String {
    return "Changes: column_from:\(column_from ?? -1)"
  }

  public override func setJSONValues(_ values: [String : Any]) {
    let columnDict: [String: Any]? =
      getJSONValue(named: "column_id", from: values, defaultValue: nil)
    self.column_from = columnDict?["from"] as? Int
  }

  public override func getJSONValues() -> [String : Any] {
    return
      [JSONDecoding.objectIdentifierKey:Changes.registerName,
       "column_from": column_from as Any
    ]
  }

}

public class ProjectCard: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "projectCard"

  var content_url: String?
  var column_id: Int = -1

  public var description: String {
    return "ProjectCard: content_url:\(content_url ?? ""), column_id:\(column_id)"
  }

  public override func setJSONValues(_ values: [String : Any]) {
    self.content_url = getJSONValue(named: "content_url", from: values, defaultValue: nil)
    self.column_id = getJSONValue(named: "column_id", from: values, defaultValue: -1)
  }

  public override func getJSONValues() -> [String : Any] {
    return
      [JSONDecoding.objectIdentifierKey:ProjectCard.registerName,
       "content_url": content_url as Any,
       "column_id": column_id
    ]
  }

}
