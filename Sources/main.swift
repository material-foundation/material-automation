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
    if githubData?.action == "synchronize" || githubData?.action == "opened" {
      LabelAnalysis.addAndFixLabelsForPullRequests(PRData: PRData)
    }
  } else if let issueData = githubData?.issueData {
    if githubData?.action == "synchronize" || githubData?.action == "opened" {
      LabelAnalysis.addAndFixLabelsForIssues(issueData: issueData)
      LabelAnalysis.addNeedsActionabilityReviewLabel(issueData: issueData)
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
