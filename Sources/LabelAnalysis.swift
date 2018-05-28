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

class LabelAnalysis {

  class func getTitleLabel(title: String) -> String? {
    do {
      let regex = try NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
      let nsString = NSString(string: title)

      let results = regex.matches(in: title,
                                  options: [], range: NSMakeRange(0, nsString.length))
      guard let range = results.first?.range else {
        return nil
      }
      return nsString.substring(with: range)
    } catch let error as NSError {
      LogFile.error("invalid regex: \(error.localizedDescription)")
    } catch {
      LogFile.error("\(error)")
    }
    return nil
  }

  class func getFilePaths(url: String) -> [String] {
    var paths = [String]()
    do {
      let contents =
        try CURLRequest(url, .followLocation(true)).perform().bodyString
      print(contents)
      let lines = contents.split(separator: "\n")
      for line in lines {
        if line.starts(with: "+++") {
          let lowerIndex = line.index(line.startIndex, offsetBy: 6)
          let substring = line.substring(with: Range(uncheckedBounds: (lower: lowerIndex,
                                                                       upper: line.endIndex)))
          paths.append(substring)
        }
      }
    } catch {
      LogFile.error("\(error)")
    }
    return paths
  }

  class func grabLabelsFromPaths(paths: [String]) -> [String] {
    var labels = [String]()
    for path in paths {
      if path.starts(with: "components/") {
        let slashed = path.split(separator: "/")
        labels.append("[\(slashed[1])]")
      } else if path.starts(with: "catalog/") {
        labels.append("[Catalog]")
      }
    }
    return labels
  }


  /// This method receives the incoming issue data and adds a [component] label based on the title
  /// prefix of the issue.
  ///
  /// If the [component] title prefix doesn't exist, it writes a comment to notify the submitter.
  ///
  /// If the [component] title prefix isn't entirely accurate, it parses the components/ directory and
  /// finds if there is a close match and updates the title accordingly. It will also notify the
  /// submitter of the change.
  ///
  /// - Parameter issueData: The incoming issue data
  class func addAndFixLabelsForIssues(issueData: IssueData, githubAPI: GithubAPI) {
    let componentNames = githubAPI.getDirectoryContentPathNames(relativePath: "components",
                                                                repoURL: issueData.repository_url)
    var labelsToAdd = [String]()
    let titleLabel = getTitleLabel(title: issueData.title, installation: installation)
    if let titleLabel = titleLabel {
      let unbracketedTitleLabel = String(titleLabel.dropFirst().dropLast())
      // Check if title label is a component name
      if componentNames.contains(unbracketedTitleLabel) {
        labelsToAdd.append(titleLabel)
      } else {
        // Check if it's close to a component name, and then fix it
        var labelDist = [String: Int]()
        for name in componentNames {
          // This isn't a component folder, continue
          if name.lowercased() == name {
            continue
          }
          labelDist[name] = getStringDistance(str1: name.lowercased(),
                                              str2: unbracketedTitleLabel.lowercased())
        }
        // get minimum distance
        let (lbl, dist) = labelDist.reduce(("", Int.max)) { $0.1 > $1.value ? ($1.key, $1.value) : $0 }
        if dist <= 2 {
          let bracketedLabel = "[" + lbl + "]"
          labelsToAdd.append(bracketedLabel)
          // update title
          if let range = issueData.title.range(of: "]") {
            let titleWithoutLabel = issueData.title[range.upperBound...]
            var updatedTitle = bracketedLabel
            if titleWithoutLabel.first != " " {
              updatedTitle += " " + titleWithoutLabel
            } else {
              updatedTitle += titleWithoutLabel
            }
            githubAPI.editIssue(url: issueData.url,
                                issueEdit: ["title": updatedTitle])
            // notify of title change
            githubAPI.createComment(url: issueData.url,
                                    comment: "Your title label prefix has been renamed from \(titleLabel) to \(bracketedLabel).")
          }
        }
      }
    }
    if (labelsToAdd.count > 0) {
      githubAPI.addLabelsToIssue(url: issueData.url,
                                 labels: Array(Set(labelsToAdd)))
    } else if titleLabel == nil {
      githubAPI.createComment(url: issueData.url,
                              comment: "The title doesn't have a [Component] prefix.")
    }
  }


  /// This method receives the incoming pull request data and adds [component] labels based on the
  /// what files have been modified.
  ///
  /// If the [component] title prefix doesn't exist, it writes a comment to notify the submitter, and looks
  /// at the code diff to figure out if there is a change to only one component and updates the title
  /// to have that component's label prefix.
  ///
  /// If the [component] title prefix isn't entirely accurate, it parses the diff and
  /// finds if there is a close match and updates the title accordingly. It will also notify the
  /// submitter of the change.
  ///
  /// If there are multiple components being modified, we will comment to let the submitter know
  /// that multiple components are being modified.
  ///
  /// - Parameter PRData: The incoming pull request data
  class func addAndFixLabelsForPullRequests(PRData: PullRequestData, githubAPI: GithubAPI) {
    var labelsToAdd = [String]()
    let diffURL = PRData.diff_url
    let paths = getFilePaths(url: diffURL)
    let labelsFromPaths = Set(grabLabelsFromPaths(paths: paths))
    if (labelsFromPaths.count > 1) {
      // notify of changing multiple components
      githubAPI.createComment(url: PRData.issue_url,
                              comment: "This PR affects multiple components.")
    }
    labelsToAdd.append(contentsOf: labelsFromPaths)
    if let titleLabel = getTitleLabel(title: PRData.title) {
      // The label in the title isn't part of the changed componentry
      if !labelsFromPaths.contains(titleLabel) {
        // Check if it's close to a component name, and then fix it
        var labelDist = [String: Int]()
        let unbracketedTitleLabel = String(titleLabel.dropFirst().dropLast())
        for label in labelsFromPaths {
          let unbracketedLabel = String(label.dropFirst().dropLast())
          labelDist[label] = getStringDistance(str1: unbracketedLabel.lowercased(),
                                              str2: unbracketedTitleLabel.lowercased())
        }
        // get minimum distance
        let (lbl, dist) = labelDist.reduce(("", Int.max)) { $0.1 > $1.value ? ($1.key, $1.value) : $0 }
        if dist <= 2 {
          labelsToAdd.append(lbl)
          // update title
          if let range = PRData.title.range(of: "]") {
            let titleWithoutLabel = PRData.title[range.upperBound...]
            var updatedTitle = lbl
            if titleWithoutLabel.first != " " {
              updatedTitle += " " + titleWithoutLabel
            } else {
              updatedTitle += titleWithoutLabel
            }
            githubAPI.editIssue(url: PRData.issue_url, issueEdit: ["title": updatedTitle])
            // notify of title change
            githubAPI.createComment(url: PRData.issue_url,
                                    comment: "Your title label prefix has been renamed from \(titleLabel) to \(lbl).")
          }
        }
      }
    } else if labelsFromPaths.count == 1, let label = labelsFromPaths.first {
      // check if there is no title label and update accordingly.
      let updatedTitle = label + " " + PRData.title
      githubAPI.editIssue(url: PRData.issue_url, issueEdit: ["title": updatedTitle])
      // notify of title change
      githubAPI.createComment(url: PRData.issue_url,
                              comment: "Based on the changes, the title has been prefixed with \(label).")
    }
    if (labelsToAdd.count > 0) {
      githubAPI.addLabelsToIssue(url: PRData.issue_url, labels: Array(Set(labelsToAdd)))
    }
  }

  /// This method gets two strings and uses the Levenshtein Distance algorithm
  /// to find out how similar they are. It returns the difference between the two strings
  /// as the number of deletions/additions/reorders needed to reach from one string to another.
  ///
  /// - Parameters:
  ///   - str1: The first string to compare.
  ///   - str2: The second string to compare.
  /// - Returns: the levenshtein difference between the two strings.
  class func getStringDistance(str1: String, str2: String) -> Int {
    if str1.isEmpty || str2.isEmpty {
      return Int.max
    }
    var distance = Array(repeating: Array(repeating: 0, count: str2.count + 1), count: str1.count + 1)
    for i in 1...str1.count {
      distance[i][0] = i
    }
    for j in 1...str2.count {
      distance[0][j] = j
    }
    let arr1 = Array(str1)
    let arr2 = Array(str2)
    for i in 1...str1.count {
      for j in 1...str2.count {
        if arr1[i-1] == arr2[j-1] {
          distance[i][j] = distance[i-1][j-1]
        } else {
          distance[i][j] = min(distance[i-1][j], distance[i][j-1], distance[i-1][j-1]) + 1
        }
      }
    }
    return distance[str1.count][str2.count]
  }

  /// Adds a "Needs actionability review" label to the issue.
  class func addNeedsActionabilityReviewLabel(issueData: IssueData, githubAPI: GithubAPI) {
    let actionabilityLabel = "Needs actionability review"
    if !issueData.labels.contains(where: { $0 == actionabilityLabel }) {
      githubAPI.addLabelsToIssue(url: issueData.url, labels: [actionabilityLabel])
    }
  }
}
