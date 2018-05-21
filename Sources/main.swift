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

routes.add(method: .get, uri: "/_ah/health", handler: { request, response in
  LogFile.info("GET - /_ah/health route handler...")
  response.setBody(string: "OK")
  response.completed()
})

// Basic GET request
routes.add(method: .get, uri: "/hello", handler: { request, response in
  LogFile.info("GET - /hello route handler...")
  response.setBody(string: "Hello from Swift on Google App Engine flexible environment!")
  response.completed()
})

routes.add(method: .post, uri: "/labels/updateall", handler: { request, response in
  LogFile.info("/labels/updateall")

  guard let password = request.header(.authorization),
    GithubAuth.verifyGooglerPassword(googlerPassword: password) else {
      response.completed(status: .unauthorized)
      return
  }
  Threading.getDefaultQueue().dispatch {
    GithubAPI.setLabelsForAllIssues()
  }
  response.completed()
})

routes.add(method: .post, uri: "/webhook", handler: { request, response in
  LogFile.info("/webhook")

  guard let sig = request.header(.custom(name: "X-Hub-Signature")),
    let bodyString = request.postBodyString,
    GithubAuth.verifyGithubSignature(payload: bodyString, requestSig: sig) else {
      LogFile.error("unauthorized request")
      response.completed(status: .unauthorized)
      return
  }
  let githubData = GithubData.createGithubData(from: request.postBodyString!)

  if let PRData = githubData?.PRData {
    // Add Labels to PR flow
    if githubData?.action == "synchronize" || githubData?.action == "opened" {
      var labelsToAdd = [String]()
      let diffURL = PRData.diff_url
      let paths = PRLabelAnalysis.getFilePaths(url: diffURL)
      let labelsFromPaths = PRLabelAnalysis.grabLabelsFromPaths(paths: paths)
      if (labelsFromPaths.count > 1) {
        //notify of changing multiple components
        GithubAPI.createComment(url: PRData.issue_url, comment: "The PR is affecting multiple components.")
      }
      labelsToAdd.append(contentsOf: labelsFromPaths)
      if let titleLabel = PRLabelAnalysis.getTitleLabel(title: PRData.title) {
        labelsToAdd.append(titleLabel)
      } else if labelsFromPaths.count == 1, let label = labelsFromPaths.first {
        //update title
        GithubAPI.editIssue(url: PRData.issue_url, issueEdit: ["title": label + PRData.title])
        //notify of title change
        GithubAPI.createComment(url: PRData.issue_url,
                                comment: "Based on the changes, the title has been prefixed with \(label)")
      }
      if (labelsToAdd.count > 0) {
        GithubAPI.addLabelsToIssue(url: PRData.issue_url, labels: Array(Set(labelsToAdd)))
      }
    }
  } else if let issueData = githubData?.issueData {
    // Add Labels to Issue flow
    if githubData?.action == "synchronize" || githubData?.action == "opened" {
      var labelsToAdd = [String]()
      if let titleLabel = PRLabelAnalysis.getTitleLabel(title: issueData.title) {
        labelsToAdd.append(titleLabel)
      }
      if (labelsToAdd.count > 0) {
        GithubAPI.addLabelsToIssue(url: issueData.url, labels: Array(Set(labelsToAdd)))
      } else {
        GithubAPI.createComment(url: issueData.url, comment: "The title doesn't have a [Component] prefix.")
      }
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

// Set up github credentials
_ = GithubAuth.refreshGithubCredentials()

do {
  // Launch the HTTP server.
  try server.start()
} catch PerfectError.networkError(let err, let msg) {
  LogFile.error("Network error thrown: \(err) \(msg)")
}
