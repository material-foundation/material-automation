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
    guard let projectName = githubData.project?.name, let url = githubData.url else {
      LogFile.error("No project name or github url")
      return
    }
    // Example of regex match: "2018-06-05 - 2018-06-18".
    let regex = "^[\\d]{4}-[\\d]{2}-[\\d]{2} - [\\d]{4}-[\\d]{2}-[\\d]{2}$"
    guard projectName.range(of: regex, options: .regularExpression, range: nil, locale: nil) != nil,
    let endDate = projectName.components(separatedBy: " - ").last else {
      LogFile.info("The project closed didn't fit the regex")
      return
    }

    // Update project name, reopen project
    guard let projectURL = githubData.project?.url else {
      LogFile.error("couldn't fetch the project URL")
      return
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let lastSprintEndDate = formatter.date(from: endDate),
      let nextSprintStartDate = Calendar.current.date(byAdding: .day, value: 1, to: lastSprintEndDate),
      let nextSprintEndDate = Calendar.current.date(byAdding: .day, value: 13, to: nextSprintStartDate) else {
        LogFile.error("couldn't parse the project date")
        return
    }

    // Rename existing sprint's name to next sprint date and re-open it.
    let nextSprint = formatter.string(from: nextSprintStartDate) + " - " + formatter.string(from: nextSprintEndDate)
    githubAPI.updateProject(projectURL: projectURL, projectUpdate: ["name": nextSprint,
                                                                    "state": "open"])


    // Create a new project to save last sprint's history
    guard let projectID = githubAPI.createNewProject(url: url, name: "New Project") else {
      LogFile.error("The project could not be created")
      return
    }

    githubAPI.updateProject(projectURL: DefaultConfigParams.githubBaseURL + "/projects/" + projectID,
                            projectUpdate: ["name": projectName,
                                            "state": "closed"])

    // Create columns for the new sprint project.
    let backlogID = githubAPI.createProjectColumn(name: "Backlog", projectID: projectID)
    let inProgressID = githubAPI.createProjectColumn(name: "In progress", projectID: projectID)
    let doneID = githubAPI.createProjectColumn(name: "Done", projectID: projectID)

    // Get last sprint's columns.
    guard let columnsURL = githubData.project?.columns_url else {
      LogFile.error("couldn't get the columns URL of the previous sprint")
      return
    }
    let projectColumns = githubAPI.getProjectColumnsCardsURLs(columnsURL: columnsURL)
    for (columnName, cardsURL) in projectColumns {
      if columnName == "In progress" {
        for card in githubAPI.listProjectCards(cardsURL: cardsURL) {
          createCardFromCard(with: card, and: inProgressID, githubAPI: githubAPI)
        }
      } else if columnName == "Backlog" {
        for card in githubAPI.listProjectCards(cardsURL: cardsURL) {
          createCardFromCard(with: card, and: backlogID, githubAPI: githubAPI)
        }
      } else if columnName == "Done" {
        for card in githubAPI.listProjectCards(cardsURL: cardsURL) {
          createCardFromCard(with: card, and: doneID, githubAPI: githubAPI)
          if let cardID = card["id"] as? Int {
            // Remove Done cards from the sprint
            githubAPI.deleteProjectCard(cardID: String(cardID))
          }
        }
      }
    }

  }

  private class func parseCardContentURL(card: [String: Any], githubAPI: GithubAPI) -> (Int?, String?) {
    var (contentID, contentType): (Int, String)
    guard let contentURL = card["content_url"] as? String else {
      return (nil, nil)
    }
    if let issueID = githubAPI.getIssueID(issueURL: contentURL) {
      contentID = issueID
    } else {
      return (nil, nil)
    }
    if contentURL.contains(string: "/issues/") {
      contentType = "Issue"
    } else if contentURL.contains(string: "/pull/") {
      contentType = "PullRequest"
    } else {
      return (nil, nil)
    }
    return (contentID, contentType)
  }

  private class func createCardFromCard(with card: [String: Any],
                                and columnID: String?,
                                githubAPI: GithubAPI) {
    if let columnID = columnID {
      let note = card["note"] as? String
      let cardsURL = DefaultConfigParams.githubBaseURL + "/projects/columns/" + columnID + "/cards"
      let (contentID, contentType) = parseCardContentURL(card: card, githubAPI: githubAPI)
      githubAPI.createProjectCard(cardsURL: cardsURL,
                                  contentID: contentID,
                                  contentType: contentType,
                                  note: note)
    }
  }

}
