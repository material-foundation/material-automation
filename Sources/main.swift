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
import PerfectLib
import PerfectHTTP
import PerfectHTTPServer
import PerfectLogger
import PerfectThread

#if os(Linux)
srandom(UInt32(time(nil)))
#endif

// Create HTTP server.
let server = HTTPServer()

// Create the container variable for routes to be added to.
var routes = Routes()

// Create GitHub app config.
let config = GithubAppConfig()

routes.add(method: .get, uri: "/_ah/health", handler: { request, response in
  LogFile.info("GET - /_ah/health route handler...")
  response.setBody(string: "OK")
  response.completed()
})

// Basic GET request
routes.add(method: .get, uri: "/hello", handler: { request, response in
  LogFile.info("GET - /hello route handler...")
  response.setBody(string: config.helloMessage)
  response.completed()
})

routes.add(method: .post, uri: "/labels/updateall", handler: { request, response in
  LogFile.info("/labels/updateall")

  guard let password = request.header(.authorization),
    GithubAuth.verifyGooglerPassword(googlerPassword: password) else {
      response.completed(status: .unauthorized)
      return
  }

  var json: [String: Any]
  do {
    json = try request.postBodyString?.jsonDecode() as? [String: Any] ?? [String: Any]()
  } catch {
    response.completed(status: .unauthorized)
    return
  }

  guard let installationID = json["installation"] as? String,
    let repoURL = json["repository_url"] as? String else {
      LogFile.error("The incoming request is missing information: \(json.description)")
      response.completed(status: .unauthorized)
      return
  }

  guard let githubAPI = GithubManager.shared.getGithubAPI(for: installationID) else {
    LogFile.error("could not get a github instance with an access token for \(installationID)")
    response.completed(status: .unauthorized)
    return
  }

  Threading.getDefaultQueue().dispatch {
    githubAPI.setLabelsForAllIssues(repoURL: repoURL)
  }
  response.completed()
})

routes.add(method: .post, uri: "/webhook", handler: { request, response in
  LogFile.info("/webhook")
  Analytics.trackEvent(category: "Incoming", action: "/webhook")

  guard
    let bodyString = request.postBodyString else {
      LogFile.error("unauthorized request")
      response.completed(status: .unauthorized)
      return
  }

  guard let githubData = GithubData.createGithubData(from: bodyString),
  let installationID = githubData.installationID else {
    LogFile.error("couldn't parse incoming webhook request")
    response.completed(status: .ok)
    return
  }

  guard let githubAPI = GithubManager.shared.getGithubAPI(for: installationID) else {
    LogFile.error("could not get a github instance with an access token for \(installationID)")
    response.completed(status: .unauthorized)
    return
  }

  if let PRData = githubData.PRData {
    // Pull Request data received.
    if githubData.action == "synchronize" || githubData.action == "opened" {
      // Pull Request either opened or updated.
      LabelAnalysis.addAndFixLabelsForPullRequests(PRData: PRData,
                                                   githubAPI: githubAPI)
    }

    // Add any opened pull requests to the current sprint.
    if githubData.action == "opened" || githubData.action == "reopened" {
      ProjectAnalysis.addPullRequestToCurrentSprint(githubData: githubData, githubAPI: githubAPI)
    }

  } else if let issueData = githubData.issueData {
    // Issue data received.
    if githubData.action == "opened" {
      // Issue opened.
      LabelAnalysis.addAndFixLabelsForIssues(issueData: issueData,
                                             githubAPI: githubAPI)
      LabelAnalysis.addNeedsActionabilityReviewLabel(issueData: issueData,
                                                     githubAPI: githubAPI)
    }

    let isClientBlockingIssue = issueData.labels.contains(where: { $0 == "Client-blocking" })
    if (githubData.action == "labeled" || githubData.action == "opened")
        && isClientBlockingIssue {
      ProjectAnalysis.addIssueToCurrentSprint(githubData: githubData, githubAPI: githubAPI)
    }

  } else if githubData.projectCard != nil {
    // Project card data received.
    if githubData.action == "moved" {
      // Card moved between columns.
      ProjectAnalysis.didMoveCard(githubData: githubData,
                                  githubAPI: githubAPI)
    }
  } else if githubData.project != nil {
    if githubData.action == "closed" {
      // Project closed
      ProjectAnalysis.didCloseProject(githubData: githubData,
                                      githubAPI: githubAPI)
    }
  }

  var ret = ""
  do {
    ret = try githubData.jsonEncodedString()
  } catch {
    LogFile.error("\(error)")
  }
  response.setHeader(.contentType, value: "application/json")
  response.appendBody(string: ret)
  response.completed()
})

// Add the routes to the server.
server.addRoutes(routes)

// Set a listen port of 8080
server.serverPort = 8080

GithubData.registerModels()

do {
  // Launch the HTTP server.
  try server.start()
} catch PerfectError.networkError(let err, let msg) {
  LogFile.error("Network error thrown: \(err) \(msg)")
}
