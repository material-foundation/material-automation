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

class PRLabelAnalysis {

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
  class func addAndFixLabelsForIssues(issueData: IssueData) {
    let componentNames = GithubAPI.getDirectoryContentPathNames(relativePath: "/components")
    var labelsToAdd = [String]()
    if let titleLabel = PRLabelAnalysis.getTitleLabel(title: issueData.title) {
      let unbracketedTitleLabel = String(titleLabel.dropFirst().dropLast())
      for name in componentNames {
        if unbracketedTitleLabel == name {
          labelsToAdd.append(titleLabel)
          break
        } else if PRLabelAnalysis.checkIfTwoStringsAreSimilar(str1: name,
                                                              str2: unbracketedTitleLabel,
                                                              threshold: 2) {
          let bracketedName = "[" + name + "]"
          labelsToAdd.append(bracketedName)

          // update title
          if let range = issueData.title.range(of: "]") {
            let titleWithoutLabel = titleLabel[range.upperBound...]
            var updatedTitle = bracketedName
            if titleWithoutLabel.first != " " {
              updatedTitle += " " + titleWithoutLabel
            } else {
              updatedTitle += titleWithoutLabel
            }
            GithubAPI.editIssue(url: issueData.url, issueEdit: ["title": updatedTitle])
            // notify of title change
            GithubAPI.createComment(url: issueData.url,
                                    comment: "Your title label prefix has been renamed from \(titleLabel) to \(bracketedName).")
          }
          break
        }
      }
    }
    if (labelsToAdd.count > 0) {
      GithubAPI.addLabelsToIssue(url: issueData.url, labels: Array(Set(labelsToAdd)))
    } else {
      GithubAPI.createComment(url: issueData.url,
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
  class func addAndFixLabelsForPullRequests(PRData: PullRequestData) {
    var labelsToAdd = [String]()
    let diffURL = PRData.diff_url
    let paths = PRLabelAnalysis.getFilePaths(url: diffURL)
    let labelsFromPaths = Set(PRLabelAnalysis.grabLabelsFromPaths(paths: paths))
    if (labelsFromPaths.count > 1) {
      // notify of changing multiple components
      GithubAPI.createComment(url: PRData.issue_url,
                              comment: "This PR affects multiple components.")
    }
    labelsToAdd.append(contentsOf: labelsFromPaths)
    if let titleLabel = PRLabelAnalysis.getTitleLabel(title: PRData.title) {
      // check if there is a title label but it needs fixing.
      let unbracketedTitleLabel = String(titleLabel.dropFirst().dropLast())
      for label in labelsFromPaths {
        let unbracketedLabel = String(label.dropFirst().dropLast())
        if label == titleLabel {
          break
        } else if PRLabelAnalysis.checkIfTwoStringsAreSimilar(str1: unbracketedLabel,
                                                              str2: unbracketedTitleLabel,
                                                              threshold: 2) {
          if let range = PRData.title.range(of: "]") {
            let titleWithoutLabel = titleLabel[range.upperBound...]
            var updatedTitle = label
            if titleWithoutLabel.first != " " {
              updatedTitle += " " + titleWithoutLabel
            } else {
              updatedTitle += titleWithoutLabel
            }
            GithubAPI.editIssue(url: PRData.issue_url, issueEdit: ["title": updatedTitle])
            // notify of title change
            GithubAPI.createComment(url: PRData.issue_url,
                                    comment: "Your title label prefix has been renamed from \(titleLabel) to \(label).")
          }
          break
        }
      }
    } else if labelsFromPaths.count == 1, let label = labelsFromPaths.first {
      // check if there is no title label and update accordingly.
      var updatedTitle = label + " " + PRData.title
      if let lastChar = PRData.title.last, lastChar != "." {
        updatedTitle += "."
      }
      GithubAPI.editIssue(url: PRData.issue_url, issueEdit: ["title": updatedTitle])
      // notify of title change
      GithubAPI.createComment(url: PRData.issue_url,
                              comment: "Based on the changes, the title has been prefixed with \(label).")
    }
    if (labelsToAdd.count > 0) {
      GithubAPI.addLabelsToIssue(url: PRData.issue_url, labels: Array(Set(labelsToAdd)))
    }
  }

  /// This method gets two strings and uses the Levenshtein Distance algorithm with some
  /// initial constraints to find out how similar they are. It is also given a threshold as to
  /// how similar they can be and returns True if the difference is lower than or equal to the
  /// threshold, and False otherwise. Every deletion/addition/reorder action is worth
  /// 1 "point" of difference.
  ///
  /// - Parameters:
  ///   - str1: The first string to compare. This is the "correct" string that the other string is compared to.
  ///   - str2: The second string to compare.
  ///   - threshold: The given threshold of allowed difference
  /// - Returns: returns true if the strings are similar based on the threshold, and false otherwise.
  class func checkIfTwoStringsAreSimilar(str1: String, str2: String, threshold: Int) -> Bool {
    if str1.isEmpty || str2.isEmpty {
      return false
    }

    var str2 = str2
    if let ind = str2.index(of: str1.first!), ind != str1.startIndex {
      str2 = String(str2[ind...])
    }

    if str2.contains(str1) {
      return true
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
    return distance[str1.count][str2.count] <= threshold
  }

}
