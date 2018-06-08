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
import Foundation
import PerfectLogger
import PerfectCURL

class ProjectAnalysis {

  class func didMoveCard(githubData: GithubData,
                         githubAPI: GithubAPI) {
    guard let fromColumn = githubData.changes?.column_from,
      let toColumn = githubData.projectCard?.column_id,
      let fromColumnName = githubAPI.getProjectColumnName(columnID: fromColumn),
      let toColumnName = githubAPI.getProjectColumnName(columnID: toColumn) else {
        LogFile.error("Couldn't fetch the column ids or column names")
        return
    }

    guard let contentURL = githubData.projectCard?.content_url else {
      LogFile.info("The moved card isn't an issue, won't do any action to it.")
      return
    }
    if let sender = githubData.sender,
      fromColumnName == "Backlog" && (toColumnName == "In progress" || toColumnName == "Done") {
      //assign issue to user
      githubAPI.editIssue(url: contentURL, issueEdit: ["assignees": [sender]])
    }

    if toColumnName == "Done" {
      //close issue
      githubAPI.editIssue(url: contentURL, issueEdit: ["state": "closed"])
    }

    if fromColumnName == "Done" && (toColumnName == "Backlog" || toColumnName == "In progress") {
      //reopen issue
      githubAPI.editIssue(url: contentURL, issueEdit: ["state": "open"])
    }
  }

  class func didCloseProject(githubData: GithubData,
                             githubAPI: GithubAPI) {
    guard let projectName = githubData.project?.name else {
      LogFile.error("No project name")
      return
    }
    // Example of regex match: "2018-06-05 - 2018-06-18"
    let regex = "^[\\d]{4}-[\\d]{2}-[\\d]{2} - [\\d]{4}-[\\d]{2}-[\\d]{2}$"
    guard projectName.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil,
    let endDate = projectName.components(separatedBy: " - ").last else {
      LogFile.info("The project closed didn't fit the regex")
      return
    }
    // Create a new project
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    if let lastSprintEndDate = formatter.date(from: endDate),
      let nextSprintStartDate = Calendar.current.date(byAdding: .day, value: 1, to: lastSprintEndDate),
      let nextSprintEndDate = Calendar.current.date(byAdding: .day, value: 14, to: nextSprintStartDate) {
      
    }

  }


}
