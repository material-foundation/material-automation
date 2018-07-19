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

class GitHubAppConfig {
  /// The App Engine storage bucket project url.
  let cloudStorageBucket = "material-automation.appspot.com"

  /// The GitHub API base url.
  let githubAPIBaseURL = "https://api.github.com"

  /// The GitHub app ID that will be used for all authentication requests.
  let githubAppId = 10819

  /// The hello message returned by the server's /hello endpoint.
  let helloMessage = "Hello from Material Automation!"

  /// The full path to the GitHub app's PEM file.
  let pemFilePath: String

  /// The user agent that will sign all API requests.
  let userAgent = "Material Automation"

  init() {
    self.pemFilePath =
      GitHubAppConfig.projectRootPath.appendingPathComponent("GithubKey.pem").absoluteString
  }

  static private let projectRootPath: URL = {
    let filePath = #file
    return URL(fileURLWithPath: "/" + filePath.split(separator: "/")
        .dropLast(2).joined(separator: "/") + "/")
  }()
}
