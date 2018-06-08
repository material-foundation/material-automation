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
  var project: Project?
  var sender: String?
  public var description: String {
    return "GithubData: \(action), Installation ID: \(installationID ?? "No Installation ID")," +
    "\(PRData?.description ?? "No PR Data"), \(issueData?.description ?? "No Issue Data")"
  }

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

  public override init() {
    super.init()
  }

  init(installation: [String: Any]?,
       action: String,
       PRData: [String: Any]?,
       issueData: [String: Any]?,
       changes: [String: Any]?,
       projectCard: [String: Any]?,
       sender: [String: Any]?) {
    if let installation = installation {
      if let installationNum = installation["id"] as? Int {
        self.installationID = "\(installationNum)"
      }
    }
    self.action = action
    if let PRData = PRData {
      self.PRData = PullRequestData.createPRData(from: PRData)
    }
    if let issueData = issueData {
      self.issueData = IssueData.createIssueData(from: issueData)
    }
    if let changes = changes {
      self.changes = Changes.createChanges(from: changes)
    }
    if let projectCard = projectCard {
      self.projectCard = ProjectCard.createProjectCard(from: projectCard)
    }
    if let sender = sender {
      self.sender = sender["login"] as? String
    }
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
      guard let incoming = try json.jsonDecode() as? [String: Any] else {
        return nil
      }
      return GithubData(installation: incoming["installation"] as? [String: Any],
                        action: incoming["action"] as? String ?? "",
                        PRData: incoming["pull_request"] as? [String: Any],
                        issueData: incoming["issue"] as? [String: Any],
                        changes: incoming["changes"] as? [String: Any],
                        projectCard: incoming["project_card"] as? [String: Any],
                        sender: incoming["sender"] as? [String: Any])
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

  public override init() {
    super.init()
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
  var repository_url: String = ""
  public var description: String {
    return "IssueData: id:\(id), title:\(title), body:\(body), state:\(state)"
  }

  public override init() {
    super.init()
  }

  init(id: Int,
       html_url: String,
       state: String,
       title: String,
       body: String,
       labels: [String],
       url: String,
       repository_url: String) {
    self.id = id
    self.html_url = html_url
    self.state = state
    self.title = title
    self.body = body
    self.labels = labels
    self.url = url
    self.repository_url = repository_url
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

  class func createIssueData(from dict: [String: Any]) -> IssueData? {
    return IssueData(id: dict["id"] as? Int ?? -1,
                     html_url: dict["html_url"] as? String ?? "",
                     state: dict["state"] as? String ?? "",
                     title: dict["title"] as? String ?? "",
                     body: dict["body"] as? String ?? "",
                     labels: dict["labels"] as? [String] ?? [String](),
                     url: dict["url"] as? String ?? "",
                     repository_url: dict["repository_url"] as? String ?? "")
  }

}


/// Changes is a class build from the incoming JSON webhook from GitHub where the field in thr JSON
/// is "changes". This field usually surfaces when there is any change done to an "entity" on GitHub.
/// If it's an issue, a PR, or a project card that has been edited, then changes provide specific
/// information on the change.
public class Changes: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "changes"

  var column_from: Int?
  public var description: String {
    return "Changes: column_from:\(column_from ?? -1)"
  }

  public override init() {
    super.init()
  }

  init(column_id: [String: Any]?) {
    if let column_id = column_id {
      if let column_from = column_id["from"] as? Int {
        self.column_from = column_from
      }
    }
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

  class func createChanges(from dict: [String: Any]) -> Changes? {
    return Changes(column_id: dict["column_id"] as? [String: Any])
  }

}

public class ProjectCard: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "projectCard"

  var content_url: String?
  var column_id: Int = -1
  public var description: String {
    return "ProjectCard: content_url:\(content_url ?? ""), column_id:\(column_id)"
  }

  public override init() {
    super.init()
  }

  init(content_url: String?,
       column_id: Int) {
    self.content_url = content_url
    self.column_id = column_id
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

  class func createProjectCard(from dict: [String: Any]) -> ProjectCard? {
    return ProjectCard(content_url: dict["content_url"] as? String,
                       column_id: dict["column_id"] as? Int ?? -1)
  }

}

public class Project: JSONConvertibleObject, CustomStringConvertible {
  static let registerName = "project"

  var columns_url: String?
  var name: String?
  public var description: String {
    return "Project: columns_url:\(columns_url ?? ""), name:\(name ?? "")"
  }

  public override init() {
    super.init()
  }

  init(columns_url: String?,
       name: String?) {
    self.columns_url = columns_url
    self.name = name
  }

  public override func setJSONValues(_ values: [String : Any]) {
    self.columns_url = getJSONValue(named: "columns_url", from: values, defaultValue: nil)
    self.name = getJSONValue(named: "name", from: values, defaultValue: nil)
  }

  public override func getJSONValues() -> [String : Any] {
    return
      [JSONDecoding.objectIdentifierKey:Project.registerName,
       "columns_url": columns_url as Any,
       "name": name as Any
    ]
  }

  class func createProject(from dict: [String: Any]) -> Project? {
    return Project(columns_url: dict["columns_url"] as? String,
                   name: dict["name"] as? String)
  }

}

