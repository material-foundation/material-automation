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

  class func movedCard(githubData: GithubData,
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


}
